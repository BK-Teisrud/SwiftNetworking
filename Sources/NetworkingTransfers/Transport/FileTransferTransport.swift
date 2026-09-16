import Foundation
import Networking

public protocol FileTransferTransport: Sendable {
  func upload(
    _ request: URLRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)?
  ) async throws -> HTTPResponse
  func download(
    _ request: URLRequest, to destination: URL, progress: (@Sendable (TransferProgress) -> Void)?
  ) async throws -> DownloadedFile
}
