# WebSocket og realtime

## Start, les, send og avslutt

```swift
import Foundation
import NetworkingRealtime

let socket = WebSocketClient(options: try WebSocketOptions(
    maximumConnectionAttempts: 5,
    heartbeatInterval: 30
)) {
    // Kjøres på nytt ved hver reconnect; hent et gjeldende token ved behov.
    var request = URLRequest(url: URL(string: "wss://chat.example.com/socket")!)
    request.setValue("Bearer synthetic-token", forHTTPHeaderField: "Authorization")
    return request
}
let stream = await socket.events()
for try await event in stream {
    switch event {
    case .connected(let attempt):
        _ = attempt
        // Send backendens subscribe/auth/resume-konvolutt her.
    case .message(let message):
        switch message {
        case .text(let json): _ = json
        case .data(let bytes): _ = bytes
        }
    case .reconnecting(let attempt, let delay):
        _ = (attempt, delay)
    }
}
```

Behold clienten og en lesertask mens forbindelsen trengs. `try await socket.send(.text(...))` eller .data sender på gjeldende connection. Sending før tilkobling gir notConnected. `await socket.disconnect()` avslutter reader, heartbeat og connection. Kall den ved logout, skjermavslutning eller når service-lifecycle slutter. Cancelling av consumerstream/reader fører også til termination/disconnect; eksplisitt disconnect er den tydelige lifecycle-grensen. Unngå å forlate en aktiv client uten å avslutte forbindelsen.

Én client har én aktiv stream. events() avslutter en tidligere stream synkront og returnerer en ny stream med nytt connection-budget/session-ID. Ny worker venter på gammel close og worker-completion før den åpner connection; events-kallet trenger ikke vente på oppryddingen. Terminal cleanup fra en gammel stream kan ikke lukke en nyere generasjon.

## Options og wire-kontrakt

| WebSocketOptions | Default og betydning |
| --- | --- |
| maximumConnectionAttempts | 1; totalt antall forbindelsesforsøk per events-session |
| reconnectBaseDelay | 1 s |
| maximumReconnectDelay | 30 s, finite og maks ett døgn |
| heartbeatInterval | 30 s; nil deaktiverer transportping |
| maximumMessageBytes | 1 MiB; både mottak og sending valideres |
| eventBufferCapacity | 64 events i bounded bufferingOldest stream |

Connect/reconnect gjør fresh makeRequest, og URLSessionConnector venter på faktisk WebSocket-handshake før .connected. Default connector setter URLSessionWebSocketTask.maximumMessageSize fra client-options. Custom connector/connection må selv begrense buffering under mottak; clienten kontrollerer størrelsen på returnerte meldinger.

Reconnect-backoff er eksponentiell med ceiling, uten jitter. maximumConnectionAttempts er en samlet sessiongrense og resettes ikke automatisk etter en kort vellykket tilkobling. En ny events-session starter et nytt budsjett. Koble appens nettverks-/foregroundsignaler til en eksplisitt restart hvis den er nødvendig.

Når eventbufferen er full avsluttes forbindelsen med bufferOverflow. Meldinger droppes ikke stilltiende. Size/overflow/policy-feil er terminale og reconnectes ikke automatisk. Consumer må håndtere gap/resume gjennom backendens cursor/sequence-protokoll. Transportfeil reconnectes innen budsjettet; når det er brukt opp terminerer streamen med feilen.

Heartbeat er WebSocket ping, ikke en appdefinert JSON-heartbeat eller servergaranti om chat-ack. Reader og heartbeat kjører i en strukturert taskgroup. En feil i én lukker connection og avbryter den andre. Custom connections må ha kooperativ cancellation/close; klienten kan ikke frigjøre en connector som ignorerer disse kontraktene.

RealtimeError er invalidConfiguration/notConnected/messageTooLarge/bufferOverflow/unsupportedMessage. URLSession- og custom connector-errors kan også terminere streamen. Explicit disconnect/cancellation gir normal stream-finish. Ingen sent message blir automatisk sendt på nytt ved reconnect.

## URLSessionWebSocketConnector og adapters

Connector krever wss, host og ingen URL user/password/fragment. Explicit `security: .allowLocalHTTP` tillater ws bare på localhost/127.0.0.1/::1. Cookies, URLCredentialStorage og cache er deaktivert; redirect er av. makeRequest eier URL/headers/Auth og må ikke logge token/queries. Connector bruker en isolert ephemeral session per connection.

WebSocketConnector.open returnerer en ready WebSocketConnection. Connection har receive/send/ping/close. Bruk protocols for deterministiske testdoubles eller en annen transport med tilsvarende kontrakt. Backendens meldingsformat, compression extensions, subscriptions og Auth-protokoll er ikke innebygde chatkontrakter.

## Chatservice i appen

En produksjonschat trenger typisk message IDs, server acknowledgements, ordering, dedup, history-pagination, cursor/resume og optional kryptering. Meldingshistorikk kan bruke HTTPClient, vedlegg TransferClient og pending sends OutboxEngine. Ack må oppfylle serverens varighetskontrakt før en outbox-operasjon slettes. .connected betyr transportklar, ikke at brukeren er autentisert eller at alle channels er abonnert.

SSE har ikke en innebygd parser/client i denne versjonen. Hvis en tredjepart bare tilbyr SSE, bruk en egen adapter med event-ID, retry og bounded parsing; ikke kall HTTPClient.data for en uendelig responsebody. WebSocket-modulen er heller ikke en ferdig Firebase/Supabase/Pusher-protokollimplementasjon.
