import Foundation

/// Stable handling categories across HTTP, file transfers and realtime; no automatic retry decision.
public enum NetworkFailureCategory: Sendable, Equatable {
  case cancelled, timeout, configuration, policy, authentication, http
  case encoding, decoding, transport, fileSystem, other
}
/// Allows modules and custom adapters to classify their own errors without losing payloads.
public protocol NetworkFailureClassifying: Error {
  var networkFailureCategory: NetworkFailureCategory { get }
}
public enum NetworkFailures {
  /// Classifies package errors and raw Foundation errors; preserves the original error for inspection.
  public static func category(of error: any Error) -> NetworkFailureCategory {
    if error is CancellationError { return .cancelled }
    if let classified = error as? any NetworkFailureClassifying {
      return classified.networkFailureCategory
    }
    let ns = error as NSError
    if ns.domain == NSURLErrorDomain {
      switch ns.code {
      case URLError.cancelled.rawValue: return .cancelled
      case URLError.timedOut.rawValue: return .timeout
      default: return .transport
      }
    }
    if ns.domain == NSCocoaErrorDomain, (0..<1024).contains(ns.code) { return .fileSystem }
    if ns.domain == NSPOSIXErrorDomain {
      if ns.code == Int(POSIXErrorCode.ETIMEDOUT.rawValue) { return .timeout }
      if ns.code == Int(POSIXErrorCode.ECANCELED.rawValue) { return .cancelled }
      let networkCodes: [POSIXErrorCode] = [
        .ECONNRESET, .ECONNREFUSED, .ECONNABORTED,
        .ENETDOWN, .ENETUNREACH, .EHOSTUNREACH, .ENOTCONN, .EADDRINUSE, .EADDRNOTAVAIL,
      ]
      if networkCodes.contains(where: { Int($0.rawValue) == ns.code }) { return .transport }
      let fileCodes: [POSIXErrorCode] = [
        .ENOENT, .EACCES, .EPERM, .ENOSPC, .EIO,
        .EROFS, .EEXIST, .ENOTDIR, .EISDIR, .EMFILE, .ENFILE, .EFBIG, .EDQUOT,
      ]
      if fileCodes.contains(where: { Int($0.rawValue) == ns.code }) { return .fileSystem }
    }
    return .other
  }
}
extension NetworkingError: NetworkFailureClassifying {
  public var networkFailureCategory: NetworkFailureCategory {
    switch self {
    case .invalidConfiguration: .configuration
    case .invalidRequest, .responseTooLarge, .redirectRejected, .invalidResponse: .policy
    case .requestEncoding: .encoding
    case .responseDecoding, .emptyResponse: .decoding
    case .timeout, .deadlineExceeded: .timeout
    case .authentication: .authentication
    case .http: .http
    case .transport(let failure):
      failure.domain == NSURLErrorDomain
        ? NetworkFailures.category(of: NSError(domain: failure.domain, code: failure.code))
        : .transport
    }
  }
}
extension AuthenticationError: NetworkFailureClassifying {
  public var networkFailureCategory: NetworkFailureCategory { .authentication }
}
