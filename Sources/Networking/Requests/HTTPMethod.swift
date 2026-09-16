import Foundation

/// Case-sensitive HTTP token. Custom methods still require URLSession/backend support.
public struct HTTPMethod: RawRepresentable, Sendable, Hashable {
  public let rawValue: String
  public init?(rawValue: String) {
    let allowed = CharacterSet(
      charactersIn: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
    guard !rawValue.isEmpty, rawValue.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
      return nil
    }
    self.rawValue = rawValue
  }
  private init(_ value: String) { rawValue = value }
  public static let get = Self("GET")
  public static let post = Self("POST")
  public static let put = Self("PUT")
  public static let patch = Self("PATCH")
  public static let delete = Self("DELETE")
  public static let head = Self("HEAD")
  public static let options = Self("OPTIONS")
}

/// Explicit confirmation that the server contract permits repeating this operation.
public enum ReplayPolicy: Sendable { case safeMethodsOnly, confirmedSafe, never }
