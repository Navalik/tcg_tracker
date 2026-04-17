# Pokemon Bundle Release Flow

Questa pipeline riguarda solo **Pokemon**.
**Magic/MTG non viene toccato**.

## Obiettivo

Generare in locale gli artefatti compressi del catalogo Pokemon e pubblicarli
sul canale corretto.

Ci sono due canali separati:

- **Produzione attuale**: GitHub Release, usato dall'app gia pubblicata.
- **Firebase Storage**: canale nuovo per la prossima versione dell'app.

Non mescolare i due flussi. Finche l'app Firebase non e in produzione, gli
aggiornamenti per gli utenti reali vanno pubblicati con lo script prod.

## Prerequisiti

- Python 3.10+ installato.
- Checkout locale della sorgente dati, per esempio `tcgdex/cards-database`.
- Per il canale prod: GitHub CLI (`gh`) autenticata.
- Per il canale Firebase: Google Cloud SDK (`gcloud`) autenticato sul progetto
  Firebase.

## Produzione Attuale

Usa questo script per aggiornare il bundle consumato dall'app attualmente in
produzione:

```powershell
.\tools\prod\release_pokemon_bundle_prod.ps1
```

Questo flusso:

- genera il bundle in `dist/pokemon_bundle`;
- mantiene il versioning storico giornaliero usato dal flusso GitHub;
- pubblica su GitHub Release tramite
  `tools/prod/publish_pokemon_bundle_release.ps1`.

Per forzare una build anche se il check sorgente non vede aggiornamenti:

```powershell
.\tools\prod\release_pokemon_bundle_prod.ps1 -ForceBuild
```

## Firebase Storage

Usa questo script per preparare o pubblicare il bundle destinato alla nuova app
che usera Firebase Storage:

```powershell
.\tools\firebase\release_pokemon_bundle_firebase.ps1
```

Questo flusso:

- genera il bundle in `dist/pokemon_bundle_firebase`;
- usa una versione univoca con timestamp UTC e commit sorgente, ad esempio
  `20260417-071530-full-base-delta-compat2-tcgdex-5b2c205`;
- pubblica su Firebase Storage tramite
  `tools/firebase/publish_catalog_bundle_firebase.ps1`;
- aggiorna `catalog/pokemon/latest/manifest.json`, salvo uso di `-SkipLatest`.

Per provare il publish senza caricare file:

```powershell
.\tools\firebase\release_pokemon_bundle_firebase.ps1 -ForceBuild -DryRunPublish
```

Per pubblicare senza aggiornare il puntatore `latest`:

```powershell
.\tools\firebase\release_pokemon_bundle_firebase.ps1 -SkipLatest
```

## Output

Ogni bundle include:

- snapshot canonici compressi (`canonical_catalog_snapshot*.json.gz`);
- database legacy compressi (`pokemon_legacy*.db.gz`);
- manifest (`manifest.json`, piu manifest per lingua quando il layout lo prevede).

I manifest includono versione, conteggi, hash SHA-256, dimensioni, schema,
compatibilita client e sorgente dati.

## Script Di Basso Livello

La cartella `tools` e divisa cosi:

- `tools/prod`: entrypoint e publish GitHub Release per l'app in produzione.
- `tools/firebase`: entrypoint e publish Firebase Storage per la nuova app.
- `tools/shared`: builder/checker condivisi, usati dagli entrypoint sopra.

Gli script condivisi di norma non vanno lanciati manualmente durante un
rilascio:

- `tools/shared/build_pokemon_bundle.py`: genera gli artefatti.
- `tools/shared/check_pokemon_bundle_updates.py`: confronta sorgente e manifest.

## Note

- Non committare i file grossi direttamente nel repo Git.
- Le release Firebase in `catalog/pokemon/releases/{version}` vanno trattate
  come immutabili.
- Rollback Firebase significa aggiornare solo `catalog/pokemon/latest/manifest.json`
  verso una release valida precedente.
