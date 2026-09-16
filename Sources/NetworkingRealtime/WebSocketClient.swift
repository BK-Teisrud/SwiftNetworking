import Foundation

/// One active event stream per client. Start a new stream to start a new connection budget.
public actor WebSocketClient {
  private let connector: any WebSocketConnector
  private let options: WebSocketOptions
  private let makeRequest: @Sendable () async throws -> URLRequest
  private var session: WebSocketSession?
  private var closing: Task<Void, Never>?
  public init(
    options: WebSocketOptions, connector: (any WebSocketConnector)? = nil,
    makeRequest: @escaping @Sendable () async throws -> URLRequest
  ) {
    self.options = options
    self.connector =
      connector ?? URLSessionWebSocketConnector(maximumMessageBytes: options.maximumMessageBytes)
    self.makeRequest = makeRequest
  }
  public func events() async -> AsyncThrowingStream<RealtimeEvent, any Error> {
    let cleanup = detach()
    let id = UUID()
    let pair = AsyncThrowingStream<RealtimeEvent, any Error>.makeStream(
      bufferingPolicy: .bufferingOldest(options.eventBufferCapacity))
    pair.continuation.onTermination = { [weak self] _ in
      Task { await self?.disconnect(generation: id) }
    }
    session = WebSocketSession(id: id, continuation: pair.continuation)
    session?.worker = Task {
      await cleanup?.value
      await run(id: id, continuation: pair.continuation)
    }
    return pair.stream
  }
  public func send(_ message: WebSocketMessage) async throws {
    try Task.checkCancellation()
    guard let connection = session?.connection else { throw RealtimeError.notConnected }
    guard RealtimeStream.size(message) <= options.maximumMessageBytes else {
      throw RealtimeError.messageTooLarge
    }
    try await connection.send(message)
    try Task.checkCancellation()
  }
  public func disconnect() async { await detach()?.value }

  // Claim ownership synchronously. New sessions wait for all older cleanup before opening.
  private func detach() -> Task<Void, Never>? {
    guard let previous = session else { return closing }
    session = nil
    previous.worker?.cancel()
    previous.continuation.finish()
    let olderCleanup = closing
    let cleanup = Task {
      await olderCleanup?.value
      await previous.connection?.close()
      await previous.worker?.value
    }
    closing = cleanup
    return cleanup
  }
  private func disconnect(generation id: UUID) async {
    if session?.id == id { await disconnect() }
  }
  private func run(
    id: UUID, continuation: AsyncThrowingStream<RealtimeEvent, any Error>.Continuation
  ) async {
    do {
      for attempt in 1...options.maximumConnectionAttempts {
        try Task.checkCancellation()
        guard session?.id == id else { throw CancellationError() }
        do {
          let request = try await makeRequest()
          try Task.checkCancellation()
          let opened = try await connector.open(request)
          guard session?.id == id, !Task.isCancelled else {
            await opened.close()
            throw CancellationError()
          }
          session?.connection = opened
          do {
            try RealtimeStream.yield(.connected(attempt: attempt), to: continuation)
            try await RealtimeStream.read(opened, continuation: continuation, options: options)
          } catch {
            await opened.close()
            throw error
          }
        } catch {
          if session?.id == id { session?.connection = nil }
          if Task.isCancelled || error is CancellationError { throw CancellationError() }
          // Policy/overflow failures are terminal; reconnecting cannot restore lost messages.
          if error is RealtimeError || attempt == options.maximumConnectionAttempts { throw error }
          let delay = min(
            options.maximumReconnectDelay,
            options.reconnectBaseDelay * pow(2, Double(min(attempt - 1, 60))))
          try RealtimeStream.yield(
            .reconnecting(attempt: attempt + 1, delay: delay), to: continuation)
          try await Task.sleep(for: .seconds(delay))
        }
      }
    } catch is CancellationError { continuation.finish() } catch {
      continuation.finish(throwing: error)
    }
    if session?.id == id {
      session = nil
    }
  }
}
