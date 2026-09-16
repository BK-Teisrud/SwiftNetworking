import Foundation

public enum AuthenticationError: Error, Sendable, Equatable {
  case missingProvider, invalidToken, rejected, providerFailure
}
public struct HTTPFailure: Sendable {
  public let metadata: ResponseMetadata
  public let body: Data
  public let bodyWasTruncated: Bool
  public init(metadata: ResponseMetadata, body: Data, bodyWasTruncated: Bool = false) {
    self.metadata = metadata
    self.body = body
    self.bodyWasTruncated = bodyWasTruncated
  }
}
public struct DecodingFailure: Sendable {
  public enum Kind: Sendable { case keyNotFound, valueNotFound, typeMismatch, dataCorrupted, other }
  public let metadata: ResponseMetadata
  public let kind: Kind
  public let codingPath: [String]
  public let description: String
  public init(error: any Error, metadata: ResponseMetadata) {
    self.metadata = metadata
    let context: DecodingError.Context?
    switch error {
    case DecodingError.keyNotFound(let key, let value):
      kind = .keyNotFound
      context = value
      codingPath = value.codingPath.map(Self.component) + [Self.component(key)]
    case DecodingError.valueNotFound(_, let value):
      kind = .valueNotFound
      context = value
      codingPath = value.codingPath.map(Self.component)
    case DecodingError.typeMismatch(_, let value):
      kind = .typeMismatch
      context = value
      codingPath = value.codingPath.map(Self.component)
    case DecodingError.dataCorrupted(let value):
      kind = .dataCorrupted
      context = value
      codingPath = value.codingPath.map(Self.component)
    default:
      kind = .other
      context = nil
      codingPath = []
    }
    description = context?.debugDescription ?? String(describing: error)
  }
  private static func component(_ key: any CodingKey) -> String {
    key.intValue.map { "[\($0)]" } ?? key.stringValue
  }
}
public struct TransportFailure: Sendable {
  public struct Cause: Sendable {
    public let domain: String
    public let code: Int
    public let description: String
  }
  public let domain: String
  public let code: Int
  public let description: String
  public let causes: [Cause]
  public init(error: any Error) {
    let ns = error as NSError
    domain = ns.domain
    code = ns.code
    description = ns.localizedDescription
    var chain: [Cause] = []
    var next = ns.userInfo[NSUnderlyingErrorKey] as? NSError
    for _ in 0..<8 {
      guard let underlying = next else { break }
      chain.append(
        .init(
          domain: underlying.domain, code: underlying.code,
          description: underlying.localizedDescription))
      next = underlying.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    causes = chain
  }
}
public struct RedirectFailure: Sendable {
  public enum Reason: Sendable, Equatable {
    case policyDenied, replayUnsafe, attemptLimit, invalidLocation, unapprovedOrigin
    case credentialsInURL, outsideAPIPrefix, unsafePath, retryAfterExceedsLimit
  }
  public let reason: Reason
  public let metadata: ResponseMetadata
  public init(reason: Reason, metadata: ResponseMetadata) {
    self.reason = reason
    self.metadata = metadata
  }
}
public enum NetworkingError: Error, Sendable {
  case invalidConfiguration(String)
  case invalidRequest(String)
  case requestEncoding(String)
  case transport(TransportFailure)
  case timeout
  case deadlineExceeded
  case responseTooLarge(limit: Int, metadata: ResponseMetadata?)
  case http(HTTPFailure)
  case emptyResponse(ResponseMetadata)
  case responseDecoding(DecodingFailure)
  case authentication(AuthenticationError)
  case redirectRejected(RedirectFailure)
  case invalidResponse
}
