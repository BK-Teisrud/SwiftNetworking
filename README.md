# Networking

Reusable Swift libraries for HTTP/JSON, file transfers, WebSocket connections, and a persistent offline outbox. Version 0.3.0. Swift 6.0+, iOS 17+, and macOS 13+. Built on Foundation and URLSession with no external package dependencies.

**[Read the complete handbook](Docs/README.md)** for installation, use cases, API contracts, examples, errors, security, application lifecycle, and testing.

| Product | Purpose |
| --- | --- |
| Networking | REST/JSON, raw bytes, response metadata, credential boundaries, bounded retries, deadlines, and diagnostics |
| NetworkingTransfers | File uploads and downloads, streaming multipart encoding, progress, and application-integrated system background transfers |
| NetworkingRealtime | WebSocket events and sending, bounded messages and buffers, heartbeat, and reconnection |
| NetworkingSync | Account-bound persistent FIFO outbox, stable idempotency keys, retry, blocking, and acknowledgement |

Each product is optional. A REST-only application only needs Networking. Transfers and Realtime import the core module; Sync is independent. Applications combine the modules in their own services or repositories. The package provides no global tokens, domain DTOs, login UI, or application navigation.

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

Use `decode` for JSON, `data` for bytes, `execute` for metadata or 204 responses, and `prepare` for controlled adapters. Use Transfers for large files. Realtime events and offline delivery have separate lifecycle contracts.

## Documentation

- [Getting started](Docs/GettingStarted.md)
- [HTTP/JSON, requests, errors, retries, and limits](Docs/HTTP.md)
- [Authentication, caching, and account changes](Docs/Authentication.md)
- [File transfers and background operation](Docs/Transfers.md)
- [WebSocket and realtime](Docs/Realtime.md)
- [Offline outbox and synchronization](Docs/Sync.md)
- [Third-party adapters and module workflows](Docs/Integrations.md)
- [Security and privacy](Docs/Security.md)
- [Testing and troubleshooting](Docs/Testing.md)
- [Complete public API declarations](Docs/API.md)

DocC catalogs are included for every product. Core handbook examples compile as part of the integration test target.

## Important contracts

HTTP requires HTTPS, rejects redirects by default, and requires explicit replay permission for methods with side effects. Authenticated or otherwise sensitive requests are not cached. Allowed redirects forward only an insensitive header allowlist. JSON coders are created for each operation, and diagnostics use a bounded queue with a dropped-event counter.

Foreground file transport performs one send and rejects redirects. Apple background sessions follow redirects automatically, so the background manager requires an explicit trusted-server contract and rejects bearer, API-key, and custom headers. The application owns stable account identifiers, upload-file retention, and the operating system completion-handler bridge.

The WebSocket client is a wire transport, not a complete chat or subscription protocol. The outbox provides at-least-once delivery and requires backend idempotency; the application owns conflict rules, its local database and cursor, scheduling, and account lifecycle. The package does not claim to provide universal exactly-once delivery, OAuth login, an encrypted database, or an SSE parser.

## Verification

```sh
swift build
swift test
```

The test suite uses no public backends. Local macOS fixtures verify real URLSession behavior, cache and account changes, file transfers, and WebSocket handshakes. Sandboxed environments must permit loopback sockets. CI covers the minimum Swift 6.0 toolchain, a current toolchain, and an iOS simulator. Background relaunch behavior must also be verified in a real application on a physical device.

The current public API is versioned as 0.3.0. Before 1.0, minor releases may contain source-breaking changes in accordance with Semantic Versioning.

## License and security

See [security reporting](SECURITY.md). Copyright © 2026 Teisrud Development AS. All rights reserved; see [LICENSE](LICENSE).
