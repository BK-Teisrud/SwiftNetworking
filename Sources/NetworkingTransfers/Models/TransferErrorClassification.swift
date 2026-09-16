import Networking

extension TransferError: NetworkFailureClassifying {
  public var networkFailureCategory: NetworkFailureCategory {
    switch self {
    case .invalidConfiguration: .configuration
    case .invalidFile, .destinationExists: .fileSystem
    case .fileTooLarge, .unexpectedResult: .policy
    }
  }
}
