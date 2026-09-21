# Offline operation, outbox, and synchronization

NetworkingSync provides a persistent account-bound outbox and a FIFO delivery engine. Operations can survive offline periods and relaunch while retaining the same idempotency key. It does not monitor connectivity or provide a universal database merge protocol.

```swift
let store = try FileOutboxStore(
    fileURL: URL(fileURLWithPath: "/path/in/app/container/account-one/outbox.json"),
    accountID: "account-one"
)
let outbox = try OutboxEngine(accountID: "account-one", store: store) { item in
    // Decode the application's command, send it with current credentials,
    // and acknowledge only after the backend's durable confirmation.
    _ = item
    return .acknowledged
}
let id = try await outbox.enqueue(payload: Data("synthetic-command".utf8))
let report = try await outbox.flush()
```

Returning `acknowledged` without sending deletes the operation. See [Integrations](Integrations.md) for an HTTP binding.

## Storage contract

An item contains its UUID, account ID, stable idempotency key, payload, creation date, attempt count, next eligible date, and optional blocked reason. Identity fields cannot change during an update.

`FileOutboxStore` uses a versioned JSON envelope, account validation, and atomic writes. Failed writes do not modify the visible queue. IDs and idempotency keys are unique among pending items. Opening a file with another account ID fails rather than delivering it to that account.

| Limit | Default |
| --- | --- |
| Items | 1,000 |
| Payload | 1 MiB per item |
| Encoded file | 16 MiB including JSON and Base64 overhead |

Store the file in private persistent application storage. The store is not a cross-process database, encrypted storage, or a coordinator for multiple extensions. Corrupt data fails explicitly and is never silently deleted.

## Delivery contract

- `acknowledged` removes an item after durable server confirmation.
- `retry(after:)` persists the next date and increments failed attempts.
- `blocked(reason:)` records an application-defined reason and stops the flush.

Unknown delivery errors receive bounded exponential delay. Cancellation preserves the item. Only acknowledgement advances to the next item, preserving FIFO order. The default attempt limit is 10 and the default maximum operations per flush is 100. Only one flush or maintenance operation runs at a time.

Cancellation can occur after the backend performed an action but before local removal. The backend must therefore implement real idempotency. This is at-least-once delivery, not exactly-once transport.

The application decides when to flush, coordinates HTTP and outbox retry budgets, separates account stores, and stops old delivery at logout. For attachments, persist a stable file reference rather than the binary payload and retain the file until server acknowledgement. Download synchronization requires a server cursor and an application-owned local transaction. Conflict strategy remains a domain decision.
