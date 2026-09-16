# HTTP, requests, JSON og feil

## Offentlige hovedoperasjoner

| Operasjon | Resultat | Kontrakt |
| --- | --- | --- |
| decode(request, as:) | DecodedResponse<Value> | 2xx og ikke-tom JSON, Value: Decodable & Sendable |
| data(request) | HTTPResponse | 2xx, bytes og metadata |
| execute(request) | ResponseMetadata | Alle 2xx, også 204; suksessbody beholdes ikke i standardtransport |
| prepare(request) | URLRequest | Bygger og autentiserer én request; sender ikke, ingen recovery/retry/egen deadline |
| flushDiagnostics() | Void | Eksplisitt venting til køen er idle; sinken må returnere |
| droppedDiagnosticEvents | Int | Antall events droppet ved full kø, delt av konfigurasjonskopier |

prepare er en adaptergrense for filtransport og signing. En request med token er sensitiv og må ikke logges eller lagres ukritisk. Kallet bruker ClientConfiguration sin URL-/header-policy; en adapter må bevare disse garantiene.

## HTTPRequest

HTTPMethod er en case-sensitive RawRepresentable token med get/post/put/patch/delete/head/options. `HTTPMethod(rawValue: "PROPFIND")` returnerer nil ved tom metode eller ugyldige tegn. At et token er gyldig betyr ikke at URLSession eller serveren støtter metodens særlige protokollkrav. Replay er automatisk tillatt bare for eksakt GET/HEAD.

HTTPRequest er en immutable beskrivelse. Den har metode, relativ path eller rå pathSegments, query, headers, body, idempotencyKey, requiresAuthentication, replayPolicy, timeout, cachePolicy, operationTimeout og diagnosticLabel. Se API.md for begge initializer-signaturene og defaultverdiene.

### Paths

```swift
let request = HTTPRequest(pathSegments: ["users", "alice/bob%:id"])
// Under https://example.com/api/:
// https://example.com/api/users/alice%2Fbob%25%3Aid
```

Bruk rå pathSegments for dynamiske ID-er. Hvert segment encodes én gang. Legacy `path:` er en relativ path som bevarer allerede gyldige percent-escapes per segment. Bokstavelig prosent foran to hex-sifre må oppgis som %25 i legacy path. Kolon, query, fragment, scheme/host-endring, backslash, controls og traversal avvises i legacy paths.

Base-prefix og avsluttende slash bevares. Tom path bevarer base-path; en tom base-path representeres som /. Segmenter og paths valideres mot traversal også gjennom nested ASCII percent-decoding. En rå ID som etter flere decodinglag blir dot-traversal kan derfor avvises. Ikke bruk pathSegments for å smugle inn en ferdig encoded hel path.

### Query

```swift
let request = HTTPRequest(path: "search", query: [
    .init(name: "q", value: "red & blue + café"),
    .init(name: "tag", value: "new"),
    .init(name: "tag", value: "sale")
])
```

Rekkefølge og gjentatte navn bevares. URLComponents encoder query; plus encodes til %2B. En nil query-value følger URLQueryItem/URLComponents sin nøkkel-uten-verdi-kontrakt. For presignerte URL-er som må bevares byte for byte brukes eksplisitt URLRequest i filmodulen eller en kontrollert adapter.

### Headers

Request-headers overstyrer defaultHeaders case-insensitivt. JSON/data body's contentType bestemmer Content-Type. idempotencyKey overstyrer Idempotency-Key når oppgitt. Authorization, Proxy-Authorization, Cookie, Host og Content-Length er reserverte i ClientConfiguration/HTTPRequest. Ugyldige navn, duplikater med ulik casing og controls i values avvises.

DefaultHeaders bør være ufølsomme. API-nøkler i egne headers kan brukes, men registrer egendefinerte sensitive navn i sensitiveHeaderNames. redirectHeaderAllowlist er en eksplisitt allowlist; ukjente headers fjernes ved tillatt redirect.

## Bodies

