import Foundation

/// Session admission and shutdown are serialized; URLSession owns task callback serialization.
final class BackgroundSessionLifecycle: @unchecked Sendable {
  private enum State { case active, finishing, cancelled }
  private let lock = NSLock()
  private var state: State = .active
  func schedule<T>(_ operation: () throws -> T) throws -> T {
    try lock.withLock {
      guard state == .active else { throw TransferError.invalidConfiguration }
      return try operation()
    }
  }
  func finish(_ operation: () -> Void) {
    lock.withLock {
      guard state == .active else { return }
      state = .finishing
      operation()
    }
  }
  func cancel(_ operation: () -> Void) {
    lock.withLock {
      guard state != .cancelled else { return }
      state = .cancelled
      operation()
    }
  }
}
