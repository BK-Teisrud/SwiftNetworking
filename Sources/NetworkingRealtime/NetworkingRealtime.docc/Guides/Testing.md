# Testing, drift, dokumentasjonsbygg og feilsøking

## Vanlige kommandoer

```sh
swift build
swift test
xcrun swift-format lint --strict --recursive Package.swift Sources Tests
```

Tests bruker ingen offentlige servere. macOS inkluderer lokale 127.0.0.1 fixtures for URLSession redirects, cache/kontobytte, timeout/cancellation, filupload/download og WebSocket-handshake. Sandkasser må tillate loopback sockets. Disse testene er macOS-only, mens deterministic module-/HTTPtests også kjøres på simulator.

## Testgrenser

| Grense | Bruk |
| --- | --- |
| HTTPTransport | Returner kontrollerte HTTPResponse/URLError steps og registrer requests |
| RetryClock/jitter | Fast UTC now og observerbare cancellable waits |
| CredentialProvider | Test manglende token, invalid syntax og recovery |
| NetworkingDiagnostics | Registrer events; flush før deterministic assertions |
| FileTransferTransport | Test appens fileworkflow uten nettverk; public result/progress initializers finnes |
| WebSocketConnector/Connection | Simuler handshake-failure, meldinger, ping, send og close |
| OutboxClock | Fast UTC now uten HTTP-avhengighet |
| OutboxStore | Atomic account-bound lagring eller testdobbel; behold ID/key/payload/order |

Custom transports skal gjøre én send per kall, returnere redirects til HTTPClient, respektere bounded options og cancellation. Legacy bridge begrenser etter adapterens nedlasting og kan ikke stoppe et allerede ukontrollert buffer. Verify custom adapters separately.

Outbox crash-/restart-test bør reopen samme file/accountID, bekrefte samme idempotency key etter retry og kontrollere duplicate-ack-kontrakt på backend. Simuler 409/manualblocked, tapt respons, logout, corrupt store og kapasitetsgrense. Kun én engine skal eie delivery for samme store/account.

Realtime test både fast recovery og consumer som ikke klarer bufferen. Size/overflow skal være terminale og ingen send skal replayes automatisk. Test backendens handshake/subscription/ack/cursor i appintegrasjon, ikke bare transportens connected-event.

## CI og simulator

.github/workflows/ci.yml tester Xcode 16.0 (minste Swift 6.0) og Xcode 26.2 på macOS, pluss iOS-simulator. Runner/Xcode-pins må vedlikeholdes mot GitHub runner-image inventory. CI er konfigurert; en lokal kjøring er ikke en påstått grønn remote workflow.

```sh
xcodebuild -scheme Networking-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/networking-derived-data test
```

Velg en faktisk tilgjengelig simulator; CI velger en available iPhone UUID automatisk. iOS 17-deployment bør også bygges separat med SDK/triple minimum. Simulatorruntime på iOS 26.2 er ikke en runtime-test på iOS 17 eller på fysisk enhet.

## API-/DocC-dokumentasjon

`swift Tools/RepositoryTools.swift docs` bygger moduler, genererer symbolgraphs/API.md og konverterer hver modules DocC-catalog til et arkiv. Verktøyet er skrevet i Swift og krever Xcode toolchain; Python og egne shell-skript brukes ikke. Default scratch/output ligger i /tmp; ingen remote publishing skjer. Se API.md for samtlige offentlige declarations. `swift Tools/RepositoryTools.swift api SYMBOLGRAPHS OUTPUT` kan brukes med eksisterende symbolgraphs for å fornye Markdown-snapshot.

DocC module-overviews peker til tekniske guides. Markdownhåndboken er den komplette bruksguiden; API.md er en generert deklarasjonsreferanse. Ikke edit genererte signaturer for å skjule en API-endring. Sentral eksempel-kode i DocumentationExamples.swift kompilerer sammen med modul-testene; ingen dokumentasjonseksempel kontakter en offentlig backend som del av testen.

Eksempler fra pakkens rot:

```sh
swift Tools/RepositoryTools.swift sync --check
swift Tools/RepositoryTools.swift docs --scratch /tmp/networking-doc-build --output /tmp/networking-docs
swift Tools/RepositoryTools.swift distribution
swift Tools/RepositoryTools.swift ios-test
```

