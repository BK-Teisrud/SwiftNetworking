import Foundation

/// All fields are owned by WebSocketClient's actor; cleanup receives a detached snapshot.
struct WebSocketSession {
  let id: UUID
  let continuation: AsyncThrowingStream<RealtimeEvent, any Error>.Continuation
  var connection: (any WebSocketConnection)?
  var worker: Task<Void, Never>?
}
