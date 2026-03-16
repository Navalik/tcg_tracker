# Pokemon Bundle Release Flow (Local Build)

Questa pipeline riguarda solo **Pokemon**.  
**Magic/MTG non viene toccato**.

## Obiettivo

Generare in locale due artefatti compressi pronti da pubblicare su GitHub Releases:

- `canonical_catalog_snapshot.json.gz`
- `pokemon_legacy.db.gz`

Più un file di controllo:

- `manifest.json` (versione, conteggi, hash SHA-256, dimensioni)

## Prerequisiti

- Python 3.10+ installato
- Checkout locale della sorgente dati (es. `tcgdex/cards-database`)

## Comando

Esegui dalla root progetto:

```powershell
python tools/build_pokemon_bundle.py `
  --source-dir C:\path\to\tcgdex\cards-database `
  --output-dir dist\pokemon_bundle `
  --profile full `
  --languages en,it `
  --version 20260315-full-en-it
```

## Output

Nella cartella `dist/pokemon_bundle` troverai:

- `canonical_catalog_snapshot.json`
- `canonical_catalog_snapshot.json.gz`
- `pokemon_legacy.db`
- `pokemon_legacy.db.gz`
- `manifest.json`

## Pubblicazione consigliata

1. Crea una nuova GitHub Release nel repo pubblico (es. `Navalik/tcg_tracker`).
2. Carica come asset:
   - `canonical_catalog_snapshot.json.gz`
   - `pokemon_legacy.db.gz`
   - `manifest.json`
3. Non committare i file grossi direttamente nel repo Git.

In alternativa usa lo script PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\publish_pokemon_bundle_release.ps1 `
  -Repo "Navalik/tcg_tracker" `
  -Tag "pokemon-bundle-20260315" `
  -Title "Pokemon bundle 2026-03-15" `
  -Notes "Offline Pokemon bundle (full, en+it)"
```

## Note

- Lo script è pensato come soluzione ponte fino al backend.
- `manifest.json` include hash SHA-256 per verifica integrità download lato app.
