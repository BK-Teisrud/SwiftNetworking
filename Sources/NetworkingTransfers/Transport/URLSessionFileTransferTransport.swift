import Foundation
import Networking

public struct URLSessionFileTransferTransport: FileTransferTransport {
  public let options: TransferOptions
  public init(options: TransferOptions) { self.options = options }
  public func upload(
    _ request: URLRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)?
  ) async throws -> HTTPResponse {
    try validate(request)
    guard file.isFileURL, request.httpBody == nil, request.httpBodyStream == nil else {
      throw TransferError.invalidFile
    }
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    guard attributes[.type] as? FileAttributeType == .typeRegular else {
      throw TransferError.invalidFile
    }
    guard ((attributes[.size] as? NSNumber)?.int64Value ?? Int64.max) <= options.maximumUploadBytes
    else { throw TransferError.fileTooLarge(limit: options.maximumUploadBytes) }
    let result = try await run(request, file: file, destination: nil, progress: progress)
    guard case .upload(let response) = result else { throw TransferError.unexpectedResult }
    return response
  }
  public func download(
    _ request: URLRequest, to destination: URL, progress: (@Sendable (TransferProgress) -> Void)?
  ) async throws -> DownloadedFile {
    try validate(request)
    guard destination.isFileURL, request.httpBody == nil, request.httpBodyStream == nil else {
      throw TransferError.invalidFile
    }
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw TransferError.destinationExists
    }
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    let result = try await run(request, file: nil, destination: destination, progress: progress)
    guard case .download(let response) = result else { throw TransferError.unexpectedResult }
    return response
  }
  private func validate(_ request: URLRequest) throws {
    guard let url = request.url, let host = url.host, url.user == nil, url.password == nil,
      url.fragment == nil,
      url.scheme?.lowercased() == "https"
        || (options.security == .allowLocalHTTP && url.scheme?.lowercased() == "http"
          && ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host.lowercased()))
    else { throw TransferError.invalidConfiguration }
    try Task.checkCancellation()
  }
  private func run(
    _ request: URLRequest, file: URL?, destination: URL?,
    progress: (@Sendable (TransferProgress) -> Void)?
  ) async throws -> TransferResult {
    let delegate = FileTransferDelegate(
      options: options, destination: destination, progress: progress)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForResource = options.resourceTimeout
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    defer { session.invalidateAndCancel() }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        var request = request
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task: URLSessionTask
        if let file {
          task = session.uploadTask(with: request, fromFile: file)
        } else {
          task = session.downloadTask(with: request)
        }
        delegate.start(task, continuation: continuation)
      }
    } onCancel: {
      delegate.cancel()
    }
  }
}
