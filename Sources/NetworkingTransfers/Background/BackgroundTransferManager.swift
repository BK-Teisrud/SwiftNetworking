import Foundation
import Networking

/// App-lifecycle component; recreate with the same identifier and directory after relaunch.
/// Use a distinct identifier/directory per account. Completion receipts survive process termination.
public final class BackgroundTransferManager: Sendable {
  public let identifier: String
  public let directory: URL
  private let lifecycle = BackgroundSessionLifecycle()
  private let options: TransferOptions
  private let session: URLSession
  private let delegate: BackgroundDelegate
  public let receiptStore: BackgroundReceiptStore
  public init(
    identifier: String, directory: URL, options: TransferOptions,
    redirectPolicy: BackgroundRedirectPolicy,
    isDiscretionary: Bool = false,
    receiptStore: BackgroundReceiptStore? = nil,
    onEvent: @escaping @Sendable (BackgroundTransferEvent) -> Void = { _ in },
    onBackgroundEventsFinished: @escaping @Sendable () -> Void = {}
  ) throws {
    guard !identifier.isEmpty, directory.isFileURL else { throw TransferError.invalidConfiguration }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    self.identifier = identifier
    self.directory = directory
    self.options = options
    if let receiptStore, receiptStore.directory.standardizedFileURL != directory.standardizedFileURL
    {
      throw TransferError.invalidConfiguration
    }
    self.receiptStore = try receiptStore ?? BackgroundReceiptStore(directory: directory)
    delegate = BackgroundDelegate(
      directory: directory, receiptStore: self.receiptStore, options: options, onEvent: onEvent,
      finished: onBackgroundEventsFinished
    )
    let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
    configuration.isDiscretionary = isDiscretionary
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForResource = options.resourceTimeout
    session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
  }
  @discardableResult public func upload(_ request: URLRequest, from file: URL) throws -> UUID {
    try lifecycle.schedule {
      try validate(request)
      guard file.isFileURL, request.httpBody == nil, request.httpBodyStream == nil else {
        throw TransferError.invalidFile
      }
      let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
      guard attributes[.type] as? FileAttributeType == .typeRegular else {
        throw TransferError.invalidFile
      }
      guard
        ((attributes[.size] as? NSNumber)?.int64Value ?? Int64.max) <= options.maximumUploadBytes
      else { throw TransferError.fileTooLarge(limit: options.maximumUploadBytes) }
      let id = UUID()
      let task = session.uploadTask(with: sanitized(request), fromFile: file)
      task.taskDescription = id.uuidString
      task.resume()
      return id
    }
  }
  @discardableResult public func download(_ request: URLRequest) throws -> UUID {
    try lifecycle.schedule {
      try validate(request)
      guard request.httpBody == nil, request.httpBodyStream == nil else {
        throw TransferError.invalidFile
      }
      let id = UUID()
      let task = session.downloadTask(with: sanitized(request))
      task.taskDescription = id.uuidString
      task.resume()
      return id
    }
  }
  public func tasks() async -> [BackgroundTransferTask] {
    await session.allTasks.map { task in
      let download = task is URLSessionDownloadTask
      let total = download ? task.countOfBytesExpectedToReceive : task.countOfBytesExpectedToSend
      return .init(
        taskIdentifier: task.taskIdentifier,
        jobID: task.taskDescription.flatMap(UUID.init(uuidString:)),
        completedBytes: download ? task.countOfBytesReceived : task.countOfBytesSent,
        expectedBytes: total >= 0 ? total : nil)
    }
  }
  public func cancel(jobID: UUID) async {
    for task in await session.allTasks where task.taskDescription == jobID.uuidString {
      task.cancel()
    }
  }
  public func cancelAll() async {
    for task in await session.allTasks {
      task.cancel()
    }
  }
  /// Reads persisted completions, including completions received while no UI listener existed.
  public func receipts() throws -> [BackgroundTransferReceipt] {
    try receiptStore.scan().receipts
  }
  public func receiptScan() throws -> BackgroundReceiptScan { try receiptStore.scan() }
  /// Acknowledgement removes the receipt. Download file is retained unless explicitly requested.
  public func acknowledge(jobID: UUID, removeDownloadedFile: Bool = false) throws {
    try receiptStore.acknowledge(jobID: jobID, removeDownloadedFile: removeDownloadedFile)
  }
  /// Stop accepting new jobs; finish existing jobs and then release the system session.
  /// Keep this manager alive until outstanding callbacks have been delivered.
  public func finishTasksAndInvalidate() {
    lifecycle.finish { session.finishTasksAndInvalidate() }
  }
  /// Permanently invalidates this instance; recreating the same identifier can attach again.
  public func invalidateAndCancel() {
    lifecycle.cancel { session.invalidateAndCancel() }
  }
  deinit { lifecycle.finish { session.finishTasksAndInvalidate() } }
  private func sanitized(_ request: URLRequest) -> URLRequest {
    var request = request
    request.httpShouldHandleCookies = false
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }
  private func validate(_ request: URLRequest) throws {
    guard let url = request.url, url.scheme?.lowercased() == "https", url.host != nil,
      url.user == nil, url.password == nil, url.fragment == nil
    else { throw TransferError.invalidConfiguration }
    let allowed = Set([
      "accept", "accept-language", "content-type", "content-encoding", "user-agent",
      "content-length",
    ])
    guard
      (request.allHTTPHeaderFields ?? [:]).keys.allSatisfy({ allowed.contains($0.lowercased()) })
    else {
      throw NetworkingError.invalidRequest(
        "Background requests allow only noncredential standard headers; use foreground transfers for bearer/API-key authentication"
      )
    }
  }
}