`docs --use-shipped-guides` bygger medfølgende guider uten å reparere dem eller oppdatere API.md. `api` krever symbolgraphs for alle fire moduler og avviser ufullstendig extraction. `ios-test` velger en tilgjengelig iPhone i nyeste tilgjengelige iOS-runtime. På GitHub lagres testresultatet under RUNNER_TEMP; lokalt brukes en unik midlertidig resultatmappe.

I en sandkasse som ikke tillater standard module-cache, kan Swift startes med `swift -module-cache-path /tmp/networking-module-cache Tools/RepositoryTools.swift COMMAND`. Dette er kun en lokal kjøreinnstilling.

## Background-verifikasjon i en faktisk app

Verifiser stable identifier/account directory ved relaunch, OS handleEvents completion bridge, receipt recovery uten aktiv UI, filretention, expired presigned URL, cancellation, force-quit og nettverksovergang. System-daemon/background lifecycle kan ikke bevises av en ren SwiftPM mock eller en enkelt foreground URLSession-test. En fysisk enhet og dine faktiske serverkontrakter er nødvendig før et apprelease som avhenger av det.

## Feilsøking

- HTTP 401: sjekk requiresAuthentication/provider og token-validity. ReplayUnsafe POST fornyes ikke automatisk. Header-/Basic-adapter bruker egen Auth-kontrakt.
- Redirect rejected: les RedirectFailure.reason/status, totalbudget og prefix. Ikke slå på forwarding for å omgå en feil URL.
- Tom/ugyldig JSON: les metadata.requestID/status og DecodingFailure.codingPath/kind. Bruk execute for 204.
- Rate limit: respekter Retry-After; maximumDelay betyr maksimum du vil vente, ikke en kortere serverdelay.
- Cache virker ikke: positiv memoryCacheBytes og passende cachePolicy trengs; auth/sensitive requests caches bevisst ikke.
- ResponseTooLarge: velg TransferClient for store filer, eller øk en kjent avgrenset JSON-grense etter behov.
- Outbox stopper: sjekk blocked head/notBefore/maxAttempts. Flush er eksplisitt; ingen automatisk timer/reachability watcher starter.
- Realtime bufferOverflow: consumer er for treg; coalesce/reduser eventarbeid eller bruk passende kapasitet og backendresume.
- Background ferdig men UI mangler data: les receipts, ikke bare live onEvent. Kall OS completion ved finished-events callback.

Benchmark og Thread Sanitizer er ikke en allerede verifisert kontrakt i denne håndboken. Mål filvolum, storestørrelse og reconnect-belastning for appenes faktiske trafikk før tuning.

## Modulstruktur og køvolum

NetworkingTests tester kun HTTP-kjernen. NetworkingTransfersTests tester multipart, fileierskap, cancellation og kvitteringer. NetworkingRealtimeTests tester session-restart med kontrollert close-gate, heartbeat og buffergrense. NetworkingSyncTests tester atomisk lagring, retry, account-isolasjon og en 1000-item kø med 1 KiB payload per item og 100 varige acknowledgements. NetworkingIntegrationTests samler loopback og kompilerbare håndbokeksempler.

Køtesten skriver ut elapsed time som et lokalt mål; den har ingen maskinavhengig tidsassertion. Dette er en correctness-test med måling, ikke et produksjonsbenchmark. JSON-store unngår gjentatt decode under delivery, men persisterer hele gjenværende køen etter hver ack. Mål også appens payloadstørrelser på enhet før valg av databaseadapter. CI bygger DocC med warnings-as-errors på nyere toolchain.

Filstore gjenbruker JSON-encoding for uendrede items mellom atomiske writes. Encoding-cache og snapshot oppdateres sammen først når write lykkes; version-1 filformatet beholdes.

## Dokumentasjon fra ren distribusjon

DocC/Guides inngår nå i distribusjonen og er genererte kopier av Docs. Rediger bare Docs, og kjør `swift Tools/RepositoryTools.swift docs` for API-snapshot og oppdatering av kopiene. `swift Tools/RepositoryTools.swift sync --check` avviser manglende, utdaterte og foreldede artikler. Guidene ignoreres ikke av Git og skal følge samme commit/release som koden.

`swift Tools/RepositoryTools.swift distribution` kopierer kun distribuerbare filer til en tom midlertidig mappe. Den bygger moduler og DocC med warnings-as-errors fra medfølgende guider uten å generere eller reparere guider/API først. CI kjører denne kontrollen på nyere Xcode. En konsument kan derfor bygge katalogen direkte i Xcode uten skjult preprocessing. Swift-verktøyet rydder gamle symbolgraphs før extraction slik at fjernede API-er ikke lever videre i artefakter.
