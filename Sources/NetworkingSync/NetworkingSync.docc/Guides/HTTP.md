# HTTP and JSON

## Requests and paths

`HTTPRequest` represents a method, a path, query items, headers, a body, authentication requirements, replay policy, idempotency key, and a static diagnostic label. Prefer `pathSegments` for untrusted identifiers because each segment is encoded separately. Use the encoded `path` form only when the caller deliberately owns the path syntax.

The client resolves requests beneath its configured base URL and API prefix. Absolute request URLs, traversal, URL credentials, and fragments are rejected. Query items are encoded by Foundation; secrets should not be placed in query strings because URLs may appear in application-owned metadata or logs.

```swift
let request = HTTPRequest(
    method: .post,
    pathSegments: ["orders"],
    body: try .json(CreateOrder(productID: "product-123")),
    idempotencyKey: UUID().uuidString,
    requiresAuthentication: true,
    replayPolicy: .confirmedSafe,
    diagnosticLabel: "orders.create"
)
let response = try await client.decode(request, as: OrderDTO.self)
```

Reserved credential headers cannot be supplied through requests. Use `CredentialProvider` or a controlled transport adapter. Header names and values are validated to prevent injection.

## Bodies and JSON coding

`HTTPBody` supports data, JSON, form-encoded fields, and empty bodies. JSON coding uses fresh encoder and decoder instances for each operation. Configure key and date strategies through `JSONCoding`; custom factories must not share mutable coders between concurrent operations.

Use:

- `decode(_:as:)` for bounded JSON responses;
- `data(_:)` for bounded bytes;
- `execute(_:)` when only response metadata matters;
- `prepare(_:)` to build a validated `URLRequest` for a trusted adapter.

Large files belong in NetworkingTransfers. The core HTTP client intentionally buffers a bounded response.

## Responses and errors

`ResponseMetadata` exposes status, headers, final URL, redirect state, and a request ID from `X-Request-ID` or `Request-ID`. Header lookup is case-insensitive. `HTTPResponse.receivedBodyBytes` may exceed `data.count` when a success body is discarded or an error body is truncated.

Non-success responses throw a structured HTTP failure containing bounded body data and metadata. Encoding and decoding failures preserve useful structured context. Use `NetworkFailures.category(of:)` for cross-module presentation or telemetry while retaining the original error for policy decisions.

## Retry, replay, deadlines, and cancellation

Retries are disabled by default. `RetryPolicy` supports bounded attempts, exponential delay, optional jitter, selected status codes, and `Retry-After`. Server minimum delays are never shortened. A shared `maximumTotalAttempts` budget covers initial sends, retries, redirects, and credential recovery.

Safe methods may replay according to policy. Side-effect methods require explicit replay permission and usually a backend-supported idempotency key. A header alone does not make a backend idempotent.

The per-request timeout belongs to URLSession. `operationTimeout` is a wall-clock budget for the complete operation, including credential lookup, waits, retries, redirects, decoding, and diagnostics scheduling. Cancellation is checked at operation boundaries and is surfaced as `CancellationError`.

## Redirect policy

Redirects are rejected by default. The optional same-origin policy requires the same scheme, host, and effective port, keeps the target inside the encoded API prefix, and strips credentials and all headers outside the insensitive allowlist. Method rewriting follows HTTP status semantics. See [Security](Security.md) for the complete contract.

## Diagnostics and caching

Diagnostics are asynchronous and bounded so a slow sink does not block networking. Call `flushDiagnostics()` only as an export or test barrier. Static diagnostic labels must not contain user input.

The default memory cache is disabled. A positive capacity and a suitable cache policy enable caching for insensitive unauthenticated requests. Authenticated or sensitive requests always bypass caching. Cache clearing is not an account-switch strategy by itself; cancel or generation-check in-flight work as well.
