import Foundation

public struct BackgroundReceiptIssue: Sendable {
  public enum Category: Sendable { case unreadable, invalidReceipt, tooLarge }
  public let fileName: String
  public let category: Category
}
public struct BackgroundReceiptScan: Sendable {
  public let receipts: [BackgroundTransferReceipt]
  public let issues: [BackgroundReceiptIssue]
}
/// One store per directory. Serializes receipt writes, scanning and acknowledgement.
/// Corrupt receipts are retained and reported individually; no completion is silently deleted.
public final class BackgroundReceiptStore: Sendable {
  public let directory: URL
  private let maximumReceiptBytes: Int
  private let lock = NSLock()
  public init(directory: URL, maximumReceiptBytes: Int = 16_777_216) throws {
    guard directory.isFileURL, maximumReceiptBytes >= 1024 else {
      throw TransferError.invalidConfiguration
    }
    self.directory = directory
    self.maximumReceiptBytes = maximumReceiptBytes
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }
  public func scan() throws -> BackgroundReceiptScan {
    try lock.withLock {
      var receipts: [BackgroundTransferReceipt] = []
      var issues: [BackgroundReceiptIssue] = []
      let files = try FileManager.default.contentsOfDirectory(
        at: directory, includingPropertiesForKeys: nil
      )
      .filter { $0.lastPathComponent.hasSuffix(".receipt.json") }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
      for file in files {
        do {
          let size =
            (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?
            .intValue ?? Int.max
          guard size <= maximumReceiptBytes else {
            issues.append(.init(fileName: file.lastPathComponent, category: .tooLarge))
            continue
          }
          let receipt: BackgroundTransferReceipt
          do {
            receipt = try JSONDecoder().decode(
              BackgroundTransferReceipt.self, from: Data(contentsOf: file))
          } catch {
            issues.append(.init(fileName: file.lastPathComponent, category: .invalidReceipt))
            continue
          }
          guard receipt.receivedBodyBytes >= 0,
            file.lastPathComponent == receipt.jobID.uuidString + ".receipt.json",
            receipt.fileName == nil || receipt.fileName == receipt.jobID.uuidString + ".download"
          else {
            issues.append(.init(fileName: file.lastPathComponent, category: .invalidReceipt))
            continue
          }
          receipts.append(receipt)
        } catch { issues.append(.init(fileName: file.lastPathComponent, category: .unreadable)) }
      }
      return .init(receipts: receipts, issues: issues)
    }
  }
  public func acknowledge(jobID: UUID, removeDownloadedFile: Bool = false) throws {
    try lock.withLock {
      if removeDownloadedFile {
        let file = directory.appendingPathComponent(jobID.uuidString + ".download")
        if FileManager.default.fileExists(atPath: file.path) {
          try FileManager.default.removeItem(at: file)
        }
      }
      try FileManager.default.removeItem(
        at: directory.appendingPathComponent(jobID.uuidString + ".receipt.json"))
    }
  }
  /// Persists full receipt, or a small failure receipt if its body exceeds the store limit.
  /// Disk errors remain errors; no persistence guarantee is possible on an unwritable disk.
  @discardableResult func saveCompletion(_ receipt: BackgroundTransferReceipt) throws
    -> BackgroundTransferReceipt
  {
    do {
      try save(receipt)
      return receipt
    } catch TransferError.fileTooLarge {
      let fallback = BackgroundTransferReceipt(
        jobID: receipt.jobID, statusCode: receipt.statusCode,
        fileName: receipt.fileName, receivedBodyBytes: receipt.receivedBodyBytes,
        responseBody: Data(), failureCategory: "receiptTooLarge")
      try save(fallback)
      return fallback
    }
  }
  func save(_ receipt: BackgroundTransferReceipt) throws {
    try lock.withLock {
      let data = try JSONEncoder().encode(receipt)
      guard data.count <= maximumReceiptBytes else {
        throw TransferError.fileTooLarge(limit: Int64(maximumReceiptBytes))
      }
      try data.write(
        to: directory.appendingPathComponent(receipt.jobID.uuidString + ".receipt.json"),
        options: .atomic)
    }
  }
}
