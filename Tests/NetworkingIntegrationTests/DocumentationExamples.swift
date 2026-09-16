// These handbook examples are compiled by swift test; no public server is contacted.
import Foundation
import Networking
import NetworkingRealtime
import NetworkingSync
import NetworkingTransfers

private struct ProductDTO: Codable, Sendable {
  let id: String
  let title: String
}
private func documentationClients() throws -> (
  HTTPClient, TransferClient, WebSocketClient, OutboxEngine
) {
  let http = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://catalog.example.com/api/")!,
      limits: ClientLimits(operationTimeout: 30),
      coding: JSONCoding(options: .init(keys: .snakeCase, dates: .iso8601)),
      diagnostics: DiagnosticsOptions(queueCapacity: 128)))
  let transfers = TransferClient(
    httpClient: http, transport: URLSessionFileTransferTransport(options: try TransferOptions()))
  let socket = WebSocketClient(options: try .init(maximumConnectionAttempts: 5)) {
    URLRequest(url: URL(string: "wss://chat.example.com/socket")!)
  }
  let file = FileManager.default.temporaryDirectory.appendingPathComponent(
    "documentation-only-outbox.json")
  let store = try FileOutboxStore(fileURL: file, accountID: "account-one")
  let engine = try OutboxEngine(accountID: "account-one", store: store) { item in
    do {
      _ = try await http.execute(
        .init(
          method: .post, path: "commands",
          body: .data(item.payload, contentType: "application/json"),
          idempotencyKey: item.idempotencyKey, requiresAuthentication: true,
          replayPolicy: .confirmedSafe))
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
  return (http, transfers, socket, engine)
}
private struct DocumentationSigningTransport: HTTPTransport {
  let base: any HTTPTransport
  let sign: @Sendable (URLRequest) async throws -> URLRequest
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    try await send(request, redirectPolicy: redirectPolicy, options: .init())
  }
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions)
    async throws -> HTTPResponse
  {
    let signed = try await sign(request)
    try Task.checkCancellation()
    guard signed.url == request.url, signed.httpMethod == request.httpMethod,
      signed.httpBody == request.httpBody
    else {
      throw NetworkingError.invalidRequest("Signer must preserve URL, method and body")
    }
    return try await base.send(
      signed, redirectPolicy: redirectPolicy,
      options: .init(
        maximumResponseBytes: options.maximumResponseBytes,
        discardSuccessBody: options.discardSuccessBody,
        maximumErrorBodyBytes: options.maximumErrorBodyBytes, allowsCaching: false))
  }
}
#if canImport(UIKit)
  import UIKit
  /// Example for a single known account session. A real app uses an account/identifier registry.
  @MainActor private final class DocumentationAppDelegate: NSObject, UIApplicationDelegate {
    private static let sessionIdentifier = "com.example.app.transfers.account-one"
    private var manager: BackgroundTransferManager?
    private var backgroundCompletion: (() -> Void)?
    func application(
      _ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
      completionHandler: @escaping () -> Void
    ) {
      guard identifier == Self.sessionIdentifier else {
        completionHandler()
        return
      }
      backgroundCompletion = completionHandler
      // Report configuration/storage failure in the app.
      do { try restoreManager() } catch { finishBackgroundEvents() }
    }
    private func restoreManager() throws {
      guard manager == nil else { return }
      let support = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0]
      manager = try BackgroundTransferManager(
        identifier: Self.sessionIdentifier,
        directory: support.appendingPathComponent("background-account-one"),
        options: try TransferOptions(),
        redirectPolicy: .systemManagedForTrustedServers,
        onBackgroundEventsFinished: { [weak self] in
          Task { @MainActor in self?.finishBackgroundEvents() }
        })
    }
    private func finishBackgroundEvents() {
      let callback = backgroundCompletion
      backgroundCompletion = nil
      callback?()
    }
  }
#endif
