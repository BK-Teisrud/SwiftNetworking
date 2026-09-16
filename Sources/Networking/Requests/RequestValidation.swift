import Foundation

func validatePath(_ path: String, configuration: Bool = false) throws {
  func fail() throws {
    if configuration { throw NetworkingError.invalidConfiguration("Unsafe base path") }
    throw NetworkingError.invalidRequest("Path contains traversal or ambiguous encoding")
  }
  var decoded = path
  // Reject nested encodings too: intermediaries must not turn a segment into traversal.
  for _ in 0..<8 {
    guard !decoded.contains("\\"),
      !decoded.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
      !decoded.split(separator: "/", omittingEmptySubsequences: false).contains(where: {
        $0 == "." || $0 == ".."
      })
    else {
      try fail()
      return
    }
    guard decoded.contains("%") else { return }
    // Decode only structural ASCII bytes, leaving literal percent and arbitrary UTF-8 intact.
    var next = ""
    var index = decoded.startIndex
    while index < decoded.endIndex {
      let after = decoded.index(after: index)
      if decoded[index] == "%",
        let end = decoded.index(after, offsetBy: 2, limitedBy: decoded.endIndex),
        let byte = UInt8(decoded[after..<end], radix: 16), byte < 128
      {
        next.append(Character(UnicodeScalar(byte)))
        index = end
      } else {
        next.append(decoded[index])
        index = after
      }
    }
    if next == decoded { return }
    decoded = next
  }
  try fail()
}
func validateHeaders(_ headers: [String: String], configuration: Bool = false) throws {
  var names = Set<String>()
  let allowed = CharacterSet(
    charactersIn: "!#$%&'*+-.^_`|~0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
  for (name, value) in headers {
    let lower = name.lowercased()
    let forbidden = ["authorization", "proxy-authorization", "cookie", "host", "content-length"]
    guard !name.isEmpty, name.unicodeScalars.allSatisfy({ allowed.contains($0) }),
      !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
      names.insert(lower).inserted, !forbidden.contains(lower)
    else {
      if configuration {
        throw NetworkingError.invalidConfiguration("Invalid, duplicate or reserved header: \(name)")
      }
      throw NetworkingError.invalidRequest("Invalid, duplicate or reserved header: \(name)")
    }
  }
}
