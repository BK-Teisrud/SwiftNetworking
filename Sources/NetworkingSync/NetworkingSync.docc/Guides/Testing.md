# Testing and troubleshooting

```sh
swift build
swift test
```

Tests contact no public server. macOS integration tests use loopback fixtures for redirects, caching, account changes, timeouts, cancellation, file transfers, and WebSocket handshakes. Sandboxes must permit loopback sockets. Deterministic module tests also run on an iOS simulator.

## Test boundaries

| Boundary | Use |
| --- | --- |
| `HTTPTransport` | Return controlled responses or errors and record requests |
| `RetryClock` and jitter | Use fixed UTC time and observable cancellable waits |
| `CredentialProvider` | Exercise missing, invalid, rejected, and recovered tokens |
| `NetworkingDiagnostics` | Record events and flush before deterministic assertions |
| `FileTransferTransport` | Test file workflows without a network |
| `WebSocketConnector` | Simulate handshakes, messages, pings, sends, and close |
| `OutboxClock` | Control scheduling time |
| `OutboxStore` | Test atomic account-bound persistence and identity preservation |

Custom transports must perform one send, expose redirects to `HTTPClient`, respect bounded options, and cooperate with cancellation. Test crash and restart with the same outbox file, idempotency key, and duplicate-ack backend behavior. Test realtime overflow and a slow consumer, not only successful connection.

## Simulator and physical device

```sh
xcodebuild -scheme Networking-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/networking-derived-data test
```

Use an installed simulator. A current simulator runtime does not verify the iOS 17 minimum or physical-device behavior.

Background transfer lifecycle must be verified in a real application on a physical device: relaunch, completion-handler bridging, receipt recovery without active UI, file retention, expired presigned URLs, cancellation, force quit, and network transitions.

## Troubleshooting

- HTTP 401: inspect authentication configuration and replay policy. Unsafe POST requests do not refresh automatically.
- Rejected redirect: inspect the reason, status, total budget, and API prefix.
- Empty or invalid JSON: inspect request ID, status, coding path, and decoding kind. Use `execute` for 204.
- Rate limiting: honor `Retry-After`; never shorten the server's minimum delay.
- Missing cache hit: authenticated and sensitive requests intentionally bypass caching.
- `responseTooLarge`: use Transfers for large files or deliberately raise a known bounded JSON limit.
- Stalled outbox: inspect the head item's block reason, next date, and attempt count.
- `bufferOverflow`: reduce event work, coalesce updates, or increase a justified capacity.
- Missing background UI update: read persistent receipts and complete the OS callback only after the session-finished event.

Benchmark and Thread Sanitizer results are not yet a published support contract. Measure workloads representative of the consuming application.
