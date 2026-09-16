import Foundation

public struct HTTPClient: Sendable {
  public let configuration: ClientConfiguration
  public init(configuration: ClientConfiguration) { self.configuration = configuration }

  public func decode<Value: Decodable & Sendable>(_ request: HTTPRequest, as type: Value.Type)
    async throws -> DecodedResponse<Value>
  {
    try await bounded(request) { operationID in
      let response = try await perform(request, operationID: operationID)
      guard !response.data.isEmpty else { throw NetworkingError.emptyResponse(response.metadata) }
      do {
        let value = try configuration.coding.makeDecoder().decode(type, from: response.data)
        try Task.checkCancellation()
        return DecodedResponse(value: value, metadata: response.metadata)
      } catch is CancellationError { throw CancellationError() } catch {
        if Task.isCancelled { throw CancellationError() }
        throw NetworkingError.responseDecoding(.init(error: error, metadata: response.metadata))
      }
    }
  }
  @discardableResult
  public func execute(_ request: HTTPRequest) async throws -> ResponseMetadata {
    try await bounded(request) { operationID in
      try await perform(request, operationID: operationID, discardSuccessBody: true).metadata
    }
  }

  public func data(_ request: HTTPRequest) async throws -> HTTPResponse {
    try await bounded(request) { operationID in try await perform(request, operationID: operationID)
    }
  }
  /// Builds and authenticates one request for an adapter. Does not send, retry or recover credentials.
  public func prepare(_ request: HTTPRequest) async throws -> URLRequest {
    try Task.checkCancellation()
    var result = try RequestBuilder(configuration: configuration).build(request)
    if request.requiresAuthentication {
      guard let provider = configuration.credentialProvider else {
        throw NetworkingError.authentication(.missingProvider)
      }
      let token = try await credential { try await provider.bearerToken() }
      result.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    if request.requiresAuthentication || hasSensitiveHeaders(result) {
      result.cachePolicy = .reloadIgnoringLocalCacheData
    }
    try Task.checkCancellation()
    return result
  }
  func hasSensitiveHeaders(_ request: URLRequest) -> Bool {
    (request.allHTTPHeaderFields ?? [:]).keys.contains {
      configuration.sensitiveHeaderNames.contains($0.lowercased())
    }
  }
  public var droppedDiagnosticEvents: Int { configuration.diagnosticDispatcher?.droppedCount ?? 0 }
  func credential(_ operation: () async throws -> String) async throws -> String {
    do {
      try Task.checkCancellation()
      let token = try await operation()
      try Task.checkCancellation()
      let allowed = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~+/=")
      let unpadded = token.prefix { $0 != "=" }
      guard !unpadded.isEmpty, token.dropFirst(unpadded.count).allSatisfy({ $0 == "=" }),
        token.unicodeScalars.allSatisfy({ allowed.contains($0) })
      else {
        throw AuthenticationError.invalidToken
      }
      return token
    } catch {
      if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled
      {
        throw CancellationError()
      }
      if let error = error as? AuthenticationError { throw NetworkingError.authentication(error) }
      throw NetworkingError.authentication(.providerFailure)
    }
  }

  private func bounded<Value: Sendable>(
    _ request: HTTPRequest, operation: @escaping @Sendable (UUID) async throws -> Value
  ) async throws -> Value {
    let operationID = UUID()
    let start = ContinuousClock.now
    do {
      guard let timeout = request.operationTimeout ?? configuration.operationTimeout else {
        return try await operation(operationID)
      }
      guard TimeLimits.valid(timeout) else {
        throw NetworkingError.invalidRequest("Invalid operation timeout")
      }
      let deadline = start.advanced(by: .seconds(timeout))
      return try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask { try await operation(operationID) }
        group.addTask {
          try await ContinuousClock().sleep(until: deadline)
          throw NetworkingError.deadlineExceeded
        }
        defer { group.cancelAll() }
        let result = try await group.next()!
        try Task.checkCancellation()
        guard ContinuousClock.now < deadline else { throw NetworkingError.deadlineExceeded }
        return result
      }
    } catch {
      let kind: DiagnosticEvent.Kind
      switch error {
      case is CancellationError: kind = .cancelled
      case NetworkingError.deadlineExceeded: kind = .deadlineExceeded
      case NetworkingError.responseDecoding, NetworkingError.emptyResponse: kind = .decodingFailure
      case NetworkingError.redirectRejected, NetworkingError.invalidRequest,
        NetworkingError.responseTooLarge:
        kind = .policyRejected
      case NetworkingError.authentication: kind = .authenticationFailure
      default: kind = .operationFailure
      }
      record(
        method: request.method, status: nil, start: start, attempt: 0, operationID: operationID,
        label: request.diagnosticLabel, kind: kind)
      throw error
    }
  }
  public func flushDiagnostics() async { await configuration.diagnosticDispatcher?.flush() }
  func record(
    method: HTTPMethod, status: Int?, start: ContinuousClock.Instant, attempt: Int,
    operationID: UUID, label: StaticString?, kind: DiagnosticEvent.Kind? = nil
  ) {
    let duration = start.duration(to: .now).components
    configuration.diagnosticDispatcher?.enqueue(
      .init(
        method: method, statusCode: status,
        duration: Double(duration.seconds) + Double(duration.attoseconds) / 1e18, attempt: attempt,
        operationID: operationID, label: label.map(String.init(describing:)),
        kind: kind ?? (status == nil ? .transportFailure : .response)))
  }
}
