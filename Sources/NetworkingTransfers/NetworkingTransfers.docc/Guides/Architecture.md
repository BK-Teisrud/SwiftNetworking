# Arkitektur og videreutvikling

## Produkter og avhengigheter

Networking er HTTP-kjernen. NetworkingTransfers og NetworkingRealtime avhenger av kjernens request-/response-/security-kontrakter. NetworkingSync er selvstendig og bruker Foundation og sin egen OutboxClock. Produktene er uavhengige valg for konsumenten; ingen global klient eller appsession opprettes av pakken.

## Ansvarsdeling i koden

| Område | Ansvar |
| --- | --- |
| Networking/Client/HTTPClient | Offentlig decode/data/execute/prepare, operasjonsfrist og diagnostikk |
| Networking/Client/HTTPOperation | Sendbudsjett, retry, recovery og eksplisitt redirect |
| Networking/Requests | Request, metode, body, JSON-coding, URL-/header-validering og preparer-protokoll |
| Networking/Transport | Transportkontrakt, URLSession og bounded responsinnsamling |
| NetworkingTransfers/Models | Filresultater, progress, limits og background-events |
| NetworkingTransfers/Transport | Foreground URLSession og terminal completion/fileierskap |
| NetworkingTransfers/Background | Session-admission, delegate-callbacks og kvitteringslagring |
| NetworkingRealtime/Models | Wire-meldinger, events, options og transportprotokoller |
| NetworkingRealtime/Session | Session-eierskap, stream-buffer og strukturert reader/heartbeat |
| NetworkingRealtime/Transport | URLSession-handshake og connection-adapter |
| NetworkingSync/Models og Storage | Outbox-kontrakt, versjonert filformat og atomisk lagring |
| NetworkingSync/OutboxEngine | FIFO delivery, blokkering, retry og kooperativ cancellation |

## Eierskap og invariants

WebSocketClient eier én WebSocketSession på sin actor. Start/stopp løsriver gammel session og avslutter streamen synkront før noen await. Ny worker venter på tidligere close og worker-completion før connector åpnes. events returnerer den nye streamen umiddelbart; den kan vente på opprydding før connected-event. En eldre termination kan bare avslutte sin egen session-ID. Kooperativ close/cancellation er nødvendig for custom adapters.

FileTransferDelegate har pending/completed/cancelled som terminal kontrakt under lock. Før completion eier transporten flyttet downloadfile og fjerner den ved cancellation. Når completion velger suksess overføres eierskapet til appen; senere cancellation sletter ikke appens fil. Appen rydder suksessfiler selv.

BackgroundTransferManager eies av appens konto-/lifecycle-koordinator. BackgroundSessionLifecycle serialiserer jobbadmission med shutdown. finishTasksAndInvalidate avviser nye jobs og lar eksisterende jobs fullføres; invalidateAndCancel avviser og kansellerer. En manager kan ikke brukes på nytt etter shutdown. Behold den til callbacks er behandlet, og opprett ikke parallelle sessions med samme identifier. Ved deinit forespørres finish uten cancellation. OS-relaunch og callbacks må fortsatt integreres i appen.

FileOutboxStore eier ett lazy snapshot per fil/account. Første tilgang validerer filen; vellykket atomisk write erstatter snapshot, og mislykket write publiserer ingen endring. Eksterne writes støttes ikke mens instance lever. Reopprett store for å lese filen på nytt etter eksplisitt reparasjon/migrering. nextItem lar engine hente hodet uten å be om en full liste. Hver bekreftelse persisteres fortsatt individuelt for crash-sikkerhet; JSON-write vokser med køstørrelsen. Databaseadapter anbefales ved større eller multiprocess køer.

## Utvidelse og testing

Bruk HTTPRequestPreparing for request-/Auth-adaptere og FileTransferTransport for filtransport. Vanlige konsumenter bruker HTTPClient som preparer; presigned URLRequest-workflows kan opprette TransferClient med bare transport. ClientLimits, RedirectOptions og DiagnosticsOptions grupperer avansert oppsett. Original konfigurasjonskonstruktør beholdes for eksisterende kode.

Tester følger produktene: NetworkingTests, NetworkingTransfersTests, NetworkingRealtimeTests og NetworkingSyncTests. NetworkingIntegrationTests kompilerer håndbokeksempler og tester ekte foreground URLSession mot loopback på macOS. Core- og Sync-testtargets kan ikke utilsiktet hente de valgfrie modulene via dependencies.

Nye features skal legges hos mekanismen som eier dem og testes ved dens kontrakt. Appens service eier kontoendring, DTO-/domenemapping, chat acknowledgements/resume og offline konfliktløsning. Et nytt produkt eller en generell middleware-kjede bør først innføres når et konkret gjenbruksbehov krever det.

Filstore gjenbruker JSON-encoding for uendrede items mellom atomiske writes. Encoding-cache og snapshot oppdateres sammen først når write lykkes; version-1 filformatet beholdes.

HTTPRequest eier én intern RequestPath (encoded eller segments). Public path/pathSegments-getters og begge init-overloads er beholdt. Delte standardverdier kommer fra options-typenes standard-instans. DocC-guider følger distribusjonen som synkroniserte kopier; felles nettverksfeilkategorier erstatter ikke de opprinnelige error-payloadene.
