import Foundation

/// Account-bound atomic JSON storage. Use one instance/writer per file; not a multiprocess database.
public actor FileOutboxStore: OutboxStore {
  private var fileEncoding = OutboxFileEncoding()
  public let fileURL: URL
  public let accountID: String
  private var snapshot: [OutboxItem]?
  private let maximumItems: Int
  private let maximumPayloadBytes: Int
  private let maximumFileBytes: Int
  public init(
    fileURL: URL, accountID: String, maximumItems: Int = 1000, maximumPayloadBytes: Int = 1_048_576,
    maximumFileBytes: Int = 16_777_216
  ) throws {
    guard fileURL.isFileURL, !accountID.isEmpty, maximumItems > 0, maximumPayloadBytes > 0,
      maximumFileBytes > 0
    else { throw SyncError.invalidConfiguration }
    self.fileURL = fileURL
    self.accountID = accountID
    self.maximumItems = maximumItems
    self.maximumPayloadBytes = maximumPayloadBytes
    self.maximumFileBytes = maximumFileBytes
  }
  public func insert(_ item: OutboxItem) throws {
    try validate(item)
    var current = try load()
    guard !current.contains(where: { $0.id == item.id || $0.idempotencyKey == item.idempotencyKey })
    else { throw SyncError.invalidConfiguration }
    guard current.count < maximumItems else { throw SyncError.capacityExceeded }
    current.append(item)
    try save(current)
  }
  public func items(accountID: String) throws -> [OutboxItem] {
    try check(accountID)
    return try load()
  }
  public func update(_ item: OutboxItem) throws {
    try validate(item)
    var current = try load()
    guard let index = current.firstIndex(where: { $0.id == item.id }) else {
      throw SyncError.operationNotFound
    }
    guard current[index].payload == item.payload,
      current[index].idempotencyKey == item.idempotencyKey,
      current[index].createdAt == item.createdAt
    else { throw SyncError.invalidConfiguration }
    current[index] = item
    try save(current)
  }
  public func remove(id: UUID, accountID: String) throws {
    try check(accountID)
    var current = try load()
    guard let index = current.firstIndex(where: { $0.id == id }) else {
      throw SyncError.operationNotFound
    }
    current.remove(at: index)
    try save(current)
  }
  private func check(_ accountID: String) throws {
    guard accountID == self.accountID else { throw SyncError.accountMismatch }
  }
  private func validate(_ item: OutboxItem) throws {
    try check(item.accountID)
    guard !item.idempotencyKey.isEmpty,
      !item.idempotencyKey.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
      item.attempts >= 0, item.attempts < Int.max, item.createdAt.timeIntervalSince1970.isFinite,
      item.notBefore.timeIntervalSince1970.isFinite
    else { throw SyncError.invalidConfiguration }
    guard item.payload.count <= maximumPayloadBytes else { throw SyncError.capacityExceeded }
  }
  public func nextItem(accountID: String) throws -> OutboxItem? {
    try check(accountID)
    return try load().first
  }
  private func load() throws -> [OutboxItem] {
    if let snapshot { return snapshot }
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard ((attributes[.size] as? NSNumber)?.intValue ?? Int.max) <= maximumFileBytes else {
      throw SyncError.capacityExceeded
    }
    let envelope: OutboxEnvelope
    do {
      envelope = try JSONDecoder().decode(OutboxEnvelope.self, from: Data(contentsOf: fileURL))
    } catch { throw SyncError.corruptStore }
    guard envelope.version == 1 else { throw SyncError.corruptStore }
    try check(envelope.accountID)
    guard envelope.items.count <= maximumItems else { throw SyncError.capacityExceeded }
    var ids = Set<UUID>()
    var keys = Set<String>()
    for item in envelope.items {
      try validate(item)
      guard ids.insert(item.id).inserted, keys.insert(item.idempotencyKey).inserted else {
        throw SyncError.corruptStore
      }
    }
    snapshot = envelope.items
    return envelope.items
  }
  private func save(_ items: [OutboxItem]) throws {
    var candidateEncoding = fileEncoding
    let encoded = try candidateEncoding.encode(
      items, accountID: accountID, maximumBytes: maximumFileBytes)
    guard encoded.count <= maximumFileBytes else { throw SyncError.capacityExceeded }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try encoded.write(to: fileURL, options: .atomic)
    snapshot = items
    fileEncoding = candidateEncoding
  }
}
