# Backend Catalog Project Plan

## Obiettivo

Spostare progressivamente BinderVault da un'app che parla direttamente con provider esterni a un sistema in cui l'app scarica pacchetti BinderVault versionati, verificabili e compatibili con il database locale.

Il backend deve diventare il punto in cui:
- si recuperano dati da provider esterni come Scryfall e TCGdex;
- si normalizzano i dati nel modello canonico BinderVault;
- si generano manifest e artifact scaricabili dall'app;
- si prepara una futura API per catalogo web, ricerca, dettaglio carta, set e prezzi.

Il requisito principale dell'app mobile resta offline-first:
- l'app non deve chiamare il backend per ogni ricerca o dettaglio carta;
- l'app deve continuare a usare il database locale;
- gli aggiornamenti arrivano tramite snapshot o pacchetti versionati.

Il sito web ha requisiti diversi:
- puo interrogare API backend;
- puo usare ricerca live;
- puo avere pagine carta e set condivisibili;
- non deve avere lo stesso vincolo offline-first dell'app mobile.

## Principio Guida

Il contratto stabile deve essere BinderVault, non il formato del provider.

L'app deve dipendere da:
- manifest BinderVault;
- snapshot canonici BinderVault;
- versioni schema e compatibilita;
- hash SHA-256;
- mapping canonici `cardId` e `printingId`.

L'app non dovrebbe dipendere a lungo termine da:
- URL GitHub Release;
- payload raw Scryfall;
- payload raw TCGdex;
- regole di rate limit dei provider;
- fallback specifici dei provider.

## Stato Attuale

Cloud e servizi gia presenti:
- Firebase Functions;
- Firebase Storage;
- Firebase Authentication;
- Firebase custom claims per entitlement Plus;
- Firebase Storage rules per backup utente Plus.

Componenti gia presenti nel repo:
- `functions/`: Firebase Functions attuali, oggi usate per entitlement Google Play;
- `storage.rules`: regole Storage, oggi limitate ai backup utente;
- `bindervault-site/`: sito statico pubblico esistente;
- `tools/build_pokemon_bundle.py`: genera bundle Pokemon offline;
- `tools/publish_pokemon_bundle_release.ps1`: pubblica bundle Pokemon su GitHub Release;
- `lib/services/pokemon_bulk_service.dart`: scarica manifest e bundle Pokemon da GitHub Release;
- `lib/db/canonical_catalog_store.dart`: storage canonico locale;
- `lib/providers/provider_contracts.dart`: contratti provider lato app.

Dipendenze esterne ancora lato app:
- Pokemon scarica da GitHub Release;
- MTG usa ancora Scryfall per bulk, lookup, search, scanner e prezzi;
- ci sono ancora URL `api.scryfall.com` nel codice app.

## Direzione Architetturale

La direzione target resta questa:

```text
Provider esterni
  Scryfall
  TCGdex
        |
        v
Backend ingestion / builder
  fetch raw data
  normalize
  validate
  map provider ids
        |
        v
Artifact BinderVault
  manifest.json
  canonical_catalog_snapshot.json.gz
  optional legacy db snapshot
  optional price snapshots
        |
        v
Firebase Storage
  versioned releases
  latest manifest
        |
        v
App Flutter
  check manifest
  download artifacts
  verify sha256
  import local DB
  search offline
```

Per il web catalog, quando diventera una feature reale:

```text
PostgreSQL / search index
        |
        v
Cloud Run API
  search cards
  card detail
  set pages
        |
        v
Web catalog
  search
  card pages
  set pages
  sharing / SEO
```

## Strategia Pragmatica

Non conviene attivare subito tutto lo stack backend.

La sequenza consigliata e:

1. Spostare Pokemon da GitHub Release a Firebase Storage.
2. Rendere generico il contratto manifest/artifact.
3. Estrarre un download layer riusabile nell'app.
4. Usare lo stesso meccanismo per MTG.
5. Solo dopo introdurre DB centrale e API web catalog.

Questo permette di ridurre subito le dipendenze runtime senza pagare complessita infrastrutturale prematura.

## Architettura MVP

Per il primo milestone servono solo:
- Firebase Storage;
- manifest versionato;
- artifact compressi;
- script di pubblicazione;
- piccola modifica nell'app Flutter.