```swift
struct CreateDTO: Encodable, Sendable { let title: String }
let json = HTTPRequest(method: .post, path: "items", body: .json(CreateDTO(title: "Chair")))
let binary = HTTPRequest(method: .put, path: "blob",
    body: .data(Data([1, 2, 3]), contentType: "application/octet-stream"))
let form = HTTPRequest(method: .post, path: "token", body: .form([
    .init(name: "grant_type", value: "client_credentials"),
    .init(name: "scope", value: "catalog read")
]))
```

JSON krever Encodable & Sendable. data ligger allerede i minnet. form er UTF-8 application/x-www-form-urlencoded: spaces blir +, literal plus blir %2B, nil values blir tom streng, og duplicate names/order bevares. Encoding-feil blir requestEncoding; ingen sending skjer etter en slik feil. Store filer bør bruke Transfers.

## JSONCoding

Options har Keys standard/snakeCase og Dates deferred/iso8601/secondsSince1970/millisecondsSince1970. Standard er Foundations default keys og deferred-to-Date. Options lager nye kodere hver gang.

```swift
let coding = JSONCoding(options: .init(keys: .snakeCase, dates: .iso8601))
```

For spesialkontrakter angis både makeEncoder og makeDecoder. Hver factory må lage en ny instans og ikke dele mutable kodere mellom tasks. ISO8601 følger Foundation-strategiens aksepterte format; bruk egen factory for andre datoformer, eksempelvis fraksjonelle sekunder som serverkontrakten krever. Coding velges per klient, ikke per request.

## Responser og metadata

ResponseMetadata har statusCode, headers, url og wasRedirected, case-insensitiv header(name), og requestID fra X-Request-ID eller Request-ID. HTTPResponse har data, metadata og receivedBodyBytes. Det siste kan være større enn data.count ved forkastet suksessbody eller begrenset feilbody. Custom transports må oppgi et korrekt, ikke-negativt antall.

DecodedResponse har value og metadata. 2xx inkluderer 202 og 206: pakken tolker ikke en 202 som ferdig backend-jobb eller samler partial-content automatisk. Appen eier polling, pagination og range-sammenstilling. Manuell 304 håndteres som HTTP-feil i standardoperasjonene; URLSession sin egen cache kan revalidere automatisk.

## Feil

| NetworkingError | Tilhørende verdi og betydning |
| --- | --- |
| invalidConfiguration | Tekst om ugyldig baseURL, grenser eller headers |
| invalidRequest | Tekst om ugyldig request/path/header/timeout |
| requestEncoding | Tekst om body-encoding-feil |
| transport | TransportFailure med NSError domain, code, description og opptil åtte Causes |
| timeout | URLSession/URLError timedOut |
| deadlineExceeded | Samlet HTTP-operasjonsfrist overskredet |
| responseTooLarge | Grense og tilgjengelig metadata |
| http | HTTPFailure med metadata, body og bodyWasTruncated |
| emptyResponse | Metadata fra en tom 2xx-respons når decode ble brukt |
| responseDecoding | DecodingFailure med metadata, kind, codingPath og description |
| authentication | AuthenticationError missingProvider/invalidToken/rejected/providerFailure |
| redirectRejected | RedirectFailure reason og metadata |
| invalidResponse | Transporten leverte ugyldig HTTP-/origin-respons |

DecodingFailure.Kind er keyNotFound/valueNotFound/typeMismatch/dataCorrupted/other. CodingPath representerer array-indekser som [n]. RedirectFailure.Reason er policyDenied/replayUnsafe/attemptLimit/invalidLocation/unapprovedOrigin/credentialsInURL/outsideAPIPrefix/unsafePath/retryAfterExceedsLimit.

CancellationError er vanlig Swift-kansellering, ikke en NetworkingError. Appen kan velge backendens feilformat fra HTTPFailure.body. Metadata, body og descriptions kan inneholde persondata eller secrets; de logges ikke automatisk.

## Retry og replay

Standard RetryPolicy er disabled, maximumAttempts 1. Aktiv defaultpolicy dekker 408/429/500/502/503/504 og URLError timedOut/networkConnectionLost. 400/401/403, cancellation og encoding/decoding er aldri vanlig retry. Andre status-/transportkoder kan velges, men disse unntakene gjelder fortsatt.

