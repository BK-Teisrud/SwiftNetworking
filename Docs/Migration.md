# Migrering og release

Ingen release/tag er publisert av denne implementasjonen. Hold intern versjon 0.x mens de nye modulene integreres i appene. CHANGELOG beskriver den planlagte neste interne versjonen; velg faktisk tag gjennom din releaseprosess.

## Endringer fra forrige implementasjon

1. Autentisert og registrert sensitive HTTP-cache er deaktivert uansett request-cachePolicy. Ufølsom cache fungerer fortsatt. clearCache/invalidateAndCancel er offentlige lifecycle-operasjoner på URLSessionTransport.
2. Tillatt redirect bruker en allowlist. Custom headers som før fulgte med fjernes nå. Legg til bare ufølsomme headers i redirectHeaderAllowlist; Authorization/Cookie kan ikke velges som manuelle reserved headers.
3. HEAD bruker ikke representasjonens Content-Length for bodygrensen.
4. HTTPTransportOptions har allowsCaching. Adapters må respektere dette og bevarer receivedBodyBytes ved discard.
5. HTTPMethod er nå RawRepresentable Sendable Hashable struct, med validated custom tokens. Tidligere uttømmende switches over enum må omskrives med default/egne case-sammenligninger.
6. HTTPBody.form og HTTPClient.prepare er nye. prepare sender ikke eller utfører recovery/deadline; følg adapterkontrakten.
7. droppedDiagnosticEvents gjør queue-overflow målbar.
8. Valgfrie produkter NetworkingTransfers/NetworkingRealtime/NetworkingSync er nye. Legg dem til eksplisitt i appens product dependencies.

Fra eldre versjoner gjelder også strukturerte NetworkingError payloads, metadata på emptyResponse, required begge advanced JSON factories, asynkron diagnostikk og optional operationTimeout/responsgrense. Retningslinjene i tidligere rapporter er historiske og erstattes av denne håndbokens faktiske kontrakt.

## Før 1.0

Kjør minimum-toolchain CI, bruk minst to faktiske apper med ulike backend/auth-/fil-/realtime-behov og verifiser kontobytte. Integrer background completion lifecycle på enhet før backgroundavhengig apprelease. Backendens idempotency, chatresume og konfliktsvar må testes i integrasjonen.

Velg lisensgrunnlag ved distribusjon utenfor egen organisasjon. Etter 1.0 skal source-breaking public API-endringer håndteres med passende major-versjon; under 0.x gjør en breaking endring en ny minor nødvendig. Ingen remote publishing/merge/tagging utføres av dokumentasjonsverktøyene.

## Strukturrefaktorering før produksjon

De fire produktnavnene er beholdt. Original ClientConfiguration-init og TransferClient(httpClient:transport:) fungerer fortsatt. Grupperte ClientLimits/RedirectOptions/DiagnosticsOptions og HTTPRequestPreparing er nye valg. Transport-only TransferClient er tilgjengelig for presigned URLRequest.

NetworkingSync er nå selvstendig. En custom clock til OutboxEngine må implementere OutboxClock i stedet for RetryClock; den trenger bare now. JSON-envelope version 1 og itemformat er uendret. OutboxStore har nextItem med defaultimplementasjon, så eksisterende store-adapters trenger ingen ny metode.

FileOutboxStore leser én gang per instance og tillater ikke eksterne writes. Reopprett instance etter filreparasjon. Background receipts returnerer nå healthy completions selv om andre filer er corrupt; receiptScan eksponerer feil per fil. Session-shutdown avviser nye jobs. WebSocket-restarts serialiserer eldre opprydding før ny connection og avslutter gamle streams umiddelbart.

## Rettelser etter strukturvurdering

prepare deaktiverer cache også for sensitive headers, og standardtransport lagrer ikke responser for reloadIgnoringLocalCacheData/Remote-policy. Request path-getters og konstruktører er source-kompatible. NetworkFailures og NetworkFailureClassifying er additive API-er. BackgroundTransferManager kan ta receiptStore; directory må stemme. BackgroundReceiptStore krever nå minst 1024 bytes. Oversized completions persisteres som receiptTooLarge uten body. DocC-guider må følge distribusjonen og holdes i sync via verktøyene.
