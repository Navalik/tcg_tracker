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
- `storage.rules`: regole Storage per cataloghi pubblici in lettura e backup utente Plus;
- `bindervault-site/`: sito statico pubblico esistente;
- `tools/shared/build_pokemon_bundle.py`: genera bundle Pokemon offline;
- `tools/shared/build_mtg_bundle.py`: genera bundle MTG da Scryfall bulk;
- `tools/prod/publish_pokemon_bundle_release.ps1`: pubblica bundle Pokemon su GitHub Release;
- `tools/firebase/publish_catalog_bundle_firebase.ps1`: pubblica bundle catalogo su Firebase Storage;
- `tools/firebase/release_pokemon_bundle_firebase.ps1`: genera e pubblica bundle Pokemon Firebase;
- `tools/firebase/release_mtg_bundle_firebase.ps1`: genera e pubblica bundle MTG Firebase;
- `lib/services/pokemon_bulk_service.dart`: scarica manifest e bundle Pokemon da Firebase Storage;
- `lib/parts/scryfall_bulk.dart`: scarica manifest e artifact MTG da Firebase Storage e li importa nel DB locale legacy;
- `lib/db/canonical_catalog_store.dart`: storage canonico locale;
- `lib/providers/provider_contracts.dart`: contratti provider lato app.

Dipendenze esterne ancora lato app:
- Pokemon usa Firebase Storage come fonte catalogo per la nuova app;
- MTG usa Firebase Storage come fonte catalogo per la nuova app;
- Pokemon GitHub Release resta solo canale della produzione precedente finche non viene sostituita dalla release mobile Firebase;
- MTG puo avere ancora fallback/lookup runtime Scryfall in flussi non migrati;
- prezzi MTG restano orientati a Scryfall/provider legacy;
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

La sequenza consigliata era:

1. Spostare Pokemon da GitHub Release a Firebase Storage.
2. Rendere generico il contratto manifest/artifact.
3. Estrarre un download layer riusabile nell'app.
4. Usare lo stesso meccanismo per MTG.
5. Solo dopo introdurre DB centrale e API web catalog.

Stato aggiornato:
- Pokemon e stato spostato su Firebase Storage per la nuova app.
- MTG e stato aggiunto a Firebase Storage con bundle `base_en` + `delta_it`.
- Il contratto manifest/artifact e gia molto simile tra i due giochi, ma non e ancora espresso in un parser/verifier unico.
- Il download layer nell'app resta parzialmente duplicato tra Pokemon e MTG.
- DB centrale e API web catalog restano fuori scope per il momento.

Questo mantiene basso il rischio infrastrutturale: Firebase Storage distribuisce
i cataloghi versionati, mentre l'app resta offline-first e importa nei database
locali esistenti.

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
  mtg/
    latest/
      manifest.json
    releases/
      20260417T0920027840000-full-base-delta-compat1/
        manifest.json
        mtg_base_en.json.gz
        mtg_delta_it.json.gz
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
tools/firebase/publish_catalog_bundle_firebase.ps1
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
- install pulita completata per il gioco pubblicato;
- versione precedente ancora presente in `releases/`;
- eventuale fallback GitHub ancora funzionante finche previsto.

### Compatibilita App Pubblicata E Dati Utente

Il progetto catalogo non deve rompere l'app gia installata dagli utenti e non
deve mettere a rischio database locali, collezioni, wishlist o deck.

Regole obbligatorie:
- non rimuovere o sovrascrivere gli artifact usati dalla produzione corrente;
- non rimuovere il canale GitHub Pokemon finche la release mobile Firebase non
  ha sostituito la produzione precedente;
- trattare Firebase Storage `catalog/{game}/releases/{version}` come
  append-only;
- aggiornare solo `latest/manifest.json` per promozione o rollback;
- non cambiare nomi file DB locali, schema o identita carte senza una
  migrazione versionata e testata;
- prima di ogni migrazione distruttiva, creare backup locale delle collezioni;
- i bundle catalogo possono aggiornare carte e set, ma non devono cancellare o
  riscrivere direttamente dati utente;
- ogni release candidata deve passare almeno verifier catalogo e test di
  install/reimport su un profilo con collezioni esistenti.

Il verifier Firebase e read-only: scarica manifest e artifact pubblicati e ne
controlla integrita. Non modifica Storage, database locali o dati utente.

### Modifica App MVP

Stato lato app:
- Pokemon scarica da Firebase Storage tramite `PokemonBulkService`;
- MTG scarica da Firebase Storage tramite `MtgHostedBundleService`;
- l'import locale resta invariato e continua a usare i database locali esistenti;
- il download layer non e ancora generico;
- il fallback GitHub resta solo legato alla produzione Pokemon precedente.

Posizione consigliata per la prossima estrazione:

```text
lib/services/tcg_environment.dart
lib/services/catalog_manifest.dart
lib/services/catalog_bundle_service.dart
```

La prossima modifica app non deve cambiare il formato locale: deve solo
spostare parsing manifest, selezione bundle, download, size check e SHA-256 in
un servizio comune usato da Pokemon e MTG.

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

