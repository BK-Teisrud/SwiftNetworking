# ``NetworkingTransfers``

File-based foreground transfers, multipart encoding, and application-integrated system background transfers.

## Overview

The complete handbook is available in `Docs/README.md`. It covers installation, use cases, defaults, examples, adapters, errors, and explicit lifecycle and security boundaries. `Docs/API.md` contains every public declaration.

Apple background sessions follow redirects automatically and therefore require explicitly trusted servers. Foreground transport rejects redirects. The application must integrate the operating-system completion handler and retain a stable identifier across relaunches.

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

- ``TransferClient``
- ``FileTransferTransport``
- ``URLSessionFileTransferTransport``
- ``TransferOptions``
- ``TransferProgress``
- ``DownloadedFile``
- ``MultipartForm``
- ``BackgroundTransferManager``
- ``BackgroundTransferReceipt``
- ``BackgroundRedirectPolicy``

### Design

- <doc:Architecture>