Non servono subito:
- Cloud SQL;
- Cloud Run API;
- Firestore;
- Supabase;
- motore search dedicato;
- sync multi-device;
- API pubbliche.

### Storage Layout MVP

Layout consigliato:

```text
catalog/
  pokemon/
    latest/
      manifest.json
    releases/
      20260416-full-en-it/
        manifest.json
        canonical_catalog_snapshot_en.json.gz
        canonical_catalog_snapshot_it.json.gz
        pokemon_legacy_en.db.gz
        pokemon_legacy_it.db.gz
```

Regole:
- i file in `releases/{version}` sono immutabili;
- `latest/manifest.json` puo cambiare e punta all'ultima release stabile;
- l'app scarica sempre prima `latest/manifest.json`;
- l'app verifica sempre `sha256` e `size_bytes` prima di importare.

### Cache E CDN MVP

`latest/manifest.json` e mutabile, gli artifact in `releases/{version}` no.

Regole cache:
- `catalog/{game}/latest/manifest.json` deve avere cache breve o disabilitata;
- gli artifact in `catalog/{game}/releases/{version}/` possono avere cache lunga;
- una nuova release deve usare una nuova `version`, non sovrascrivere artifact esistenti;
- l'app deve tollerare che `latest/manifest.json` sia temporaneamente cacheato e riprovare piu tardi;
- rollback e hotfix avvengono aggiornando `latest/manifest.json`, non cambiando gli artifact versionati.

Header consigliati:

```text
latest/manifest.json
  Cache-Control: no-cache, max-age=0

releases/{version}/...
  Cache-Control: public, max-age=31536000, immutable
```

Se Firebase Storage o il client non permettono subito un controllo fine degli header, la regola funzionale resta:
- trattare `latest/manifest.json` come puntatore volatile;
- trattare ogni file in `releases/{version}` come contenuto immutabile.

### Manifest Contract MVP

Il manifest deve essere semplice e stabile.

Campi obbligatori:

```json
{
  "bundle": "pokemon",
  "version": "20260416-full-en-it",
  "schema_version": 2,
  "compatibility_version": 2,
  "generated_at": "2026-04-16T08:00:00Z",
  "source": {
    "provider": "tcgdex",
    "kind": "api",
    "ref": null,
    "commit": null
  },
  "bundles": [
    {
      "id": "bundle_en",
      "kind": "bundle",
      "profile": "full",
      "languages": ["en"],
      "requires": [],
      "counts": {
        "printings": 10000,
        "canonical_cards": 10000,
        "canonical_sets": 100
      },
      "artifacts": [
        {
          "name": "canonical_catalog_snapshot_en.json.gz",
          "path": "catalog/pokemon/releases/20260416-full-en-it/canonical_catalog_snapshot_en.json.gz",
          "download_url": "https://...",
          "size_bytes": 12345678,
          "sha256": "..."
        }
      ]
    }
  ]
}
```

Decisione MVP:
- includere `download_url` negli artifact per minimizzare logica client;
- mantenere `path` per audit, diagnostica e migrazioni future;
- evitare endpoint HTTP custom finche Storage basta.

### Naming E Versioning MVP

La `version` del bundle deve essere stabile, leggibile e ordinabile.

Formato ufficiale:

```text
YYYYMMDD-profile-lang
```

Esempi:

```text
20260416-full-en
20260416-full-it
20260416-full-en-it
20260416-full-en-it-r2
```

Regole:
- `YYYYMMDD` e la data di generazione o pubblicazione della release;
- `profile` identifica il contenuto, per ora `full`;
- `lang` usa codici lingua lowercase separati da `-`;
- se nello stesso giorno serve una correzione, aggiungere suffisso `-r2`, `-r3`;
- non riutilizzare mai una `version` gia pubblicata;
- il nome della directory in `releases/{version}` deve coincidere con il campo `version` del manifest;
- il client deve confrontare le versioni come stringhe opache, non dedurre semantica dalla data.

La semantica vera resta nei campi del manifest:
- `schema_version`;
- `compatibility_version`;
- `profile`;
- `languages`;
- `generated_at`;
- `source`.

### Storage Rules MVP

