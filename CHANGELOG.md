# Endringslogg

## Neste interne 0.3.0 — ikke publisert

- GitHub-klargjøring med ignore-/tekstregler, CI-oppsett, bidragsmaler og publiseringsveiledning. Alle rettigheter forbeholdt Teisrud Development AS.

- Rettet HEAD, cache ved kontobytte, sensitive headers ved redirect og discarded byteantall.
- Ny ufølsom redirect-allowlist, cache invalidation, HTTP prepare, form encoding og validerte custom metoder.
- Valgfrie produkter for filoverføring/multipart/background, WebSocket/heartbeat/reconnect og kontoavgrenset persisted outbox.
- Målbar diagnostikk-overflow, utvidede reelle fixtures og kompilerbare håndbokeksempler.
- Komplett norsk håndbok, generert offentlig API-referanse og DocC-arkivbygg.

Breaking endring: HTTPMethod er RawRepresentable struct; custom headers forwardes bare ved allowlist og auth/sensitive caching er deaktivert. Background er en separat eksplisitt system-managed trusted-server-kontrakt.

## Tidligere interne 0.2.0-utkast — ikke publisert

- Retry-After respekteres ved retry og redirects. For lang serverventing hindrer ny sending.
- Rettet årstolkning og validering av ventetid før Duration-konvertering.
- Strukturerte transport-, decoding- og redirect-feil; metadata på tom respons.
- Rå pathSegments, immutable JSON-options og kontrollerte URLSession-options.
- Valgfri samlet operationTimeout og responsgrense under nedlasting.
- Avgrenset asynkron diagnostikk med korrelasjon, kategorier og monoton varighet.
- Utvidede regresjonstester og CI for Swift 6.0, nyere Swift og iOS-simulator.

API-endringer: tilhørende verdier i NetworkingError er endret. Avanserte JSONCoding-factories krever nå begge closures. Diagnostikk leveres asynkront; bruk flushDiagnostics ved eksport eller deterministisk testing.

Ingen release er publisert eller tagget. Bruk 0.x-versjoner mens kontrakten prøves i egne apper. En API-endring krever ny minor-versjon før 1.0. Etter integrasjon i to faktiske apper og grønn CI kan 1.0 vurderes. Publisering utenfor organisasjonen krever et valgt lisensgrunnlag.

## Strukturrefaktorering før produksjon

- Samlet WebSocket-session-eierskap og serialisert restart-opprydding.
- Terminal filtransfer-completion som beskytter app-eide downloadfiler.
- Delt offentlige modeller, operasjoner og transportimplementasjoner etter ansvar.
- Grupperte klientvalg og request-preparer, samt presigned transport-only klient.
- Selvstendig Sync med OutboxClock, nextItem og lazy snapshot med atomisk publisering.
- Separat background receipt store, feil per kvittering og eksplisitt session-shutdown.
- Modulvise testtargets, egne integrasjonstester og oppdatert API-/arkitekturdokumentasjon.

## Rettelser etter strukturvurdering

- Lik sensitive-header-cachebeskyttelse for prepare og HTTP-sending, inkludert ingen cachelagring.
- Konfigurerbar background receipt store og liten vedvarende fallback ved oversized kvitteringer.
- Distribuerbare DocC-artikler, synkroniseringskontroll og dokumentasjonsbygg fra tom distribusjonsmappe i CI.
- Samlede defaults, additive felles nettverksfeilkategorier og én intern request-path-representasjon.
