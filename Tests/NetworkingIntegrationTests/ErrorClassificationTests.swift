import Foundation
import Networking
import NetworkingRealtime
import NetworkingTransfers
import Testing

@Test func failureCategoriesWorkAcrossModulesWithoutReplacingErrors() {
  #expect(NetworkFailures.category(of: CancellationError()) == .cancelled)
  #expect(NetworkFailures.category(of: URLError(.cancelled)) == .cancelled)
  #expect(NetworkFailures.category(of: URLError(.timedOut)) == .timeout)
  #expect(NetworkFailures.category(of: NetworkingError.deadlineExceeded) == .timeout)
  #expect(NetworkFailures.category(of: URLError(.networkConnectionLost)) == .transport)
  #expect(
    NetworkFailures.category(of: NetworkingError.transport(.init(error: URLError(.timedOut))))
      == .timeout)
  #expect(NetworkFailures.category(of: TransferError.fileTooLarge(limit: 1)) == .policy)
  #expect(NetworkFailures.category(of: TransferError.destinationExists) == .fileSystem)
  #expect(NetworkFailures.category(of: RealtimeError.bufferOverflow) == .policy)
  #expect(NetworkFailures.category(of: RealtimeError.notConnected) == .transport)
  #expect(NetworkFailures.category(of: AuthenticationError.rejected) == .authentication)
  #expect(NetworkFailures.category(of: CocoaError(.fileReadNoSuchFile)) == .fileSystem)
  #expect(
    NetworkFailures.category(
      of: NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ECONNRESET.rawValue)))
      == .transport)
  #expect(
    NetworkFailures.category(
      of: NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ENOSPC.rawValue)))
      == .fileSystem)
  struct Unknown: Error {}
  #expect(NetworkFailures.category(of: Unknown()) == .other)
}
