import Foundation
import Testing

@testable import Networking

private actor StubTransport: HTTPTransport {
  enum Step: Sendable {
    case response(Int, Data, [String: String])
    case failure(URLError.Code)
  }
  var steps: [Step]
  var requests: [URLRequest] = []
  init(_ steps: [Step] = [.response(200, Data(), [:])]) { self.steps = steps }
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    requests.append(request)
    guard !steps.isEmpty else { throw NetworkingError.invalidResponse }
    switch steps.removeFirst() {
    case .response(let status, let data, let headers):
      return .init(
        data: data, metadata: .init(statusCode: status, headers: headers, url: request.url))
    case .failure(let code): throw URLError(code)
    }
  }
}
private actor FakeClock: RetryClock {
  var waits: [TimeInterval] = []
  func now() async -> Date { Date(timeIntervalSince1970: 0) }
  func sleep(for seconds: TimeInterval) async throws {
    try Task.checkCancellation()
    waits.append(seconds)
  }
}
private actor Credentials: CredentialProvider {
  var recoveries: [String] = []
  let initial: String
  init(_ initial: String = "old-token") { self.initial = initial }
  func bearerToken() async throws -> String { initial }
  func recover(rejectedToken: String) async throws -> String {
    recoveries.append(rejectedToken)
    return "new-token"
  }
}
private actor Diagnostics: NetworkingDiagnostics {
  var events: [DiagnosticEvent] = []
  func record(_ event: DiagnosticEvent) async { events.append(event) }
}
private struct Model: Codable, Sendable, Equatable { let name: String }
private func client(
  _ transport: StubTransport, retry: RetryPolicy = .disabled,
  credentials: Credentials? = nil, clock: FakeClock = FakeClock(),
  cap: Int? = nil, diagnostics: Diagnostics? = nil
) throws -> HTTPClient {
  .init(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/v1/")!,
      transport: transport, retry: retry, credentialProvider: credentials,
      diagnostics: diagnostics, clock: clock, maximumTotalAttempts: cap))
}

@Test func urlBuildingAndHeaders() throws {
  let config = try ClientConfiguration(
    baseURL: URL(string: "https://example.com/api/v1/")!,
    defaultHeaders: ["Accept": "application/json", "X-Test": "default"])
  let request = HTTPRequest(
    method: .post, path: "/users/Zoë Smith",
    query: [.init(name: "tag", value: "a+b & c"), .init(name: "tag", value: "two")],
    headers: ["x-test": "override"], body: .json(Model(name: "Ada")), idempotencyKey: "key")
  let built = try RequestBuilder(configuration: config).build(request)
  #expect(built.url?.path == "/api/v1/users/Zoë Smith")
  #expect(built.url?.absoluteString.contains("%2B") == true)
  #expect(
    URLComponents(url: built.url!, resolvingAgainstBaseURL: false)?.queryItems == request.query)
  #expect(built.value(forHTTPHeaderField: "X-Test") == "override")
  #expect(built.value(forHTTPHeaderField: "Content-Type") == "application/json")
  #expect(built.value(forHTTPHeaderField: "Idempotency-Key") == "key")
  #expect(try JSONDecoder().decode(Model.self, from: built.httpBody!) == Model(name: "Ada"))
  let raw = try RequestBuilder(configuration: config).build(
    .init(
      path: "blob", body: .data(Data([1, 2]), contentType: "application/octet-stream"), timeout: 5,
      cachePolicy: .returnCacheDataDontLoad))
  #expect(raw.httpBody == Data([1, 2]))
  #expect(raw.timeoutInterval == 5)
  #expect(raw.cachePolicy == .returnCacheDataDontLoad)
}

@Test(arguments: [
  "https://evil.com/a", "//evil.com", "../users", "a/../../b", "%2e%2e/users", "%252e%252e/users",
  "a%2f..%2fb", "a\\b", "a?secret=1", "a#fragment", "a\n",
])
func rejectsUnsafePaths(path: String) throws {
  let config = try ClientConfiguration(baseURL: URL(string: "https://example.com/api/")!)
  #expect(throws: NetworkingError.self) {
    try RequestBuilder(configuration: config).build(.init(path: path))
  }
}