Stato:
- completata per la nuova app Firebase;
- il canale GitHub Release resta solo per la produzione precedente finche serve;
- i manifest Firebase includono `download_url`, `path`, `size_bytes` e `sha256`;
- il client Pokemon legge `catalog/pokemon/latest/manifest.json`.

Task:
- definire path Storage `catalog/pokemon/releases/{version}`; **done**
- aggiornare o adattare il manifest per includere `download_url`; **done**
- creare `tools/firebase/publish_catalog_bundle_firebase.ps1`; **done**
- aggiornare `storage.rules` per lettura pubblica di `catalog/`; **done**
- pubblicare una release Pokemon su Firebase Storage; **done**
- modificare `PokemonBulkService` per leggere il nuovo manifest; **done**
- mantenere GitHub Release come fallback temporaneo;
- testare install pulita e aggiornamento su build release candidata.

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
- creare verifier post-pubblicazione per manifest e artifact Firebase;
- creare parser manifest generico;
- creare servizio download artifact con verifica hash;
- spostare logica comune fuori da `PokemonBulkService` e `MtgHostedBundleService`;
- mantenere import specifici Pokemon e MTG separati;
- aggiungere test del parser manifest;
- documentare compatibilita manifest.

Criteri di successo:
- Pokemon continua a funzionare;
- MTG continua a funzionare;
- il codice per scaricare e verificare artifact non e specifico di un gioco;
- un comando locale puo verificare `latest/manifest.json`, `download_url`, `size_bytes` e `sha256` per ogni gioco.

### Fase 3 - MTG Snapshot Da Backend/Builder

Obiettivo:
- iniziare a spostare MTG fuori dal runtime Scryfall lato app.

Stato:
- parzialmente completata;
- esiste `tools/shared/build_mtg_bundle.py`;
- esiste `tools/firebase/release_mtg_bundle_firebase.ps1`;
- Firebase Storage espone `catalog/mtg/latest/manifest.json`;
- il client usa `MtgHostedBundleService` per scaricare `base_en` e `delta_it`, ricombinarli e importarli nel DB locale legacy;
- MTG non e ancora uno snapshot canonico BinderVault completo: gli artifact mantengono forma compatibile Scryfall compattata.

Task:
- creare builder MTG locale partendo da Scryfall bulk; **done**
- generare snapshot compatibile BinderVault/Scryfall compattato; **done**
- preservare mapping da Scryfall ID legacy; **implicitamente preservato tramite `id` Scryfall, da formalizzare come mapping canonico**
- pubblicare artifact MTG su Firebase Storage; **done**
- aggiungere manifest MTG; **done**
- aggiungere download/import MTG nell'app; **done**
- generare snapshot canonico MTG vero;
- mantenere fallback Scryfall temporaneo.

Criteri di successo:
- MTG puo installare un catalogo da artifact Firebase;
- Scryfall resta necessario per builder e per eventuali flussi runtime non ancora migrati;
- il runtime app riduce le chiamate dirette a Scryfall per il bulk catalogo.

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

Non attivare questa fase solo per distribuire cataloghi mobile da Firebase
Storage: Pokemon e MTG sono gia coperti dal modello artifact/manifest. Cloud
Run e Cloud SQL diventano utili quando servono API web, ricerca server-side,
ingestion automatica o un catalogo centrale interrogabile.

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
   - Decisione MVP: pubblici in lettura, nessun dato utente.

2. Manifest con `download_url` o solo `path` Storage?
   - Decisione MVP: entrambi, ma il client usa `download_url`.

3. GitHub fallback per quanto tempo?
   - Decisione operativa: tenerlo solo finche la produzione Pokemon precedente non viene sostituita dalla release mobile Firebase.

4. Estrarre subito `CatalogBundleService`?
   - Prossima decisione tecnica: si, dopo aver aggiunto un verifier post-pubblicazione e test del manifest contract.

Decisioni da rinviare:

1. Cloud SQL o Supabase.
2. Firestore per audit release.
3. Cloud Run API.
4. Search engine dedicato.
5. Sync multi-device.
6. SEO/SSR del web catalog.

## Prossimo Step Consigliato

Implementare la parte operativa della Fase 2: verifier post-pubblicazione e
contratto manifest condiviso.

Checklist concreta:
- creare `tools/firebase/verify_catalog_bundle_firebase.ps1`;
- supportare almeno `-Game pokemon` e `-Game mtg`;
- scaricare `catalog/{game}/latest/manifest.json`;
- validare JSON, `bundle`, `version`, `schema_version`, `compatibility_version` e lista `bundles`;
- per ogni artifact verificare `download_url`, `size_bytes` e `sha256`;
- fallire con messaggio chiaro se un artifact manca o non corrisponde;
- documentare il comando nei release flow Pokemon e MTG;
- poi estrarre parser/downloader condiviso nell'app.

Questo e il passo con miglior rapporto valore/rischio adesso: Pokemon e MTG
sono gia distribuiti da Firebase Storage, quindi serve una garanzia automatica
che ogni publish sia scaricabile e coerente prima di costruire ulteriore
backend.