Oggi `storage.rules` protegge solo i backup utente.

Per gli artifact catalogo serve una decisione esplicita:

Opzione consigliata per MVP:
- artifact catalogo pubblici in lettura;
- scrittura solo da script/admin;
- nessun dato utente dentro `catalog/`.

Regola indicativa:

```text
match /catalog/{allPaths=**} {
  allow read: if true;
  allow write: if false;
}
```

La scrittura deve avvenire tramite strumenti admin, Firebase CLI, service account o pipeline CI, non dal client mobile.

### Publisher MVP

Creare uno script dedicato:

```text
tools/publish_catalog_bundle_firebase.ps1
```

Responsabilita:
- validare che esistano manifest e artifact;
- caricare artifact in `catalog/pokemon/releases/{version}/`;
- aggiornare `catalog/pokemon/latest/manifest.json`;
- opzionalmente verificare download e hash dopo upload.

Per la prima versione puo essere manuale da PC locale.

Automazione CI o Cloud Run Jobs vengono dopo.

### Ownership E Operativita MVP

Per evitare release ambigue, la pubblicazione dei bundle deve avere una ownership esplicita.

Regole operative:
- il bundle viene generato da una macchina developer autorizzata oppure da una pipeline CI dedicata;
- la pubblicazione usa Firebase CLI o service account con permessi limitati allo Storage del progetto;
- le credenziali non devono essere committate nel repo;
- solo chi ha accesso al progetto Firebase puo aggiornare `catalog/{game}/latest/manifest.json`;
- ogni pubblicazione deve annotare versione, data, sorgente dati e hash degli artifact.

Checklist pre-pubblicazione:
- build bundle completata senza errori;
- `manifest.json` valido;
- `compatibility_version` supportata dall'app;
- tutti gli artifact referenziati dal manifest esistono;
- `size_bytes` e `sha256` calcolati;
- `download_url` generati o aggiornati;
- install locale testata almeno una volta se il formato cambia.

Checklist post-pubblicazione:
- `latest/manifest.json` scaricabile;
- ogni `download_url` scaricabile;
- hash remoto uguale a quello del manifest;
- install pulita Pokemon completata;
- versione precedente ancora presente in `releases/`;
- eventuale fallback GitHub ancora funzionante finche previsto.

### Modifica App MVP

Primo intervento lato app:
- sostituire URL GitHub hardcoded in `PokemonBulkService`;
- introdurre configurazione centralizzata per manifest catalogo;
- permettere download da Firebase Storage;
- mantenere GitHub Release come fallback temporaneo;
- aggiornare messaggi UI che citano GitHub;
- lasciare invariato l'import locale.

Posizione consigliata:

```text
lib/services/tcg_environment.dart
lib/services/catalog_manifest.dart
lib/services/catalog_bundle_service.dart
```

Per il primo step si puo anche fare una modifica piu piccola:
- aggiungere `pokemonManifestUrl` centralizzato;
- riusare la logica esistente in `PokemonBulkService`;
- estrarre il servizio generico nella fase successiva.

### Rollback MVP

`latest/manifest.json` e l'unico puntatore mutabile.

Se una release e rotta:
- non modificare i file gia pubblicati in `releases/{version}`;
- ripubblicare `catalog/{game}/latest/manifest.json` facendolo puntare all'ultima release valida;
- verificare che l'app scarichi il manifest corretto dopo cache refresh;
- conservare la release rotta per analisi oppure marcarla come non valida in documentazione/release notes interne;
- pubblicare una nuova release correttiva con una nuova `version`, non sovrascrivere quella rotta.

Regola:
- rollback significa cambiare solo `latest/manifest.json`;
- una release versionata resta immutabile anche se contiene un errore.

## Roadmap Operativa

### Fase 1 - Pokemon Su Firebase Storage

Obiettivo:
- sostituire GitHub Release come host principale dei bundle Pokemon.

Task:
- definire path Storage `catalog/pokemon/releases/{version}`;
- aggiornare o adattare il manifest per includere `download_url`;
- creare `tools/publish_catalog_bundle_firebase.ps1`;
- aggiornare `storage.rules` per lettura pubblica di `catalog/`;
- pubblicare una release Pokemon su Firebase Storage;
- modificare `PokemonBulkService` per leggere il nuovo manifest;
- mantenere GitHub Release come fallback temporaneo;
- testare install pulita e aggiornamento.

