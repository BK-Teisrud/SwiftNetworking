import Foundation
import Testing

@testable import NetworkingSync

@Test func failedPersistenceDoesNotPublishUncommittedSnapshot() async throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let url = root.appendingPathComponent("queue.json")
  let store = try FileOutboxStore(fileURL: url, accountID: "one", maximumFileBytes: 4096)
  let first = OutboxItem(accountID: "one", idempotencyKey: "first", payload: Data([1]))
  try await store.insert(first)
  let oversized = OutboxItem(
    accountID: "one", idempotencyKey: "second", payload: Data(repeating: 1, count: 3000))
  await #expect(throws: SyncError.self) { try await store.insert(oversized) }
  #expect(try await store.nextItem(accountID: "one")?.id == first.id)
  #expect(try await store.items(accountID: "one").count == 1)
  let reopened = try FileOutboxStore(fileURL: url, accountID: "one")
  #expect(try await reopened.items(accountID: "one").map(\.id) == [first.id])
}
@Test func thousandItemQueuePreservesFIFOAndDurabilityDuringBatchDelivery() async throws {
  struct Envelope: Encodable {
    let version: Int
    let accountID: String
    let items: [OutboxItem]
  }
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let url = root.appendingPathComponent("queue.json")
  let items = (0..<1000).map {
    OutboxItem(
      accountID: "one", idempotencyKey: "key-\($0)", payload: Data(repeating: 1, count: 1024))
  }
  try JSONEncoder().encode(Envelope(version: 1, accountID: "one", items: items)).write(to: url)
  let store = try FileOutboxStore(fileURL: url, accountID: "one")
  actor Delivery {
    var ids: [UUID] = []
    func acknowledge(_ item: OutboxItem) -> SyncDisposition {
      ids.append(item.id)
      return .acknowledged
    }
  }
  let delivery = Delivery()
  let engine = try OutboxEngine(accountID: "one", store: store) { await delivery.acknowledge($0) }
  let start = ContinuousClock.now
  #expect(try await engine.flush(maximumOperations: 100).acknowledged == 100)
  print("Outbox sample: 100 acknowledgements, 1000 × 1 KiB payloads:", start.duration(to: .now))
  #expect(await delivery.ids == Array(items.prefix(100).map(\.id)))
  let reopened = try FileOutboxStore(fileURL: url, accountID: "one")
  #expect(
    try await reopened.items(accountID: "one").map(\.id) == Array(items.dropFirst(100).map(\.id)))
}
