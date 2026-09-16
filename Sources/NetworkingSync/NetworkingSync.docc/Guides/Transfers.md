# Filupload, download, multipart og bakgrund

## Foreground filtransport

```swift
import Foundation
import Networking
import NetworkingTransfers

let http = HTTPClient(configuration: try .init(
    baseURL: URL(string: "https://media.example.com/api/")!
))
let transfer = TransferClient(httpClient: http,
    transport: URLSessionFileTransferTransport(options: try TransferOptions()))
let localFile = URL(fileURLWithPath: "/path/in/app/container/photo.jpg")
let response = try await transfer.upload(
    HTTPRequest(method: .post, path: "attachments", headers: ["Content-Type": "image/jpeg"]),
    from: localFile,
    progress: { progress in
        // Callback kommer på transportens queue. Returner raskt.
        // Send en avgrenset/coalesced oppdatering videre til din UI-koordinator.
        _ = progress.fractionCompleted
    }
)
```

Upload bruker URLSession.uploadTask fra en vanlig fil. Filen må være tilgjengelig, regular file og innen maximumUploadBytes. Den må ikke endres eller slettes under overføringen. Request kan ikke også ha HTTPBody/httpBodyStream. Velg passende POST/PUT-metode, Content-Type og idempotency-kontrakt fra serveren.

Download skriver til systemets midlertidige fil og flytter en vellykket 2xx til din destination. Destinasjonen må være en file URL og ikke eksistere. Parent directory opprettes. Filen eies av appen etter vellykket return. Ved feil/cancellation fjernes filer som denne operasjonen selv har flyttet; en eksisterende appfil overskrives ikke.

```swift
let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let downloaded = try await transfer.download(HTTPRequest(path: "exports/latest"), to: destination)
let metadata = downloaded.metadata
// Flytt eller slett filen når appen er ferdig med den.
```

Det lastes ikke en stor downloadbody inn i Data. HTTP-feilbody leses bare som et begrenset prefix fra systemfilen. Ikke bruk HTTPClient.data til store filer.

## API-er og resultat

TransferClient har upload/download-overloads for både HTTPRequest og URLRequest. HTTPRequest bygger base/prefix/default headers og eventuell bearer via HTTPClient.prepare. URLRequest-overload bruker requesten direkte, uten base-headers og uten tokeninnhenting.

FileTransferTransport er test-/adaptergrensen. upload returnerer HTTPResponse, download returnerer DownloadedFile med fileURL, metadata og receivedBodyBytes. TransferProgress har Direction upload/download, completedBytes, optional totalBytes og optional fractionCompleted. Ukjent total gir nil fraction; 0 total gir også nil. Callbacks er synkrone @Sendable og må returnere raskt; nettverk skal ikke vente på UI/export/logger.

Standard foregroundtransport oppretter en isolert ephemeral session per overføring, uten cache/cookies/credential storage. Den gjør én send, følger ikke redirects og har ingen automatisk retry/401-recovery. HTTPRequest-operationTimeout i REST-konfigurasjonen brukes ikke som samlet transferfrist; resourceTimeout i TransferOptions gjelder transportressursen. Tokeninnhenting gjennom prepare har ingen egen deadline. Bruk en kooperativ tidsavgrenset Auth-provider hvis den delen må avgrenses.

| TransferOptions | Default |
| --- | --- |
| maximumUploadBytes | 500 MiB |
| maximumDownloadBytes | 500 MiB |
| maximumResponseBytes | 10 MiB for upload-respons |
| maximumErrorBodyBytes | 16 KiB |
| resourceTimeout | 300 s, finite/positiv og maks ett døgn |
| security | httpsOnly; foreground localHTTP krever eksplisitt opt-in |

Størrelsesgrensene gjelder bytes, ikke pikseloppløsning eller MIME-innhold. Appen må validere bilder, filformat, størrelse og sikker lagringsplass for sitt domene. URLSession progress/chunkgrenser kan oppdage overskridelse etter at siste chunk allerede er mottatt/skrevet; grensen er ikke en reservasjon av diskplass.

TransferError har invalidConfiguration, invalidFile, fileTooLarge(limit:), destinationExists og unexpectedResult. HTTP/status-/redirect-feil bruker NetworkingError; lokale Foundation-/URLSession-I/O-feil kan også kastes. Cancellation er CancellationError fra handleren. Custom transports må selv respektere hele sin beskrevne kontrakt.

## Multipart uten hel-fil-buffering

