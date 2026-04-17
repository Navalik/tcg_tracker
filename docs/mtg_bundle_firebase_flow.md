# MTG Bundle Firebase Flow

Questa pipeline prepara un bundle Magic intermedio su Firebase Storage.
Non sostituisce ancora un database centralizzato: sposta solo il download
runtime da Scryfall al nostro catalogo versionato.

## Obiettivo

Scaricare il bulk Scryfall `all_cards` solo quando cambia, filtrare le lingue
supportate e pubblicare artifact compatti su Firebase Storage.

Lingue MVP:

- `en`: base completa/canonica.
- `it`: delta localizzato dove Scryfall ha stampe italiane.

## Comando

```powershell
.\tools\firebase\release_mtg_bundle_firebase.ps1
```

Per generare senza pubblicare:

```powershell
.\tools\firebase\release_mtg_bundle_firebase.ps1 -SkipPublish
```

Per provare il publish senza caricare file:

```powershell
.\tools\firebase\release_mtg_bundle_firebase.ps1 -DryRunPublish
```

Per forzare riscaricamento del bulk Scryfall:

```powershell
.\tools\firebase\release_mtg_bundle_firebase.ps1 -ForceDownload -ForceBuild
```

## Output

```text
dist/mtg_bundle_firebase/
  mtg_base_en.json.gz
  mtg_delta_it.json.gz
  manifest.json
```

Pubblicazione Firebase:

```text
catalog/mtg/releases/{version}/
catalog/mtg/latest/manifest.json
```

## Compatibilita

Gli artifact contengono array JSON di carte Scryfall compattate. Una volta
decompressi, mantengono la forma dati gia usata dall'importer Magic attuale.

Il client non e ancora stato spostato su questo bundle. La produzione attuale
puo continuare a usare Scryfall direttamente finche la nuova app non integra
`catalog/mtg/latest/manifest.json`.
