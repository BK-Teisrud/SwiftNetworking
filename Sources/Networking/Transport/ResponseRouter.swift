import Foundation

final class ResponseRouter: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var collectors: [Int: ResponseCollector] = [:]
  func register(_ collector: ResponseCollector, task: URLSessionTask) {
    lock.withLock { collectors[task.taskIdentifier] = collector }
  }
  private func collector(_ task: URLSessionTask) -> ResponseCollector? {
    lock.withLock { collectors[task.taskIdentifier] }
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
    guard let collector = collector(dataTask) else {
      completionHandler(.cancel)
      return
    }
    collector.urlSession(
      session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    collector(dataTask)?.urlSession(session, dataTask: dataTask, didReceive: data)
  }
  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask,
    willCacheResponse proposedResponse: CachedURLResponse,
    completionHandler: @escaping @Sendable (CachedURLResponse?) -> Void
  ) {
    completionHandler(collector(dataTask)?.allowsCaching == true ? proposedResponse : nil)
  }
  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
  ) {
    let collector = lock.withLock { collectors.removeValue(forKey: task.taskIdentifier) }
    collector?.urlSession(session, task: task, didCompleteWithError: error)
  }
}
