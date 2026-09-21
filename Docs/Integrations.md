# Integrations, signing, and module composition

## API keys and custom authentication

Service-specific API-key headers may be added to `HTTPRequest`. Known API-key names are treated as sensitive and disable caching. Add any provider-specific names to `sensitiveHeaderNames`. Unknown headers are removed during redirects.

Distributed applications cannot keep an embedded key universally secret. Store credentials behind an application-owned secure boundary and never commit real values.

For Basic authentication, HMAC, or other signing, wrap `HTTPTransport` or use `HTTPClient.prepare` and sign the final URL, method, headers, and body. A signing adapter is trusted: it must preserve origin and body semantics, cooperate with cancellation, avoid following redirects internally, and disable caching when it adds credentials. Cryptographic keys and algorithms remain outside this package.

## OAuth and forms

`HTTPBody.form` encodes `application/x-www-form-urlencoded` data and can support noninteractive token endpoints. Browser authorization, PKCE, state, callback handling, client-secret policy, logout, and Keychain storage belong in the authentication layer. Do not perform interactive login inside `CredentialProvider.recover`.

## GraphQL

GraphQL queries and mutations can be sent as ordinary JSON POST requests. HTTP 200 may still contain GraphQL errors, so an application-owned envelope must interpret `data` and `errors`. Normalized caching, schema-generated clients, and subscription protocols are not included. A GraphQL WebSocket protocol requires its own handshake, subscription, acknowledgement, and ping messages on top of NetworkingRealtime.

## Connecting the outbox to HTTP

```swift
let engine = try OutboxEngine(accountID: "account-one", store: store) { item in
    do {
        _ = try await http.execute(HTTPRequest(
            method: .post,
            path: "commands",
            body: .data(item.payload, contentType: "application/json"),
            idempotencyKey: item.idempotencyKey,
            requiresAuthentication: true,
            replayPolicy: .confirmedSafe
        ))
        return .acknowledged
    } catch NetworkingError.http(let failure) {
        switch failure.metadata.statusCode {
        case 400, 422: return .blocked(reason: "validation")
        case 401, 403: return .blocked(reason: "authentication")
        case 409: return .blocked(reason: "conflict")
        case 429: return .blocked(reason: "rateLimited")
        default: throw NetworkingError.http(failure)
        }
    }
}
```

This requires a backend that durably acknowledges operations and truly deduplicates the stable idempotency key. Coordinate HTTP retries with outbox retries to avoid multiplying sends. Interpret 202, 409, and 429 according to the real backend contract.

## Chat with attachments and offline sending

1. Persist the attachment in private storage and place a file reference or hash in the outbox payload.
2. Upload using Transfers or a trusted background presigned URL.
3. Send the message command with a stable identity and idempotency key.
4. Remove queued data and files only after the backend's durable acknowledgement.
5. Use WebSocket for live events and recover reconnect gaps through a backend cursor or REST history.

The application service owns this workflow because backend atomicity, acknowledgement, and storage rules differ between products.
