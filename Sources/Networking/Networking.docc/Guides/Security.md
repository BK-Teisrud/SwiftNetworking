# Sikkerhet, personvern og tekniske grenser

## Transportgrenser

HTTPClient krever HTTPS, ingen base-user/password/query/fragment og et konfigurert API-prefix. allowLocalHTTP er eksplisitt og bare localhost/127.0.0.1/::1. WebSocket krever wss, med tilsvarende eksplisitt lokal ws-policy. Foreground files krever HTTPS, optional local HTTP. Bakgrunn støtter bare HTTPS og system-managed redirects mot betrodde servere.

Ingen defaultkomponent aksepterer "trust all" TLS, deaktiverer certificate validation eller leverer certificate pinning. Appen eier ATS, entitlements, appcontainer, serverkontrakter og eventuell separat pinning-adapter. HTTPTransport/FileTransferTransport/WebSocketConnector/OutboxStore er betrodde utvidelser; Sendable beviser ikke at en adapter respekterer sikkerhetspolicyen.

## HTTP redirects

Standard reject gjelder autentiserte og uautentiserte requests. sameOriginWithoutCredentials krever tillatt replay, ledig felles totalbudsjett, samme scheme/host/effektiv port, ingen URL-credentials og path innen encoded API-prefix. Target valideres mot traversal.

Forwarding kopierer bare redirectHeaderAllowlist, default Accept/Accept-Language/Content-Type/Content-Encoding. Authorization/Cookie/Proxy-Authorization er reserverte og kan ikke velges som request-/allowlist-headers gjennom konfigurasjon. Sensitive headernavn trekkes også fra allowlisten. Ukjente API-key-/customheaders fjernes. Det er et bevisst brudd med eldre forwarding som beholdt ukjente headers.

301/302 POST og 303 non-HEAD blir GET uten body/Content-Type/Content-Encoding. 307/308 bevarer method/body når replay er bekreftet. Bearer-token gjeninnføres ikke på redirect og 401 etter redirect gir ingen recovery. Flere sends teller mot samme SendBudget.

Foregroundfiltransport følger aldri redirects. Backgroundmanagerens redirect-callback kan ikke håndheve dette fordi Apples backgroundsessions alltid følger redirections. Den krever eksplisitt systemManagedForTrustedServers og avviser credential/custom headers. Velg foreground når origin-/credential-isolasjon må håndheves før sending. Denne forskjellen må ikke skjules av et felles policy-navn.

## Cache og konto

Standard minnecache er av. Positiv kapasitet og riktig cachePolicy trengs for ufølsomme requests. Autentisert/bekreftet sensitive HTTP bruker reloadIgnoringLocalCacheData og bounded allowsCaching false. Direkte URLSessionTransport requests med Authorization/Cookie caches heller ikke. Custom/key-signing adapters må slå av caching for auth de legger til etter building.

Account changes krever også avbrudd/generasjonssjekk av aktive operasjoner. Cachetømming stopper ikke et allerede sendt serverkall eller et gammelt resultat på vei til UI. Kontospecifikke background IDs/directories og outbox accountID må holdes adskilt.

## Diagnostikk

DiagnosticEvent inneholder method/statusCode/duration/attempt/operationID/label/kind. operationID er tilfeldig per HTTP-operasjon og korrelerer retry/redirect/terminal event. StaticString diagnosticLabel skal være et fast ufølsomt navn, ikke en bruker-ID, URL eller søkestreng. Attempt 0 brukes for terminal operasjonsfeil; andre events er sends. Kind er response/transportFailure/cancelled/decodingFailure/deadlineExceeded/policyRejected/authenticationFailure/operationFailure.

Duration er ContinuousClock monotontid. RetryClock.now er UTC Date for HTTP-date/retry. Paths/queries/request-ID/headers/body logges ikke automatisk. Queue capacity default 128 pending events; overflow drop-newest øker droppedDiagnosticEvents. Én worker leverer til sink, og en treg sink blokkerer ikke nettkallet. flushDiagnostics er en eksportbarriere, ikke en cancellable UI-venting med egen deadline, og trenger en sink som returnerer.

Metadata.url, error descriptions, HTTPFailure.body og saved response/filer kan fortsatt være sensitive når appen leser dem. Retention, redaction og eksportpolicy eies av appen. Background receipts lagrer ikke URL/headers/error descriptions, men bounded responseBody og downloadfil kan inneholde persondata.

## Persistence og ressurser

Outbox JSON er ikke kryptert. Account binding beskytter feil konto-ID, ikke et kompromittert filsystem. Velg app-private Application Support, passende NSFileProtection/protection-at-rest og delete-/retention-policy. Behold uploadfiler stabile gjennom foreground/background overføringer. Begrens diskbruk; limits garanterer ikke fri diskplass.

HTTP response 10 MiB/error prefix 16 KiB er defaults. Foreground file limits er 500 MiB per upload/download. Multipart counts inkluderer framing. Outbox maks 1000 items/1 MiB payload/16 MiB encoded file. Realtime maks 1 MiB per message/64 events. Options gjør dette eksplisitt og bounded; limits er ikke en erstatning for MIME-/image-/domenevalidering.

Ferske JSON options er trygge standarder. Custom factories må ikke dele mutable encoder/decoder. @unchecked Sendable-klasser i default delegates bruker lock eller dokumentert serial delegatequeue; ingen appdeler trenger unchecked for å bruke modulene.

## Bevisste avgrensninger

Ingen global request-dedup, global rate-limit scheduler, URLSessionTaskMetrics exporter, OAuth-login, Keychain, SSE-parser, E2E chatkryptering, domeneconflict resolver, encrypted database, GraphQL schema-client, garantert exactly-once eller universell background-resumption inngår. Disse behovene kan implementeres med respektive adapter-/appgrenser. Biblioteket kan brukes på tvers av apper, men backendspesifikke workflows krever faktisk integrasjonstest.

## Felles feilklassifisering

NetworkFailures.category(of: error) gir cancelled, timeout, configuration, policy, authentication, http, encoding, decoding, transport, fileSystem eller other. NetworkingError, AuthenticationError, TransferError og RealtimeError implementerer NetworkFailureClassifying. Rå CancellationError/URLError og kjente Foundation I/O-feil klassifiseres også. Originalfeilen og strukturerte payloads beholdes; kategorien avgjør ikke replay/retry automatisk. Task.isCancelled er fortsatt viktig når en custom adapter kaster en annen feil samtidig med cancellation.

```swift
catch {
    switch NetworkFailures.category(of: error) {
    case .cancelled: break
    case .timeout: /* vis appens timeout-handling */ break
    case .authentication: /* la appens Auth-service håndtere */ break
    default: /* inspiser originalfeil/status/metadata */ break
    }
}
```

Custom network-feil kan implementere NetworkFailureClassifying. Sync er selvstendig: lokale SyncError-cases håndteres direkte, mens HTTP-delivery bruker samme nettverksklassifisering i appens adapter.
