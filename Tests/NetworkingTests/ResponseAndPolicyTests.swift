import Foundation
import Testing

@testable import Networking

private actor QualityTransport: HTTPTransport {
  var requests: [URLRequest] = []
  var responses: [HTTPResponse]
  init(_ responses: [HTTPResponse]) { self.responses = responses }
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    requests.append(request)
    return responses.removeFirst()
  }
}
private actor QualityClock: RetryClock {
  var waits: [Double] = []
  func now() -> Date { Date(timeIntervalSince1970: 0) }
  func sleep(for seconds: Double) { waits.append(seconds) }
}
private func response(_ status: Int, _ headers: [String: String] = [:], body: String = "")
  -> HTTPResponse
{
  .init(data: Data(body.utf8), metadata: .init(statusCode: status, headers: headers))
}
@Test func fourDigitFutureDatesNeverBecomePastDates() {
  let policy = RetryPolicy(maximumDelay: 30, jitter: { 1 })
  let now = Date(timeIntervalSince1970: 1_767_225_600)
  for date in ["Fri, 01 Jan 2077 00:00:06 GMT", "Fri Jan  1 00:00:06 2077"] {
    #expect(policy.delay(attempt: 1, retryAfter: date, now: now) == nil)
  }
  #expect(policy.delay(attempt: 1, retryAfter: String(repeating: "9", count: 400), now: now) == nil)
}
@Test(arguments: [Double.nan, Double.infinity, -1, 1e30, 86_401])
func invalidSleepAndConfigurationThrowInsteadOfTrapping(value: Double) async throws {
  do {
    try await SystemRetryClock().sleep(for: value)
    Issue.record("Expected validation error")
  } catch NetworkingError.invalidConfiguration {}
  do {
    _ = try ClientConfiguration(
      baseURL: URL(string: "https://example.com")!, retry: .init(baseDelay: value))
    Issue.record("Expected invalid retry configuration")
  } catch NetworkingError.invalidConfiguration {}
}
@Test func exactMaximumDelayIsAccepted() async throws {
  _ = try ClientConfiguration(
    baseURL: URL(string: "https://example.com")!, timeout: 86_400,
    retry: .init(baseDelay: 86_400, maximumDelay: 86_400))
  #expect(
    RetryPolicy(maximumDelay: 86_400).delay(attempt: 1, retryAfter: "86400", now: Date()) == 86_400)
  try await SystemRetryClock().sleep(for: 0)
}
@Test func serverWaitBeyondBudgetSuppressesRetry() async throws {
  let transport = QualityTransport([response(429, ["Retry-After": "120"])])
  let clock = QualityClock()
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      retry: .init(maximumAttempts: 2), clock: clock))
  do {
    _ = try await client.data(.init(path: ""))
    Issue.record("Expected HTTP error")
  } catch NetworkingError.http(let failure) { #expect(failure.metadata.statusCode == 429) }
  #expect(await transport.requests.count == 1)
  #expect(await clock.waits.isEmpty)
}
@Test(arguments: [10, 120])
func redirectsRespectServerWait(seconds: Int) async throws {
  let transport = QualityTransport([
    response(302, ["Location": "/api/final", "Retry-After": "\(seconds)"]), response(204),
  ])
  let clock = QualityClock()
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api")!, transport: transport,
      redirectPolicy: .sameOriginWithoutCredentials, clock: clock))
  do {
    _ = try await client.data(.init(path: "start"))
    #expect(seconds == 10)
  } catch NetworkingError.redirectRejected(let failure) {
    #expect(seconds == 120)
    #expect(failure.reason == .retryAfterExceedsLimit)
    #expect(failure.metadata.statusCode == 302)
  }
  #expect(await clock.waits == (seconds == 10 ? [10] : []))
  #expect(await transport.requests.count == (seconds == 10 ? 2 : 1))
}
private struct Model: Codable, Sendable { let userName: String }
@Test func decodingAndEmptyFailuresPreserveMetadata() async throws {
  let transport = QualityTransport([
    response(200, ["X-Request-ID": "decode-id"], body: "{}"),
    response(204, ["X-Request-ID": "empty-id"]),
  ])
  let client = HTTPClient(
    configuration: try .init(baseURL: URL(string: "https://example.com")!, transport: transport))
  do {
    _ = try await client.decode(.init(path: ""), as: Model.self)
    Issue.record("Expected decoding failure")
  } catch NetworkingError.responseDecoding(let failure) {
    #expect(failure.metadata.requestID == "decode-id")
    #expect(failure.kind == .keyNotFound)
    #expect(failure.codingPath == ["userName"])
  }
  do {
    _ = try await client.decode(.init(path: ""), as: Model.self)
    Issue.record("Expected empty response")
  } catch NetworkingError.emptyResponse(let metadata) {
    #expect(metadata.statusCode == 204)
    #expect(metadata.requestID == "empty-id")
  }
}
@Test func rawSegmentsEncodeSlashPercentAndColonExactlyOnce() async throws {
  let configuration = try ClientConfiguration(baseURL: URL(string: "https://example.com/api")!)
  let request = try RequestBuilder(configuration: configuration).build(
    .init(pathSegments: ["users", "alice/bob%:id"]))
  #expect(request.url?.absoluteString == "https://example.com/api/users/alice%2Fbob%25%3Aid")
}
private struct SlowCredentials: CredentialProvider {
  func bearerToken() async throws -> String {
    try await Task.sleep(for: .seconds(10))
    return "token"
  }
  func recover(rejectedToken: String) async throws -> String { try await bearerToken() }
}
@Test func deadlineIncludesCredentialAcquisition() async throws {
  let transport = QualityTransport([])
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      credentialProvider: SlowCredentials(), operationTimeout: 0.02))
  do {
    _ = try await client.data(.init(path: "", requiresAuthentication: true))
    Issue.record("Expected deadline")
  } catch NetworkingError.deadlineExceeded {}
  #expect(await transport.requests.isEmpty)
}
@Test func customTransportResponseLimitIsChecked() async throws {
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!,
      transport: QualityTransport([response(200, body: "12345")]), maximumResponseBytes: 4))
  do {
    _ = try await client.data(.init(path: ""))
    Issue.record("Expected size limit")
  } catch NetworkingError.responseTooLarge(let limit, let metadata) {
    #expect(limit == 4)
    #expect(metadata?.statusCode == 200)
  }
}
@Test func immutableCodingOptionsCreateIndependentCoders() throws {
  let coding = JSONCoding(options: .init(keys: .snakeCase))
  #expect(coding.makeEncoder() !== coding.makeEncoder())
  #expect(coding.makeDecoder() !== coding.makeDecoder())
  let data = try coding.makeEncoder().encode(Model(userName: "test"))
  #expect(String(decoding: data, as: UTF8.self).contains("user_name"))
  #expect(try coding.makeDecoder().decode(Model.self, from: data).userName == "test")
}

