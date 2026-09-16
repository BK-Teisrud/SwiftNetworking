import Foundation

extension HTTPClient {
  func perform(_ request: HTTPRequest, operationID: UUID, discardSuccessBody: Bool = false)
    async throws -> HTTPResponse
  {
    try Task.checkCancellation()
    let original = try RequestBuilder(configuration: configuration).build(request)
    var token: String?
    if request.requiresAuthentication {
      guard let provider = configuration.credentialProvider else {
        throw NetworkingError.authentication(.missingProvider)
      }
      token = try await credential { try await provider.bearerToken() }
    }
    var nextRequest = original
    var redirected = false
    var budget = SendBudget(maximum: configuration.maximumTotalAttempts)
    var retries = 0
    var recovered = false
    while true {
      try Task.checkCancellation()
      let attempt = budget.take()
      var urlRequest = nextRequest
      if !redirected, let token {
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      }
      if request.requiresAuthentication || hasSensitiveHeaders(urlRequest) {
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
      }
      let start = ContinuousClock.now
      try Task.checkCancellation()
      let response: HTTPResponse
      do {
        let raw = try await configuration.transport.send(
          urlRequest, redirectPolicy: configuration.redirectPolicy,
          options: .init(
            maximumResponseBytes: configuration.maximumResponseBytes,
            discardSuccessBody: discardSuccessBody,
            maximumErrorBodyBytes: configuration.maximumErrorBodyBytes,
            allowsCaching: !request.requiresAuthentication && !hasSensitiveHeaders(urlRequest)))
        response = HTTPResponse(
          data: raw.data,
          metadata: .init(
            statusCode: raw.metadata.statusCode,
            headers: raw.metadata.headers, url: raw.metadata.url,
            wasRedirected: redirected || raw.metadata.wasRedirected),
          receivedBodyBytes: raw.receivedBodyBytes)
        try Task.checkCancellation()
      } catch {
        let mapped = mapTransportError(error)
        record(
          method: HTTPMethod(rawValue: urlRequest.httpMethod ?? "") ?? request.method, status: nil,
          start: start, attempt: attempt, operationID: operationID, label: request.diagnosticLabel)
        try Task.checkCancellation()
        if request.allowsReplay, budget.hasRemaining,
          retries < configuration.retry.maximumAttempts - 1, retryable(mapped)
        {
          retries += 1
          nextRequest = original
          redirected = false
          if try await pause(attempt: retries, retryAfter: nil) { continue }
        }
        throw mapped
      }
      record(
        method: HTTPMethod(rawValue: urlRequest.httpMethod ?? "") ?? request.method,
        status: response.metadata.statusCode, start: start, attempt: attempt,
        operationID: operationID, label: request.diagnosticLabel)
      try Task.checkCancellation()
      if let url = response.metadata.url, !sameOrigin(configuration.baseURL, url) {
        throw NetworkingError.invalidResponse
      }
      let status = response.metadata.statusCode
      if [301, 302, 303, 307, 308].contains(status),
        let location = response.metadata.header("Location")
      {
        let target = try redirectTarget(
          location, response: response, request: request,
          current: urlRequest, hasBudget: budget.hasRemaining)
        guard
          try await pause(
            attempt: 1, retryAfter: response.metadata.header("Retry-After"), onlyWhenPresent: true)
        else {
          throw NetworkingError.redirectRejected(
            .init(reason: .retryAfterExceedsLimit, metadata: response.metadata))
        }
        nextRequest = urlRequest
        nextRequest.url = target
        for header in nextRequest.allHTTPHeaderFields?.keys ?? [String: String]().keys {
          if !configuration.redirectHeaderAllowlist.contains(header.lowercased()) {
            nextRequest.setValue(nil, forHTTPHeaderField: header)
          }
        }
        nextRequest.httpShouldHandleCookies = false
        if (status == 303 && urlRequest.httpMethod != "HEAD")
          || ([301, 302].contains(status) && urlRequest.httpMethod == "POST")
        {
          nextRequest.httpMethod = "GET"
          nextRequest.httpBody = nil
          nextRequest.setValue(nil, forHTTPHeaderField: "Content-Type")
          nextRequest.setValue(nil, forHTTPHeaderField: "Content-Encoding")
        }
        redirected = true
        continue
      }
      if (200..<300).contains(status) {
        return HTTPResponse(
          data: response.data,
          metadata: .init(
            statusCode: status, headers: response.metadata.headers,
            url: response.metadata.url, wasRedirected: redirected || response.metadata.wasRedirected
          ), receivedBodyBytes: response.receivedBodyBytes)
      }
      if status == 401, !redirected, !response.metadata.wasRedirected, let tokenUsed = token,
        !recovered,
        request.allowsReplay,
        budget.hasRemaining,
        let provider = configuration.credentialProvider
      {
        recovered = true
        token = try await credential { try await provider.recover(rejectedToken: tokenUsed) }
        continue
      }
      if request.allowsReplay, budget.hasRemaining,
        retries < configuration.retry.maximumAttempts - 1,
        ![400, 401, 403].contains(status), configuration.retry.statusCodes.contains(status)
      {
        retries += 1
        nextRequest = original
        redirected = false
        if try await pause(attempt: retries, retryAfter: response.metadata.header("Retry-After")) {
          continue
        }
      }
      throw NetworkingError.http(
        .init(
          metadata: response.metadata,
          body: Data(response.data.prefix(configuration.maximumErrorBodyBytes)),
          bodyWasTruncated: response.receivedBodyBytes > configuration.maximumErrorBodyBytes))
    }
  }
  private func mapTransportError(_ error: any Error) -> any Error {
    if error is CancellationError || Task.isCancelled { return CancellationError() }
    if let error = error as? URLError {
      if error.code == .cancelled { return CancellationError() }
      if error.code == .timedOut { return NetworkingError.timeout }
      return NetworkingError.transport(.init(error: error))
    }
    if let error = error as? NetworkingError { return error }
    return NetworkingError.transport(.init(error: error))
  }
  private func retryable(_ error: any Error) -> Bool {
    guard let error = error as? NetworkingError else { return false }
    switch error {
    case .timeout: return configuration.retry.transportCodes.contains(URLError.timedOut.rawValue)
    case .transport(let failure):
      return failure.domain == NSURLErrorDomain
        && configuration.retry.transportCodes.contains(failure.code)
    default: return false
    }
  }
  private func pause(attempt: Int, retryAfter: String?, onlyWhenPresent: Bool = false) async throws
    -> Bool
  {
    try Task.checkCancellation()
    if onlyWhenPresent && retryAfter == nil { return true }
    let now = await configuration.clock.now()
    guard let delay = configuration.retry.delay(attempt: attempt, retryAfter: retryAfter, now: now)
    else { return false }
    try await configuration.clock.sleep(for: delay)
    try Task.checkCancellation()
    return true
  }
  private func redirectTarget(
    _ location: String, response: HTTPResponse, request: HTTPRequest,
    current: URLRequest, hasBudget: Bool
  ) throws -> URL {
    func reject(_ reason: RedirectFailure.Reason) throws -> Never {
      throw NetworkingError.redirectRejected(.init(reason: reason, metadata: response.metadata))
    }
    guard case .sameOriginWithoutCredentials = configuration.redirectPolicy else {
      try reject(.policyDenied)
    }
    guard request.allowsReplay else { try reject(.replayUnsafe) }
    guard hasBudget else { try reject(.attemptLimit) }
    guard let target = URL(string: location, relativeTo: current.url)?.absoluteURL,
      let components = URLComponents(url: target, resolvingAgainstBaseURL: false),
      let base = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
    else { try reject(.invalidLocation) }
    guard sameOrigin(configuration.baseURL, target) else { try reject(.unapprovedOrigin) }
    guard target.user == nil, target.password == nil else { try reject(.credentialsInURL) }
    do { try validatePath(components.percentEncodedPath) } catch { try reject(.unsafePath) }
    let boundary =
      base.percentEncodedPath.hasSuffix("/")
      ? base.percentEncodedPath : base.percentEncodedPath + "/"
    guard
      components.percentEncodedPath == base.percentEncodedPath
        || components.percentEncodedPath.hasPrefix(boundary)
    else { try reject(.outsideAPIPrefix) }
    return target
  }
}

private struct SendBudget {
  let maximum: Int
  private var used = 0
  init(maximum: Int) { self.maximum = maximum }
  var hasRemaining: Bool { used < maximum }
  mutating func take() -> Int {
    precondition(hasRemaining)
    used += 1
    return used
  }
}
