import Foundation

public enum RedirectPolicy: Sendable { case reject, sameOriginWithoutCredentials }
public struct HTTPTransportOptions: Sendable {
  public let allowsCaching: Bool
  public let maximumResponseBytes: Int
  public let discardSuccessBody: Bool
  public let maximumErrorBodyBytes: Int
  public init(
    maximumResponseBytes: Int = 10_485_760, discardSuccessBody: Bool = false,
    maximumErrorBodyBytes: Int = 16_384, allowsCaching: Bool = true
  ) {
    self.allowsCaching = allowsCaching
    self.maximumResponseBytes = maximumResponseBytes
    self.discardSuccessBody = discardSuccessBody
    self.maximumErrorBodyBytes = maximumErrorBodyBytes
  }
}
/// Transports must return redirects without following them. Override bounded send to enforce limits during download.
public protocol HTTPTransport: Sendable {
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions)
    async throws -> HTTPResponse
}
extension HTTPTransport {
  public func send(
    _ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions
  ) async throws -> HTTPResponse {
    var request = request
    if !options.allowsCaching { request.cachePolicy = .reloadIgnoringLocalCacheData }
    let response = try await send(request, redirectPolicy: redirectPolicy)
    guard max(response.data.count, response.receivedBodyBytes) <= options.maximumResponseBytes
    else {
      throw NetworkingError.responseTooLarge(
        limit: options.maximumResponseBytes, metadata: response.metadata)
    }
    if options.discardSuccessBody && (200..<300).contains(response.metadata.statusCode) {
      return .init(
        data: Data(), metadata: response.metadata, receivedBodyBytes: response.receivedBodyBytes)
    }
    return response
  }
}
func sameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
  func port(_ url: URL) -> Int? { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
  return lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
    && lhs.host?.lowercased() == rhs.host?.lowercased() && port(lhs) == port(rhs)
}
