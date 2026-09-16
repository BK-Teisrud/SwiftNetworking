import Foundation
import Networking

/// Foreground file transfers. A single send; no implicit replay, recovery or redirects.
public struct TransferClient: Sendable {
  private let preparer: (any HTTPRequestPreparing)?
  private let transport: any FileTransferTransport
  public init(httpClient: HTTPClient, transport: any FileTransferTransport) {
    self.preparer = httpClient
    self.transport = transport
  }
  /// For absolute, presigned URLRequests; HTTPRequest calls require a preparer.
  public init(transport: any FileTransferTransport) {
    self.preparer = nil
    self.transport = transport
  }
  public init(requestPreparer: any HTTPRequestPreparing, transport: any FileTransferTransport) {
    self.preparer = requestPreparer
    self.transport = transport
  }
  private func prepare(_ request: HTTPRequest) async throws -> URLRequest {
    guard let preparer else {
      throw NetworkingError.invalidRequest("HTTPRequest requires a request preparer")
    }
    return try await preparer.prepare(request)
  }
  public func upload(
    _ request: HTTPRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)? = nil
  ) async throws -> HTTPResponse {
    guard request.body == nil else {
      throw NetworkingError.invalidRequest("File upload cannot also have an HTTPBody")
    }
    return try await transport.upload(prepare(request), from: file, progress: progress)
  }
  public func download(
    _ request: HTTPRequest, to destination: URL,
    progress: (@Sendable (TransferProgress) -> Void)? = nil
  ) async throws -> DownloadedFile {
    try await transport.download(prepare(request), to: destination, progress: progress)
  }
  /// Explicit absolute URLRequest for presigned URLs/signers. No base headers or bearer token are added.
  public func upload(
    _ request: URLRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)? = nil
  ) async throws -> HTTPResponse {
    try await transport.upload(request, from: file, progress: progress)
  }
  public func download(
    _ request: URLRequest, to destination: URL,
    progress: (@Sendable (TransferProgress) -> Void)? = nil
  ) async throws -> DownloadedFile {
    try await transport.download(request, to: destination, progress: progress)
  }
}
