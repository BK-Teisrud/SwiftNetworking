import Foundation
import Testing

@testable import NetworkingSync

private func temporary(_ name: String) -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(
    "Networking-\(UUID().uuidString)", isDirectory: true
  ).appendingPathComponent(name)
}
private actor Clock: OutboxClock {
  var date = Date(timeIntervalSince1970: 100)
  func now() -> Date { date }
  func sleep(for seconds: Double) { date.addTimeInterval(seconds) }
  func advance(_ seconds: Double) { date.addTimeInterval(seconds) }
}
private actor Deliveries {
  var seen: [OutboxItem] = []
  var fail = true
  func deliver(_ item: OutboxItem) -> SyncDisposition {
    seen.append(item)
    return fail ? .retry(after: 10) : .acknowledged
  }
  func succeed() { fail = false }
}
@Test func outboxPersistsRetryIdentityAndAccountIsolation() async throws {
  let file = temporary("outbox.json")
  defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
  let store = try FileOutboxStore(fileURL: file, accountID: "one")
  let clock = Clock()
  let delivery = Deliveries()
  let engine = try OutboxEngine(accountID: "one", store: store, clock: clock) {
    await delivery.deliver($0)
  }
  let id = try await engine.enqueue(payload: Data("operation".utf8), idempotencyKey: "stable-key")
  let result = try await engine.flush()
  #expect(result.deferred == 1)
  let reopened = try FileOutboxStore(fileURL: file, accountID: "one")
  #expect(try await reopened.items(accountID: "one").first?.id == id)
  #expect(try await reopened.items(accountID: "one").first?.attempts == 1)
  await #expect(throws: SyncError.self) { try await reopened.items(accountID: "two") }
  #expect(try await engine.flush().deferred == 1)
  await clock.advance(10)
  await delivery.succeed()
  #expect(try await engine.flush().acknowledged == 1)
  #expect(try await engine.pending().isEmpty)
  #expect(await delivery.seen.map(\.idempotencyKey) == ["stable-key", "stable-key"])
}
@Test func outboxCapacityBlockingAndConcurrentInsertion() async throws {
  let file = temporary("queue.json")
  defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
  let store = try FileOutboxStore(
    fileURL: file, accountID: "one", maximumItems: 10, maximumPayloadBytes: 4)
  let engine = try OutboxEngine(accountID: "one", store: store, maximumAttempts: 1) { _ in
    .retry(after: 0)
  }
  try await withThrowingTaskGroup(of: Void.self) { group in
    for _ in 0..<10 { group.addTask { _ = try await engine.enqueue(payload: Data([1])) } }
    try await group.waitForAll()
  }
  #expect(try await engine.pending().count == 10)
  await #expect(throws: SyncError.self) { try await engine.enqueue(payload: Data([1])) }
  #expect(try await engine.flush().blocked == 1)
  let first = try #require(try await engine.pending().first)
  #expect(first.blockedReason == "attemptLimit")
  try await engine.retryBlocked(id: first.id)
  #expect(try await engine.pending().first?.blockedReason == nil)
  try await engine.discard(id: first.id)
  #expect(try await engine.pending().count == 9)
}
@Test func reopenedOutboxRespectsLowerAttemptLimit() async throws {
  let file = temporary("queue.json")
  defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
  let store = try FileOutboxStore(fileURL: file, accountID: "one")
  var previous = OutboxItem(accountID: "one", idempotencyKey: "stable", payload: Data())
  previous.attempts = 1
  try await store.insert(previous)
  let engine = try OutboxEngine(accountID: "one", store: store, maximumAttempts: 1) { _ in
    Issue.record("A persisted exhausted attempt budget must not send again")
    return .acknowledged
  }
  #expect(try await engine.flush().blocked == 1)
  #expect(try await engine.pending().first?.blockedReason == "attemptLimit")
  let wrongAccount = try FileOutboxStore(fileURL: file, accountID: "two")
  do {
    _ = try await wrongAccount.items(accountID: "two")
    Issue.record("Expected account binding failure")
  } catch SyncError.accountMismatch {}
}
