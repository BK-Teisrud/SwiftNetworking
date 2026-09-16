# ``NetworkingTransfers``

Filbaserte foregroundoverføringer, multipart og appintegrert systembakgrunn.

## Overview

Den komplette norske håndboken ligger i Docs/README.md i repositoryet. Den beskriver installasjon, alle bruksområder, defaults, kodeeksempler, adaptere, feil og eksplisitte lifecycle-/sikkerhetsgrenser. Docs/API.md inneholder samtlige offentlige deklarasjoner.

Bakgrunnssesjoner følger redirects automatisk i Apple-systemet og krever eksplisitt betrodde servere. Foreground transport avviser redirects. Appen må integrere OS completion-handler og stable identifier ved relaunch.

## Topics

### Håndbok

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
- <doc:Migration>
- <doc:API>

### Offentlige symboler

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

### Arkitektur

- <doc:Architecture>
