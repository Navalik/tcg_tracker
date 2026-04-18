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

## Validazione Manifest Locale

Dopo la generazione e prima del publish, validare il contratto del manifest e
gli artifact locali:

```powershell
python .\tools\shared\validate_catalog_manifest.py --manifest .\dist\mtg_bundle_firebase\manifest.json --game mtg --verify-local-artifacts
```

## Verifica Post-Pubblicazione

Dopo un publish reale, verificare che il manifest `latest` e gli artifact
referenziati siano scaricabili e coerenti con `size_bytes` e `sha256`:

```powershell
.\tools\firebase\verify_catalog_bundle_firebase.ps1 -Game mtg
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

Il client usa `catalog/mtg/latest/manifest.json` come fonte del download
runtime. Il bundle viene ricombinato localmente e importato nel database
legacy, quindi la pipeline Firebase sostituisce il download diretto da
Scryfall ma non ancora lo storage locale dell'app.
