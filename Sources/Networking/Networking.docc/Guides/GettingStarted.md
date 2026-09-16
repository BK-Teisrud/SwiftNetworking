# Kom i gang og bruk på tvers av apper

## Installasjon

I Xcode velger du Add Package Dependencies og ditt repository, eller Add Local for denne mappen. Velg produktene appen trenger. URL og versjon kan ikke fylles inn med en påstått release som ikke finnes.

For en annen Swift Package bruker du en lokal dependency:

```swift
// I Package.swift hos konsumenten:
.package(path: "../Networking")
// I dependencies for appens target:
.product(name: "Networking", package: "Networking"),
.product(name: "NetworkingTransfers", package: "Networking"),
.product(name: "NetworkingRealtime", package: "Networking"),
.product(name: "NetworkingSync", package: "Networking")
```

For et remote repository erstatter du path-dependency med din faktiske URL og en eksisterende tag/ref. Produktnavnene er de samme. REST-only apper trenger bare Networking. Transfers og Realtime avhenger av Networking. Sync er selvstendig; modulene avhenger ikke av hverandre.

## Første JSON-kall

```swift
import Foundation
import Networking

struct ProductDTO: Decodable, Sendable {
    let id: String
    let title: String
}
let configuration = try ClientConfiguration(
    baseURL: URL(string: "https://catalog.example.com/api/v1/")!,
    limits: ClientLimits(operationTimeout: 30),
    defaultHeaders: ["Accept": "application/json"]
)
let catalog = HTTPClient(configuration: configuration)
let response = try await catalog.decode(
    HTTPRequest(pathSegments: ["products", "123"], diagnosticLabel: "catalog.detail"),
    as: ProductDTO.self
)
let product = response.value
let requestID = response.metadata.requestID
```

Bruk decode for JSON, data for bytes og execute for metadata/tom suksess. Ikke lag en kunstig Decodable modell for 204. DTO-til-domene-mapping skjer etter responsen, i appen.

## Én klient per backend og policy

```swift
let billing = HTTPClient(configuration: try .init(
    baseURL: URL(string: "https://billing.example.com/v2/")!,
    coding: JSONCoding(options: .init(keys: .snakeCase, dates: .iso8601))
))
```

Klienter er immutable Sendable verdier. De kan deles mellom samtidige tasks. Standardtransporten eier en separat ephemeral URLSession. Ikke opprett en ny REST-klient for hvert kall; behold en klient per backend/policy gjennom en passende appsession.

## Plassering i appen

```text
View / ViewModel
    → appens service eller repository
        → DTO/endpoints + domene-/feilmapping
            → HTTPClient / TransferClient / WebSocketClient / OutboxEngine
                → transport og lagring
```

Appens service-protokoll er vanligvis den beste testgrensen for UI. HTTPTransport er testgrensen for HTTP-regler. Det er ikke nødvendig å samle alle kall på MainActor eller en global actor. UI må selv oppdatere sin MainActor-tilstand etter resultat/progress/events.

## Valgfrie moduler

- Transfers: velg TransferOptions, URLSessionFileTransferTransport og TransferClient. Bruk HTTPRequest når base/policy og bearer skal brukes, URLRequest når URL-en er eksplisitt og signert.
- Realtime: velg WebSocketOptions og en makeRequest closure. Behold WebSocketClient mens streamen er aktiv, og kall disconnect ved skjerm-/session-avslutning.
- Sync: velg privat fileURL, accountID og FileOutboxStore. OutboxEngine tar en deliver closure som beskriver ditt backend-kall og hvordan det bekreftes.

En chatapp kan bruke REST til historikk, Transfers til vedlegg, Realtime til levende meldinger og Sync til en outbox for offline-sending. De fire mekanismene har ulike lifecycle-kontrakter og bør kobles sammen av appens chatservice.
