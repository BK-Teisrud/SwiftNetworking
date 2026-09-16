import Foundation

final class ResponseCollector: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private let options: HTTPTransportOptions
  private weak var task: URLSessionTask?
  private var continuation: CheckedContinuation<HTTPResponse, any Error>?
  private var cancelled = false
  private var metadata: ResponseMetadata?
  private var data = Data()
  private var received = 0
  private var failure: (any Error)?
  init(options: HTTPTransportOptions) { self.options = options }
  var allowsCaching: Bool { options.allowsCaching }
  func start(_ task: URLSessionTask, continuation: CheckedContinuation<HTTPResponse, any Error>) {
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
      let value = (task, continuation)
      continuation = nil
      return value
    }
    state.0?.cancel()
    state.1?.resume(throwing: CancellationError())
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) { completionHandler(nil) }
  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void
  ) {
    let allowed = lock.withLock {
      guard let response = response as? HTTPURLResponse else {
        failure = NetworkingError.invalidResponse
        return false
      }
      let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
        if let key = entry.key as? String { result[key] = String(describing: entry.value) }
      }
      metadata = .init(statusCode: response.statusCode, headers: headers, url: response.url)
      if dataTask.originalRequest?.httpMethod != "HEAD",
        response.expectedContentLength > Int64(options.maximumResponseBytes)
      {
        failure = NetworkingError.responseTooLarge(
          limit: options.maximumResponseBytes, metadata: metadata)
        return false
      }
      return true
    }
    completionHandler(allowed ? .allow : .cancel)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
    let exceeded = lock.withLock {
      guard chunk.count <= options.maximumResponseBytes - received else {
        failure = NetworkingError.responseTooLarge(
          limit: options.maximumResponseBytes, metadata: metadata)
        return true
      }
      received += chunk.count
      if metadata.map({ (200..<300).contains($0.statusCode) }) == true {
        if !options.discardSuccessBody { data.append(chunk) }
      } else {
        data.append(chunk.prefix(max(0, options.maximumErrorBodyBytes - data.count)))
      }
      return false
    }
    if exceeded { dataTask.cancel() }
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    let state = lock.withLock {
      () -> (CheckedContinuation<HTTPResponse, any Error>?, Result<HTTPResponse, any Error>) in
      let continuation = self.continuation
      self.continuation = nil
      if let error = failure ?? error { return (continuation, .failure(error)) }
      guard let metadata else { return (continuation, .failure(NetworkingError.invalidResponse)) }
      return (
        continuation, .success(.init(data: data, metadata: metadata, receivedBodyBytes: received))
      )
    }
    state.0?.resume(with: state.1)
  }
}
