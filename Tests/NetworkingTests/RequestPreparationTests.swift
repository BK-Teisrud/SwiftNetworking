import Foundation
import Testing

@testable import Networking

@Test func prepareDisablesCacheForConfiguredSensitiveHeaders() async throws {
  let client = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com/api/")!,
      defaultHeaders: ["X-API-Key": "synthetic"], cachePolicy: .useProtocolCachePolicy))
  let request = try await client.prepare(.init(path: "private"))
  #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
  let publicClient = HTTPClient(
    configuration: try .init(
      baseURL: URL(string: "https://example.com")!, cachePolicy: .useProtocolCachePolicy))
  #expect(
    try await publicClient.prepare(.init(path: "public")).cachePolicy == .useProtocolCachePolicy)
}
@Test func requestPathGettersAndEncodedURLsRemainCompatible() async throws {
  let client = HTTPClient(
    configuration: try .init(baseURL: URL(string: "https://example.com/api/")!))
  let encoded = HTTPRequest(path: "files/a%2Fb")
  let raw = HTTPRequest(pathSegments: ["files", "a/b"])
  #expect(encoded.path == "files/a%2Fb")
  #expect(encoded.pathSegments == nil)
  #expect(raw.path.isEmpty)
  #expect(raw.pathSegments == ["files", "a/b"])
  let encodedURL = try await client.prepare(encoded).url
  let rawURL = try await client.prepare(raw).url
  #expect(encodedURL == rawURL)
}
@Test func groupedAndOriginalDefaultsStayAligned() throws {
  let url = URL(string: "https://example.com")!
  let original = try ClientConfiguration(baseURL: url)
  let grouped = try ClientConfiguration(baseURL: url, limits: .init())
  #expect(original.timeout == grouped.timeout)
  #expect(original.maximumResponseBytes == grouped.maximumResponseBytes)
  #expect(original.maximumErrorBodyBytes == grouped.maximumErrorBodyBytes)
  #expect(original.redirectHeaderAllowlist == grouped.redirectHeaderAllowlist)
  #expect(original.sensitiveHeaderNames == grouped.sensitiveHeaderNames)
  #expect(original.maximumTotalAttempts == grouped.maximumTotalAttempts)
}