@Test func configurationAndReservedHeaders() throws {
  #expect(throws: NetworkingError.self) {
    try ClientConfiguration(baseURL: URL(string: "http://example.com")!)
  }
  #expect(throws: NetworkingError.self) {
    try ClientConfiguration(baseURL: URL(string: "http://example.com")!, security: .allowLocalHTTP)
  }
  _ = try ClientConfiguration(
    baseURL: URL(string: "http://localhost:8080/api")!, security: .allowLocalHTTP)
  for url in [
    "https://user:pass@example.com", "https://example.com/?a=1", "https://example.com/%2e%2e/",
  ] {
    #expect(throws: NetworkingError.self) { try ClientConfiguration(baseURL: URL(string: url)!) }
  }
  let config = try ClientConfiguration(baseURL: URL(string: "https://example.com")!)
  for headers in [
    ["Authorization": "Bearer secret"], ["Cookie": "secret"], ["Host": "evil.com"],
    ["X-Test": "bad\r\nvalue"], ["X": "a", "x": "b"],
  ] {
    #expect(throws: NetworkingError.self) {
      try RequestBuilder(configuration: config).build(
        .init(path: "", headers: headers, requiresAuthentication: true))
    }
  }
  #expect(throws: NetworkingError.self) {
    try ClientConfiguration(baseURL: config.baseURL, defaultHeaders: ["Authorization": "secret"])
  }
}

@Test func jsonAndEmptyResponses() async throws {
  let transport = StubTransport([
    .response(200, Data(#"{"name":"Ada"}"#.utf8), ["X-Request-ID": "123"]),
    .response(204, Data(), [:]), .response(200, Data(), [:]),
    .response(200, Data("invalid".utf8), [:]),
  ])
  let api = try client(transport)
  let decoded = try await api.decode(.init(path: "users"), as: Model.self)
  #expect(decoded.value.name == "Ada")
  #expect(decoded.metadata.requestID == "123")
  #expect(try await api.execute(.init(method: .delete, path: "users/1")).statusCode == 204)
  do {
    _ = try await api.decode(.init(path: "empty"), as: Model.self)
    Issue.record("Expected emptyResponse")
  } catch NetworkingError.emptyResponse {}
  do {
    _ = try await api.decode(.init(path: "invalid"), as: Model.self)
    Issue.record("Expected decoding error")
  } catch NetworkingError.responseDecoding {}
}

@Test(arguments: [#"{"error":"bad"}"#, "Server failed", "<html>error</html>"])
func statusBeforeDecoding(body: String) async throws {
  let transport = StubTransport([.response(500, Data(body.utf8), ["Content-Type": "text/html"])])
  let api = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport, maximumErrorBodyBytes: 5))
  do {
    _ = try await api.decode(.init(path: ""), as: Model.self)
    Issue.record("Expected HTTP error")
  } catch NetworkingError.http(let failure) {
    #expect(failure.metadata.statusCode == 500)
    #expect(failure.body == Data(body.utf8.prefix(5)))
    #expect(failure.bodyWasTruncated)
    #expect(failure.metadata.header("content-type") == "text/html")
  }
}

@Test func timeoutAndCancellation() async throws {
  let api = try client(StubTransport([.failure(.timedOut), .failure(.cancelled)]))
  do {
    _ = try await api.data(.init(path: ""))
    Issue.record("Expected timeout")
  } catch NetworkingError.timeout {}
  do {
    _ = try await api.data(.init(path: ""))
    Issue.record("Expected cancellation")
  } catch is CancellationError {}
  let transport = StubTransport()
  let cancelledAPI = try client(transport)
  let task = Task {
    try await Task.sleep(for: .seconds(100))
    return try await cancelledAPI.data(.init(path: ""))
  }
  task.cancel()
  do {
    _ = try await task.value
    Issue.record("Expected cancellation")
  } catch is CancellationError {}
  #expect(await transport.requests.isEmpty)
}

@Test func retryLimitsAndRetryAfter() async throws {
  let clock = FakeClock()
  let transport = StubTransport([
    .response(503, Data(), ["Retry-After": "3"]), .failure(.networkConnectionLost),
    .response(200, Data(), [:]),
  ])
  let api = try client(
    transport, retry: .init(maximumAttempts: 3, baseDelay: 2, maximumDelay: 10, jitter: { 1 }),
    clock: clock)
  _ = try await api.data(.init(path: ""))
  #expect(await transport.requests.count == 3)
  #expect(await clock.waits == [3, 4])
  let policy = RetryPolicy(maximumAttempts: 3, baseDelay: 2, maximumDelay: 10, jitter: { 1 })
  #expect(
    policy.delay(
      attempt: 1, retryAfter: "Thu, 01 Jan 1970 00:00:06 GMT", now: Date(timeIntervalSince1970: 0))
      == 6)
  #expect(policy.delay(attempt: 1, retryAfter: "999", now: Date()) == nil)
  #expect(policy.delay(attempt: 1, retryAfter: "-1", now: Date()) == 2)
  let failing = StubTransport(Array(repeating: .response(503, Data(), [:]), count: 5))
  let failingAPI = try client(failing, retry: policy)
  await #expect(throws: NetworkingError.self) { try await failingAPI.data(.init(path: "")) }
  #expect(await failing.requests.count == 3)
}

@Test func unsafeReplayAndExplicitConfirmation() async throws {
  for method in [HTTPMethod.post, .put, .patch, .delete] {
    let transport = StubTransport([.response(503, Data(), [:]), .response(200, Data(), [:])])
    let api = try client(transport, retry: .init(maximumAttempts: 2))
    await #expect(throws: NetworkingError.self) {
      try await api.data(.init(method: method, path: "", idempotencyKey: "key"))
    }
    #expect(await transport.requests.count == 1)
  }
  let transport = StubTransport([.response(503, Data(), [:]), .response(200, Data(), [:])])
  _ = try await client(transport, retry: .init(maximumAttempts: 2)).data(
    .init(method: .post, path: "", replayPolicy: .confirmedSafe))
  #expect(await transport.requests.count == 2)
}

