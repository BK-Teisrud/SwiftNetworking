import Foundation

/// Builds and authenticates one request without sending, retrying or credential recovery.
public protocol HTTPRequestPreparing: Sendable {
  func prepare(_ request: HTTPRequest) async throws -> URLRequest
}
extension HTTPClient: HTTPRequestPreparing {}
