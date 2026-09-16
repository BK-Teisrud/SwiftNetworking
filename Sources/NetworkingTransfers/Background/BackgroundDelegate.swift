import Foundation
import Networking

final class BackgroundDelegate: NSObject, URLSessionDataDelegate,
  URLSessionDownloadDelegate, @unchecked Sendable
{
  private let directory: URL
  private let receiptStore: BackgroundReceiptStore
  private let options: TransferOptions
  private let onEvent: @Sendable (BackgroundTransferEvent) -> Void
  private let finished: @Sendable () -> Void
  // URLSession's serial delegate queue owns all state below.
  private var bodies: [Int: Data] = [:]
  private var failures: [Int: String] = [:]
  private var sizes: [Int: Int64] = [:]
  private var files: [Int: String] = [:]
  init(
    directory: URL, receiptStore: BackgroundReceiptStore, options: TransferOptions,
    onEvent: @escaping @Sendable (BackgroundTransferEvent) -> Void,
    finished: @escaping @Sendable () -> Void
  ) {
    self.directory = directory
    self.receiptStore = receiptStore
    self.options = options
    self.onEvent = onEvent
    self.finished = finished
  }
  private func id(_ task: URLSessionTask) -> UUID? {
    task.taskDescription.flatMap(UUID.init(uuidString:))
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    failures[task.taskIdentifier] = "redirectRejected"
    completionHandler(nil)
  }
  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    if response.expectedContentLength > Int64(options.maximumResponseBytes) {
      failures[dataTask.taskIdentifier] = "responseTooLarge"
      completionHandler(.cancel)
    } else {
      completionHandler(.allow)
    }
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let key = dataTask.taskIdentifier
    let received = sizes[key] ?? 0
    guard Int64(data.count) <= Int64(options.maximumResponseBytes) - received else {
      failures[key] = "responseTooLarge"
      dataTask.cancel()
      return
    }
    sizes[key] = received + Int64(data.count)
    let success =
      (dataTask.response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } ?? false
    let limit = success ? options.maximumResponseBytes : options.maximumErrorBodyBytes
    let existingCount = bodies[key]?.count ?? 0
    bodies[key, default: Data()].append(data.prefix(max(0, limit - existingCount)))
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64, totalBytesExpectedToSend: Int64
  ) {
    if let id = id(task) {
      onEvent(
        .progress(
          jobID: id,
          .init(
            direction: .upload, completedBytes: totalBytesSent,
            totalBytes: totalBytesExpectedToSend >= 0 ? totalBytesExpectedToSend : nil)))
    }
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
  ) {
    if totalBytesWritten > options.maximumDownloadBytes
      || totalBytesExpectedToWrite > options.maximumDownloadBytes
    {
      failures[downloadTask.taskIdentifier] = "fileTooLarge"
      downloadTask.cancel()
    }
    if let id = id(downloadTask) {
      onEvent(
        .progress(
          jobID: id,
          .init(
            direction: .download, completedBytes: totalBytesWritten,
            totalBytes: totalBytesExpectedToWrite >= 0 ? totalBytesExpectedToWrite : nil)))
    }
  }
  func urlSession(
    _ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    let key = downloadTask.taskIdentifier
    guard let id = id(downloadTask), failures[key] == nil else { return }
    do {
      let size =
        (try FileManager.default.attributesOfItem(atPath: location.path)[.size] as? NSNumber)?
        .int64Value ?? Int64.max
      sizes[key] = size
      guard size <= options.maximumDownloadBytes else {
        failures[key] = "fileTooLarge"
        return
      }
      guard let response = downloadTask.response as? HTTPURLResponse else {
        failures[key] = "invalidResponse"
        return
      }
      guard (200..<300).contains(response.statusCode) else {
        let handle = try FileHandle(forReadingFrom: location)
        defer { try? handle.close() }
        bodies[key] = try handle.read(upToCount: options.maximumErrorBodyBytes) ?? Data()
        return
      }
      let name = id.uuidString + ".download"
      try FileManager.default.moveItem(at: location, to: directory.appendingPathComponent(name))
      files[key] = name
    } catch { failures[key] = "fileIO" }
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    let key = task.taskIdentifier
    defer {
      bodies.removeValue(forKey: key)
      failures.removeValue(forKey: key)
      sizes.removeValue(forKey: key)
      files.removeValue(forKey: key)
    }
    guard let id = id(task) else { return }
    let status = (task.response as? HTTPURLResponse)?.statusCode
    let missingDownload =
      task is URLSessionDownloadTask && files[key] == nil
      && status.map({ (200..<300).contains($0) }) == true
    let category =
      failures[key] ?? (missingDownload ? "invalidResponse" : nil)
      ?? (error != nil
        ? "transport" : (status.map { (200..<300).contains($0) } == true ? nil : "http"))
    if category != nil, let name = files[key] {
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
      files[key] = nil
    }
    let receipt = BackgroundTransferReceipt(
      jobID: id, statusCode: status, fileName: files[key], receivedBodyBytes: sizes[key] ?? 0,
      responseBody: bodies[key] ?? Data(), failureCategory: category)
    do {
      let persisted = try receiptStore.saveCompletion(receipt)
      onEvent(.finished(persisted))
    } catch {
      onEvent(
        .finished(
          .init(
            jobID: id, statusCode: status, fileName: files[key], receivedBodyBytes: sizes[key] ?? 0,
            responseBody: Data(), failureCategory: "receiptIO")))
      return
    }
  }
  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) { finished() }
}
