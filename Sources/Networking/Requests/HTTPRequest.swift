import Foundation

public struct HTTPRequest: Sendable {
  public let method: HTTPMethod
  let requestPath: RequestPath
  public var path: String {
    if case .encoded(let value) = requestPath { return value }
    return ""
  }
  public var pathSegments: [String]? {
    if case .segments(let values) = requestPath { return values }
    return nil
  }
  public let operationTimeout: TimeInterval?
  public let diagnosticLabel: StaticString?
  public let query: [URLQueryItem]
  public let headers: [String: String]
  public let body: HTTPBody?
  public let idempotencyKey: String?
  public let requiresAuthentication: Bool
  public let replayPolicy: ReplayPolicy
  public let timeout: TimeInterval?
  public let cachePolicy: URLRequest.CachePolicy?
  public init(
    method: HTTPMethod = .get, path: String, query: [URLQueryItem] = [],
    headers: [String: String] = [:], body: HTTPBody? = nil, idempotencyKey: String? = nil,
    requiresAuthentication: Bool = false, replayPolicy: ReplayPolicy = .safeMethodsOnly,
    timeout: TimeInterval? = nil, cachePolicy: URLRequest.CachePolicy? = nil,
    operationTimeout: TimeInterval? = nil, diagnosticLabel: StaticString? = nil
  ) {
    self.method = method
    self.requestPath = .encoded(path)
    self.operationTimeout = operationTimeout
    self.diagnosticLabel = diagnosticLabel
    self.query = query
    self.headers = headers
    self.body = body
    self.idempotencyKey = idempotencyKey
    self.requiresAuthentication = requiresAuthentication
    self.replayPolicy = replayPolicy
    self.timeout = timeout
    self.cachePolicy = cachePolicy
  }
  /// Raw segment values are encoded exactly once; a slash in a value remains within its segment.
  public init(
    method: HTTPMethod = .get, pathSegments: [String], query: [URLQueryItem] = [],
    headers: [String: String] = [:], body: HTTPBody? = nil, idempotencyKey: String? = nil,
    requiresAuthentication: Bool = false, replayPolicy: ReplayPolicy = .safeMethodsOnly,
    timeout: TimeInterval? = nil, cachePolicy: URLRequest.CachePolicy? = nil,
    operationTimeout: TimeInterval? = nil, diagnosticLabel: StaticString? = nil
  ) {
    self.method = method
    self.requestPath = .segments(pathSegments)
    self.query = query
    self.headers = headers
    self.body = body
    self.idempotencyKey = idempotencyKey
    self.requiresAuthentication = requiresAuthentication
    self.replayPolicy = replayPolicy
    self.timeout = timeout
    self.cachePolicy = cachePolicy
    self.operationTimeout = operationTimeout
    self.diagnosticLabel = diagnosticLabel
  }
  var allowsReplay: Bool {
    switch replayPolicy {
    case .confirmedSafe: true
    case .never: false
    case .safeMethodsOnly: method == .get || method == .head
    }
  }
}

enum RequestPath: Sendable {
  case encoded(String)
  case segments([String])
}