Regola obbligatoria sul fallback:
- GitHub Release resta disponibile per una sola release mobile dopo il passaggio a Firebase Storage;
- durante quella release l'app prova Firebase Storage come fonte primaria e GitHub solo come fallback;
- dalla release mobile successiva il fallback GitHub deve essere rimosso dal codice;
- nuove feature non devono aggiungere altra logica dipendente da GitHub Release.

Criteri di successo:
- Pokemon si installa da Firebase Storage;
- hash SHA-256 viene verificato;
- una release precedente resta scaricabile;
- `latest/manifest.json` puo cambiare senza aggiornare l'app;
- il codice non dipende piu solo da GitHub Release.

### Fase 2 - Manifest E Download Layer Generici

Obiettivo:
- rendere il download cataloghi riusabile per Pokemon e MTG.

Task:
- creare parser manifest generico;
- creare servizio download artifact con verifica hash;
- spostare logica comune fuori da `PokemonBulkService`;
- mantenere import specifico Pokemon separato;
- aggiungere test del parser manifest;
- documentare compatibilita manifest.

Criteri di successo:
- Pokemon continua a funzionare;
- il codice per scaricare artifact non e Pokemon-specific;
- MTG puo riusare lo stesso layer.

### Fase 3 - MTG Snapshot Da Backend/Builder

Obiettivo:
- iniziare a spostare MTG fuori dal runtime Scryfall lato app.

Task:
- creare builder MTG locale partendo da Scryfall bulk;
- generare snapshot canonico BinderVault;
- preservare mapping da Scryfall ID legacy;
- pubblicare artifact MTG su Firebase Storage;
- aggiungere manifest MTG;
- aggiungere download/import MTG nell'app;
- mantenere fallback Scryfall temporaneo.

Criteri di successo:
- MTG puo installare un catalogo da artifact BinderVault;
- Scryfall resta necessario solo per builder/fallback;
- il runtime app riduce le chiamate dirette a Scryfall.

### Fase 4 - Backend Centrale

Da fare solo quando servono davvero API web, ricerca server-side o ingestion automatica.

Componenti consigliati:
- Cloud Run API;
- Cloud Run Jobs;
- Cloud SQL PostgreSQL;
- Cloud Scheduler;
- Secret Manager;
- Artifact Registry;
- Firebase Storage per artifact.

Responsabilita:
- ingestion provider;
- normalizzazione nel DB canonico;
- generazione artifact mobile;
- API catalogo web;
- ricerca e dettaglio carta;
- set pages;
- prezzi come dominio separato.

Non attivare questa fase solo per spostare Pokemon da GitHub a Firebase Storage.

### Fase 5 - Web Catalog

Obiettivo:
- creare catalogo consultabile da browser.

Task:
- creare `web-catalog/`;
- creare endpoint search e detail;
- definire URL permanenti per carte e set;
- pubblicare su Firebase Hosting;
- aggiungere Open Graph base;
- valutare SEO/SSR/static generation solo dopo il primo MVP.

Nota:
- una webapp catalogo ha bisogno di dati interrogabili;
- file `.json.gz` grandi vanno bene per app mobile, non come unica sorgente del web catalog.

### Fase 6 - Prezzi

Obiettivo:
- separare prezzi dal catalogo.

Task:
- creare artifact prezzi separati;
- definire TTL;
- generare snapshot piccoli e frequenti;
- evitare rigenerazione catalogo per refresh prezzi;
- esporre prezzi in app e web tramite dominio dedicato.

Layout indicativo:

```text
catalog/
  prices/
    mtg/
      latest/
        manifest.json
      releases/
        20260416-eur/
          prices_eur.json.gz
```

## Target Infrastrutturale Futuro

Quando il backend centrale diventa necessario, la scelta piu coerente con lo stack attuale e:

