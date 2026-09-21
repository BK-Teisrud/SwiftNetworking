# ``NetworkingSync``

Vedvarende kontoavgrenset FIFO outbox med at-least-once delivery.

## Overview

Den komplette norske håndboken ligger i Docs/README.md i repositoryet. Den beskriver installasjon, alle bruksområder, defaults, kodeeksempler, adaptere, feil og eksplisitte lifecycle-/sikkerhetsgrenser. Docs/API.md inneholder samtlige offentlige deklarasjoner.

App/backend eier deduplisering og konfliktregler. Ingen exactly-once-garanti, kryptert database eller automatisk connectivity-scheduler inngår.

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
- <doc:API>

### Offentlige symboler

- ``OutboxEngine``
- ``OutboxStore``
- ``FileOutboxStore``
- ``OutboxItem``
- ``SyncDisposition``
- ``SyncReport``
- ``SyncError``

### Arkitektur

- <doc:Architecture>
