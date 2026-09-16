# Networking

Gjenbrukbare Swift-biblioteker for HTTP/JSON, filoverføring, WebSocket og en vedvarende offline-outbox. Swift 6.0+, iOS 17+, macOS 13+. Foundation/URLSession, uten eksterne biblioteksavhengigheter.

**[Les den komplette håndboken](Docs/README.md)** — installasjon, alle bruksområder, API-kontrakter, eksempler, feil, sikkerhet, app-lifecycle, tester og migrering.

| Produkt | Bruk |
| --- | --- |
| Networking | REST/JSON, rå bytes, metadata, credentials-grense, bounded retry, deadline og diagnostikk |
| NetworkingTransfers | Upload fra fil, download til fil, streaming multipart-encoding, progress og appintegrert systembakgrunn |
| NetworkingRealtime | WebSocket events/send, bounded messages/buffer, heartbeat og reconnect |
| NetworkingSync | Account-bound persisted FIFO outbox, stabile idempotency keys, retry/block/ack |

Produktene er valgfrie. En REST-only app trenger bare Networking. Transfers og Realtime importerer kjernen. Sync er selvstendig. Modulene kan kombineres av appens service/repository. Ingen globale tokens, domene-DTO-er eller login-UI brukes.

```swift
import Foundation
import Networking

struct ProductDTO: Decodable, Sendable { let id: String; let title: String }
let client = HTTPClient(configuration: try .init(
    baseURL: URL(string: "https://catalog.example.com/api/")!,
    operationTimeout: 30
))
let response = try await client.decode(
    HTTPRequest(pathSegments: ["products", "123"]), as: ProductDTO.self
)
```

Bruk decode for JSON, data for bytes, execute for metadata/204 og prepare for kontrollerte adaptere. Store filer bruker Transfers. Realtime-events og offline-delivery har egne lifecycle-kontrakter.

## Dokumentasjon

- [Kom i gang](Docs/GettingStarted.md)
- [HTTP/JSON, requests, feil, retry og grenser](Docs/HTTP.md)
- [Autentisering, cache og kontobytte](Docs/Authentication.md)
- [Filoverføringer og bakgrunn](Docs/Transfers.md)
- [WebSocket/realtime](Docs/Realtime.md)
- [Offline/outbox og synkronisering](Docs/Sync.md)
- [Tredjepartsadaptere og modul-workflows](Docs/Integrations.md)
- [Sikkerhet og personvern](Docs/Security.md)
- [Testing, drift og dokumentasjonsbygg](Docs/Testing.md)
- [Migrering og release](Docs/Migration.md)
- [Alle offentlige API-deklarasjoner](Docs/API.md)

DocC-catalogs finnes for alle produkter. `swift Tools/RepositoryTools.swift docs` genererer API-referanse og DocC-arkiver lokalt, uten publishing. Sentrale håndbokeksempler kompileres i testtargetet.

## Viktige kontrakter

HTTP bruker HTTPS, avviser redirects som standard og krever eksplisitt replay for sideeffektmetoder. Autentiserte/sensitive HTTP-requests caches ikke. Tillatte redirects forwarder bare en ufølsom header-allowlist. JSONkodere opprettes ferskt og diagnostikk leveres med bounded kø/drop-teller.

Foregroundfiltransport gjør én send og avviser redirects. Apple-backgroundsessions følger redirects automatisk; backgroundmanageren krever en eksplisitt trusted-server-kontrakt og avviser bearer/API-key/custom headers. Appen eier stable kontoidentifikator, uploadfilretention og OS completion-handler-bridge.

WebSocket-klienten er en wire-transport, ikke en ferdig chat-/subscriptionprotokoll. Outbox er at-least-once delivery og krever backend-idempotency; appen eier konfliktregler, lokal database/cursor, scheduler og kontolifecycle. Ingen universell exactly-once, OAuth-login, kryptert database eller SSE-parser påstås inkludert.

## Verifikasjon

```sh
swift build
swift test
```

Ingen offentlige backends brukes i testsuiten. Lokale macOS-fixtures verifiserer ekte URLSession, cache/kontobytte, filoverføringer og WebSocket-handshake. Testene trenger lokale socketrettigheter i sandkasser. CI dekker minimum Swift 6.0, nyere toolchain og iOS-simulator. Bakgrunn/relaunch må dessuten verifiseres i faktiske apper på enhet.

Ingen release eller tag er publisert. Se [CHANGELOG](CHANGELOG.md) og migreringskapitlet før oppgradering; særlig HTTPMethod, cache-/redirect-policy og tidligere NetworkingError payloads har endret kontrakt.

## Repository og rettigheter

Se [GitHub-oppsett og publisering](Docs/Repository.md), [videreutvikling](CONTRIBUTING.md) og [sikkerhetsrapportering](SECURITY.md). Copyright © 2026 Teisrud Development AS. Alle rettigheter forbeholdt; se [LICENSE](LICENSE).
