# Tools

Usa solo gli entrypoint nelle cartelle di canale.

## Produzione Attuale

Pubblica il bundle Pokemon su GitHub Release, usato dall'app gia in produzione:

```powershell
.\tools\prod\release_pokemon_bundle_prod.ps1
```

## Firebase

Pubblica il bundle Pokemon su Firebase Storage, usato dalla nuova app:

```powershell
.\tools\firebase\release_pokemon_bundle_firebase.ps1
```

Prepara/pubblica il bundle Magic da Scryfall `all_cards`, filtrato EN/IT:

```powershell
.\tools\firebase\release_mtg_bundle_firebase.ps1
```

## Shared

`tools/shared` contiene builder e checker comuni. Non e un canale di rilascio.
