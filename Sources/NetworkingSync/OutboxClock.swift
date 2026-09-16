import Foundation

/// Time source for persisted delivery scheduling; no HTTP or sleep dependency.
public protocol OutboxClock: Sendable {
  func now() async -> Date
}
public struct SystemOutboxClock: OutboxClock {
  public init() {}
  public func now() async -> Date { Date() }
}
