import Foundation

/// Contains no URL, headers, credentials or body. Labels must be static operation names.
public struct DiagnosticEvent: Sendable {
  public enum Kind: Sendable {
    case response, transportFailure, cancelled, decodingFailure, deadlineExceeded, policyRejected,
      authenticationFailure, operationFailure
  }
  public let method: HTTPMethod
  public let statusCode: Int?
  public let duration: TimeInterval
  public let attempt: Int
  public let operationID: UUID
  public let label: String?
  public let kind: Kind
}
public protocol NetworkingDiagnostics: Sendable {
  func record(_ event: DiagnosticEvent) async
}

/// One worker per configuration, bounded pending queue; overflow drops newest events.
final class DiagnosticDispatcher: @unchecked Sendable {
  private let lock = NSLock()
  private let sink: any NetworkingDiagnostics
  private let capacity: Int
  private var pending: [DiagnosticEvent] = []
  private var running = false
  private var dropped = 0
  var droppedCount: Int { lock.withLock { dropped } }
  private var waiters: [CheckedContinuation<Void, Never>] = []
  init(sink: any NetworkingDiagnostics, capacity: Int) {
    self.sink = sink
    self.capacity = capacity
  }
  func enqueue(_ event: DiagnosticEvent) {
    let start = lock.withLock {
      guard pending.count < capacity else {
        if dropped < Int.max { dropped += 1 }
        return false
      }
      pending.append(event)
      if running { return false }
      running = true
      return true
    }
    if start { Task { await drain() } }
  }
  private func drain() async {
    while true {
      let next: (DiagnosticEvent?, [CheckedContinuation<Void, Never>]) = lock.withLock {
        if !pending.isEmpty { return (pending.removeFirst(), []) }
        running = false
        let completed = waiters
        waiters.removeAll()
        return (nil, completed)
      }
      guard let event = next.0 else {
        for continuation in next.1 { continuation.resume() }
        return
      }
      await sink.record(event)
    }
  }
  /// Explicit export barrier; the sink must cooperate and eventually return.
  func flush() async {
    await withCheckedContinuation { continuation in
      let idle = lock.withLock {
        if !running { return true }
        waiters.append(continuation)
        return false
      }
      if idle { continuation.resume() }
    }
  }
}
