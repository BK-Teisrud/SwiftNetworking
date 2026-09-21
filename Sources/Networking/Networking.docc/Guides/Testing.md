# Testing og feilsøking

## Vanlige kommandoer

```sh
swift build
swift test
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

## Simulator og enhet

```sh
xcodebuild -scheme Networking-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/networking-derived-data test
```

Velg en faktisk tilgjengelig simulator. En nyere simulatorruntime er ikke en runtime-test på iOS 17 eller på fysisk enhet.

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
