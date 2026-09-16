import Foundation

struct RequestBuilder {
  let configuration: ClientConfiguration
  func build(_ request: HTTPRequest) throws -> URLRequest {
    guard !request.path.hasPrefix("//"), !request.path.contains(":"),
      !request.path.contains("?"), !request.path.contains("#")
    else {
      throw NetworkingError.invalidRequest("Use a relative path and separate query items")
    }
    try validatePath(request.path)
    try validateHeaders(request.headers)
    let timeout = request.timeout ?? configuration.timeout
    guard TimeLimits.valid(timeout) else {
      throw NetworkingError.invalidRequest("Timeout must be positive and finite")
    }
    guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false)
    else {
      throw NetworkingError.invalidConfiguration("Invalid base URL")
    }
    let base = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
    let encoded: String
    if let segments = request.pathSegments {
      let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%;:?#"))
      encoded = segments.map { $0.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(
        separator: "/")
      try validatePath(encoded)
    } else {
      let relative = String(request.path.drop(while: { $0 == "/" }))
      encoded = relative.split(separator: "/", omittingEmptySubsequences: false)
        .map { encodePathSegment(String($0)) }.joined(separator: "/")
    }
    components.percentEncodedPath =
      encoded.isEmpty ? base : (base.hasSuffix("/") ? base : base + "/") + encoded
    components.queryItems = request.query.isEmpty ? nil : request.query
    // Encode '+' as well, avoiding form-style servers interpreting it as a space.
    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(
      of: "+", with: "%2B")
    guard let url = components.url, sameOrigin(configuration.baseURL, url) else {
      throw NetworkingError.invalidRequest("Invalid request URL")
    }
    var result = URLRequest(
      url: url, cachePolicy: request.cachePolicy ?? configuration.cachePolicy,
      timeoutInterval: timeout)
    result.httpMethod = request.method.rawValue
    result.httpShouldHandleCookies = false
    for (name, value) in configuration.defaultHeaders {
      result.setValue(value, forHTTPHeaderField: name)
    }
    for (name, value) in request.headers { result.setValue(value, forHTTPHeaderField: name) }
    if let body = request.body {
      try validateHeaders(["Content-Type": body.contentType])
      guard !body.contentType.isEmpty else {
        throw NetworkingError.invalidRequest("Invalid content type")
      }
      do { result.httpBody = try body.encode(configuration.coding) } catch is CancellationError {
        throw CancellationError()
      } catch {
        if Task.isCancelled { throw CancellationError() }
        throw NetworkingError.requestEncoding(String(describing: error))
      }
      result.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
    }
    if let key = request.idempotencyKey {
      guard !key.isEmpty, !key.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
      else {
        throw NetworkingError.invalidRequest("Invalid idempotency key")
      }
      result.setValue(key, forHTTPHeaderField: "Idempotency-Key")
    }
    return result
  }
}

/// Preserve valid escapes within a segment without turning escaped delimiters into separators.
private func encodePathSegment(_ segment: String) -> String {
  let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/%"))
  let chars = Array(segment)
  var result = ""
  var index = 0
  let hex = Set("0123456789abcdefABCDEF")
  while index < chars.count {
    if chars[index] == "%", index + 2 < chars.count, hex.contains(chars[index + 1]),
      hex.contains(chars[index + 2])
    {
      result += String(chars[index...index + 2])
      index += 3
    } else {
      result += String(chars[index]).addingPercentEncoding(withAllowedCharacters: allowed)!
      index += 1
    }
  }
  return result
}
