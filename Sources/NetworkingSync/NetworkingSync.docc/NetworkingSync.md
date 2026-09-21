# ``NetworkingSync``

Persistent account-bound FIFO outbox with at-least-once delivery.

## Overview

The complete handbook is available in `Docs/README.md`. It covers installation, use cases, defaults, examples, adapters, errors, and explicit lifecycle and security boundaries. `Docs/API.md` contains every public declaration.

The application and backend own deduplication and conflict rules. The module provides no exactly-once guarantee, encrypted database, or automatic connectivity scheduler.

## Topics

### Guides

- <doc:Handbook>
- <doc:GettingStarted>
- <doc:HTTP>
- <doc:Authentication>
- <doc:Transfers>
- <doc:Realtime>
- <doc:Sync>
- <doc:Integrations>
- <doc:Security>
- <doc:Testing>
- <doc:API>

### Public symbols

- ``OutboxEngine``
- ``OutboxStore``
- ``FileOutboxStore``
- ``OutboxItem``
- ``SyncDisposition``
- ``SyncReport``
- ``SyncError``

### Design

- <doc:Architecture>
