import Foundation
import Networking

public struct URLSessionWebSocketConnector: WebSocketConnector {
  public let security: ConnectionSecurity
  public let maximumMessageBytes: Int
  public init(security: ConnectionSecurity = .httpsOnly, maximumMessageBytes: Int = 1_048_576) {
    self.security = security
    self.maximumMessageBytes = maximumMessageBytes
  }
  public func open(_ request: URLRequest) async throws -> any WebSocketConnection {
    guard maximumMessageBytes > 0, let url = request.url, let host = url.host, url.user == nil,
      url.password == nil, url.fragment == nil,
      url.scheme?.lowercased() == "wss"
        || (security == .allowLocalHTTP && url.scheme?.lowercased() == "ws"
          && ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased()))
    else {
      throw RealtimeError.invalidConfiguration
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    let delegate = SocketRedirectDelegate()
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    let task = session.webSocketTask(with: request)
    task.maximumMessageSize = maximumMessageBytes
    do {
      try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
          delegate.start(task, continuation: continuation)
        }
      } onCancel: {
        delegate.cancel()
      }
      try Task.checkCancellation()
      return SessionSocket(session: session, task: task)
    } catch {
      session.invalidateAndCancel()
      throw error
    }
  }
}
