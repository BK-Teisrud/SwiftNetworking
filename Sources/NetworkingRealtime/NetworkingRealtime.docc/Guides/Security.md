# Security, privacy, and technical boundaries

## Transport boundaries

`HTTPClient` requires HTTPS, rejects base URLs with credentials, query, or fragment, and confines paths to the configured API prefix. Local HTTP is an explicit policy limited to loopback hosts. WebSocket requires `wss` with the equivalent explicit local exception. Foreground files require HTTPS unless local testing is enabled; background transfer supports only HTTPS and system-managed redirects to trusted servers.

No default component trusts all certificates, disables TLS validation, or implements certificate pinning. The application owns ATS, entitlements, container protection, server contracts, and any pinning adapter. Custom transports, connectors, and stores are trusted extensions; `Sendable` does not prove policy compliance.

## Redirects

Redirects are rejected by default. `sameOriginWithoutCredentials` requires replay permission, a remaining shared send budget, the same scheme, host, and effective port, no URL credentials, and a target within the encoded API prefix.

Only explicitly allowed insensitive headers are forwarded. Authorization, Cookie, and Proxy-Authorization are reserved and cannot be added to the allowlist. Sensitive and unknown custom headers are removed. Bearer credentials are not restored after a redirect, and a redirected 401 does not trigger recovery.

Foreground file transport never follows redirects. Apple background sessions always follow redirects, so their manager requires `systemManagedForTrustedServers` and rejects credential or custom headers. Use foreground transfer when origin and credential isolation must be enforced before sending.

## Cache and accounts

The default memory cache is disabled. Authenticated and known-sensitive requests use cache-bypass policy regardless of configured cache settings. Custom signing adapters must also disable caching when they add credentials.

Account changes require cancellation or generation checks for in-flight operations. Clearing a cache cannot stop an already-sent server request or an old result traveling toward the UI. Keep background identifiers, directories, and outbox account IDs separate per account.

## Diagnostics and privacy

Diagnostics contain method, status, duration, attempt, operation ID, a static label, and event kind. Labels must be fixed insensitive names, never user IDs, URLs, or search strings. Paths, queries, request IDs, headers, and bodies are not logged automatically. The queue is bounded and records dropped events.

Response metadata, error descriptions, bounded error bodies, receipts, and downloaded files may still contain sensitive data when the application reads them. The application owns retention, redaction, export, and file-protection policy.

## Persistence and resource limits

Outbox JSON is not encrypted. Account binding detects an incorrect account ID but does not protect a compromised file system. Use private Application Support storage, suitable data protection, and explicit deletion and retention rules.

Default limits include 10 MiB HTTP responses, a 16 KiB error prefix, 500 MiB foreground uploads and downloads, 1,000 outbox items, 1 MiB per outbox payload, a 16 MiB encoded outbox file, 1 MiB realtime messages, and 64 realtime events. These limits do not replace MIME, image, domain, or available-disk validation.

## Intentional exclusions

The package does not include global request deduplication, a global rate-limit scheduler, an OAuth login flow, Keychain storage, an SSE parser, end-to-end chat encryption, a domain conflict resolver, an encrypted database, a GraphQL schema client, guaranteed exactly-once delivery, or universal background resumption. Implement these concerns at the documented adapter and application boundaries and verify backend-specific workflows with integration tests.

## Shared error classification

`NetworkFailures.category(of:)` classifies cancellation, timeout, configuration, policy, authentication, HTTP, encoding, decoding, transport, file-system, and other failures without replacing the original structured error. Classification never decides replay or retry automatically. Custom errors may implement `NetworkFailureClassifying`.