private final class SizedProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let headers = request.url!.path == "/length" ? ["Content-Length": "1000"] : [:]
    let status = request.url!.path == "/error" ? 500 : 200
    let response = HTTPURLResponse(
      url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    for _ in 0..<4 { client?.urlProtocol(self, didLoad: Data("1234".utf8)) }
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
@Test(arguments: ["length", "chunks"])
func defaultTransportLimitsDeclaredAndIncrementalSizes(path: String) async throws {
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://fixture.example")!,
      transport: URLSessionTransport(protocolClasses: [SizedProtocol.self]), maximumResponseBytes: 8
    ))
  do {
    _ = try await client.data(.init(path: path))
    Issue.record("Expected size limit")
  } catch NetworkingError.responseTooLarge(let limit, let metadata) {
    #expect(limit == 8)
    #expect(metadata?.statusCode == 200)
  }
}
@Test func defaultTransportDiscardsSuccessAndBoundsErrorMemory() async throws {
  let transport = URLSessionTransport(protocolClasses: [SizedProtocol.self])
  let success = try await transport.send(
    URLRequest(url: URL(string: "https://fixture.example/chunks")!), redirectPolicy: .reject,
    options: .init(maximumResponseBytes: 20, discardSuccessBody: true))
  #expect(success.data.isEmpty)
  #expect(success.receivedBodyBytes == 16)
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://fixture.example")!, transport: transport,
      maximumErrorBodyBytes: 3))
  do {
    _ = try await client.data(.init(path: "error"))
    Issue.record("Expected HTTP error")
  } catch NetworkingError.http(let failure) {
    #expect(failure.body == Data("123".utf8))
    #expect(failure.bodyWasTruncated)
  }
}
private actor QueueSink: NetworkingDiagnostics {
  var events: [DiagnosticEvent] = []
  var waiter: CheckedContinuation<Void, Never>?
  var entered = false
  func record(_ event: DiagnosticEvent) async {
    events.append(event)
    if !entered {
      entered = true
      await withCheckedContinuation { waiter = $0 }
    }
  }
  func release() {
    waiter?.resume()
    waiter = nil
  }
}
@Test func diagnosticQueueIsBoundedAndCorrelatesOperations() async throws {
  let sink = QueueSink()
  let transport = QualityTransport(Array(repeating: response(200), count: 10))
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport, diagnostics: sink,
      diagnosticQueueCapacity: 2))
  _ = try await client.data(.init(path: "", diagnosticLabel: "catalog.list"))
  while !(await sink.entered) { await Task.yield() }
  for _ in 0..<9 { _ = try await client.data(.init(path: "", diagnosticLabel: "catalog.list")) }
  await sink.release()
  await client.flushDiagnostics()
  let events = await sink.events
  #expect(events.count == 3)
  #expect(client.droppedDiagnosticEvents == 7)
  #expect(Set(events.map(\.operationID)).count == 3)
  #expect(
    events.allSatisfy { $0.label == "catalog.list" && $0.kind == .response && $0.duration >= 0 })
}
@Test func transportFailurePreservesUnderlyingErrorChain() {
  let underlying = NSError(domain: "Underlying", code: 7)
  let failure = Networking.TransportFailure(
    error: NSError(
      domain: NSURLErrorDomain, code: -1005, userInfo: [NSUnderlyingErrorKey: underlying]))
  #expect(failure.domain == NSURLErrorDomain)
  #expect(failure.code == -1005)
  #expect(failure.causes.first?.domain == "Underlying")
  #expect(failure.causes.first?.code == 7)
}

