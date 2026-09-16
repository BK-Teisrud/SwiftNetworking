import Foundation
import Testing

@testable import Networking

private actor SequenceTransport: HTTPTransport {
  var requests: [URLRequest] = []
  var responses: [HTTPResponse]
  init(_ responses: [HTTPResponse]) { self.responses = responses }
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    requests.append(request)
    return responses.removeFirst()
  }
}
private func reply(_ status: Int, _ headers: [String: String] = [:]) -> HTTPResponse {
  .init(data: Data(), metadata: .init(statusCode: status, headers: headers))
}
private func api(
  _ transport: SequenceTransport, cap: Int = 4, diagnostics: (any NetworkingDiagnostics)? = nil
) throws -> HTTPClient {
  .init(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/")!, transport: transport,
      diagnostics: diagnostics, redirectPolicy: .sameOriginWithoutCredentials,
      maximumTotalAttempts: cap))
}

@Test(arguments: ["https://example.com/api%2Fv1/", "https://example.com/api%3Btenant/"])
func encodedBaseAndSegmentsArePreserved(base: String) throws {
  let builder = RequestBuilder(configuration: try .init(baseURL: URL(string: base)!))
  #expect(try builder.build(.init(path: "")).url?.absoluteString == base)
  #expect(
    try builder.build(.init(path: "files/a%2Fb%3Bc")).url?.absoluteString == base
      + "files/a%2Fb%3Bc")
}

@Test(arguments: [301, 302, 303, 307, 308])
func redirectRequiresReplayAndBudget(status: Int) async throws {
  for (method, policy, cap) in [
    (HTTPMethod.post, ReplayPolicy.safeMethodsOnly, 4), (.get, .never, 4),
    (.get, .safeMethodsOnly, 1),
  ] {
    let transport = SequenceTransport([reply(status, ["Location": "next"])])
    await #expect(throws: NetworkingError.self) {
      try await api(transport, cap: cap).data(
        .init(
          method: method, path: "start", body: .data(Data([1]), contentType: "text/plain"),
          replayPolicy: policy))
    }
    #expect(await transport.requests.count == 1)
  }
}

@Test func redirectChainSharesTotalBudget() async throws {
  let transport = SequenceTransport([
    reply(307, ["Location": "next"]), reply(308, ["Location": "final"]), reply(200),
  ])
  let response = try await api(transport, cap: 3).data(
    .init(
      method: .post, path: "start", body: .data(Data([1, 2]), contentType: "text/plain"),
      replayPolicy: .confirmedSafe))
  #expect(response.metadata.wasRedirected)
  #expect(
    await transport.requests.map(\.httpBody) == [Data([1, 2]), Data([1, 2]), Data([1, 2])])
  let limited = SequenceTransport([
    reply(307, ["Location": "next"]), reply(308, ["Location": "final"]),
  ])
  await #expect(throws: NetworkingError.self) {
    try await api(limited, cap: 2).data(.init(path: "start"))
  }
  #expect(await limited.requests.count == 2)
}

@Test(arguments: [
  "https://evil.example/api/next", "http://example.com/api/next",
  "https://example.com:8443/api/next", "/outside", "../outside",
  "https://user@example.com/api/next",
])
func redirectRejectsUnsafeDestination(destination: String) async throws {
  let transport = SequenceTransport([reply(302, ["Location": destination])])
  await #expect(throws: NetworkingError.self) {
    try await api(transport).data(.init(path: "start"))
  }
  #expect(await transport.requests.count == 1)
}

private actor GatedDiagnostics: NetworkingDiagnostics {
  var entered = false
  var continuation: CheckedContinuation<Void, Never>?
  func record(_ event: DiagnosticEvent) async {
    if !entered {
      entered = true
      await withCheckedContinuation { continuation = $0 }
    }
  }
  func release() {
    continuation?.resume()
    continuation = nil
  }
}
@Test func slowDiagnosticsDoesNotBlockSuccessfulResponse() async throws {
  let diagnostics = GatedDiagnostics()
  let client = try api(SequenceTransport([reply(200)]), diagnostics: diagnostics)
  _ = try await client.data(.init(path: "start"))
  while !(await diagnostics.entered) { await Task.yield() }
  await diagnostics.release()
  await client.flushDiagnostics()
}

@Test(arguments: [
  "Thu, 01 Jan 1970 00:00:06 GMT", "Thursday, 01-Jan-70 00:00:06 GMT", "Thu Jan  1 00:00:06 1970",
])
func retryAfterAcceptsEveryHTTPDate(value: String) {
  let policy = RetryPolicy(baseDelay: 2, maximumDelay: 100, jitter: { 1 })
  #expect(policy.delay(attempt: 1, retryAfter: value, now: Date(timeIntervalSince1970: 0)) == 6)
}
@Test func retryAfterTwoDigitYearUsesCurrentCenturyWindow() {
  let policy = RetryPolicy(baseDelay: 2, maximumDelay: 86_400, jitter: { 1 })
  let now = Date(timeIntervalSince1970: 3_155_760_000)  // 2070-01-01
  // A date 69 years ahead must be interpreted as the most recent matching past year.
  #expect(policy.delay(attempt: 1, retryAfter: "Thursday, 01-Jan-39 00:00:06 GMT", now: now) == 0)
}

