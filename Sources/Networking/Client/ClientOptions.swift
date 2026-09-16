import Foundation

/// Shared send, duration and memory limits. Validated when creating ClientConfiguration.
public struct ClientLimits: Sendable {
  public static let standard = Self(
    requestTimeout: 30, operationTimeout: nil,
    maximumTotalAttempts: nil, maximumResponseBytes: 10_485_760, maximumErrorBodyBytes: 16_384)
  public let requestTimeout: TimeInterval
  public let operationTimeout: TimeInterval?
  public let maximumTotalAttempts: Int?
  public let maximumResponseBytes: Int
  public let maximumErrorBodyBytes: Int
  public init(
    requestTimeout: TimeInterval = ClientLimits.standard.requestTimeout,
    operationTimeout: TimeInterval? = nil,
    maximumTotalAttempts: Int? = nil,
    maximumResponseBytes: Int = ClientLimits.standard.maximumResponseBytes,
    maximumErrorBodyBytes: Int = ClientLimits.standard.maximumErrorBodyBytes
  ) {
    self.requestTimeout = requestTimeout
    self.operationTimeout = operationTimeout
    self.maximumTotalAttempts = maximumTotalAttempts
    self.maximumResponseBytes = maximumResponseBytes
    self.maximumErrorBodyBytes = maximumErrorBodyBytes
  }
}
/// Redirect forwarding and credential-header classification, validated by ClientConfiguration.
public struct RedirectOptions: Sendable {
  public static let standard = Self(
    policy: .reject,
    headerAllowlist: [
      "Accept", "Accept-Language", "Content-Type", "Content-Encoding",
    ], sensitiveHeaderNames: ["X-API-Key", "API-Key"])
  public let policy: RedirectPolicy
  public let headerAllowlist: Set<String>
  public let sensitiveHeaderNames: Set<String>
  public init(
    policy: RedirectPolicy = RedirectOptions.standard.policy,
    headerAllowlist: Set<String> = RedirectOptions.standard.headerAllowlist,
    sensitiveHeaderNames: Set<String> = RedirectOptions.standard.sensitiveHeaderNames
  ) {
    self.policy = policy
    self.headerAllowlist = headerAllowlist
    self.sensitiveHeaderNames = sensitiveHeaderNames
  }
}
/// Bounded asynchronous diagnostics; capacity is validated by ClientConfiguration.
public struct DiagnosticsOptions: Sendable {
  public static let standard = Self(sink: nil, queueCapacity: 128)
  public let sink: (any NetworkingDiagnostics)?
  public let queueCapacity: Int
  public init(
    sink: (any NetworkingDiagnostics)? = nil,
    queueCapacity: Int = DiagnosticsOptions.standard.queueCapacity
  ) {
    self.sink = sink
    self.queueCapacity = queueCapacity
  }
}
extension ClientConfiguration {
  /// Grouped configuration. The original initializer remains available for existing consumers.
  public init(
    baseURL: URL, limits: ClientLimits, defaultHeaders: [String: String] = [:],
    coding: JSONCoding = .init(), transport: any HTTPTransport = URLSessionTransport(),
    retry: RetryPolicy = .disabled, credentialProvider: (any CredentialProvider)? = nil,
    redirects: RedirectOptions = .init(), diagnostics: DiagnosticsOptions = .init(),
    cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData,
    security: ConnectionSecurity = .httpsOnly, clock: any RetryClock = SystemRetryClock()
  ) throws {
    try self.init(
      baseURL: baseURL, defaultHeaders: defaultHeaders, timeout: limits.requestTimeout,
      coding: coding, transport: transport, retry: retry, credentialProvider: credentialProvider,
      diagnostics: diagnostics.sink, cachePolicy: cachePolicy, redirectPolicy: redirects.policy,
      security: security, clock: clock, maximumTotalAttempts: limits.maximumTotalAttempts,
      maximumErrorBodyBytes: limits.maximumErrorBodyBytes,
      maximumResponseBytes: limits.maximumResponseBytes, operationTimeout: limits.operationTimeout,
      diagnosticQueueCapacity: diagnostics.queueCapacity,
      redirectHeaderAllowlist: redirects.headerAllowlist,
      sensitiveHeaderNames: redirects.sensitiveHeaderNames)
  }
  public var limits: ClientLimits {
    .init(
      requestTimeout: timeout, operationTimeout: operationTimeout,
      maximumTotalAttempts: maximumTotalAttempts, maximumResponseBytes: maximumResponseBytes,
      maximumErrorBodyBytes: maximumErrorBodyBytes)
  }
  public var redirects: RedirectOptions {
    .init(
      policy: redirectPolicy, headerAllowlist: redirectHeaderAllowlist,
      sensitiveHeaderNames: sensitiveHeaderNames)
  }
}
