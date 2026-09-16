import Foundation
import Networking
import Testing

@testable import NetworkingRealtime

private actor Socket: WebSocketConnection {
  var messages: [WebSocketMessage]
  var sent: [WebSocketMessage] = []
  var closed = false
  init(_ messages: [WebSocketMessage]) { self.messages = messages }
  func receive() async throws -> WebSocketMessage {
    if !messages.isEmpty { return messages.removeFirst() }
    try await Task.sleep(for: .seconds(10))
    throw URLError(.networkConnectionLost)
  }
  func send(_ message: WebSocketMessage) { sent.append(message) }
  func ping() {}
  func close() { closed = true }
}
private actor Connector: WebSocketConnector {
  let socket: Socket
  var requests = 0
  let failFirst: Bool
  init(socket: Socket, failFirst: Bool = false) {
    self.socket = socket
    self.failFirst = failFirst
  }
  func open(_ request: URLRequest) throws -> any WebSocketConnection {
    requests += 1
    if failFirst && requests == 1 { throw URLError(.cannotConnectToHost) }
    return socket
  }
}
@Test func realtimeReconnectSendAndClose() async throws {
  let socket = Socket([.text("hello")])
  let connector = Connector(socket: socket, failFirst: true)
  let client = WebSocketClient(
    options: try .init(maximumConnectionAttempts: 2, reconnectBaseDelay: 0, heartbeatInterval: nil),
    connector: connector
  ) { URLRequest(url: URL(string: "wss://example.com/socket")!) }
  let events = await client.events()
  var connected = 0
  var reconnects = 0
  for try await event in events {
    switch event {
    case .reconnecting: reconnects += 1
    case .connected: connected += 1
    case .message(let message):
      #expect(message == .text("hello"))
      try await client.send(.text("reply"))
      await client.disconnect()
    }
  }
  #expect(connected == 1)
  #expect(reconnects == 1)
  #expect(await connector.requests == 2)
  #expect(await socket.sent == [.text("reply")])
  #expect(await socket.closed)
}
@Test func realtimeSizeViolationIsTerminal() async throws {
  let socket = Socket([.text("too large")])
  let connector = Connector(socket: socket)
  let client = WebSocketClient(
    options: try .init(
      maximumConnectionAttempts: 3, heartbeatInterval: nil, maximumMessageBytes: 2),
    connector: connector
  ) { URLRequest(url: URL(string: "wss://example.com")!) }
  do {
    for try await _ in await client.events() {}
    Issue.record("Expected message size error")
  } catch RealtimeError.messageTooLarge {}
  #expect(await connector.requests == 1)
  #expect(await socket.closed)
}
