import Networking

extension RealtimeError: NetworkFailureClassifying {
  public var networkFailureCategory: NetworkFailureCategory {
    switch self {
    case .invalidConfiguration: .configuration
    case .notConnected: .transport
    case .messageTooLarge, .bufferOverflow, .unsupportedMessage: .policy
    }
  }
}
