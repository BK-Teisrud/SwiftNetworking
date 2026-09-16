# Offline, outbox og synkronisering

## Hva Sync løser

NetworkingSync leverer en vedvarende kontoavgrenset outbox og en FIFO delivery-engine. Handlinger kan legges i kø offline, overleve relaunch og prøves igjen med samme idempotency key. Den overvåker ikke connectivity automatisk og har ikke en universell database-/merge-protokoll.

```swift
import Foundation
import NetworkingSync

let privateFile = URL(fileURLWithPath: "/path/in/app/container/account-one/outbox.json")
let store = try FileOutboxStore(fileURL: privateFile, accountID: "account-one")
let outbox = try OutboxEngine(accountID: "account-one", store: store) { item in
    // Decode ditt eget commandformat fra item.payload.
    // Send med gjeldende Auth og item.idempotencyKey.
    // Returner acknowledged bare ved backendens faktiske bekreftelse.
    _ = item
    return .acknowledged
}
let id = try await outbox.enqueue(payload: Data("synthetic-command".utf8))
let report = try await outbox.flush()
```

Denne illustrative closure må erstattes av appens faktiske delivery. Å returnere acknowledged uten å sende sletter handlingen fra køen. Se Integrations.md for HTTP-binding og DocumentationExamples.swift for kompilerbare konstruktorer.

## OutboxItem og lagring

OutboxItem har id UUID, accountID, idempotencyKey, payload Data, createdAt, attempts, notBefore og optional blockedReason. Payload/key/createdAt er immutable identitet. Store-update får ikke endre dem. Retry bruker samme key; en tapt respons kan bety at serveren allerede har utført handlingen.

FileOutboxStore har versioned JSON-envelope, accountID-sjekk og atomic file-write. Første tilgang laster og validerer filen til et actor-eid snapshot. Hver insert/update/remove skriver atomisk før det nye snapshot publiseres. Mislykket write endrer ikke synlig kø. Concurrent insert på samme store mister ikke hverandres writes. IDs og idempotencyKeys er unike blant pending items. Reopening med en annen accountID gir accountMismatch, ikke levering til ny konto.

| Storegrense | Default |
| --- | --- |
| maximumItems | 1000 |
| maximumPayloadBytes | 1 MiB per item |
| maximumFileBytes | 16 MiB, inkludert JSON/base64-overhead |

Filen må ligge i app-private persistent storage, eksempelvis Application Support. Én instance/writer per file. Dette er ikke en cross-process database, filkoordinator for flere app extensions eller encrypted store. Bruk en database-adapter til OutboxStore hvis appen trenger transaksjoner på flere tabeller, bedre skalering eller extensions. Custom stores må gjøre mutations atomiske og bevare FIFO/identitet/account-kontrakt. nextItem returnerer hodet; defaultimplementasjonen bruker items.first, mens filstore bruker snapshot. Eksterne filendringer støttes ikke mens store-instance lever. Reopprett instance etter eksplisitt reparasjon/migrering.

Bounds, finite dates, ikke-negativ attempts og key-kontroll valideres. Corrupt JSON/version/duplicates feiler; engine sletter ikke automatisk filen som en "recovery". Appen må håndtere, migrere, bevare for feilsøking eller eksplisitt rydde sin egen data. Det finnes ingen automatisert schema migration utover envelope-versionkontroll.

## Delivery og ordering

SyncDisposition:

- acknowledged: serveren har bekreftet; item fjernes.
- retry(after: seconds): persistér neste tidspunkt og øk failed-attempt count. Delay må være finite, 0–86 400 s.
- blocked(reason:): persistér appvalgt grunn og stopp denne flushen.

Unknown delivery-errors gir retry med exponentiell delay (1 s, 2 s, …, capped beregning); cancellation gir CancellationError og item beholdes. Ingen error descriptions/tokens persisteres automatisk. reason er eksplisitt appdata og kan være sensitivt hvis appen velger det.

Engine maximumAttempts er 10 som default. Ved nok failed retries markeres item blockedReason attemptLimit. flush(maximumOperations:) er 100 som default. Kun acknowledged fortsetter til neste item i samme flush. Retry/blocked/notBefore stopper ved hodet og bevarer ordering. Et blocked første item stanser dermed senere items; dette er bevisst for sekvensavhengige commands.

OutboxEngine har én aktiv flush. Et samtidig flush-kall returnerer alreadyRunning true og gjør ingen ekstra levering. Enqueue kan fortsatt foregå via atomic store. retryBlocked/discard er maintenance-operasjoner og avvises mens flush/maintenance er aktiv. pending leser aktuelle items. retryBlocked(id:) resetter attempts/blocked og setter notBefore til now. discard(id:) er appens eksplisitte beslutning om å slette en handling.

SyncReport har acknowledged/deferred/blocked og alreadyRunning. Deferred er en head-operasjon som ikke ble levert nå, ikke total kølengde. Bruk pending for full status. Ingen automatisk timer/scheduler opprettes for notBefore.

## Cancellation og backend-idempotency

Cancellation sjekkes før delivery og etter resultatet før lagringsmutasjon. Hvis serveren utførte handlingen og tasken deretter ble cancelled, kan item fortsatt ligge i kø. Neste levering må derfor være sikker gjennom serverens idempotency-kontrakt. Dette er at-least-once delivery, ikke exactly-once transport. Å legge en tilfeldig key-header til en backend som ignorerer den skaper ingen dedup-garanti.

Deliver må være kooperativ og ha et passende nettverks-/Auth-budsjett. En SyncEngine-flush har ikke sin egen hard deadline; appen kan cancel tasken, og HTTP-delivery kan bruke HTTPClient.operationTimeout. RetryPolicy og outbox-retry må samordnes for å unngå for mange sends per persisted forsøk.

## Appens offline-koordinator

Kall flush ved passende app-/network-signaler, foreground, eksplisitt retry eller egen scheduler. Reachability er et hint, ikke bevis på at serveren er tilgjengelig. Opprett en egen store/accountID per konto og stopp gammel delivery før logout. Ikke lagre tokens i payload.

For filuploads lagres en persistent lokal filreferanse/hash i payload, ikke hele store binære vedlegget. Behold filen til serverack, og bruk et klart totrinnsløp hvis upload og message/create er separate operasjoner. Appen må også eie lokal optimistic UI og bekrefte/markere failed handlinger.

Download-sync trenger servercursor/version/checkpoint og en lokal transaksjon som installerer både data og cursor. Konfliktløsning kan være server-wins/client-wins/manual/domain-merge; det kan ikke velges korrekt for alle apper av en HTTP-pakke. Denne versjonen leverer ikke en ferdig snapshot-/cursor-store, CRDT eller cross-device merge-motor. Disse grenser er en del av kontrakten, ikke skjult behovsdekning.

OutboxClock har bare now og kan injiseres for scheduling-tester. SystemOutboxClock bruker Date. NetworkingSync har ingen HTTP-modulavhengighet.

Filstore gjenbruker JSON-encoding for uendrede items mellom atomiske writes. Encoding-cache og snapshot oppdateres sammen først når write lykkes; version-1 filformatet beholdes.
