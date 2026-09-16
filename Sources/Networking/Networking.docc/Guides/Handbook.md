# Networking — full håndbok

Denne dokumentasjonen beskriver alle fire biblioteksproduktene og de offentlige kontraktene. Start med hurtigstarten, velg de modulene appen trenger, og bruk API-referansen når du skal finne signaturer og tilgjengelige medlemmer.

| Dokument | Innhold |
| --- | --- |
| [Kom i gang](GettingStarted.md) | Installasjon, moduler, klienter, arkitektur og første kall |
| [HTTP og JSON](HTTP.md) | Alle request-/responsoperasjoner, paths, bodies, JSON, feil, retry og tidsbudsjett |
| [Autentisering og kontosession](Authentication.md) | Bearer, refresh-koordinering, kontoovergang, cache og lifecycle |
| [Filoverføringer](Transfers.md) | File upload/download, multipart, progress, absolutte URL-er og systembakgrunn |
| [Realtime](Realtime.md) | WebSocket, events, sending, heartbeat, reconnect og kapasitet |
| [Offline og synkronisering](Sync.md) | Vedvarende outbox, idempotency, ordering, retry og konfliktgrenser |
| [Tredjepartsintegrasjoner](Integrations.md) | API-key, signing, Basic-adaptere, form, GraphQL og presignerte URL-er |
| [Sikkerhet og grenser](Security.md) | HTTPS, redirects, credentials, storage, ressursgrenser og personvern |
| [Testing og drift](Testing.md) | Deterministiske adapters, lokale fixtures, CI, dokumentasjonsbygg og feilsøking |
| [Git og GitHub](Repository.md) | Repository-filer, publisering, CI, tilgang og rettigheter |
| [Migrering og release](Migration.md) | API-endringer, oppgradering og releasekontrakt |
| [Komplett API-referanse](API.md) | Alle offentlige symboler og deklarasjoner, generert fra Swift-modulene |

## Hva pakken kan brukes til

| Appbehov | Modul og grense |
| --- | --- |
| Katalog, administrasjon, CRUD, konto-API | Networking: vanlig HTTP, JSON og avgrensede binære bodies |
| Bilder, vedlegg og eksportfiler | NetworkingTransfers: filbasert upload/download og multipart |
| Store eller langvarige overføringer | Foreground file transport eller appintegrert BackgroundTransferManager med systemets lifecycle |
| Chat, liveoppdateringer og subscriptions | NetworkingRealtime: WebSocket transport; appen eier wire-protokoll og gjenopptak |
| Handlinger som må overleve offline/relaunch | NetworkingSync: account-bound outbox; backend må støtte deduplisering |
| Tredjepart via HTTPS, bearer/API-key/form/GraphQL | Networking og tjenestespesifikke adaptere; signing skjer etter request-bygging |
| Presignerte fil-URL-er | Eksplisitt URLRequest i Transfers; URL og query beholdes uten base-headers/token |

Bibliotekene er backend-agnostiske. Ingen produkter definerer dine DTO-er, login-UI, database, chat-ack-format eller konfliktregler. Del transport og tekniske kontrakter mellom apper, og hold domenereglene i appens egne services/repositories.

## Plattform og distribusjon

Swift 6.0+, iOS 17+, macOS 13+. Foundation/URLSession brukes; ingen eksterne biblioteksavhengigheter. Andre plattformer og Linux er ikke en verifisert supportkontrakt. Bakgrunnsoverføringer krever en faktisk app og OS-lifecycle-integrasjon. Pakken er ikke publisert eller tagget av denne endringen.

API-signaturene i API.md er autoritative for den bygde versjonen. Eksemplene bruker syntetiske origins og må tilpasses ditt API. Kode i Tests/NetworkingIntegrationTests/DocumentationExamples.swift kompilerer sentrale håndbokeksempler uten å kontakte offentlige servere.

Se [arkitekturen](Architecture.md) for ansvarsdeling, eierskap og regler for videreutvikling.
