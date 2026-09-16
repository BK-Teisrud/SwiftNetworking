import Foundation

public struct JSONCoding: Sendable {
  public let makeEncoder: @Sendable () -> JSONEncoder
  public let makeDecoder: @Sendable () -> JSONDecoder
  public struct Options: Sendable {
    public enum Keys: Sendable { case standard, snakeCase }
    public enum Dates: Sendable { case deferred, iso8601, secondsSince1970, millisecondsSince1970 }
    public let keys: Keys
    public let dates: Dates
    public init(keys: Keys = .standard, dates: Dates = .deferred) {
      self.keys = keys
      self.dates = dates
    }
  }
  public init(options: Options = .init()) {
    makeEncoder = {
      let encoder = JSONEncoder()
      if case .snakeCase = options.keys { encoder.keyEncodingStrategy = .convertToSnakeCase }
      switch options.dates {
      case .deferred: break
      case .iso8601: encoder.dateEncodingStrategy = .iso8601
      case .secondsSince1970: encoder.dateEncodingStrategy = .secondsSince1970
      case .millisecondsSince1970: encoder.dateEncodingStrategy = .millisecondsSince1970
      }
      return encoder
    }
    makeDecoder = {
      let decoder = JSONDecoder()
      if case .snakeCase = options.keys { decoder.keyDecodingStrategy = .convertFromSnakeCase }
      switch options.dates {
      case .deferred: break
      case .iso8601: decoder.dateDecodingStrategy = .iso8601
      case .secondsSince1970: decoder.dateDecodingStrategy = .secondsSince1970
      case .millisecondsSince1970: decoder.dateDecodingStrategy = .millisecondsSince1970
      }
      return decoder
    }
  }
  /// Factories must return a new coder on each invocation.
  public init(
    makeEncoder: @escaping @Sendable () -> JSONEncoder,
    makeDecoder: @escaping @Sendable () -> JSONDecoder
  ) {
    self.makeEncoder = makeEncoder
    self.makeDecoder = makeDecoder
  }
}
