# Git, GitHub og distribusjon

Repositoryet inneholder fire Swift Package-produkter. Ingen eksterne avhengigheter, Git LFS eller submoduler er nødvendige. Teisrud Development AS beholder alle rettigheter; `LICENSE` er en proprietær rettighetsmelding. Bruk og distribusjon til andre må være skriftlig autorisert. Velg et privat repository dersom koden bare skal være tilgjengelig for selskapet og inviterte samarbeidspartnere.

## Hva Git skal inneholde

Commit Package.swift, Sources (inkludert alle .docc/Guides), Tests, Docs, Tools, README, CHANGELOG, LICENSE og repository-konfigurasjonen. .gitignore utelater byggprodukter, personlig Xcode-tilstand, lokale credentials og genererte DocC-arkiver. Eksempelkonfigurasjon med syntetiske verdier kan hete .env.example. Ignore-regler fjerner ikke allerede sporede filer eller hemmeligheter fra historikken.

Dette er et bibliotek uten eksterne dependencies. Package.resolved utelates her; apper som bruker biblioteket bør ha sin egen policy for låsing av avhengigheter. .gitattributes normaliserer tekstlinjer til LF og markerer vanlige binærfiler. .editorconfig beskriver tegnsett og innrykk; Swift-formatkontrollen i CI er autoritativ for Swift.

## Første opplasting

Opprett et tomt GitHub-repository uten automatisk README, lisens eller gitignore. Kjør fra pakkens rot:

```sh
git status --short
git diff --check
python3 Tools/sync-documentation.py --check
bash Tools/check-distribution.sh
git add --all
git diff --cached --stat
git diff --cached --check
```

Gjennomgå det som er staged, særlig nye filer og eventuelle credentials. Deretter:

```sh
git commit -m "Prepare Networking package for GitHub"
```

Legg til repositoryets faktiske SSH- eller HTTPS-URL som origin med `git remote add origin URL`, hvor URL erstattes med adressen fra GitHub. Kontroller med `git remote -v`, og kjør `git push -u origin main`. Git-identitet og GitHub-autentisering må være konfigurert lokalt. En allerede konfigurert origin skal kontrolleres før den endres.

## GitHub-innstillinger

CI kjører macOS-tester med Xcode 16.0 og 26.2, samt tester med iOS-simulator. Nyere toolchain kontrollerer også Swift-format og dokumentasjon fra en ren distribusjon. Workflowen har lesetilgang til repositoryet, tidsgrenser og avbryter eldre kjøringer av samme branch. Dependabot foreslår ukentlige oppdateringer av GitHub Actions.

Aktiver branch protection/ruleset for main etter første vellykkede CI-kjøring: krev pull request og velg de faktiske macOS- og iOS-jobbene som obligatoriske statuskontroller. Tilpass reviewerkrav til antall vedlikeholdere. Aktiver private vulnerability reporting dersom tilgjengelig. CODEOWNERS må eventuelt opprettes med faktiske GitHub-brukernavn/team; ingen eieridentitet er gjettet.

## Release og bruk fra andre apper

Det er ikke opprettet remote, release eller versjonstag av dette oppsettet. Før en release: oppdater CHANGELOG, vurder API-kompatibilitet, kjør CI og verifiser appintegrasjoner som trenger OS-bakgrunnslifecycle. Bruk SemVer og opprett et tag for den faktiske versjonen først når den er godkjent.

Appene legger deretter til den faktiske GitHub-URL-en og velger ønskede produkter i Swift Package Manager. Private repositoryer krever tilgang også på appenes CI-maskiner. Ikke bygg tokens inn i Package.swift eller URL-er. LICENSE følger med distribusjonssjekkens pakkesnapshot. Se [migrering](Migration.md) og [kom i gang](GettingStarted.md).
