import Foundation

/// FIFO, at-least-once outbox delivery. No automatic reachability monitor or domain merge rules.
public actor OutboxEngine {
  public let accountID: String
  private let store: any OutboxStore
  private let clock: any OutboxClock
  private let maximumAttempts: Int
  private let deliver: @Sendable (OutboxItem) async throws -> SyncDisposition
  private var flushing = false
  public init(
    accountID: String, store: any OutboxStore, maximumAttempts: Int = 10,
    clock: any OutboxClock = SystemOutboxClock(),
    deliver: @escaping @Sendable (OutboxItem) async throws -> SyncDisposition
  ) throws {
    guard !accountID.isEmpty, maximumAttempts > 0, maximumAttempts < Int.max else {
      throw SyncError.invalidConfiguration
    }
    self.accountID = accountID
    self.store = store
    self.maximumAttempts = maximumAttempts
    self.clock = clock
    self.deliver = deliver
  }
  @discardableResult public func enqueue(payload: Data, idempotencyKey: String = UUID().uuidString)
    async throws -> UUID
  {
    try Task.checkCancellation()
    let item = OutboxItem(
      accountID: accountID, idempotencyKey: idempotencyKey, payload: payload,
      createdAt: await clock.now())
    try await store.insert(item)
    return item.id
  }
  public func pending() async throws -> [OutboxItem] { try await store.items(accountID: accountID) }
  public func retryBlocked(id: UUID) async throws {
    guard !flushing else { throw SyncError.invalidConfiguration }
    flushing = true
    defer { flushing = false }
    guard var item = try await store.items(accountID: accountID).first(where: { $0.id == id })
    else { throw SyncError.operationNotFound }
    item.attempts = 0
    item.blockedReason = nil
    item.notBefore = await clock.now()
    try await store.update(item)
  }
  public func discard(id: UUID) async throws {
    guard !flushing else { throw SyncError.invalidConfiguration }
    flushing = true
    defer { flushing = false }
    try await store.remove(id: id, accountID: accountID)
  }
  public func flush(maximumOperations: Int = 100) async throws -> SyncReport {
    guard maximumOperations > 0 else { throw SyncError.invalidConfiguration }
    guard !flushing else {
      return .init(acknowledged: 0, deferred: 0, blocked: 0, alreadyRunning: true)
    }
    flushing = true
    defer { flushing = false }
    var acknowledged = 0
    var deferred = 0
    var blocked = 0
    for _ in 0..<maximumOperations {
      try Task.checkCancellation()
      guard var item = try await store.nextItem(accountID: accountID) else { break }
      guard item.accountID == accountID else { throw SyncError.accountMismatch }
      guard item.attempts >= 0, item.attempts < Int.max,
        item.notBefore.timeIntervalSince1970.isFinite
      else { throw SyncError.corruptStore }
      if item.attempts >= maximumAttempts, item.blockedReason == nil {
        item.blockedReason = "attemptLimit"
        try await store.update(item)
      }
      if item.blockedReason != nil {
        blocked += 1
        break
      }
      if item.notBefore > (await clock.now()) {
        deferred += 1
        break
      }
      let disposition: SyncDisposition
      do { disposition = try await deliver(item) } catch {
        if error is CancellationError || Task.isCancelled { throw CancellationError() }
        disposition = .retry(after: min(300, pow(2, Double(min(item.attempts, 8)))))
      }
      try Task.checkCancellation()
      switch disposition {
      case .acknowledged:
        try await store.remove(id: item.id, accountID: accountID)
        acknowledged += 1
      case .blocked(let reason):
        item.blockedReason = reason
        try await store.update(item)
        blocked += 1
      case .retry(let delay):
        guard delay.isFinite, delay >= 0, delay <= 86_400 else {
          throw SyncError.invalidConfiguration
        }
        item.attempts += 1
        if item.attempts >= maximumAttempts {
          item.blockedReason = "attemptLimit"
          blocked += 1
        } else {
          item.notBefore = (await clock.now()).addingTimeInterval(delay)
          deferred += 1
        }
        try await store.update(item)
      }
      if case .acknowledged = disposition { continue }
      break
    }
    return .init(
      acknowledged: acknowledged, deferred: deferred, blocked: blocked, alreadyRunning: false)
  }
}
