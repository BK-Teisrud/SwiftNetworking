import Foundation

enum RealtimeStream {
  static func read(
    _ opened: any WebSocketConnection,
    continuation: AsyncThrowingStream<RealtimeEvent, any Error>.Continuation,
    options: WebSocketOptions
  ) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        while true {
          try Task.checkCancellation()
          let message = try await opened.receive()
          guard Self.size(message) <= options.maximumMessageBytes else {
            throw RealtimeError.messageTooLarge
          }
          try Self.yield(.message(message), to: continuation)
        }
      }
      if let interval = options.heartbeatInterval {
        group.addTask {
          while true {
            try await Task.sleep(for: .seconds(interval))
            try await opened.ping()
          }
        }
      }
      do {
        _ = try await group.next()
        group.cancelAll()
        await opened.close()
      } catch {
        group.cancelAll()
        await opened.close()
        throw error
      }
    }
  }
  static func size(_ message: WebSocketMessage) -> Int {
    switch message {
    case .text(let text): text.utf8.count
    case .data(let data): data.count
    }
  }
  static func yield(
    _ event: RealtimeEvent,
    to continuation: AsyncThrowingStream<RealtimeEvent, any Error>.Continuation
  ) throws {
    switch continuation.yield(event) {
    case .enqueued: break
    case .dropped: throw RealtimeError.bufferOverflow
    case .terminated: throw CancellationError()
    @unknown default: throw RealtimeError.bufferOverflow
    }
  }
}
