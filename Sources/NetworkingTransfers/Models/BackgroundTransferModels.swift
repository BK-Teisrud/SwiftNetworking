import Foundation
import Networking

/// Persisted completion, scoped to one system background-session identifier/account.
public struct BackgroundTransferReceipt: Codable, Sendable {
  public let jobID: UUID
  public let statusCode: Int?
  public let fileName: String?
  public let receivedBodyBytes: Int64
  public let responseBody: Data
  /// nil means HTTP success; categories contain no URL, headers or error descriptions.
  public let failureCategory: String?
}
/// Apple background sessions always follow HTTP redirects; choose only for trusted servers.
public enum BackgroundRedirectPolicy: Sendable { case systemManagedForTrustedServers }
public enum BackgroundTransferEvent: Sendable {
  case progress(jobID: UUID, TransferProgress)
  case finished(BackgroundTransferReceipt)
}
public struct BackgroundTransferTask: Sendable {
  public let taskIdentifier: Int
  public let jobID: UUID?
  public let completedBytes: Int64
  public let expectedBytes: Int64?
}