private struct FailingCredentials: CredentialProvider {
  let failInitially: Bool
  func bearerToken() async throws -> String {
    if failInitially { throw AuthenticationError.rejected }
    return "initial-token"
  }
  func recover(rejectedToken: String) async throws -> String { throw AuthenticationError.rejected }
}
@Test(arguments: [true, false])
func credentialFailureIsStructured(initial: Bool) async throws {
  let transport = SequenceTransport([reply(401)])
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      credentialProvider: FailingCredentials(failInitially: initial)))
  do {
    _ = try await client.data(.init(path: "", requiresAuthentication: true))
    Issue.record("Expected credential failure")
  } catch NetworkingError.authentication(let error) { #expect(error == .rejected) }
  #expect(await transport.requests.count == (initial ? 0 : 1))
}

private struct TransportFailure: HTTPTransport {
  func send(_ request: URLRequest, redirectPolicy: RedirectPolicy) async throws -> HTTPResponse {
    throw URLError(.timedOut)
  }
}
@Test func slowDiagnosticsDoesNotReplaceTransportFailure() async throws {
  let diagnostics = GatedDiagnostics()
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: TransportFailure(),
      diagnostics: diagnostics))
  do {
    _ = try await client.data(.init(path: ""))
    Issue.record("Expected timeout")
  } catch NetworkingError.timeout {}
  while !(await diagnostics.entered) { await Task.yield() }
  await diagnostics.release()
  await client.flushDiagnostics()
}
private actor RecoveryCounter: CredentialProvider {
  var recoveries = 0
  func bearerToken() async throws -> String { "initial-token" }
  func recover(rejectedToken: String) async throws -> String {
    recoveries += 1
    return "updated-token"
  }
}
@Test func neverReplayBlocksRecoveryWithAvailableBudget() async throws {
  let transport = SequenceTransport([reply(401)])
  let provider = RecoveryCounter()
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      credentialProvider: provider, maximumTotalAttempts: 4))
  await #expect(throws: NetworkingError.self) {
    try await client.data(.init(path: "", requiresAuthentication: true, replayPolicy: .never))
  }
  #expect(await provider.recoveries == 0)
  #expect(await transport.requests.count == 1)
}
private struct CancelDuringDecoding: Decodable, Sendable {
  init(from decoder: any Decoder) throws { withUnsafeCurrentTask { $0?.cancel() } }
}
@Test func cancellationDuringSuccessfulDecodingIsPreserved() async throws {
  let transport = SequenceTransport([.init(data: Data("{}".utf8), metadata: .init(statusCode: 200))]
  )
  let client = try api(transport)
  let task = Task { try await client.decode(.init(path: ""), as: CancelDuringDecoding.self) }
  await #expect(throws: CancellationError.self) { try await task.value }
}
private struct InvalidRecoveredCredentials: CredentialProvider {
  func bearerToken() async throws -> String { "valid-token" }
  func recover(rejectedToken: String) async throws -> String { "invalid\r\ncredential" }
}
@Test func invalidRecoveredTokenIsRejectedBeforeReplay() async throws {
  let transport = SequenceTransport([reply(401)])
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, transport: transport,
      credentialProvider: InvalidRecoveredCredentials()))
  do {
    _ = try await client.data(.init(path: "", requiresAuthentication: true))
    Issue.record("Expected invalid token")
  } catch NetworkingError.authentication(let error) { #expect(error == .invalidToken) }
  #expect(await transport.requests.count == 1)
}

private struct ImmediateClock: RetryClock {
  func now() async -> Date { Date(timeIntervalSince1970: 0) }
  func sleep(for seconds: TimeInterval) async throws { try Task.checkCancellation() }
}
@Test func redirectsRetryAndRecoveryUseOneBudget() async throws {
  let transport = SequenceTransport([
    reply(307, ["Location": "next"]), reply(503), reply(401), reply(200),
  ])
  let provider = RecoveryCounter()
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/")!, transport: transport,
      retry: .init(maximumAttempts: 3), credentialProvider: provider,
      redirectPolicy: .sameOriginWithoutCredentials,
      clock: ImmediateClock(), maximumTotalAttempts: 4))
  _ = try await client.data(.init(path: "start", requiresAuthentication: true))
  let requests = await transport.requests
  #expect(requests.count == 4)
  #expect(requests[1].value(forHTTPHeaderField: "Authorization") == nil)
  #expect(requests[2].url?.path == "/api/start")
  #expect(requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer initial-token")
  #expect(requests[3].value(forHTTPHeaderField: "Authorization") == "Bearer updated-token")
  #expect(await provider.recoveries == 1)
}

private actor EventRecorder: NetworkingDiagnostics {
  var methods: [HTTPMethod] = []
  func record(_ event: DiagnosticEvent) async { methods.append(event.method) }
}
@Test func redirectDiagnosticsDescribeActualMethod() async throws {
  let transport = SequenceTransport([reply(303, ["Location": "next"]), reply(200)])
  let diagnostics = EventRecorder()
  let client = try api(transport, diagnostics: diagnostics)
  _ = try await client.data(
    .init(method: .post, path: "start", replayPolicy: .confirmedSafe))
  await client.flushDiagnostics()
  #expect(await diagnostics.methods == [.post, .get])
}