@Test func recoveryIsBoundedAndTokensUpdated() async throws {
  let credentials = Credentials()
  let transport = StubTransport([.response(401, Data(), [:]), .response(401, Data(), [:])])
  let api = try client(transport, retry: .init(maximumAttempts: 5), credentials: credentials)
  await #expect(throws: NetworkingError.self) {
    try await api.data(.init(path: "", requiresAuthentication: true))
  }
  #expect(await credentials.recoveries == ["old-token"])
  let requests = await transport.requests
  #expect(requests.count == 2)
  #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old-token")
  #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new-token")
}

@Test func noRecoveryForForbiddenUnauthenticatedOrUnsafe() async throws {
  for request in [
    HTTPRequest(path: "", requiresAuthentication: true), HTTPRequest(path: ""),
    HTTPRequest(method: .post, path: "", requiresAuthentication: true),
  ] {
    let credentials = Credentials()
    let status = request.method == .get && request.requiresAuthentication ? 403 : 401
    let transport = StubTransport([.response(status, Data(), [:])])
    let api = try client(transport, credentials: credentials)
    await #expect(throws: NetworkingError.self) { try await api.data(request) }
    #expect(await credentials.recoveries.isEmpty)
  }
}

@Test func combinedAttemptCap() async throws {
  let transport = StubTransport([
    .response(503, Data(), [:]), .response(401, Data(), [:]), .response(503, Data(), [:]),
    .response(200, Data(), [:]),
  ])
  let credentials = Credentials()
  let api = try client(
    transport, retry: .init(maximumAttempts: 4), credentials: credentials, cap: 3)
  await #expect(throws: NetworkingError.self) {
    try await api.data(.init(path: "", requiresAuthentication: true))
  }
  #expect(await transport.requests.count == 3)
  #expect(await credentials.recoveries.count == 1)
}

