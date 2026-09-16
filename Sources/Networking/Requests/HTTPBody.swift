import Foundation

public struct HTTPBody: Sendable {
  let encode: @Sendable (JSONCoding) throws -> Data
  let contentType: String
  public static func json<T: Encodable & Sendable>(_ value: T) -> Self {
    Self(encode: { try $0.makeEncoder().encode(value) }, contentType: "application/json")
  }
  /// UTF-8 form encoding, preserving duplicate names/order; nil values become empty strings.
  public static func form(_ fields: [URLQueryItem]) -> Self {
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._*")
    func component(_ value: String) -> String {
      value.addingPercentEncoding(withAllowedCharacters: allowed)!.replacingOccurrences(
        of: "%20", with: "+")
    }
    let text = fields.map { component($0.name) + "=" + component($0.value ?? "") }.joined(
      separator: "&")
    return .data(Data(text.utf8), contentType: "application/x-www-form-urlencoded")
  }
  public static func data(_ data: Data, contentType: String) -> Self {
    Self(encode: { _ in data }, contentType: contentType)
  }
}
