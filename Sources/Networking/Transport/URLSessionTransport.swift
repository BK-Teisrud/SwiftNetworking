import Foundation

public final class URLSessionTransport: HTTPTransport, Sendable {
  public struct Options: Sendable {
    public let waitsForConnectivity: Bool
    public let allowsExpensiveNetworkAccess: Bool
    public let allowsConstrainedNetworkAccess: Bool
    public let memoryCacheBytes: Int
    public init(
      waitsForConnectivity: Bool = false, allowsExpensiveNetworkAccess: Bool = true,
      allowsConstrainedNetworkAccess: Bool = true, memoryCacheBytes: Int = 0
    ) throws {
      guard memoryCacheBytes >= 0 else {
        throw NetworkingError.invalidConfiguration("Negative cache capacity")
      }
      self.waitsForConnectivity = waitsForConnectivity
      self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
      self.allowsConstrainedNetworkAccess = allowsConstrainedNetworkAccess
      self.memoryCacheBytes = memoryCacheBytes
    }
  }
  private let session: URLSession
  private let router: ResponseRouter
  public convenience init() { self.init(protocolClasses: nil) }
  public convenience init(options: Options) { self.init(protocolClasses: nil, options: options) }
  init(protocolClasses: [AnyClass]?, options: Options? = nil) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = protocolClasses
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCache = options.flatMap {
      $0.memoryCacheBytes > 0 ? URLCache(memoryCapacity: $0.memoryCacheBytes, diskCapacity: 0) : nil
    }
    configuration.urlCredentialStorage = nil
    configuration.requestCachePolicy =
      (options?.memoryCacheBytes ?? 0) > 0 ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
    configuration.waitsForConnectivity = options?.waitsForConnectivity ?? false
    configuration.allowsExpensiveNetworkAccess = options?.allowsExpensiveNetworkAccess ?? true
    configuration.allowsConstrainedNetworkAccess = options?.allowsConstrainedNetworkAccess ?? true
    let router = ResponseRouter()
    self.router = router
    session = URLSession(configuration: configuration, delegate: router, delegateQueue: nil)
  }
  /// Removes cached responses. Account changes also require cancellation/discarding of old operations.
  public func clearCache() { session.configuration.urlCache?.removeAllCachedResponses() }
  public func invalidateAndCancel() { session.invalidateAndCancel() }
  deinit { session.invalidateAndCancel() }
  public func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws
    -> HTTPResponse
  {
    try await send(request, redirectPolicy: redirectPolicy, options: .init())
  }
  public func send(
    _ request: URLRequest, redirectPolicy: RedirectPolicy, options: HTTPTransportOptions
  ) async throws -> HTTPResponse {
    guard request.url != nil, options.maximumResponseBytes > 0, options.maximumErrorBodyBytes >= 0
    else {
      throw NetworkingError.invalidRequest("Invalid transport request or limits")
    }
    let allowsCaching =
      options.allowsCaching && request.cachePolicy != .reloadIgnoringLocalCacheData
      && request.cachePolicy != .reloadIgnoringLocalAndRemoteCacheData
      && request.value(forHTTPHeaderField: "Authorization") == nil
      && request.value(forHTTPHeaderField: "Cookie") == nil
    let collector = ResponseCollector(
      options: .init(
        maximumResponseBytes: options.maximumResponseBytes,
        discardSuccessBody: options.discardSuccessBody,
        maximumErrorBodyBytes: options.maximumErrorBodyBytes,
        allowsCaching: allowsCaching))
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        var boundedRequest = request
        if !allowsCaching { boundedRequest.cachePolicy = .reloadIgnoringLocalCacheData }
        let task = session.dataTask(with: boundedRequest)
        router.register(collector, task: task)
        collector.start(task, continuation: continuation)
      }
    } onCancel: {
      collector.cancel()
    }
  }
}