@Test func clientIsolationAndDiagnostics() async throws {
  let first = StubTransport()
  let second = StubTransport()
  let diagnostics = Diagnostics()
  let a = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://one.example/api")!, defaultHeaders: ["X-App": "one"],
      transport: first, credentialProvider: Credentials("one-token"), diagnostics: diagnostics))
  let b = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://two.example/v2")!, defaultHeaders: ["X-App": "two"],
      transport: second, credentialProvider: Credentials("two-token")))
  async let ar = a.data(
    .init(
      path: "private/person@example.com", query: [.init(name: "secret", value: "secret")],
      requiresAuthentication: true))
  async let br = b.data(.init(path: "", requiresAuthentication: true))
  _ = try await (ar, br)
  let ra = try #require(await first.requests.first)
  let rb = try #require(await second.requests.first)
  #expect(ra.url?.host == "one.example")
  #expect(rb.url?.host == "two.example")
  #expect(ra.value(forHTTPHeaderField: "Authorization") == "Bearer one-token")
  #expect(rb.value(forHTTPHeaderField: "Authorization") == "Bearer two-token")
  #expect(ra.value(forHTTPHeaderField: "X-App") == "one")
  #expect(rb.value(forHTTPHeaderField: "X-App") == "two")
  await a.flushDiagnostics()
  let event = try #require(await diagnostics.events.first)
  #expect(event.method == .get)
  #expect(event.statusCode == 200)
  #expect(!String(reflecting: event).contains("secret"))
  #expect(!String(reflecting: event).contains("example.com"))
}

@Test func missingAndInvalidCredentials() async throws {
  let transport = StubTransport()
  await #expect(throws: NetworkingError.self) {
    try await client(transport).data(.init(path: "", requiresAuthentication: true))
  }
  await #expect(throws: NetworkingError.self) {
    try await client(transport, credentials: Credentials("bad\r\ntoken")).data(
      .init(path: "", requiresAuthentication: true))
  }
  #expect(await transport.requests.isEmpty)
}

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let status = request.url!.path == "/redirect" ? 302 : 200
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
      headerFields: status == 302
        ? ["Location": "https://evil.example/"] : ["X-Request-ID": "fixture"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(#"{"name":"transport"}"#.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}

@Test func urlSessionTransportResponseAndRejectedRedirect() async throws {
  let transport = URLSessionTransport(protocolClasses: [FixtureProtocol.self])
  let api = HTTPClient(
    configuration: try .init(baseURL: URL(string: "https://fixture.example")!, transport: transport)
  )
  let response = try await api.decode(.init(path: "json"), as: Model.self)
  #expect(response.value.name == "transport")
  #expect(response.metadata.requestID == "fixture")
  do {
    _ = try await api.data(.init(path: "redirect"))
    Issue.record("Expected redirect rejection")
  } catch NetworkingError.redirectRejected {}
}

private actor WaitingClock: RetryClock {
  private var started = false
  private var waiter: CheckedContinuation<Void, Never>?
  func now() async -> Date { Date(timeIntervalSince1970: 0) }
  func sleep(for seconds: TimeInterval) async throws {
    started = true
    waiter?.resume()
    waiter = nil
    try await Task.sleep(for: .seconds(100))
  }
  func waitUntilSleeping() async {
    if started { return }
    await withCheckedContinuation { waiter = $0 }
  }
}

@Test func cancellationDuringRetryWait() async throws {
  let transport = StubTransport([.response(503, Data(), [:]), .response(200, Data(), [:])])
  let clock = WaitingClock()
  let api = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      retry: .init(maximumAttempts: 2), clock: clock))
  let task = Task { try await api.data(.init(path: "")) }
  await clock.waitUntilSleeping()
  task.cancel()
  do {
    _ = try await task.value
    Issue.record("Expected cancellation")
  } catch is CancellationError {}
  #expect(await transport.requests.count == 1)
}

private struct DatedModel: Codable, Sendable {
  let displayName: String
  let createdAt: Date
}
private struct FailingBody: Encodable, Sendable {
  func encode(to encoder: any Encoder) throws { throw AuthenticationError.rejected }
}

