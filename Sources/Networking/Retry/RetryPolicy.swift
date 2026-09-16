import Foundation

public protocol RetryClock: Sendable {
  func now() async -> Date
  func sleep(for seconds: TimeInterval) async throws
}
public struct SystemRetryClock: RetryClock {
  public init() {}
  public func now() async -> Date { Date() }
  public func sleep(for seconds: TimeInterval) async throws {
    guard TimeLimits.valid(seconds, allowZero: true) else {
      throw NetworkingError.invalidConfiguration("Sleep must be within 0...86400 seconds")
    }
    try Task.checkCancellation()
    try await Task.sleep(for: .seconds(seconds))
  }
}
public struct RetryPolicy: Sendable {
  public let maximumAttempts: Int
  public let baseDelay: TimeInterval
  public let maximumDelay: TimeInterval
  public let statusCodes: Set<Int>
  public let transportCodes: Set<Int>
  public let jitter: @Sendable () -> Double
  public static let disabled = RetryPolicy()
  /// maximumAttempts includes the initial send. 400, 401 and 403 are never automatic retries.
  public init(
    maximumAttempts: Int = 1, baseDelay: TimeInterval = 0.5, maximumDelay: TimeInterval = 30,
    statusCodes: Set<Int> = [408, 429, 500, 502, 503, 504],
    transportCodes: Set<Int> = [
      URLError.timedOut.rawValue, URLError.networkConnectionLost.rawValue,
    ],
    jitter: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
  ) {
    self.maximumAttempts = maximumAttempts
    self.baseDelay = baseDelay
    self.maximumDelay = maximumDelay
    self.statusCodes = statusCodes
    self.transportCodes = transportCodes
    self.jitter = jitter
  }
  func delay(attempt: Int, retryAfter: String?, now: Date) -> TimeInterval? {
    guard TimeLimits.valid(baseDelay, allowZero: true),
      TimeLimits.valid(maximumDelay, allowZero: true), attempt > 0
    else { return nil }
    if let retryAfter {
      let trimmed = retryAfter.trimmingCharacters(in: .whitespaces)
      if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }) {
        guard let seconds = Double(trimmed), seconds.isFinite, seconds <= maximumDelay else {
          return nil
        }
        return seconds
      }
      if let date = Self.httpDate(trimmed, now: now) {
        let seconds = max(0, date.timeIntervalSince(now))
        return seconds <= maximumDelay ? seconds : nil
      }
    }
    let ceiling = min(maximumDelay, baseDelay * pow(2, Double(min(attempt - 1, 60))))
    let sample = jitter()
    return ceiling * (sample.isFinite ? min(1, max(0, sample)) : 0)
  }
  private static func httpDate(_ value: String, now: Date) -> Date? {
    let formats = [
      (
        #"^[A-Za-z]{3}, [0-9]{2} [A-Za-z]{3} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
        "EEE, dd MMM yyyy HH:mm:ss 'GMT'", false
      ),
      (
        #"^[A-Za-z]+, [0-9]{2}-[A-Za-z]{3}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
        "EEEE, dd-MMM-yy HH:mm:ss 'GMT'", true
      ),
      (
        #"^[A-Za-z]{3} [A-Za-z]{3} [ 0-9][0-9] [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}$"#,
        "EEE MMM d HH:mm:ss yyyy", false
      ),
    ]
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let year = calendar.component(.year, from: now)
    for (pattern, format, twoDigitYear) in formats
    where value.range(of: pattern, options: .regularExpression) != nil {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.calendar = calendar
      formatter.timeZone = calendar.timeZone
      formatter.isLenient = false
      formatter.dateFormat = format
      // Interpret two-digit years in a window ending 50 years after the current year.
      formatter.twoDigitStartDate = calendar.date(
        from: DateComponents(year: year - 49, month: 1, day: 1))
      if let parsed = formatter.date(from: value) {
        if twoDigitYear,
          let futureLimit = calendar.date(byAdding: .year, value: 50, to: now), parsed > futureLimit
        {
          return calendar.date(byAdding: .year, value: -100, to: parsed)
        }
        return parsed
      }
    }
    return nil
  }

}
