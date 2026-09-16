import Foundation
import Testing

@testable import Networking

@Test func groupedConfigurationPreservesLimitsAndValidatesInvalidOptions() throws {
  let url = URL(string: "https://example.com/api")!
  let configuration = try ClientConfiguration(
    baseURL: url,
    limits: .init(
      requestTimeout: 12, operationTimeout: 20, maximumTotalAttempts: 3,
      maximumResponseBytes: 1024, maximumErrorBodyBytes: 128),
    redirects: .init(policy: .sameOriginWithoutCredentials))
  #expect(configuration.limits.requestTimeout == 12)
  #expect(configuration.maximumTotalAttempts == 3)
  #expect(configuration.maximumResponseBytes == 1024)
  #expect(throws: NetworkingError.self) {
    try ClientConfiguration(baseURL: url, limits: .init(requestTimeout: .nan))
  }
  #expect(throws: NetworkingError.self) {
    try ClientConfiguration(baseURL: url, limits: .init(), diagnostics: .init(queueCapacity: 0))
  }
}
