import Foundation

/// Implementations own storage and concurrent refresh coordination; never initiate interactive login.
public protocol CredentialProvider: Sendable {
  func bearerToken() async throws -> String
  func recover(rejectedToken: String) async throws -> String
}
