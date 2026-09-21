# Authentication, account sessions, and caching

## CredentialProvider

`CredentialProvider` supplies a bearer token and may recover once after a rejected token. The application's authentication layer owns login, Keychain storage, expiry, refresh deduplication, deadlines, and account-generation checks. Networking never starts interactive login.

```swift
actor AppCredentials: CredentialProvider {
    private var token: String
    private let refresh: @Sendable (String) async throws -> String

    init(token: String, refresh: @escaping @Sendable (String) async throws -> String) {
        self.token = token
        self.refresh = refresh
    }

    func bearerToken() async throws -> String { token }

    func recover(rejectedToken: String) async throws -> String {
        if token != rejectedToken { return token }
        token = try await refresh(rejectedToken)
        return token
    }
}
```

This minimal adapter does not deduplicate concurrent refreshes. Production authentication code should share an in-flight refresh task and verify the account generation before installing a new token.

Bearer syntax is validated before sending. Recovery occurs at most once per operation after a 401, only when replay is permitted and the total send budget has capacity. A 403 does not refresh. Recovery is disabled after a redirect. Cancellation remains `CancellationError`.

## Account changes and logout

Authenticated requests and requests with known sensitive headers bypass caching. `URLSessionTransport.clearCache()` removes cached responses, while `invalidateAndCancel()` permanently shuts down that transport instance.

Logout requires more than clearing a cache:

1. Advance the application's account generation and reject results from the old account.
2. Cancel old UI and service tasks and disconnect WebSockets.
3. Cancel the old outbox flush and select a store with the new account ID.
4. Cancel account-specific background transfers and classify late callbacks as old-account data.
5. Clear the cache or create a new client, transport, and credential adapter.

Cancellation cannot undo a server action that already completed.

## Optional modules

Transfers prepared from `HTTPRequest` use the HTTP client's bearer provider, but file transfer performs one send without automatic 401 recovery. WebSocket request creation runs for each connection and should obtain a current token. Background transfers reject bearer, API-key, and cookie headers because system sessions follow redirects; use tightly scoped presigned URLs for trusted servers.

Outbox payloads must contain domain data and stable idempotency keys, never access or refresh tokens. The delivery closure obtains current credentials when it sends.
