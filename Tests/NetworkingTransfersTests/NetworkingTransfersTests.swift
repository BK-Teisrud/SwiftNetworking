import Foundation
import Networking
import Testing

@testable import NetworkingTransfers

private func temporary(_ name: String) -> URL {
  FileManager.default.temporaryDirectory.appendingPathComponent(
    "Networking-\(UUID().uuidString)", isDirectory: true
  ).appendingPathComponent(name)
}
@Test func multipartStreamsFilesAndEscapesFraming() throws {
  let destination = temporary("body.multipart")
  defer { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()) }
  let attachment = destination.deletingLastPathComponent().appendingPathComponent("attachment.bin")
  try FileManager.default.createDirectory(
    at: attachment.deletingLastPathComponent(), withIntermediateDirectories: true)
  let bytes = Data(repeating: 65, count: 200_000)
  try bytes.write(to: attachment)
  let encoded = try MultipartForm(parts: [
    .init(name: "caption", content: .data(Data("hello".utf8))),
    .init(
      name: "file", filename: "photo.bin", contentType: "application/octet-stream",
      content: .file(attachment)),
  ]).write(to: destination)
  let data = try Data(contentsOf: destination)
  #expect(data.count == Int(encoded.byteCount))
  #expect(data.range(of: bytes) != nil)
  let boundary = encoded.contentType.components(separatedBy: "boundary=")[1]
  #expect(data.suffix(Data("--\(boundary)--\r\n".utf8).count) == Data("--\(boundary)--\r\n".utf8))
}
@Test func multipartLimitsCleanUpAndNeverOverwrite() throws {
  let destination = temporary("body")
  defer { try? FileManager.default.removeItem(at: destination.deletingLastPathComponent()) }
  let form = MultipartForm(parts: [.init(name: "x", content: .data(Data(repeating: 0, count: 100)))]
  )
  #expect(throws: TransferError.self) { try form.write(to: destination, maximumBytes: 10) }
  #expect(!FileManager.default.fileExists(atPath: destination.path))
  try Data("keep".utf8).write(to: destination)
  #expect(throws: TransferError.self) { try form.write(to: destination) }
  #expect(try Data(contentsOf: destination) == Data("keep".utf8))
  let injected = MultipartForm(parts: [.init(name: "evil\r\nheader", content: .data(Data()))])
  let other = destination.deletingLastPathComponent().appendingPathComponent("other")
  #expect(throws: TransferError.self) { try injected.write(to: other) }
  #expect(!FileManager.default.fileExists(atPath: other.path))
}
@Test func transferAdapterUsesAuthenticatedPreparedRequest() async throws {
  actor Transport: FileTransferTransport {
    var request: URLRequest?
    func upload(
      _ request: URLRequest, from file: URL, progress: (@Sendable (TransferProgress) -> Void)?
    ) -> HTTPResponse {
      self.request = request
      return .init(data: Data(), metadata: .init(statusCode: 204))
    }
    func download(
      _ request: URLRequest, to destination: URL, progress: (@Sendable (TransferProgress) -> Void)?
    ) -> DownloadedFile {
      .init(fileURL: destination, metadata: .init(statusCode: 200), receivedBodyBytes: 0)
    }
  }
  struct Credentials: CredentialProvider {
    func bearerToken() async throws -> String { "transfer-token" }
    func recover(rejectedToken: String) async throws -> String { "unused" }
  }
  let transport = Transport()
  let http = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/")!, credentialProvider: Credentials()))
  let client = TransferClient(httpClient: http, transport: transport)
  _ = try await client.upload(
    .init(method: .post, pathSegments: ["files", "a/b"], requiresAuthentication: true),
    from: temporary("file"))
  #expect(await transport.request?.url?.absoluteString == "https://example.com/api/files/a%2Fb")
  #expect(
    await transport.request?.value(forHTTPHeaderField: "Authorization") == "Bearer transfer-token")
}