```swift
let form = MultipartForm(parts: [
    .init(name: "caption", content: .data(Data("Holiday".utf8))),
    .init(name: "image", filename: "photo.jpg", contentType: "image/jpeg", content: .file(localFile))
])
let bodyFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
let encoded = try form.write(to: bodyFile)
defer { try? FileManager.default.removeItem(at: bodyFile) }
let result = try await transfer.upload(
    HTTPRequest(method: .post, path: "attachments", headers: ["Content-Type": encoded.contentType]),
    from: encoded.fileURL
)
```

Part.Content er data eller file. Det genereres en tilfeldig boundary per write. File-delene kopieres i 64 KiB chunks; også framing telles mot maximumBytes (default 500 MiB). Write er synkront og cancellation sjekkes per chunk; store encodings bør utføres utenfor MainActor. Parent opprettes, destination skapes eksklusivt, og delvis output fjernes ved feil. Names/filenames/contentType med controls, quotes eller backslash avvises for å hindre header-injeksjon. Bruk enkle filnavn når backend ikke støtter UTF-8 i quoted Content-Disposition; filename* og andre servervarianter har ingen egen encoder.

Multipart.Encoded har fileURL/contentType/byteCount. Behold outputfilen til overføringen er avsluttet. For bakgrund må den ligge i en persistent app-private directory, ikke en tilfeldig fil som appen rydder underveis.

## Presignerte URL-er og signing

```swift
var signedRequest = URLRequest(url: URL(string: "https://storage.example.com/object?signature=synthetic")!)
signedRequest.httpMethod = "PUT"
signedRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
_ = try await transfer.upload(signedRequest, from: localFile)
```

Eksplisitt URLRequest bevarer URL/query og får ingen katalog-/API-token. Foreground validerer HTTPS og URL uten user/password/fragment; tillatte lokale tests kan velge localHTTP. TLS-validering omgås ikke. Header-/signeringsregler på eksplisitte requests eies av appens signer. Automatisk redirect er av: få en ny godkjent URL fra serveren i stedet for å følge en uventet Location.

## Systembakgrunn og relaunch

BackgroundTransferManager er en app-lifecycle-komponent, ikke en async funksjon som holder UI-tasken levende. Opprett én manager per stable identifier. Identifier og directory må være kontoavgrenset og like etter relaunch. System-taskens taskDescription inneholder en stabil job UUID. Opprett manageren igjen ved OS-event og les receipts for resultater som kom uten en UI-listener.

```swift
let directory = URL(fileURLWithPath: "/path/in/app/container/background-account-one")
let manager = try BackgroundTransferManager(
    identifier: "com.example.app.transfers.account-one",
    directory: directory,
    options: try TransferOptions(),
    redirectPolicy: .systemManagedForTrustedServers,
    onEvent: { event in
        // Callback på delegatequeue. Send til din event-/UI-koordinator.
        _ = event
    },
    onBackgroundEventsFinished: {
        // Appens lifecycle bridge kaller OS completion handler på MainActor.
    }
)
let jobID = try manager.download(URLRequest(url: URL(string: "https://storage.example.com/export?signature=synthetic")!))
```

**Apple følger redirects automatisk i background sessions og kaller ikke redirect-delegaten.** Den eksplisitte BackgroundRedirectPolicy uttrykker denne kontrakten. Backgroundmanageren tillater bare HTTPS og et begrenset sett standardheaders (Accept, Accept-Language, Content-Type, Content-Encoding, User-Agent, Content-Length), uten bearer/API-key/Cookie-headers. Bruk bare kjente betrodde servere/presignerte URLs med passende scopes. Denne manageren gir ikke REST-klientens origin-/prefix-isolasjon for videresending. Foreground brukes når redirect-/credential-garantiene må håndheves før sending.

upload/download returnerer jobID når system-tasken er startet. tasks() gir aktive system-task-ID-er, jobIDs og byteantall. cancel(jobID:) og cancelAll() er eksplisitte avbrudd; serveren kan allerede ha behandlet en upload. invalidateAndCancel avslutter instansen.

BackgroundTransferReceipt lagres atomisk som jobID.receipt.json. Vellykket download ligger som jobID.download. Receipt har jobID, statusCode, fileName, receivedBodyBytes, begrenset responseBody og optional failureCategory. Nil category betyr HTTP-success. responseBody kan dekodes av appen for en upload-respons. Receipts/filer kan inneholde sensitivt innhold og må ha passende appcontainer/file protection og retention.

