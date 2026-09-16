import Foundation

public struct ResponseMetadata: Sendable {
  public let statusCode: Int
  public let headers: [String: String]
  public let url: URL?
  public let wasRedirected: Bool
  public var requestID: String? { header("X-Request-ID") ?? header("Request-ID") }
  public init(
    statusCode: Int, headers: [String: String] = [:], url: URL? = nil, wasRedirected: Bool = false
  ) {
    self.statusCode = statusCode
    self.headers = headers
    self.url = url
    self.wasRedirected = wasRedirected
  }
  public func header(_ name: String) -> String? {
    headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
  }
}
public struct HTTPResponse: Sendable {
  public let receivedBodyBytes: Int
  public let data: Data
  public let metadata: ResponseMetadata
  public init(data: Data, metadata: ResponseMetadata, receivedBodyBytes: Int? = nil) {
    self.receivedBodyBytes = receivedBodyBytes ?? data.count
    self.data = data
    self.metadata = metadata
  }
}
public struct DecodedResponse<Value: Sendable>: Sendable {
  public let value: Value
  public let metadata: ResponseMetadata
  public init(value: Value, metadata: ResponseMetadata) {
    self.value = value
    self.metadata = metadata
  }
}
