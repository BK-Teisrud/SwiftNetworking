import Foundation
import Networking

/// Wire messages, without assumptions about a backend's chat or subscription protocol.
public enum WebSocketMessage: Sendable, Equatable {
  case text(String)
  case data(Data)
}
public enum RealtimeError: Error, Sendable {
  case invalidConfiguration, notConnected, messageTooLarge, bufferOverflow, unsupportedMessage
}
public protocol WebSocketConnection: Sendable {
  func receive() async throws -> WebSocketMessage
  func send(_ message: WebSocketMessage) async throws
  func ping() async throws
  func close() async
}
public protocol WebSocketConnector: Sendable {
  /// Must return an isolated connection and cooperate with cancellation.
  func open(_ request: URLRequest) async throws -> any WebSocketConnection
}
public struct WebSocketOptions: Sendable {
  public let maximumConnectionAttempts: Int
  public let reconnectBaseDelay: Double
  public let maximumReconnectDelay: Double
  public let heartbeatInterval: Double?
  public let maximumMessageBytes: Int
  public let eventBufferCapacity: Int
  public init(
    maximumConnectionAttempts: Int = 1, reconnectBaseDelay: Double = 1,
    maximumReconnectDelay: Double = 30, heartbeatInterval: Double? = 30,
    maximumMessageBytes: Int = 1_048_576, eventBufferCapacity: Int = 64
  ) throws {
    guard maximumConnectionAttempts > 0, maximumConnectionAttempts < Int.max,
      reconnectBaseDelay.isFinite, reconnectBaseDelay >= 0, reconnectBaseDelay <= 86_400,
      maximumReconnectDelay.isFinite, maximumReconnectDelay >= 0, maximumReconnectDelay <= 86_400,
      heartbeatInterval.map({ $0.isFinite && $0 > 0 && $0 <= 86_400 }) ?? true,
      maximumMessageBytes > 0, eventBufferCapacity > 0
    else { throw RealtimeError.invalidConfiguration }
    self.maximumConnectionAttempts = maximumConnectionAttempts
    self.reconnectBaseDelay = reconnectBaseDelay
    self.maximumReconnectDelay = maximumReconnectDelay
    self.heartbeatInterval = heartbeatInterval
    self.maximumMessageBytes = maximumMessageBytes
    self.eventBufferCapacity = eventBufferCapacity
  }
}
public enum RealtimeEvent: Sendable {
  case connected(attempt: Int)
  case message(WebSocketMessage)
  case reconnecting(attempt: Int, delay: Double)
}
