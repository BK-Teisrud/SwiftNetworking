import Foundation
import Networking

public struct TransferProgress: Sendable {
  public enum Direction: Sendable { case upload, download }
  public let direction: Direction
  public let completedBytes: Int64
  public let totalBytes: Int64?
  public init(direction: Direction, completedBytes: Int64, totalBytes: Int64? = nil) {
    self.direction = direction
    self.completedBytes = completedBytes
    self.totalBytes = totalBytes
  }
  public var fractionCompleted: Double? {
    totalBytes.flatMap { $0 > 0 ? min(1, Double(completedBytes) / Double($0)) : nil }
  }
}
public struct DownloadedFile: Sendable {
  /// Caller owns the destination file after a successful return.
  public let fileURL: URL
  public let metadata: ResponseMetadata
  public let receivedBodyBytes: Int64
  public init(fileURL: URL, metadata: ResponseMetadata, receivedBodyBytes: Int64) {
    self.fileURL = fileURL
    self.metadata = metadata
    self.receivedBodyBytes = receivedBodyBytes
  }
}
public enum TransferError: Error, Sendable {
  case invalidConfiguration, invalidFile
  case fileTooLarge(limit: Int64)
  case destinationExists, unexpectedResult
}
public struct TransferOptions: Sendable {
  public let maximumUploadBytes: Int64
  public let maximumDownloadBytes: Int64
  public let maximumResponseBytes: Int
  public let maximumErrorBodyBytes: Int
  public let resourceTimeout: Double
  public let security: ConnectionSecurity
  public init(
    maximumUploadBytes: Int64 = 524_288_000, maximumDownloadBytes: Int64 = 524_288_000,
    maximumResponseBytes: Int = 10_485_760, maximumErrorBodyBytes: Int = 16_384,
    resourceTimeout: Double = 300, security: ConnectionSecurity = .httpsOnly
  ) throws {
    guard maximumUploadBytes > 0, maximumDownloadBytes > 0, maximumResponseBytes > 0,
      maximumErrorBodyBytes >= 0,
      resourceTimeout.isFinite, resourceTimeout > 0, resourceTimeout <= 86_400
    else { throw TransferError.invalidConfiguration }
    self.maximumUploadBytes = maximumUploadBytes
    self.maximumDownloadBytes = maximumDownloadBytes
    self.maximumResponseBytes = maximumResponseBytes
    self.maximumErrorBodyBytes = maximumErrorBodyBytes
    self.resourceTimeout = resourceTimeout
    self.security = security
  }
}
