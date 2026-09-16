#if os(macOS)
  import Darwin
  import CryptoKit
  import NetworkingTransfers
  import NetworkingRealtime
  import Foundation
  import Testing
  @testable import Networking

  /// Loopback-only HTTP fixture. Every shared collection is protected by lock.
  private final class LocalServer: @unchecked Sendable {
    struct Received: Sendable {
      let method: String
      let path: String
      let headers: String
      let body: Data
    }
    private let lock = NSLock()
    private let listener: Int32
    private var clients: Set<Int32> = []
    private var received: [Received] = []
    private var stopped = false
    let baseURL: URL
    var requests: [Received] { lock.withLock { received } }
    init() throws {
      let localListener = socket(AF_INET, SOCK_STREAM, 0)
      guard localListener >= 0 else { throw POSIXError(.EPERM) }
      var address = sockaddr_in()
      address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      address.sin_family = sa_family_t(AF_INET)
      address.sin_addr.s_addr = inet_addr("127.0.0.1")
      let result = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.bind(localListener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
      }
      guard result == 0, listen(localListener, 16) == 0 else {
        Darwin.close(localListener)
        throw POSIXError(.EPERM)
      }
      var length = socklen_t(MemoryLayout<sockaddr_in>.size)
      _ = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          getsockname(localListener, $0, &length)
        }
      }
      baseURL = URL(string: "http://127.0.0.1:\(UInt16(bigEndian: address.sin_port))/api/")!
      listener = localListener
      DispatchQueue.global().async { [self] in acceptConnections() }
    }
    func stop() {
      lock.withLock {
        guard !stopped else { return }
        stopped = true
        for client in clients { shutdown(client, SHUT_RDWR) }
        shutdown(listener, SHUT_RDWR)
        Darwin.close(listener)
      }
    }
    private func acceptConnections() {
      while true {
        let client = accept(listener, nil, nil)
        guard client >= 0 else { return }
        let active = lock.withLock {
          if stopped {
            Darwin.close(client)
            return false
          }
          clients.insert(client)
          return true
        }
        guard active else { return }
        DispatchQueue.global().async { [self] in handle(client) }
      }
    }
    private func handle(_ client: Int32) {
      defer {
        lock.withLock {
          clients.remove(client)
          Darwin.close(client)
        }
      }
      var noSignal: Int32 = 1
      setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
      var bytes = Data()
      var buffer = [UInt8](repeating: 0, count: 4096)
      var headerEnd: Data.Index?
      while headerEnd == nil {
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0 else { return }
        bytes.append(contentsOf: buffer.prefix(count))
        headerEnd = bytes.range(of: Data("\r\n\r\n".utf8))?.upperBound
        guard bytes.count < 65536 else { return }
      }
      let end = headerEnd!
      let headers = String(decoding: bytes[..<end], as: UTF8.self)
      let first = headers.components(separatedBy: "\r\n")[0].split(separator: " ")
      guard first.count >= 2 else { return }
      let contentLength =
        headers.components(separatedBy: "\r\n").first {
          $0.lowercased().hasPrefix("content-length:")
        }
        .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
      while bytes.count - end < contentLength {
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0 else { return }
        bytes.append(contentsOf: buffer.prefix(count))
      }
      let path = String(first[1])
      lock.withLock {
        received.append(
          .init(method: String(first[0]), path: path, headers: headers, body: Data(bytes[end...])))
      }
      if path == "/api/socket" {
        guard
          let line = headers.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("sec-websocket-key:")
          })
        else { return }
        let key = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
          .trimmingCharacters(in: .whitespaces)
        let digest = Insecure.SHA1.hash(
          data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
        let handshake = Data(
          "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(Data(digest).base64EncodedString())\r\n\r\n"
            .utf8)
        handshake.withUnsafeBytes { pointer in
          _ = Darwin.send(client, pointer.baseAddress, handshake.count, 0)
        }
        let frame = Data([0x81, 5]) + Data("hello".utf8)
        frame.withUnsafeBytes { pointer in
          _ = Darwin.send(client, pointer.baseAddress, frame.count, 0)
        }
        _ = recv(client, &buffer, buffer.count, 0)
        return
      }
      if path == "/api/slow" {
        // Block until URLSession cancels/times out or fixture stops, without timing sleeps.
        _ = recv(client, &buffer, buffer.count, 0)
        return
      }
      let suffix = path.split(separator: "/").last.map(String.init) ?? ""
      let redirectStatus = Int(suffix)
      let response: String
      if let status = redirectStatus, [301, 302, 303, 307, 308].contains(status) {
        response =
          "HTTP/1.1 \(status) Redirect\r\nLocation: /api/final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      } else if path == "/api/external" {
        response =
          "HTTP/1.1 302 Redirect\r\nLocation: \(baseURL.absoluteString.replacingOccurrences(of: "127.0.0.1", with: "localhost"))final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      } else if path == "/api/chain" {
        response =
          "HTTP/1.1 307 Redirect\r\nLocation: /api/302\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      } else if path == "/api/cacheable" {
        response =
          "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nCache-Control: max-age=3600\r\nContent-Length: 4\r\nConnection: close\r\n\r\ndata"
      } else if path == "/api/cookie" {
        response =
          "HTTP/1.1 204 No Content\r\nSet-Cookie: session=synthetic; Path=/\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      } else {
        response =
          "HTTP/1.1 204 No Content\r\nCache-Control: max-age=3600\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      }
      let data = Data(response.utf8)
      data.withUnsafeBytes { pointer in
        var offset = 0
        while offset < data.count {
          let written = Darwin.send(
            client, pointer.baseAddress!.advanced(by: offset), data.count - offset, 0)
          guard written > 0 else { return }
          offset += written
        }
      }
    }
    func waitForRequest() async throws {
      for _ in 0..<500 {
        if !requests.isEmpty { return }
        try await Task.sleep(for: .milliseconds(10))
      }
      throw NetworkingError.timeout
    }
  }
  private struct LocalCredentials: CredentialProvider {
    func bearerToken() async throws -> String { "synthetic-token" }
    func recover(rejectedToken: String) async throws -> String {
      throw AuthenticationError.rejected
    }
  }
  private func localClient(
    _ server: LocalServer, redirects: RedirectPolicy = .reject, cap: Int = 3, timeout: Double = 30
  ) throws -> HTTPClient {
    .init(
      configuration: try .init(
        baseURL: server.baseURL, timeout: timeout, credentialProvider: LocalCredentials(),
        redirectPolicy: redirects, security: .allowLocalHTTP, maximumTotalAttempts: cap))
  }

  @Test(arguments: [301, 302, 303, 307, 308])
  func actualURLSessionRedirectsStripToken(status: Int) async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, redirects: .sameOriginWithoutCredentials)
    let response = try await client.data(.init(path: String(status), requiresAuthentication: true))
    #expect(response.metadata.wasRedirected)
    let requests = server.requests
    #expect(requests.count == 2)
    #expect(requests[0].headers.contains("Bearer synthetic-token"))
    #expect(!requests[1].headers.lowercased().contains("authorization:"))
  }

  @Test(arguments: [307, 308])
  func actualUnsafePostRedirectIsNotForwarded(status: Int) async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, redirects: .sameOriginWithoutCredentials)
    await #expect(throws: NetworkingError.self) {
      try await client.data(
        .init(
          method: .post, path: String(status), body: .data(Data([1]), contentType: "text/plain"),
          replayPolicy: .never))
    }
    #expect(server.requests.count == 1)
  }
  @Test func actualDefaultRedirectAndSingleSendCap() async throws {
    for (policy, cap) in [(RedirectPolicy.reject, 3), (.sameOriginWithoutCredentials, 1)] {
      let server = try LocalServer()
      defer { server.stop() }
      let client = try localClient(server, redirects: policy, cap: cap)
      await #expect(throws: NetworkingError.self) { try await client.data(.init(path: "302")) }
      #expect(server.requests.count == 1)
    }
  }
  @Test func actualURLSessionTimeout() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, timeout: 1)
    do {
      _ = try await client.data(.init(path: "slow"))
      Issue.record("Expected timeout")
    } catch NetworkingError.timeout {}
    #expect(server.requests.count == 1)
  }
  @Test func cancellationDuringActualURLSessionTransfer() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server)
    let task = Task { try await client.data(.init(path: "slow")) }
    defer { task.cancel() }
    try await server.waitForRequest()
    task.cancel()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(server.requests.count == 1)
  }
  @Test func standardSessionsNeverStoreOrShareCookies() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let a = try localClient(server)
    let b = try localClient(server)
    _ = try await a.execute(.init(path: "cookie"))
    _ = try await a.execute(.init(path: "check-a"))
    _ = try await b.execute(.init(path: "check-b"))
    #expect(server.requests.count == 3)
    #expect(server.requests.allSatisfy { !$0.headers.lowercased().contains("cookie:") })
  }

  @Test(arguments: [301, 302, 303, 307, 308])
  func actualConfirmedPostRedirectRespectsMethodAndBody(status: Int) async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, redirects: .sameOriginWithoutCredentials)
    _ = try await client.data(
      .init(
        method: .post, path: String(status),
        body: .data(Data([1, 2, 3]), contentType: "application/octet-stream"),
        requiresAuthentication: true, replayPolicy: .confirmedSafe))
    let requests = server.requests
    #expect(requests.count == 2)
    #expect(requests[0].body == Data([1, 2, 3]))
    #expect(!requests[1].headers.lowercased().contains("authorization:"))
    if [307, 308].contains(status) {
      #expect(requests[1].method == "POST")
      #expect(requests[1].body == Data([1, 2, 3]))
    } else {
      #expect(requests[1].method == "GET")
      #expect(requests[1].body.isEmpty)
    }
  }
  @Test func standardTransportDoesNotImplicitlyCache() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server)
    for _ in 0..<2 {
      _ = try await client.execute(.init(path: "cached", cachePolicy: .returnCacheDataElseLoad))
    }
    #expect(server.requests.count == 2)
  }

  @Test func actualExternalOriginIsRejectedBeforeForwarding() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, redirects: .sameOriginWithoutCredentials)
    do {
      _ = try await client.data(.init(path: "external", requiresAuthentication: true))
      Issue.record("Expected rejection")
    } catch NetworkingError.redirectRejected {}
    #expect(server.requests.count == 1)
  }
  @Test func actualRedirectChainStopsAtSharedBudget() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let client = try localClient(server, redirects: .sameOriginWithoutCredentials, cap: 2)
    do {
      _ = try await client.data(.init(path: "chain"))
      Issue.record("Expected exhausted budget")
    } catch NetworkingError.redirectRejected {}
    #expect(server.requests.count == 2)
  }
  @Test func explicitMemoryCacheWorksAndStaysIsolated() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    func client() throws -> HTTPClient {
      HTTPClient(
        configuration: try .init(
          baseURL: server.baseURL,
          transport: URLSessionTransport(options: try .init(memoryCacheBytes: 1_048_576)),
          cachePolicy: .useProtocolCachePolicy, security: .allowLocalHTTP))
    }
    let first = try client()
    #expect(try await first.data(.init(path: "cacheable")).data == Data("data".utf8))
    #expect(try await first.data(.init(path: "cacheable")).data == Data("data".utf8))
    #expect(server.requests.count == 1)
    _ = try await client().data(.init(path: "cacheable"))
    #expect(server.requests.count == 2)
  }

  private actor AccountCredentials: CredentialProvider {
    var token = "one"
    func bearerToken() async throws -> String { token }
    func recover(rejectedToken: String) async throws -> String { token }
    func switchAccount() { token = "two" }
  }
  @Test func authenticatedCacheNeverReusesPreviousAccountResponse() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let credentials = AccountCredentials()
    let transport = URLSessionTransport(options: try .init(memoryCacheBytes: 1_048_576))
    let client = HTTPClient(
      configuration: try .init(
        baseURL: server.baseURL, transport: transport, credentialProvider: credentials,
        cachePolicy: .useProtocolCachePolicy, security: .allowLocalHTTP))
    _ = try await client.data(.init(path: "cacheable", requiresAuthentication: true))
    await credentials.switchAccount()
    _ = try await client.data(.init(path: "cacheable", requiresAuthentication: true))
    #expect(server.requests.count == 2)
    #expect(server.requests[1].headers.contains("Bearer two"))
    // Unauthenticated caching remains available and can be explicitly cleared.
    _ = try await client.data(.init(path: "cacheable"))
    _ = try await client.data(.init(path: "cacheable"))
    #expect(server.requests.count == 3)
    transport.clearCache()
    _ = try await client.data(.init(path: "cacheable"))
    #expect(server.requests.count == 4)
  }
  @Test func realFileUploadDownloadAndLimits() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("upload")
    try Data("attachment".utf8).write(to: file)
    let client = TransferClient(
      httpClient: try localClient(server),
      transport: URLSessionFileTransferTransport(options: try .init(security: .allowLocalHTTP)))
    let upload = try await client.upload(
      .init(method: .post, path: "upload", requiresAuthentication: true), from: file)
    #expect(upload.metadata.statusCode == 204)
    #expect(server.requests[0].body == Data("attachment".utf8))
    #expect(server.requests[0].headers.contains("Bearer synthetic-token"))
    let destination = directory.appendingPathComponent("download")
    let result = try await client.download(.init(path: "cacheable"), to: destination)
    #expect(result.receivedBodyBytes == 4)
    #expect(try Data(contentsOf: destination) == Data("data".utf8))
    let limited = TransferClient(
      httpClient: try localClient(server),
      transport: URLSessionFileTransferTransport(
        options: try .init(maximumDownloadBytes: 2, security: .allowLocalHTTP)))
    let rejected = directory.appendingPathComponent("rejected")
    do {
      _ = try await limited.download(.init(path: "cacheable"), to: rejected)
      Issue.record("Expected size limit")
    } catch TransferError.fileTooLarge {}
    #expect(!FileManager.default.fileExists(atPath: rejected.path))
  }
  @Test func realWebSocketHandshakeAndMessages() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let url = URL(
      string: server.baseURL.absoluteString.replacingOccurrences(of: "http:", with: "ws:")
        + "socket")!
    let connector = URLSessionWebSocketConnector(security: .allowLocalHTTP)
    let connection = try await connector.open(URLRequest(url: url))
    #expect(try await connection.receive() == .text("hello"))
    await connection.close()
    #expect(server.requests.count == 1)
  }

  @Test func preparedAPIKeyRequestsNeverReadOrWriteMemoryCache() async throws {
    let server = try LocalServer()
    defer { server.stop() }
    let transport = URLSessionTransport(options: try .init(memoryCacheBytes: 1_048_576))
    let client = HTTPClient(
      configuration: try .init(
        baseURL: server.baseURL, transport: transport,
        cachePolicy: .useProtocolCachePolicy, security: .allowLocalHTTP))
    // Seed public cache. A sensitive exported request must bypass it.
    _ = try await client.data(.init(path: "cacheable"))
    #expect(server.requests.count == 1)
    for key in ["account-one", "account-two"] {
      let prepared = try await client.prepare(.init(path: "cacheable", headers: ["X-API-Key": key]))
      _ = try await transport.send(prepared, redirectPolicy: .reject)
    }
    #expect(server.requests.count == 3)
    transport.clearCache()
    let prepared = try await client.prepare(
      .init(path: "cacheable", headers: ["X-API-Key": "account-three"]))
    _ = try await transport.send(prepared, redirectPolicy: .reject)
    _ = try await transport.send(prepared, redirectPolicy: .reject)
    #expect(server.requests.count == 5)
  }
#endif
