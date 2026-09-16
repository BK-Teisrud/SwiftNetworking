import Foundation

final class SessionSocket: WebSocketConnection, Sendable {
  private let session: URLSession
  private let task: URLSessionWebSocketTask
  init(session: URLSession, task: URLSessionWebSocketTask) {
    self.session = session
    self.task = task
  }
  deinit {
    task.cancel(with: .goingAway, reason: nil)
    session.invalidateAndCancel()
  }
  func receive() async throws -> WebSocketMessage {
    try await withTaskCancellationHandler {
      switch try await task.receive() {
      case .string(let text): return .text(text)
      case .data(let data): return .data(data)
      @unknown default: throw RealtimeError.unsupportedMessage
      }
    } onCancel: {
      task.cancel(with: .goingAway, reason: nil)
    }
  }
  func send(_ message: WebSocketMessage) async throws {
    try await task.send(
      {
        switch message {
        case .text(let value): .string(value)
        case .data(let value): .data(value)
        }
      }())
  }
  func ping() async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, any Error>) in
      task.sendPing { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
      }
    }
  }
  func close() async {
    task.cancel(with: .goingAway, reason: nil)
    session.invalidateAndCancel()
  }
}
