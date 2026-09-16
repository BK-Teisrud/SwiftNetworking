import Foundation

final class SocketRedirectDelegate: NSObject, URLSessionWebSocketDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private weak var task: URLSessionTask?
  private var continuation: CheckedContinuation<Void, any Error>?
  private var cancelled = false
  func start(_ task: URLSessionTask, continuation: CheckedContinuation<Void, any Error>) {
    let cancelled = lock.withLock {
      self.task = task
      self.continuation = continuation
      return self.cancelled
    }
    if cancelled { cancel() } else { task.resume() }
  }
  func cancel() {
    let state = lock.withLock {
      cancelled = true
      let result = (task, continuation)
      continuation = nil
      return result
    }
    state.0?.cancel()
    state.1?.resume(throwing: CancellationError())
  }
  private func finish(_ error: (any Error)?) {
    let waiter = lock.withLock {
      let value = continuation
      continuation = nil
      return value
    }
    if let error { waiter?.resume(throwing: error) } else { waiter?.resume() }
  }
  func urlSession(
    _ session: URLSession, webSocketTask: URLSessionWebSocketTask,
    didOpenWithProtocol protocol: String?
  ) { finish(nil) }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) { finish(error ?? URLError(.cannotConnectToHost)) }

  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) { completionHandler(nil) }
}
