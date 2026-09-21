# Getting started across applications

## Installation

In Xcode, choose **Add Package Dependencies** and add:

```text
https://github.com/BK-Teisrud/SwiftNetworking.git
```

Select version 0.3.0, or **Up to Next Minor Version** from 0.3.0, then select the products your application needs.

From another Swift package:

```swift
.package(
    url: "https://github.com/BK-Teisrud/SwiftNetworking.git",
    .upToNextMinor(from: "0.3.0")
)

// In the target dependencies:
.product(name: "Networking", package: "SwiftNetworking"),
.product(name: "NetworkingTransfers", package: "SwiftNetworking"),
.product(name: "NetworkingRealtime", package: "SwiftNetworking"),
.product(name: "NetworkingSync", package: "SwiftNetworking")
```

REST-only applications need only Networking. Transfers and Realtime depend on Networking. Sync is independent.

## First JSON request

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

Use `decode` for JSON, `data` for bytes, and `execute` for metadata or an empty success response. Do not create an artificial `Decodable` type for a 204 response. Map DTOs to domain models in the application after receiving the response.

## One client per backend and policy

```swift
let billing = HTTPClient(configuration: try .init(
    baseURL: URL(string: "https://billing.example.com/v2/")!,
    coding: JSONCoding(options: .init(keys: .snakeCase, dates: .iso8601))
))
```

Clients are immutable, `Sendable` values and may be shared by concurrent tasks. The default transport owns a separate ephemeral URLSession. Keep one client per backend and policy in an appropriate application session instead of creating a client for every request.

## Placement in an application

```text
View / ViewModel
    → application service or repository
        → DTOs/endpoints and domain/error mapping
            → HTTPClient / TransferClient / WebSocketClient / OutboxEngine
                → transport and storage
```

The application service protocol is usually the best UI test boundary. `HTTPTransport` is the test boundary for HTTP behavior. Calls do not need to run on `MainActor`; update UI state on `MainActor` after receiving results, progress, or events.

## Optional modules

- Transfers: use `TransferOptions`, `URLSessionFileTransferTransport`, and `TransferClient`. Use `HTTPRequest` when base URL, policy, and bearer authentication should apply; use `URLRequest` for explicit signed URLs.
- Realtime: provide `WebSocketOptions` and a `makeRequest` closure. Retain the client while its stream is active and disconnect it when the screen or session ends.
- Sync: choose a private file URL, account ID, and `FileOutboxStore`. The delivery closure describes the real backend call and its durable acknowledgement.

A chat application might use REST for history, Transfers for attachments, Realtime for live messages, and Sync for offline sending. The application service combines these mechanisms because each has a different lifecycle contract.
