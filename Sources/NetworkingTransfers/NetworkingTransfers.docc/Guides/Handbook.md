# Networking — complete handbook

This handbook describes all four library products and their public contracts. Start with the quick start, select only the modules your application needs, and use the API reference for exact declarations.

| Document | Contents |
| --- | --- |
| [Getting started](GettingStarted.md) | Installation, modules, clients, architecture, and the first request |
| [HTTP and JSON](HTTP.md) | Requests, responses, paths, bodies, JSON, errors, retry, and time budgets |
| [Authentication and account sessions](Authentication.md) | Bearer tokens, refresh coordination, account changes, cache, and lifecycle |
| [File transfers](Transfers.md) | Uploads, downloads, multipart, progress, absolute URLs, and system background transfers |
| [Realtime](Realtime.md) | WebSocket events, sending, heartbeat, reconnection, and capacity |
| [Offline and synchronization](Sync.md) | Persistent outbox, idempotency, ordering, retry, and conflict boundaries |
| [Integrations](Integrations.md) | API keys, signing, Basic authentication adapters, forms, GraphQL, and presigned URLs |
| [Security and boundaries](Security.md) | HTTPS, redirects, credentials, storage, resource limits, and privacy |
| [Testing and troubleshooting](Testing.md) | Test adapters, integration tests, and troubleshooting |
| [Complete API reference](API.md) | Public symbols and declarations generated from the Swift modules |

## Choosing a product

| Application need | Product and boundary |
| --- | --- |
| Catalogs, administration, CRUD, and account APIs | Networking for HTTP, JSON, and bounded binary bodies |
| Images, attachments, and exports | NetworkingTransfers for file-based uploads, downloads, and multipart |
| Large or long-running transfers | Foreground file transport or an application-integrated `BackgroundTransferManager` |
| Chat, live updates, and subscriptions | NetworkingRealtime as a WebSocket transport; the application owns the wire protocol and resumption |
| Actions that must survive offline operation or relaunch | NetworkingSync as an account-bound outbox; the backend must deduplicate |
| Third-party HTTPS services | Networking plus service-specific adapters |
| Presigned file URLs | An explicit `URLRequest` in Transfers; the URL and query are preserved without base headers or a token |

The libraries are backend-agnostic. They do not define your DTOs, login UI, database, acknowledgement format, or conflict rules. Share transport and technical contracts between applications while keeping domain rules in application-owned services.

## Platform and distribution

Version 0.3.0 requires Swift 6.0+ and supports iOS 17+ and macOS 13+. It uses Foundation and URLSession with no external package dependencies. Other platforms, including Linux, are not verified support contracts. Background transfers require integration with a real application and operating-system lifecycle.

The declarations in `API.md` are authoritative for the built version. Examples use synthetic origins and must be adapted to your API. `Tests/NetworkingIntegrationTests/DocumentationExamples.swift` compiles the central examples without contacting public servers.

See [Architecture](Architecture.md) for ownership and responsibility boundaries.