@Test func twoDigitYearBoundaryIsBasedOnFullDate() {
  let policy = RetryPolicy(maximumDelay: 86_400)
  let now = Date(timeIntervalSince1970: 1_767_312_000)  // 2026-01-02
  // Within 50 years remains a future date; beyond 50 years rolls back a century.
  #expect(
    policy.delay(attempt: 1, retryAfter: "Wednesday, 01-Jan-76 00:00:00 GMT", now: now) == nil)
  #expect(policy.delay(attempt: 1, retryAfter: "Friday, 03-Jan-76 00:00:00 GMT", now: now) == 0)
  #expect(policy.delay(attempt: 1, retryAfter: "Fri, 03 Jan 2076 00:00:00 GMT", now: now) == nil)
}

private final class HEADProtocol: URLProtocol, @unchecked Sendable {
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    let response = HTTPURLResponse(
      url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
      headerFields: ["Content-Length": "1000000"])!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
@Test func headAcceptsLargeRepresentationWithoutBody() async throws {
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://fixture.example")!,
      transport: URLSessionTransport(protocolClasses: [HEADProtocol.self]), maximumResponseBytes: 8)
  )
  #expect(try await client.execute(.init(method: .head, path: "")).statusCode == 200)
}
@Test func legacyTransportPreservesDiscardedByteCount() async throws {
  let transport = QualityTransport([response(200, body: "1234")])
  let result = try await transport.send(
    URLRequest(url: URL(string: "https://example.com")!), redirectPolicy: .reject,
    options: .init(discardSuccessBody: true))
  #expect(result.data.isEmpty)
  #expect(result.receivedBodyBytes == 4)
}
@Test func redirectDropsAPIKeyAndCustomHeaders() async throws {
  let transport = QualityTransport([response(302, ["Location": "/api/final"]), response(204)])
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/")!, transport: transport,
      redirectPolicy: .sameOriginWithoutCredentials))
  _ = try await client.data(
    .init(
      path: "start",
      headers: ["X-API-Key": "key", "X-Custom-Secret": "secret", "Accept": "application/json"]))
  let requests = await transport.requests
  #expect(requests[1].value(forHTTPHeaderField: "X-API-Key") == nil)
  #expect(requests[1].value(forHTTPHeaderField: "X-Custom-Secret") == nil)
  #expect(requests[1].value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func customHTTPMethodsAndFormEncodingAreValidated() throws {
  #expect(HTTPMethod(rawValue: "PROPFIND")?.rawValue == "PROPFIND")
  #expect(HTTPMethod(rawValue: "GET\r\nHeader: x") == nil)
  let configuration = try ClientConfiguration(baseURL: URL(string: "https://example.com")!)
  let request = try RequestBuilder(configuration: configuration).build(
    .init(
      method: .post, path: "form",
      body: .form([
        .init(name: "q", value: "a+b & café"), .init(name: "q", value: nil),
      ])))
  #expect(String(decoding: request.httpBody!, as: UTF8.self) == "q=a%2Bb+%26+caf%C3%A9&q=")
  #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
}
