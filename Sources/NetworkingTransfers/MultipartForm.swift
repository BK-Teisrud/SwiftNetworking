import Foundation

/// Writes multipart to a caller-owned file using bounded chunks; does not load attachments into memory.
public struct MultipartForm: Sendable {
  public struct Part: Sendable {
    public enum Content: Sendable {
      case data(Data)
      case file(URL)
    }
    public let name: String
    public let filename: String?
    public let contentType: String
    public let content: Content
    public init(
      name: String, filename: String? = nil, contentType: String = "text/plain; charset=utf-8",
      content: Content
    ) {
      self.name = name
      self.filename = filename
      self.contentType = contentType
      self.content = content
    }
  }
  public let parts: [Part]
  public init(parts: [Part]) { self.parts = parts }
  public struct Encoded: Sendable {
    public let fileURL: URL
    public let contentType: String
    public let byteCount: Int64
  }
  /// A random boundary is generated for each encoding. Destination must not exist.
  public func write(to destination: URL, maximumBytes: Int64 = 524_288_000) throws -> Encoded {
    guard destination.isFileURL, maximumBytes > 0 else { throw TransferError.invalidConfiguration }
    guard !FileManager.default.fileExists(atPath: destination.path) else {
      throw TransferError.destinationExists
    }
    let boundary = "Networking-" + UUID().uuidString
    try FileManager.default.createDirectory(
      at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    // Exclusive creation prevents overwriting a file created concurrently.
    let output = try FileHandle(forWritingTo: createExclusiveFile(destination))
    var succeeded = false
    defer {
      try? output.close()
      if !succeeded { try? FileManager.default.removeItem(at: destination) }
    }
    var count: Int64 = 0
    func append(_ data: Data) throws {
      try Task.checkCancellation()
      guard Int64(data.count) <= maximumBytes - count else {
        throw TransferError.fileTooLarge(limit: maximumBytes)
      }
      try output.write(contentsOf: data)
      count += Int64(data.count)
    }
    for part in parts {
      guard !part.name.isEmpty, !part.contentType.isEmpty, safe(part.name), safe(part.contentType),
        part.filename.map(safe) ?? true
      else { throw TransferError.invalidConfiguration }
      var header = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(part.name)\""
      if let filename = part.filename { header += "; filename=\"\(filename)\"" }
      header += "\r\nContent-Type: \(part.contentType)\r\n\r\n"
      try append(Data(header.utf8))
      switch part.content {
      case .data(let data): try append(data)
      case .file(let url):
        guard url.isFileURL, url.standardizedFileURL != destination.standardizedFileURL else {
          throw TransferError.invalidFile
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
          throw TransferError.invalidFile
        }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        while let chunk = try input.read(upToCount: 65_536), !chunk.isEmpty { try append(chunk) }
      }
      try append(Data("\r\n".utf8))
    }
    try append(Data("--\(boundary)--\r\n".utf8))
    try output.synchronize()
    succeeded = true
    return .init(
      fileURL: destination, contentType: "multipart/form-data; boundary=\(boundary)",
      byteCount: count)
  }
  private func safe(_ string: String) -> Bool {
    !string.unicodeScalars.contains { $0.value < 32 || $0.value == 127 || $0 == "\"" || $0 == "\\" }
  }
  private func createExclusiveFile(_ url: URL) throws -> URL {
    try Data().write(to: url, options: .withoutOverwriting)
    return url
  }
}
