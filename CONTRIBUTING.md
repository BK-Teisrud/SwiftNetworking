# Videreutvikling

Koden og dokumentasjonen tilhører Teisrud Development AS. Repositoryet er ikke et åpent kildekodeprosjekt; se [LICENSE](LICENSE). Bidrag og tilgang må være avtalt med selskapet.

Les [arkitekturen](Docs/Architecture.md) før du endrer ansvar mellom modulene. Hold offentlig API lite, beskriv lifecycle og feilkontrakter, og oppdater sentral dokumentasjon i Docs ved atferdsendringer.

Kjør før pull request:

```sh
swift test
xcrun swift-format lint --strict --recursive Package.swift Sources Tests Tools
swift Tools/RepositoryTools.swift sync --check
swift Tools/RepositoryTools.swift distribution
```

Ved dokumentasjonsendringer kjører du først `swift Tools/RepositoryTools.swift sync`. Ved offentlige API-endringer kjører du `swift Tools/RepositoryTools.swift docs`, som også oppdaterer API-referansen. Commit genererte Guides sammen med sentrale artikler. Tester skal bruke fixtures og syntetiske credentials.

Beskriv problemet, ny oppførsel, relevante tester og eventuelle API-/migreringsendringer. CI må være grønn før merge. Endringer i bakgrunnsoverføringer må også verifiseres i en faktisk app på enhet når OS-lifecycle påvirkes.
