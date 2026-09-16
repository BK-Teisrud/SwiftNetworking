import Foundation
import Networking

enum TransferResult: Sendable {
  case upload(HTTPResponse)
  case download(DownloadedFile)
}
final class FileTransferDelegate: NSObject, URLSessionDataDelegate,
  URLSessionDownloadDelegate, @unchecked Sendable
{
  private let lock = NSLock()
  private let options: TransferOptions
  private let destination: URL?
  private let progress: (@Sendable (TransferProgress) -> Void)?
  private var continuation: CheckedContinuation<TransferResult, any Error>?
  private weak var task: URLSessionTask?
  private var state: CompletionState = .pending
  private enum CompletionState { case pending, completed, cancelled }
  private var data = Data()
  private var received = 0
  private var metadata: ResponseMetadata?
  private var failure: (any Error)?
  private var download: DownloadedFile?
  init(
    options: TransferOptions, destination: URL?, progress: (@Sendable (TransferProgress) -> Void)?
  ) {
    self.options = options
    self.destination = destination
    self.progress = progress
  }
  func start(_ task: URLSessionTask, continuation: CheckedContinuation<TransferResult, any Error>) {
    let cancelled = lock.withLock {
      self.task = task
      self.continuation = continuation
      return state == .cancelled
    }
    if cancelled {
      task.cancel()
      continuation.resume(throwing: CancellationError())
      lock.withLock { self.continuation = nil }
    } else {
      task.resume()
    }
  }
  func cancel() {
    let cancelled = lock.withLock {
      () -> (URLSessionTask?, CheckedContinuation<TransferResult, any Error>?, URL?)? in
      guard state == .pending else { return nil }
      state = .cancelled
      let result = (task, continuation, download?.fileURL)
      continuation = nil
      download = nil
      return result
    }
    cancelled?.0?.cancel()
    if let file = cancelled?.2 { try? FileManager.default.removeItem(at: file) }
    cancelled?.1?.resume(throwing: CancellationError())
  }
  private func meta(_ response: HTTPURLResponse) -> ResponseMetadata {
    .init(
      statusCode: response.statusCode,
      headers: response.allHeaderFields.reduce(into: [:]) { result, pair in
        if let name = pair.key as? String { result[name] = String(describing: pair.value) }
      }, url: response.url)
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    lock.withLock {
      failure = NetworkingError.redirectRejected(
        .init(reason: .policyDenied, metadata: meta(response)))
    }
    completionHandler(nil)
  }
  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    let allowed = lock.withLock {
      guard let response = response as? HTTPURLResponse else {
        failure = NetworkingError.invalidResponse
        return false
      }
      metadata = meta(response)
      if response.expectedContentLength > Int64(options.maximumResponseBytes) {
        failure = NetworkingError.responseTooLarge(
          limit: options.maximumResponseBytes, metadata: metadata)
        return false
      }
      return true
    }
    completionHandler(allowed ? .allow : .cancel)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
    let exceeded = lock.withLock {
      guard chunk.count <= options.maximumResponseBytes - received else {
        failure = NetworkingError.responseTooLarge(
          limit: options.maximumResponseBytes, metadata: metadata)
        return true
      }
      received += chunk.count
      if metadata.map({ (200..<300).contains($0.statusCode) }) == true {
        data.append(chunk)
      } else {
        data.append(chunk.prefix(max(0, options.maximumErrorBodyBytes - data.count)))
      }
      return false
    }
    if exceeded { dataTask.cancel() }
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64, totalBytesExpectedToSend: Int64
  ) {
    progress?(
      .init(
        direction: .upload, completedBytes: totalBytesSent,
        totalBytes: totalBytesExpectedToSend >= 0 ? totalBytesExpectedToSend : nil))
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    if totalBytesWritten > options.maximumDownloadBytes
      || totalBytesExpectedToWrite > options.maximumDownloadBytes
    {
      lock.withLock { failure = TransferError.fileTooLarge(limit: options.maximumDownloadBytes) }
      downloadTask.cancel()
    }
    progress?(
      .init(
        direction: .download, completedBytes: totalBytesWritten,
        totalBytes: totalBytesExpectedToWrite >= 0 ? totalBytesExpectedToWrite : nil))
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    finishDownload(at: location, response: downloadTask.response as? HTTPURLResponse)
  }
  func finishDownload(at location: URL, response: HTTPURLResponse?) {
    lock.withLock {
      guard state == .pending, failure == nil else { return }
      do {
        guard let response, let destination else {
          throw NetworkingError.invalidResponse
        }
        metadata = meta(response)
        let size =
          (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?
          .int64Value ?? Int64.max
        guard size <= options.maximumDownloadBytes else {
          throw TransferError.fileTooLarge(limit: options.maximumDownloadBytes)
        }
        guard (200..<300).contains(response.statusCode) else {
          let handle = try FileHandle(forReadingFrom: location)
          defer { try? handle.close() }
          let body = try handle.read(upToCount: options.maximumErrorBodyBytes) ?? Data()
          throw NetworkingError.http(
            .init(metadata: meta(response), body: body, bodyWasTruncated: size > Int64(body.count)))
        }
        try FileManager.default.moveItem(at: location, to: destination)
        download = .init(fileURL: destination, metadata: meta(response), receivedBodyBytes: size)
      } catch { failure = error }
    }
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    let state = lock.withLock {
      () -> (
        CheckedContinuation<TransferResult, any Error>?, Result<TransferResult, any Error>, URL?
      ) in
      guard self.state == .pending else { return (nil, .failure(CancellationError()), nil) }
      self.state = .completed
      let continuation = self.continuation
      self.continuation = nil
      defer { download = nil }
      if let error = failure ?? error { return (continuation, .failure(error), download?.fileURL) }
      if let download { return (continuation, .success(.download(download)), nil) }
      guard let metadata else {
        return (continuation, .failure(NetworkingError.invalidResponse), nil)
      }
      guard (200..<300).contains(metadata.statusCode) else {
        return (
          continuation,
          .failure(
            NetworkingError.http(
              .init(metadata: metadata, body: data, bodyWasTruncated: received > data.count))), nil
        )
      }
      return (
        continuation,
        .success(.upload(.init(data: data, metadata: metadata, receivedBodyBytes: received))), nil
      )
    }
    if let file = state.2 { try? FileManager.default.removeItem(at: file) }
    state.0?.resume(with: state.1)
  }
}