receipts() leser persisted resultater; acknowledge(jobID:, removeDownloadedFile:) fjerner receipt og valgfritt downloadfil. Fjern ikke en fil appen fortsatt bruker. Et receiptIO-event betyr at diskpersistens feilet: appen må håndtere dette, siden det ikke er en holdbar completionkvittering.

På iOS må application(_:handleEventsForBackgroundURLSession:completionHandler:) gjenopprette riktig manager og lagre OS-handleren. onBackgroundEventsFinished skal videresende til denne handleren på MainActor. AppDelegate/UIApplicationDelegateAdaptor eller din lifecycle-koordinator eier bridgen. Ikke kall OS-handleren bare fordi én enkelt fil er ferdig; vent på sessionens finished-events callback. Background mode/ATS/container-/entitlementvalg eies av appen.

Systemet planlegger backgroundtasks; isDiscretionary gjør tidspunktet mer fleksibelt. resourceTimeout er et systembudsjett, ikke en garanti om start innen et bestemt antall sekunder. Systemet kan gjenoppta downloads internt; pakken eksponerer ikke en egen opaque resumeData-API eller garantert resumption etter appens egen cancellation. User force-quit, URL-expiry og backendstøtte påvirker oppførselen. Behold uploadfilen stabil til receipt foreligger.

Background/relaunch-kontrakten må verifiseres i en faktisk app på enhet. De automatiserte pakketestene verifiserer foregroundfiltransport, multipart og kontraktstyper; de simulerer ikke OS-launch/daemon-handoff.

## Presigned oppsett og request-preparer

```swift
let transfer = TransferClient(
    transport: URLSessionFileTransferTransport(options: try TransferOptions())
)
// Bruk upload/download med en eksplisitt URLRequest fra signeren din.
```

Denne konstruktøren krever ingen HTTPClient/baseURL. HTTPRequest-overloads avvises med invalidRequest hvis preparer mangler. Bruk init(httpClient:transport:) for standard request-/Auth-bygging, eller init(requestPreparer:transport:) med en HTTPRequestPreparing-adapter. Filtransportens separate retry-/deadline-kontrakt gjelder fortsatt.

## Kvitteringsfeil og session-shutdown

BackgroundReceiptStore serialiserer scan/save/acknowledge per directory. Manager.receiptScan() returnerer healthy receipts og issues enkeltvis; issue har fileName og unreadable/invalidReceipt/tooLarge. Corrupt filer beholdes. receipts() returnerer healthy receipts uten å la en enkelt corrupt fil blokkere dem; bruk receiptScan for full feilstatus. Standard max receipt size er 16 MiB. Bodygrense, kvitteringsgrense og diskretention er ulike hensyn.

Manager.finishTasksAndInvalidate() avviser nye jobs og fullfører eksisterende. invalidateAndCancel() avviser og kansellerer. Behold manager til callbacks er levert, og bruk én manager per stable identifier/directory/account. Deinit forespør finish uten å kansellere jobs; explicit app-lifecycle er fortsatt anbefalt. En avsluttet manager kan ikke ta nye jobs. Kvitteringer kan også leses via separat BackgroundReceiptStore etter session-avslutning.

## Konfigurerbar kvitteringsgrense og varig fallback

BackgroundTransferManager har optional receiptStore. Den injiserte BackgroundReceiptStore må ha samme standardized directory som manageren. Velg maximumReceiptBytes som dekker JSON/base64-overhead for ønsket upload-respons: binære bytes blir omtrent 4/3 i JSON, pluss metadata. Standard er 16 MiB, og minimum er 1024 bytes.

Hvis full kvittering er for stor, lagres en liten kvittering med failureCategory receiptTooLarge, tom responseBody og bevart jobID/status/fileName/receivedBodyBytes. Samme kvittering leveres til live listener. Filen beholdes for appens recovery/acknowledgement. Dermed finnes en vedvarende ferdigmelding også etter relaunch. Ved diskfeil kan heller ikke fallback lagres; receiptIO er da et live event og ingen garanti om persistence. receiptTooLarge beskriver kvitteringen, ikke nødvendigvis en mislykket HTTP-operasjon.

```swift
let receipts = try BackgroundReceiptStore(directory: directory,
    maximumReceiptBytes: 32 * 1024 * 1024)
let manager = try BackgroundTransferManager(identifier: identifier, directory: directory,
    options: TransferOptions(maximumResponseBytes: 20 * 1024 * 1024),
    redirectPolicy: .systemManagedForTrustedServers, receiptStore: receipts)
```
