import Foundation
import Networking
import Testing

@testable import NetworkingRealtime

private actor CloseGate {
  var entered = false
  var blocker: CheckedContinuation<Void, Never>?
  var observers: [CheckedContinuation<Void, Never>] = []
  func block() async {
    entered = true
    for observer in observers { observer.resume() }
    observers = []
    await withCheckedContinuation { blocker = $0 }
  }
  func wait() async {
    if entered { return }
    await withCheckedContinuation { observers.append($0) }
  }
  func release() {
    blocker?.resume()
    blocker = nil
  }
}
private actor LifecycleSocket: WebSocketConnection {
  let gate: CloseGate?
  let heartbeatFails: Bool
  var closing = false
  var closed = false
  init(gate: CloseGate? = nil, heartbeatFails: Bool = false) {
    self.gate = gate
    self.heartbeatFails = heartbeatFails
  }
  func receive() async throws -> WebSocketMessage {
    while !closing { try await Task.sleep(for: .milliseconds(1)) }
    throw CancellationError()
  }
  func send(_ message: WebSocketMessage) throws {
    if closing { throw RealtimeError.notConnected }
  }
  func ping() throws { if heartbeatFails { throw URLError(.networkConnectionLost) } }
  func close() async {
    if closing { return }
    closing = true
    await gate?.block()
    closed = true
  }
}
private actor LifecycleConnector: WebSocketConnector {
  let gate: CloseGate?
  let heartbeatFails: Bool
  var sockets: [LifecycleSocket] = []
  var overlapped = false
  init(gate: CloseGate? = nil, heartbeatFails: Bool = false) {
    self.gate = gate
    self.heartbeatFails = heartbeatFails
  }
  func open(_ request: URLRequest) async -> any WebSocketConnection {
    for socket in sockets { if !(await socket.closed) { overlapped = true } }
    let socket = LifecycleSocket(gate: sockets.isEmpty ? gate : nil, heartbeatFails: heartbeatFails)
    sockets.append(socket)
    return socket
  }
}
@Test(.timeLimit(.minutes(1))) func overlappingRestartsWaitForOldConnectionAndFinishOldStreams()
  async throws
{
  let gate = CloseGate()
  let connector = LifecycleConnector(gate: gate)
  let client = WebSocketClient(options: try .init(heartbeatInterval: nil), connector: connector) {
    URLRequest(url: URL(string: "wss://example.com")!)
  }
  var original = await client.events().makeAsyncIterator()
  _ = try await original.next()
  let firstStream = await client.events()
  await gate.wait()
  let secondStream = await client.events()
  #expect(await connector.sockets.count == 1)
  await gate.release()
  var first = firstStream.makeAsyncIterator()
  #expect(try await first.next() == nil)
  var second = secondStream.makeAsyncIterator()
  _ = try await second.next()
  // Termination of the older stream must not disconnect this replacement.
  try await client.send(.text("still-connected"))
  await client.disconnect()
  #expect(try await second.next() == nil)
  #expect(!((await connector.overlapped)))
  let sockets = await connector.sockets
  for socket in sockets { #expect(await socket.closed) }
  #expect(try await original.next() == nil)
}
@Test(.timeLimit(.minutes(1))) func heartbeatFailureClosesConnectionAndTerminatesReader()
  async throws
{
  let connector = LifecycleConnector(heartbeatFails: true)
  let client = WebSocketClient(options: try .init(heartbeatInterval: 0.001), connector: connector) {
    URLRequest(url: URL(string: "wss://example.com")!)
  }
  do {
    for try await _ in await client.events() {}
    Issue.record("Expected heartbeat failure")
  } catch let error as URLError { #expect(error.code == .networkConnectionLost) }
  let sockets = await connector.sockets
  #expect(sockets.count == 1)
  #expect(await sockets.first?.closed == true)
}
@Test func eventOverflowFailsInsteadOfSilentlyLosingMessages() throws {
  let pair = AsyncThrowingStream<RealtimeEvent, any Error>.makeStream(
    bufferingPolicy: .bufferingOldest(1))
  try RealtimeStream.yield(.message(.text("first")), to: pair.continuation)
  #expect(throws: RealtimeError.self) {
    try RealtimeStream.yield(.message(.text("second")), to: pair.continuation)
  }
  pair.continuation.finish()
}
