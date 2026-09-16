import Foundation
import Networking
import Testing

@testable import NetworkingTransfers

private func directory() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  return url
}
@Test func completedDownloadRetainsCallerFileAfterLateCancellation() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source")
  let destination = root.appendingPathComponent("destination")
  try Data("owned-by-caller".utf8).write(to: source)
  let delegate = FileTransferDelegate(options: try .init(), destination: destination, progress: nil)
  let response = HTTPURLResponse(
    url: URL(string: "https://example.com/file")!, statusCode: 200, httpVersion: nil,
    headerFields: nil)!
  delegate.finishDownload(at: source, response: response)
  let session = URLSession(configuration: .ephemeral)
  defer { session.invalidateAndCancel() }
  let task = session.downloadTask(with: response.url!)
  delegate.urlSession(session, task: task, didCompleteWithError: nil)
  delegate.cancel()
  #expect(try Data(contentsOf: destination) == Data("owned-by-caller".utf8))
}
@Test func cancellationBeforeCompletionRemovesOnlyOwnedDownload() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("source")
  let destination = root.appendingPathComponent("destination")
  try Data([1]).write(to: source)
  let delegate = FileTransferDelegate(options: try .init(), destination: destination, progress: nil)
  delegate.finishDownload(
    at: source,
    response: HTTPURLResponse(
      url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil
    ))
  delegate.cancel()
  #expect(!FileManager.default.fileExists(atPath: destination.path))
}
@Test func receiptScanKeepsHealthyCompletionsWhenAnotherReceiptIsCorrupt() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = try BackgroundReceiptStore(directory: root, maximumReceiptBytes: 1024)
  let id = UUID()
  try store.save(
    .init(
      jobID: id, statusCode: 204, fileName: nil, receivedBodyBytes: 0, responseBody: Data(),
      failureCategory: nil))
  try Data("broken".utf8).write(to: root.appendingPathComponent("broken.receipt.json"))
  try Data(repeating: 0, count: 1025).write(to: root.appendingPathComponent("large.receipt.json"))
  let result = try store.scan()
  #expect(result.receipts.map(\.jobID) == [id])
  #expect(result.issues.count == 2)
  try store.acknowledge(jobID: id)
  #expect(try store.scan().receipts.isEmpty)
  #expect(
    FileManager.default.fileExists(atPath: root.appendingPathComponent("broken.receipt.json").path))
}
@Test func transportOnlyClientRejectsUnpreparedRelativeRequest() async throws {
  let client = TransferClient(transport: URLSessionFileTransferTransport(options: try .init()))
  await #expect(throws: NetworkingError.self) {
    try await client.download(HTTPRequest(path: "file"), to: URL(fileURLWithPath: "/tmp/unused"))
  }
}

@Test func cancellationBeforeDelegateStartResumesWithoutSending() async throws {
  let delegate = FileTransferDelegate(options: try .init(), destination: nil, progress: nil)
  delegate.cancel()
  let session = URLSession(configuration: .ephemeral)
  defer { session.invalidateAndCancel() }
  let task = session.dataTask(with: URL(string: "https://example.com")!)
  do {
    let _: TransferResult = try await withCheckedThrowingContinuation {
      delegate.start(task, continuation: $0)
    }
    Issue.record("Expected cancellation")
  } catch is CancellationError {}
}

@Test func backgroundShutdownRejectsNewJobsAndAllowsExplicitCancellation() throws {
  let lifecycle = BackgroundSessionLifecycle()
  #expect(try lifecycle.schedule { 1 } == 1)
  var finished = 0
  lifecycle.finish { finished += 1 }
  lifecycle.finish { finished += 1 }
  #expect(finished == 1)
  #expect(throws: TransferError.self) { try lifecycle.schedule { 2 } }
  var cancelled = 0
  lifecycle.cancel { cancelled += 1 }
  lifecycle.cancel { cancelled += 1 }
  #expect(cancelled == 1)
}

@Test func presignedClientUsesAbsoluteRequestWithoutRequiringHTTPClient() async throws {
  actor Capture: FileTransferTransport {
    var captured: URLRequest?
    func upload(
      _ request: URLRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)?
    ) -> HTTPResponse {
      captured = request
      return .init(data: Data(), metadata: .init(statusCode: 204))
    }
    func download(
      _ request: URLRequest, to destination: URL, progress: (@Sendable (TransferProgress) -> Void)?
    ) -> DownloadedFile {
      captured = request
      return .init(fileURL: destination, metadata: .init(statusCode: 200), receivedBodyBytes: 0)
    }
  }
  let transport = Capture()
  let client = TransferClient(transport: transport)
  var request = URLRequest(
    url: URL(string: "https://files.example.com/object?signature=synthetic")!)
  request.httpMethod = "PUT"
  request.setValue("synthetic-signature", forHTTPHeaderField: "X-Signature")
  _ = try await client.upload(request, from: URL(fileURLWithPath: "/tmp/synthetic"))
  let captured = await transport.captured
  #expect(captured == request)
  #expect(captured?.value(forHTTPHeaderField: "Authorization") == nil)
}

@Test func oversizedCompletionPersistsSmallRecoverableFailureReceipt() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = try BackgroundReceiptStore(directory: root, maximumReceiptBytes: 1024)
  let id = UUID()
  let filename = id.uuidString + ".download"
  let receipt = BackgroundTransferReceipt(
    jobID: id, statusCode: 200, fileName: filename,
    receivedBodyBytes: 2048, responseBody: Data(repeating: 1, count: 2048), failureCategory: nil)
  let persisted = try store.saveCompletion(receipt)
  #expect(persisted.failureCategory == "receiptTooLarge")
  #expect(persisted.responseBody.isEmpty)
  let reopened = try BackgroundReceiptStore(directory: root, maximumReceiptBytes: 1024)
  let recovered = try #require(try reopened.scan().receipts.first)
  #expect(recovered.jobID == id)
  #expect(recovered.fileName == filename)
  #expect(recovered.receivedBodyBytes == 2048)
  #expect(recovered.failureCategory == "receiptTooLarge")
  #expect(throws: TransferError.self) {
    try BackgroundReceiptStore(directory: root, maximumReceiptBytes: 1)
  }
}
@Test func configuredReceiptLimitSupportsLargerResponses() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let body = Data(repeating: 0, count: 13 * 1024 * 1024)
  let store = try BackgroundReceiptStore(directory: root, maximumReceiptBytes: 24 * 1024 * 1024)
  let id = UUID()
  let persisted = try store.saveCompletion(
    .init(
      jobID: id, statusCode: 200, fileName: nil,
      receivedBodyBytes: Int64(body.count), responseBody: body, failureCategory: nil))
  #expect(persisted.failureCategory == nil)
  #expect(try store.scan().receipts.first?.responseBody == body)
}

@Test func backgroundManagerRejectsReceiptStoreFromAnotherDirectory() throws {
  let root = try directory()
  defer { try? FileManager.default.removeItem(at: root) }
  let store = try BackgroundReceiptStore(directory: root.appendingPathComponent("other"))
  #expect(throws: TransferError.self) {
    try BackgroundTransferManager(
      identifier: "com.example.unused", directory: root,
      options: .init(), redirectPolicy: .systemManagedForTrustedServers, receiptStore: store)
  }
}
