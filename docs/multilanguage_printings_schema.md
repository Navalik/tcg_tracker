# Multi-Language / Printing-Aware Schema

Questo documento descrive il modello dati target di BinderVault per supportare:

- piu lingue per lo stesso TCG
- piu printings della stessa carta
- inventario e collection separati per stampa reale

## Concetti

### 1. `card`
Identita concettuale della carta.

Esempi:
- `Black Lotus`
- `Pikachu`

La `card` non rappresenta una copia posseduta e non basta per distinguere lingua, set o collector number.

### 2. `printing`
Stampa concreta della carta.

Una `printing` deve distinguere almeno:
- gioco
- set
- collector number
- lingua
- eventuale variante editoriale necessaria

Esempi:
- `Pikachu Base Set EN`
- `Pikachu Base Set IT`
- `Black Lotus Alpha EN`

### 3. `localization`
Testi localizzati associati a card o set.

Serve per:
- nome carta
- testo regole
- subtype line
- nome set

## Regola Chiave

L'inventario e le collection devono puntare a `printing_id`, non a `card_id`.

Questo significa che:
- stessa carta in lingue diverse = oggetti distinti
- stessa carta in set diversi = oggetti distinti
- UI puo raggruppare, ma il dato non va fuso

## Schema Target

### `catalog_cards`
Identita concettuale della carta.

Campi principali:
- `id` PK
- `game_id`
- `canonical_name`
- `sort_name`
- `default_language`
- `metadata_json`
- `created_at_ms`
- `updated_at_ms`

Note:
- un record per carta concettuale
- non distingue set o lingua della printing

### `catalog_sets`
Identita del set.

Campi principali:
- `id` PK
- `game_id`
- `code`
- `canonical_name`
- `series_id`
- `release_date`
- `metadata_json`
- `created_at_ms`
- `updated_at_ms`

### `card_printings`
Stampa concreta e unita primaria per possesso/collection.

Campi attuali / target:
- `id` PK
- `game_id`
- `card_id` FK -> `catalog_cards.id`
- `set_id` FK -> `catalog_sets.id`
- `collector_number`
- `language_code`
- `rarity`
- `release_date`
- `image_uris_json`
- `finish_keys_json`
- `metadata_json`
- `created_at_ms`
- `updated_at_ms`

Vincolo logico desiderato:
- una riga per ogni stampa reale
- `language_code` deve far parte dell'identita della printing

### `catalog_card_localizations`
Testi carta per lingua.

Campi:
- `card_id`
- `language_code`
- `name`
- `subtype_line`
- `rules_text`
- `flavor_text`
- `search_aliases_json`
- `updated_at_ms`

PK:
- `(card_id, language_code)`

### `catalog_set_localizations`
Testi set per lingua.

Campi:
- `set_id`
- `language_code`
- `name`
- `series_name`
- `updated_at_ms`

PK:
- `(set_id, language_code)`

### `provider_mappings`
Bridge tra oggetti provider esterni e oggetti canonici interni.

Campi:
- `id` PK
- `game_id`
- `provider_id`
- `object_type`
- `provider_object_id`
- `provider_object_version`
- `card_id`
- `printing_id`
- `set_id`
- `mapping_confidence`
- `mapping_source`
- `payload_hash`
- `created_at_ms`
- `updated_at_ms`

Uso:
- collegare Scryfall / TCGdex / legacy rows agli oggetti canonici

### `price_snapshots`
Storico prezzi per printing.

Campi:
- `id` PK
- `printing_id`
- `source_id`
- `currency_code`
- `amount`
- `finish_key`
- `captured_at_ms`

### `collection_cards`
Inventario e membership utente.

Campi legacy/transizione:
- `collection_id`
- `card_id`
- `printing_id`
- `quantity`
- `foil`
- `alt_art`

Direzione target:
- `printing_id` sorgente primaria
- `card_id` solo campo di compatibilita temporanea

## Relazioni

```text
catalog_cards 1 --- N card_printings
catalog_sets  1 --- N card_printings

catalog_cards 1 --- N catalog_card_localizations
catalog_sets  1 --- N catalog_set_localizations

card_printings 1 --- N price_snapshots
card_printings 1 --- N provider_mappings

collections 1 --- N collection_cards
card_printings 1 --- N collection_cards
```

## Comportamento Applicativo

### Ricerca
- cerca sulle printings
- puo filtrare per `language_code`
- puo raggruppare in UI per `card_id`

### Set Collection
- di default include tutte le printings delle lingue abilitate
- puo filtrare per lingua

### Smart Collection
- `languages` e filtro di primo livello
- il conteggio va fatto sulle printings, non sulle card astratte

### Inventario
- possesso riferito a `printing_id`
- quantita separate per lingua e set

## Stato Audit Attuale

### Magic
Stato attuale: quasi allineato.

- `printingId` deriva da `scryfall id`
- questo e gia molto vicino a "una printing reale = un id univoco"
- il modello e compatibile con la distinzione per lingua

### Pokemon
Stato attuale: non ancora allineato al target.

- il catalogo canonico TCGdex oggi costruisce una sola printing per `providerObjectId`
- le localizzazioni sono attaccate come `LocalizedCardData`
- quindi oggi la lingua non e ancora parte forte dell'identita della printing

Conseguenza:
- `pokemon:printing:tcgdex:<id>` non garantisce ancora separazione `EN` / `IT`

## Refactor Necessario Su Pokemon

Per allineare Pokemon al modello target servono questi passaggi:

1. introdurre `language_code` esplicito in `card_printings`
2. generare printings distinte per lingua nel pipeline canonico
3. tenere `provider_mappings` legacy solo dove la mappatura resta univoca
4. portare la UI a passare `printing_id` esplicito invece di ricostruirlo dal vecchio `card_id`

## Esempio

Carta concettuale:
- `pokemon:card:pikachu-base`

Printings:
- `pokemon:printing:base:pikachu:en`
- `pokemon:printing:base:pikachu:it`

Collection:
- `collection_cards(collection_id=1, printing_id=...:en, quantity=2)`
- `collection_cards(collection_id=1, printing_id=...:it, quantity=1)`

La UI puo mostrare:
- 3 copie totali di Pikachu

Ma il database conserva:
- 2 EN
- 1 IT
