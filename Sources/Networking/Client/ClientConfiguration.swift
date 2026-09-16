import Foundation

public enum ConnectionSecurity: Sendable { case httpsOnly, allowLocalHTTP }

public struct ClientConfiguration: Sendable {
  public let baseURL: URL
  public let defaultHeaders: [String: String]
  public let timeout: TimeInterval
  public let coding: JSONCoding
  public let transport: any HTTPTransport
  public let retry: RetryPolicy
  public let credentialProvider: (any CredentialProvider)?
  public let diagnostics: (any NetworkingDiagnostics)?
  public let cachePolicy: URLRequest.CachePolicy
  public let redirectPolicy: RedirectPolicy
  public let redirectHeaderAllowlist: Set<String>
  public let sensitiveHeaderNames: Set<String>
  public let clock: any RetryClock
  /// Shared cap for all sends, including credential recovery. Defaults to retry.maximumAttempts + 1.
  public let maximumTotalAttempts: Int
  public let maximumResponseBytes: Int
  public let operationTimeout: TimeInterval?
  let diagnosticDispatcher: DiagnosticDispatcher?
  public let maximumErrorBodyBytes: Int
  public init(
    baseURL: URL, defaultHeaders: [String: String] = [:],
    timeout: TimeInterval = ClientLimits.standard.requestTimeout,
    coding: JSONCoding = .init(), transport: any HTTPTransport = URLSessionTransport(),
    retry: RetryPolicy = .disabled, credentialProvider: (any CredentialProvider)? = nil,
    diagnostics: (any NetworkingDiagnostics)? = nil,
    cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalCacheData,
    redirectPolicy: RedirectPolicy = RedirectOptions.standard.policy,
    security: ConnectionSecurity = .httpsOnly,
    clock: any RetryClock = SystemRetryClock(), maximumTotalAttempts: Int? = nil,
    maximumErrorBodyBytes: Int = ClientLimits.standard.maximumErrorBodyBytes,
    maximumResponseBytes: Int = ClientLimits.standard.maximumResponseBytes,
    operationTimeout: TimeInterval? = nil,
    diagnosticQueueCapacity: Int = DiagnosticsOptions.standard.queueCapacity,
    redirectHeaderAllowlist: Set<String> = RedirectOptions.standard.headerAllowlist,
    sensitiveHeaderNames: Set<String> = RedirectOptions.standard.sensitiveHeaderNames
  ) throws {
    guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
      let host = components.host, !host.isEmpty, components.user == nil, components.password == nil,
      components.query == nil, components.fragment == nil
    else {
      throw NetworkingError.invalidConfiguration(
        "Base URL must have an origin and no credentials, query or fragment")
    }
    let local = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased())
    guard
      components.scheme?.lowercased() == "https"
        || (security == .allowLocalHTTP && components.scheme?.lowercased() == "http" && local)
    else {
      throw NetworkingError.invalidConfiguration("HTTPS required; local HTTP needs explicit opt-in")
    }
    try validatePath(components.percentEncodedPath, configuration: true)
    guard TimeLimits.valid(timeout), retry.maximumAttempts > 0, retry.maximumAttempts < Int.max,
      TimeLimits.valid(retry.baseDelay, allowZero: true),
      TimeLimits.valid(retry.maximumDelay, allowZero: true),
      operationTimeout.map({ TimeLimits.valid($0) }) ?? true, maximumResponseBytes > 0,
      diagnosticQueueCapacity > 0,
      (maximumTotalAttempts ?? (retry.maximumAttempts + 1)) > 0, maximumErrorBodyBytes >= 0
    else {
      throw NetworkingError.invalidConfiguration(
        "Invalid timeout, retry limits or error body limit")
    }
    try validateHeaders(defaultHeaders, configuration: true)
    try validateHeaders(
      Dictionary(uniqueKeysWithValues: redirectHeaderAllowlist.map { ($0, "") }),
      configuration: true)
    for name in sensitiveHeaderNames { try validateHeaders([name: ""], configuration: true) }
    self.redirectHeaderAllowlist = Set(redirectHeaderAllowlist.map { $0.lowercased() }).subtracting(
      sensitiveHeaderNames.map { $0.lowercased() })
    self.sensitiveHeaderNames = Set(sensitiveHeaderNames.map { $0.lowercased() })
    self.baseURL = baseURL
    self.defaultHeaders = defaultHeaders
    self.timeout = timeout
    self.coding = coding
    self.transport = transport
    self.retry = retry
    self.credentialProvider = credentialProvider
    self.diagnostics = diagnostics
    self.cachePolicy = cachePolicy
    self.redirectPolicy = redirectPolicy
    self.clock = clock
    self.maximumTotalAttempts = maximumTotalAttempts ?? (retry.maximumAttempts + 1)
    self.maximumErrorBodyBytes = maximumErrorBodyBytes
    self.maximumResponseBytes = maximumResponseBytes
    self.operationTimeout = operationTimeout
    self.diagnosticDispatcher = diagnostics.map {
      DiagnosticDispatcher(sink: $0, capacity: diagnosticQueueCapacity)
    }
  }
}
