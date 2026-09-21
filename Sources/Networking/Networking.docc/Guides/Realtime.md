# WebSocket and realtime

## Connect, receive, send, and disconnect

```swift
let socket = WebSocketClient(options: try WebSocketOptions(
    maximumConnectionAttempts: 5,
    heartbeatInterval: 30
)) {
    var request = URLRequest(url: URL(string: "wss://chat.example.com/socket")!)
    request.setValue("Bearer synthetic-token", forHTTPHeaderField: "Authorization")
    return request
}

for try await event in await socket.events() {
    switch event {
    case .connected: break
    case .message(let message): _ = message
    case .reconnecting(let attempt, let delay): _ = (attempt, delay)
    }
}
```

Retain the client and reader task while the connection is needed. Sending before connection throws `notConnected`. Call `disconnect()` at logout or when the owning service ends. Cancelling the consumer stream also terminates the connection.

One client has one active stream. Calling `events()` terminates the previous stream and starts a new connection budget. Cleanup from an older generation cannot close a newer one.

## Options and wire contract

| Option | Default |
| --- | --- |
| `maximumConnectionAttempts` | 1 total attempt per event session |
| `reconnectBaseDelay` | 1 second |
| `maximumReconnectDelay` | 30 seconds |
| `heartbeatInterval` | 30 seconds; `nil` disables ping |
| `maximumMessageBytes` | 1 MiB for incoming and outgoing messages |
| `eventBufferCapacity` | 64 events |

The default connector waits for the real WebSocket handshake before emitting `connected`. Reconnect backoff is exponential and bounded. A full event buffer terminates with `bufferOverflow`; events are never silently dropped. Size, overflow, and policy errors are terminal. The application must recover gaps through its backend cursor or sequence protocol.

Heartbeat is a WebSocket ping, not an application JSON heartbeat or message acknowledgement. Sent messages are not replayed automatically after reconnect.

The URLSession connector requires `wss`, a host, and no URL credentials or fragment. Explicit local security policy permits `ws` only for loopback hosts. Cookies, credential storage, cache, and redirects are disabled.

The module supplies a wire transport, not a complete chat, GraphQL subscription, Firebase, Supabase, or Pusher protocol. Production chat still needs message IDs, acknowledgements, ordering, deduplication, history, cursor resumption, and any domain encryption. SSE is not included.