@Test func configurableCodingAndEncodingFailure() async throws {
  let coding = JSONCoding(
    makeEncoder: {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      encoder.dateEncodingStrategy = .iso8601
      return encoder
    },
    makeDecoder: {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .iso8601
      return decoder
    })
  let transport = StubTransport([
    .response(200, Data(#"{"display_name":"Ada","created_at":"1970-01-01T00:00:00Z"}"#.utf8), [:])
  ])
  let config = try ClientConfiguration(
    baseURL: URL(string: "https://example.com")!, coding: coding, transport: transport,
    retry: .init(maximumAttempts: 3))
  let api = HTTPClient(configuration: config)
  let decoded = try await api.decode(.init(path: ""), as: DatedModel.self)
  #expect(decoded.value.createdAt == Date(timeIntervalSince1970: 0))
  let built = try RequestBuilder(configuration: config).build(
    .init(method: .post, path: "", body: .json(decoded.value)))
  #expect(String(data: built.httpBody!, encoding: .utf8)?.contains("display_name") == true)
  do {
    _ = try await api.data(.init(path: "", body: .json(FailingBody())))
    Issue.record("Expected encoding failure")
  } catch NetworkingError.requestEncoding {}
  #expect(await transport.requests.count == 1)
}

@Test func disabledRetryAndNonRetryableErrors() async throws {
  let disabled = StubTransport([.response(503, Data(), [:])])
  await #expect(throws: NetworkingError.self) { try await client(disabled).data(.init(path: "")) }
  #expect(await disabled.requests.count == 1)
  for status in [400, 403] {
    let transport = StubTransport([.response(status, Data(), [:])])
    await #expect(throws: NetworkingError.self) {
      try await client(transport, retry: .init(maximumAttempts: 3, statusCodes: [400, 403])).data(
        .init(path: ""))
    }
    #expect(await transport.requests.count == 1)
  }
  for step in [StubTransport.Step.response(200, Data("bad JSON".utf8), [:]), .failure(.cancelled)] {
    let transport = StubTransport([step])
    do {
      _ = try await client(
        transport, retry: .init(maximumAttempts: 3, transportCodes: [URLError.cancelled.rawValue])
      ).decode(.init(path: ""), as: Model.self)
      Issue.record("Expected failure")
    } catch is CancellationError {} catch NetworkingError.responseDecoding {}
    #expect(await transport.requests.count == 1)
  }
}

@Test func neverReplayAndSingleSendCap() async throws {
  for request in [
    HTTPRequest(path: "", requiresAuthentication: true, replayPolicy: .never),
    HTTPRequest(path: "", requiresAuthentication: true),
  ] {
    let transport = StubTransport([.response(401, Data(), [:])])
    let credentials = Credentials()
    await #expect(throws: NetworkingError.self) {
      try await client(
        transport, retry: .init(maximumAttempts: 3), credentials: credentials, cap: 1
      ).data(request)
    }
    #expect(await credentials.recoveries.isEmpty)
    #expect(await transport.requests.count == 1)
  }
}

@Test(arguments: ["100% complete", "100%25", "caf%C3%A9", "café"])
func specialPathEncoding(path: String) throws {
  let config = try ClientConfiguration(baseURL: URL(string: "https://example.com/api/")!)
  let built = try RequestBuilder(configuration: config).build(.init(path: path))
  let expected = path.removingPercentEncoding ?? path
  #expect(built.url?.path == "/api/" + expected)
}

private struct RedirectedUnauthorizedTransport: HTTPTransport {
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    .init(
      data: Data(),
      metadata: .init(
        statusCode: 401, url: URL(string: "https://example.com/redirected")!, wasRedirected: true))
  }
}

@Test func redirectedUnauthorizedDoesNotRejectUnusedToken() async throws {
  let credentials = Credentials()
  let api = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: RedirectedUnauthorizedTransport(),
      credentialProvider: credentials, redirectPolicy: .sameOriginWithoutCredentials))
  await #expect(throws: NetworkingError.self) {
    try await api.data(.init(path: "", requiresAuthentication: true))
  }
  #expect(await credentials.recoveries.isEmpty)
}

@Test(arguments: [
  "https://example.com/api/v1/", "https://example.com/api//v1///", "https://example.com/api/v1",
  "https://example.com/",
])
func basePrefixIsPreserved(base: String) throws {
  let config = try ClientConfiguration(baseURL: URL(string: base)!)
  let builder = RequestBuilder(configuration: config)
  #expect(try builder.build(.init(path: "")).url == config.baseURL)
  let expected = base.hasSuffix("/") ? base + "users/" : base + "/users/"
  #expect(try builder.build(.init(path: "/users/")).url?.absoluteString == expected)
}
