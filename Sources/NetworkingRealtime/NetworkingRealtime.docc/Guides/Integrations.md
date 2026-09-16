# Tredjepart, signing og samspill mellom modulene

## REST og API-nøkler

```swift
let request = HTTPRequest(path: "weather", headers: ["X-API-Key": "synthetic-key"])
```

Pakken forbyr manuelle Authorization/Cookie-headers i HTTPRequest, men en egen API-key-header er tillatt. X-API-Key/API-Key er default sensitiveHeaderNames og deaktiverer HTTP-caching. Legg til andre navn når serveren bruker en annen header. Ukjente headers fjernes ved redirect fordi forwarding bruker en allowlist. Query-baserte secrets gjenkjennes ikke automatisk som sensitive; de bør ikke caches eller logges, og en query kan inngå i metadata.url.

Bruk appens secure secret/token-grense; ingen faktisk key tilhører dokumentasjon/repository. En nøkkel innebygd i en distribuert app er ikke et universelt skjult serversecret.

## Signing etter URL/body-bygging

HTTPClient.prepare gir den ferdige URLRequest for en adapter. HTTPTransport er også en grense for signing av sendte HTTP-requests. Signeren må få de eksakte bytes/headers serveren signerer, og må respektere replay, cancellation og origin-policy.

```swift
import Foundation
import Networking

struct SigningTransport: HTTPTransport {
    let base: any HTTPTransport
    let sign: @Sendable (URLRequest) async throws -> URLRequest
    func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
        try await send(request, redirectPolicy: redirectPolicy, options: .init())
    }
    func send(_ request: URLRequest, redirectPolicy: RedirectPolicy,
              options: HTTPTransportOptions) async throws -> HTTPResponse {
        let signed = try await sign(request)
        try Task.checkCancellation()
        guard signed.url == request.url, signed.httpMethod == request.httpMethod,
              signed.httpBody == request.httpBody else {
            throw NetworkingError.invalidRequest("Signer must preserve URL, method and body")
        }
        // En signer kan legge til sensitive auth-headers: slå av caching her.
        let bounded = HTTPTransportOptions(
            maximumResponseBytes: options.maximumResponseBytes,
            discardSuccessBody: options.discardSuccessBody,
            maximumErrorBodyBytes: options.maximumErrorBodyBytes,
            allowsCaching: false
        )
        return try await base.send(signed, redirectPolicy: redirectPolicy, options: bounded)
    }
}
```

Dette er en komplett adapterkontrakt, ikke en AWS/HMAC/OAuth-signaturimplementasjon. sign-closure er din leverandørspesifikke signer og keys eies av appens sikkerhetslag. Avanserte stream-signere krever en egnet fil/stream-adapter, ikke denne Data-baserte HTTP-body-kontrakten. En custom transport er en betrodd utvidelse; ikke endre origin eller følg redirects internt.

Basic-auth kan implementeres i en slik adapter ved å sette Authorization etter building. HTTPRequest.requiresAuthentication skal da være false; bearer-provider-kontrakten brukes ikke som Basic-login. URLSessionTransport deaktiverer cache for Authorization og beholder TLS-validering. Password storage, expiry og 401-policy er integrasjonens ansvar. Cookie-session-biblioteker trenger en egen bevisst cookie-aware adapter; default transport lagrer ingen cookies.

## OAuth og form-urlencoded

HTTPBody.form encoder fields for application/x-www-form-urlencoded, eksempelvis et ikkeinteraktivt token-endepunkt. OAuth-autoriseringsflyt, browser callback, PKCE/state, client-secret-policy, logout og Keychain er Auth-lagets ansvar. Ikke lag interaktiv login i CredentialProvider.recover.

JSON endpoints brukes med HTTPBody.json og JSONCoding passende for serveren. Custom HTTPMethod støtter gyldige metodenavn som OPTIONS/PROPFIND, men gjør ikke URLSession til en komplett WebDAV-/CONNECT-protokollmotor.

## GraphQL

Vanlige GraphQL-query/mutation-kall kan representeres som POST med JSON-konvolutt (query, variables og optional operationName). GraphQL kan returnere HTTP 200 med errors i JSON: decode er da en vellykket HTTP-decode, og appens GraphQL-envelope må tolke errors/data. Normalisert entity-cache, querybuilder og subscriptions er ikke innebygget. WebSocket-protokoller som graphql-transport-ws krever appens handshake/subscription/ping-message-logikk oppå Realtime.

## Knytt OutboxEngine til HTTP

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

Eksemplet forutsetter en backend som faktisk støtter stabil idempotency key og bekrefter handlingen før 2xx. Hvis 202 betyr en varig backend-jobb som først senere blir acked, må din delivery avvente eller lagre jobID i en appstyrt flyt. confirmedSafe velges ikke ut fra at eksemplet har en key.

store/http opprettes som vist i de andre kapitlene. Payload-formatet velges av appen. 429 block er en konservativ eksempelpolicy som unngår å overse serverens Retry-After; appen kan implementere korrekt sekund-/HTTP-dato-tolkning og reschedule når den vet minimumsventingen. Ikke avkort en lang serverventing til et tidligere retry. 409 og andre semantiske konflikter trenger appens løsning før retryBlocked.

Når outbox eier retries er det ofte hensiktsmessig med HTTP retry disabled og et lite maximumTotalAttempts/operationTimeout. Backend-koordinerte rate limits mellom samtidige klientkall er ikke en automatisk global throttle.

## Chat med vedlegg og offline-send

1. Persistér vedlegget i appcontainer og lagre en filreferanse/hash i outboxpayload.
2. Last opp filen med TransferClient eller trusted background/presigned URL. Backend må deduplisere retry av samme vedlegg hvis nødvendig.
3. Send meldingscommand med stabil ID/idempotency key.
4. Oppdater lokal optimistisk melding først etter serverack, og slett kø/fil først når serverkontrakten tillater det.
5. Bruk WebSocket til live-events. Ved reconnect resubscribe og hent gap via backendcursor/REST-historikk.

Pakken setter ikke sammen disse fem trinnene automatisk fordi backendens atomisitets-/ack-/lagringsregler varierer. En appservice er riktig sted for workflowen.