ReplayPolicy safeMethodsOnly tillater GET/HEAD. confirmedSafe bekrefter en serverkontrakt om gjentakelse for andre metoder. never hindrer retry, credential recovery og redirects. Idempotency key er metadata og gjør ikke en operasjon automatisk replay-safe.

maximumAttempts inkluderer initial sending og avgrenser vanlige retries. maximumTotalAttempts avgrenser alle sendinger, også redirects og én mulig credential recovery; default retry.maximumAttempts + 1. Retry av/total 1 gir én sending; retry av/default total 2 gir plass til én recovery eller redirect; retry 3/total 4 gir aldri mer enn fire sendinger samlet.

Backoff er eksponentiell, base 0,5 s, ceiling 30 s, full jitter. Retry-After kan være heltallssekunder eller IMF-fixdate/RFC850/asctime. Gyldig venting over maximumDelay gir ingen ny sending; HTTP-feilen returneres. Tillatte redirects venter også på gyldig Retry-After, eller avvises med retryAfterExceedsLimit. Ugyldig header faller tilbake til backoff. Injiser RetryClock/jitter for tester.

## Tid og størrelsesgrenser

Request-timeout er 30 s som default, overstyrbar per request. operationTimeout er en optional monoton frist rundt building/encoding, credentials, transport, retries og decoding; request kan velge en annen positiv frist. Nil requestverdi arver klientfristen. Det finnes ingen request-sentinel som deaktiverer en aktiv klientfrist; bruk en passende annen klientpolicy eller positiv override.

Tidsverdier må være finite og innen ett døgn; request-/operasjonsfrister positive, retry-delays kan være 0. Duration-overflow avvises før sleep. Deadline bruker strukturert task cancellation og kan ikke avbryte synkron kode eller en adapter som ignorerer cancellation. SystemRetryClock sjekker også ugyldige direkte sleep-argumenter.

Default totalrespons er 10 MiB og feilbody 16 KiB. Default URLSession kontrollerer deklarert lengde og mottatte chunks. HEAD bruker ikke representasjonens Content-Length som bodygrense. execute teller mottatte bytes uten å lagre en suksessbody. Custom transports må override bounded send for inkrementell beskyttelse; legacy-broen kontrollerer først etter nedlasting og bevarer mottatt byteantall ved discard.

## Grupperte konfigurasjonsvalg

```swift
let client = HTTPClient(configuration: try ClientConfiguration(
    baseURL: URL(string: "https://example.com/api/")!,
    limits: ClientLimits(requestTimeout: 15, operationTimeout: 30,
        maximumTotalAttempts: 3, maximumResponseBytes: 2_097_152),
    redirects: RedirectOptions(policy: .sameOriginWithoutCredentials),
    diagnostics: DiagnosticsOptions(queueCapacity: 128)
))
```

ClientLimits grupperer request-/operasjonsfrister, total sendgrense og bodygrenser. RedirectOptions grupperer policy, forwarding-allowlist og sensitive headernavn. DiagnosticsOptions grupperer sink og køkapasitet. Alle verdier valideres av ClientConfiguration; options oppretter ingen tasks/sessions selv. limits er eksplisitt i den grupperte konstruktøren, slik at den opprinnelige konstruktøren fortsatt kan brukes uten overload-ambiguity. `ClientConfiguration(baseURL: url)` er fortsatt det korte standardoppsettet.

HTTPRequestPreparing er den smale adaptergrensen for prepare; HTTPClient implementerer den. Protokollen sender ikke og lover ikke retry/recovery eller en egen deadline.

## Eksporterte sensitive requests

prepare bruker samme sensitive-headerregel som vanlige klientkall: bearer og registrerte sensitive headers overstyrer cachePolicy til reloadIgnoringLocalCacheData. URLSessionTransport hindrer både cachelesing og lagring for denne policyen, eller når HTTPTransportOptions.allowsCaching er false. En adapter må respektere begge signalene; en request-policy alene styrer ikke nødvendigvis lagring i en egendefinert transport. prepare har fortsatt ingen sending/recovery eller egen operasjonsfrist.

Standardverdier eies av ClientLimits.standard, RedirectOptions.standard og DiagnosticsOptions.standard. Den opprinnelige konstruktøren og de grupperte options bruker de samme verdiene.
