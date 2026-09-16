import Foundation

/// Version 1 remains compatible with the original Codable envelope.
struct OutboxEnvelope: Codable {
  let version: Int
  let accountID: String
  let items: [OutboxItem]
}
/// Reuses unchanged item encodings; each acknowledged item still gets a durable atomic write.
struct OutboxFileEncoding {
  struct Entry {
    let item: OutboxItem
    let data: Data
  }
  private(set) var entries: [UUID: Entry] = [:]
  mutating func encode(_ items: [OutboxItem], accountID: String, maximumBytes: Int) throws -> Data {
    let encoder = JSONEncoder()
    let account = try encoder.encode(accountID)
    var result = Data("{\"version\":1,\"accountID\":".utf8)
    result.append(account)
    result.append(Data(",\"items\":[".utf8))
    var updated: [UUID: Entry] = [:]
    for (index, item) in items.enumerated() {
      let entry: Entry
      if let previous = entries[item.id], previous.item == item {
        entry = previous
      } else {
        entry = Entry(item: item, data: try encoder.encode(item))
      }
      let separatorBytes = index == 0 ? 0 : 1
      guard result.count <= maximumBytes,
        entry.data.count <= maximumBytes - result.count - separatorBytes - 2
      else { throw SyncError.capacityExceeded }
      if index != 0 { result.append(44) }
      result.append(entry.data)
      updated[item.id] = entry
    }
    result.append(Data("]}".utf8))
    guard result.count <= maximumBytes else { throw SyncError.capacityExceeded }
    entries = updated
    return result
  }
}
