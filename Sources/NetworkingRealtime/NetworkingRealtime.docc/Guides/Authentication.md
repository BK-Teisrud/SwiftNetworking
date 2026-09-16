# Autentisering, kontosession og cache

## CredentialProvider

Protocol krever bearerToken() og recover(rejectedToken:) async throws -> String. Appens Auth-lag eier login, Keychain/tokenlagring, expiry og koordinering. Networking starter aldri interaktiv innlogging.

```swift
import Foundation
import Networking

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

Dette er en enkel adapter, ikke en komplett refresh-koordinator. Actor-reentrancy gjør at to recover-kall kan starte to refresh-kall. Produksjonens Auth-lag må deduplisere refresh, eksempelvis gjennom en delt in-flight refresh-task, og kontrollere token-/konto-generasjon før nytt token installeres. En delt refresh må ha sin egen avgrensede deadline og en definert cancellation-kontrakt.

Tokenet valideres som bearer token-syntaks og sendes bare ved requiresAuthentication. Manglende provider eller ugyldig token feiler før sending. Recovery skjer høyst én gang per HTTP-operasjon, ved 401, hvis replay er tillatt og totalbudsjettet har plass. 403 fornyer ikke. Recovery skjer ikke etter redirect. Kast AuthenticationError for ønsket strukturert kategori; andre provider-errors blir providerFailure. Cancellation/URLError.cancelled bevares som CancellationError.

## Kontobytte og logout

Autentiserte HTTPClient-requests bruker reloadIgnoringLocalCacheData og allowsCaching false, uansett cachePolicy. Dette gjelder også kjent sensitive header-navn; standard sensitiveHeaderNames er X-API-Key og API-Key, og egne navn legges til eksplisitt. Default URLSession blokkerer dessuten cache for en direkte request med Authorization eller Cookie. Legacy/custom transport-adaptere må respektere bounded options-kontrakten.

Dette hindrer gjenbruk av cacheable respons fra en tidligere bearer-konto. Minnecache er fortsatt tilgjengelig for ufølsomme, uautentiserte kall. URLSessionTransport.clearCache() fjerner cached responses, og invalidateAndCancel() avslutter den transportinstansen permanent.

Logout er større enn cachetømming:

1. Endre appens kontogenerasjon og avslutt/discard resultater fra gammel konto.
2. Avbryt gamle UI-/service tasks og WebSocketClient.disconnect().
3. Stopp gammel OutboxEngine flush via task cancellation; velg ny accountID/store.
4. cancelAll på kontoens BackgroundTransferManager og håndter evt. sent leverte completions som gammel kontos data.
5. Tøm cache eller lag en ny klient/transport og ny Auth-adapter for den nye kontoen.

En allerede utført serverhandling kan ikke rulles tilbake ved task cancellation. Appen må skille en avbrutt lokal venting fra backendens faktiske tilstand.

## Auth i de valgfrie modulene

TransferClient med HTTPRequest bruker HTTPClient.prepare og bearer provider. Filoverføring er én send, uten automatisk 401-recovery/replay. Appen kan få nytt token og starte på nytt når serverkontrakten tillater det.

WebSocketClient.makeRequest kjøres ved hver forbindelse/reconnect. Hent et gyldig token der. WebSocketConnector bruker eksplisitt wss URLRequest og legger ikke til base-/auth-headers. Ingen automatisk refresh ved avvist handshake skjer i websocketmodulen.

BackgroundTransferManager tillater ikke bearer/API-key/Cookie-headers fordi systembakgrunn følger redirects automatisk. Bruk en kontrollert presignert URL fra en betrodd server, eller foreground transfers for headerbasert auth. OS-et kan lagre requests/resume-tilstand; bruk app-private storage og tokens med passende scope/levetid.

Outbox skal lagre domenepayload og stabil idempotency key, ikke access-/refresh-tokens. Deliver henter gjeldende credentials ved sending. En accountID-grense beskytter køene mot utilsiktet krysslevering, men krypterer ikke filen og autentiserer ikke kontoen.