```text
Firebase Hosting
  sito pubblico e webapp

Firebase Auth
  account utenti

Firebase Storage
  pacchetti mobile, immagini proprie, export, backup

Cloud Run API
  API catalogo web
  API future per collezioni/deck
  API amministrative leggere

Cloud Run Jobs
  ingestion provider
  build cataloghi
  build snapshot mobile
  refresh prezzi

Cloud SQL PostgreSQL
  DB canonico centrale
  provider mappings
  catalogo interrogabile
  collezioni/deck multi-device future

Cloud Scheduler
  avvio job periodici

Secret Manager
  chiavi provider e configurazione sensibile
```

### Perche PostgreSQL

PostgreSQL e la scelta naturale per:
- carte;
- stampe;
- set;
- localizzazioni;
- provider mappings;
- prezzi;
- deck;
- collezioni multi-device future;
- query e filtri complessi.

Firestore puo essere utile per audit leggero, dashboard o dati Firebase-centrici, ma non dovrebbe diventare il catalogo canonico principale.

### Perche Non Una VM

Una VM manuale con PostgreSQL richiede gestione diretta di:
- patch sicurezza;
- backup;
- restore;
- firewall;
- monitoring;
- aggiornamenti PostgreSQL;
- disco;
- hardening.

Meglio usare servizi gestiti quando si arriva a questa fase.

### Supabase

Supabase resta una alternativa valida se si vuole Postgres gestito rapidamente.

Nel contesto BinderVault, pero:
- Firebase Auth e gia presente;
- Firebase Functions gestisce entitlement Google Play;
- Firebase Storage e gia usato per backup;
- aggiungere Supabase significa gestire due ecosistemi.

Raccomandazione:
- non introdurre Supabase nel MVP catalog artifact;
- rivalutarlo solo quando si decide davvero il DB centrale;
- se viene scelto, usare Supabase come Postgres server-side e non duplicare Auth utenti finali nella stessa fase.

## Budget

Per il solo MVP Firebase Storage:
- costo iniziale basso;
- attenzione a traffico download e dimensione artifact;
- configurare budget alert;
- non servire file grossi tramite Functions.

Per il backend centrale futuro:

```text
Cloud SQL PostgreSQL piccolo          25-50 EUR/mese
Cloud Run API                          0-15 EUR/mese iniziali
Cloud Run Jobs                         0-10 EUR/mese iniziali
Firebase Hosting/Storage/Auth          0-20 EUR/mese iniziali
Cloud Scheduler/Secrets/Logging         0-10 EUR/mese iniziali
Margine traffico/download              10-30 EUR/mese
```

Per restare nel budget:
- evitare alta disponibilita Cloud SQL all'inizio;
- configurare budget alert;
- servire artifact direttamente da Storage;
- limitare logging verboso;
- mettere cache HTTP dove possibile;
- usare job schedulati, non processi sempre accesi.

## Decisioni Aperte

Decisioni da prendere subito:

1. Artifact catalogo pubblici o accessibili solo con token?
   - Consiglio MVP: pubblici in lettura, nessun dato utente.

2. Manifest con `download_url` o solo `path` Storage?
   - Consiglio MVP: entrambi, ma il client usa `download_url`.

3. GitHub fallback per quanto tempo?
   - Consiglio: tenerlo per una release, poi rimuoverlo.

4. Estrarre subito `CatalogBundleService`?
   - Consiglio: prima migrazione piccola in `PokemonBulkService`, poi estrazione.

Decisioni da rinviare:

1. Cloud SQL o Supabase.
2. Firestore per audit release.
3. Cloud Run API.
4. Search engine dedicato.
5. Sync multi-device.
6. SEO/SSR del web catalog.

## Prossimo Step Consigliato

Implementare Fase 1.

Checklist concreta:
- aggiungere regola read-only per `catalog/` in `storage.rules`;
- adattare manifest Pokemon con path Storage e `download_url`;
- creare script `tools/publish_catalog_bundle_firebase.ps1`;
- pubblicare un bundle Pokemon su Firebase Storage;
- aggiungere configurazione manifest in app;
- aggiornare `PokemonBulkService` per Firebase Storage;
- lasciare GitHub come fallback temporaneo;
- testare install pulita Pokemon;
- aggiornare documentazione del release flow.

Questo e il passo con miglior rapporto valore/rischio: riduce subito la dipendenza da GitHub Release, valida Firebase Storage come distribution layer e prepara il terreno per MTG senza introdurre ancora un backend complesso.
