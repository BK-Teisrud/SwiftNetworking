import Foundation

public enum SyncError: Error, Sendable {
  case invalidConfiguration, accountMismatch, capacityExceeded, corruptStore, operationNotFound
}
public struct OutboxItem: Codable, Sendable, Equatable {
  public let id: UUID
  public let accountID: String
  public let idempotencyKey: String
  public let payload: Data
  public let createdAt: Date
  public var attempts: Int
  public var notBefore: Date
  public var blockedReason: String?
  public init(
    id: UUID = UUID(), accountID: String, idempotencyKey: String, payload: Data,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.accountID = accountID
    self.idempotencyKey = idempotencyKey
    self.payload = payload
    self.createdAt = createdAt
    self.notBefore = createdAt
    self.attempts = 0
    self.blockedReason = nil
  }
}
/// Each mutation must be atomic. One engine owns delivery for an account/store.
public protocol OutboxStore: Sendable {
  func insert(_ item: OutboxItem) async throws
  func nextItem(accountID: String) async throws -> OutboxItem?
  func items(accountID: String) async throws -> [OutboxItem]
  func update(_ item: OutboxItem) async throws
  func remove(id: UUID, accountID: String) async throws
}
public enum SyncDisposition: Sendable {
  case acknowledged
  case retry(after: Double)
  case blocked(reason: String)
}
public struct SyncReport: Sendable {
  public let acknowledged: Int
  public let deferred: Int
  public let blocked: Int
  public let alreadyRunning: Bool
}

extension OutboxStore {
  public func nextItem(accountID: String) async throws -> OutboxItem? {
    try await items(accountID: accountID).first
  }
}
