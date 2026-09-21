# Architecture

## Products and dependencies

Networking is the HTTP core. NetworkingTransfers and NetworkingRealtime depend on its request, response, and security contracts. NetworkingSync is independent and uses Foundation plus its own `OutboxClock`. Consumers select products independently; the package creates no global client or application session.

| Area | Responsibility |
| --- | --- |
| Networking/Client | Public operations, operation deadlines, send budgets, retry, recovery, redirects, and diagnostics |
| Networking/Requests | Requests, methods, bodies, JSON coding, validation, and request preparation |
| Networking/Transport | Transport contracts, URLSession, and bounded response collection |
| NetworkingTransfers | File results, progress, foreground transport, background lifecycle, and receipt storage |
| NetworkingRealtime | Messages, events, bounded streams, session ownership, heartbeat, and URLSession connections |
| NetworkingSync | Outbox contracts, versioned storage, FIFO delivery, blocking, retry, and cancellation |

## Ownership and invariants

`WebSocketClient` owns one actor-isolated session. Replacing a stream terminates the previous generation, waits for its worker to close, and prevents stale cleanup from closing a newer session. Custom connections must cooperate with cancellation and close.

The foreground transfer transport owns a downloaded file until it reports success. Ownership then moves to the application, which must remove the file when appropriate. Cancellation never removes an application-owned success file.

The application account or lifecycle coordinator owns `BackgroundTransferManager`. Shutdown rejects new jobs; graceful invalidation allows existing jobs to complete, while cancel invalidation stops them. Retain the manager until callbacks finish and never create parallel sessions with the same identifier.

`FileOutboxStore` owns one lazy snapshot per file and account. A successful atomic write replaces the snapshot; a failed write publishes no change. External writes are unsupported while an instance is alive. Use a database adapter for large or multi-process queues.

## Extension and testing

Use `HTTPRequestPreparing` for request or authentication adapters, `HTTPTransport` for HTTP test doubles, and `FileTransferTransport` for file transport. `ClientLimits`, `RedirectOptions`, and `DiagnosticsOptions` group advanced configuration.

Tests follow product boundaries. Integration tests compile handbook examples and exercise real foreground URLSession behavior against loopback fixtures on macOS. Application services remain responsible for account changes, DTO mapping, chat acknowledgement and resumption, and offline conflict resolution.
