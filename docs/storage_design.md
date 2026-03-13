# Storage Design

## Purpose

This document defines the target canonical storage design for the multi-TCG refactor.

It is based on:
- [architecture_decisions.md](c:/Users/Naval/Documents/TGC/tcg_tracker/docs/architecture_decisions.md)
- [language_strategy.md](c:/Users/Naval/Documents/TGC/tcg_tracker/docs/language_strategy.md)
- [provider_identity_strategy.md](c:/Users/Naval/Documents/TGC/tcg_tracker/docs/provider_identity_strategy.md)
- [domain_models.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/domain/domain_models.dart)

It is intentionally independent from the current `cards` table design.

## Goals

The target storage must:
- be provider-agnostic
- support multiple games
- support multilingual local data
- separate canonical card identity from printing identity
- support provider mappings explicitly
- preserve collection semantics during migration
- allow game-specific metadata without collapsing everything into one universal row

## Current Problem To Solve

Today both MTG and Pokemon are forced into a single broad `cards` table.

That creates these structural problems:
- card identity and printing identity are collapsed
- language is stored at row level in a provider-shaped way
- prices are attached directly to generic card rows
- provider ids are effectively treated as app ids
- Pokemon metadata is compressed into MTG-oriented columns and ad hoc JSON

## Canonical Storage Overview

The target schema should be centered on these groups:

### Core catalog

- `games`
- `catalog_cards`
- `catalog_sets`
- `card_printings`

### Localizations

- `catalog_card_localizations`
- `catalog_set_localizations`

### Provider mappings

- `provider_mappings`

### Game-specific metadata

- `pokemon_printing_metadata`

### Search support

- `card_search_documents`
- optional auxiliary filter tables later if needed

### Prices

- `price_snapshots`

### Collections

- `collections`
- `collection_memberships`
- `collection_inventory`

### Migration safety

- `migration_backups`
- `migration_id_mapping_audit`
- `migration_failures`

## Physical DB Strategy

Short-to-medium term recommendation:
- keep one physical DB file per game during transition if that reduces rollout risk
- but use the same canonical schema shape across games

Long-term recommendation:
- one canonical schema, capable of holding multiple games in one DB if desired

Reason:
- current runtime already depends on per-game DB switching
- changing both schema model and DB topology in one step is unnecessary risk

## Table Design

### `games`

Purpose:
- stable registry of game identities inside storage

Columns:
- `id` TEXT PK
- `display_name` TEXT NOT NULL
- `capabilities_json` TEXT NOT NULL
- `created_at_ms` INTEGER NOT NULL

Notes:
- keeps DB self-describing
- capability snapshot is useful for diagnostics, not the source of truth

### `catalog_cards`

Purpose:
- canonical card identity per game

Columns:
- `id` TEXT PK
- `game_id` TEXT NOT NULL
- `canonical_name` TEXT NOT NULL
- `sort_name` TEXT
- `default_language` TEXT
- `metadata_json` TEXT NOT NULL DEFAULT '{}'
- `created_at_ms` INTEGER NOT NULL
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `game_id -> games.id`

Notes:
- this table is provider-agnostic
- no provider id should be primary identity here

### `catalog_sets`

Purpose:
- canonical set identity per game

Columns:
- `id` TEXT PK
- `game_id` TEXT NOT NULL
- `code` TEXT NOT NULL
- `canonical_name` TEXT NOT NULL
- `series_id` TEXT
- `release_date` TEXT
- `metadata_json` TEXT NOT NULL DEFAULT '{}'
- `created_at_ms` INTEGER NOT NULL
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `game_id -> games.id`
- unique `(game_id, code)`

Notes:
- `code` is provider-facing but still useful as a practical access key
- canonical set id remains app-owned

### `card_printings`

Purpose:
- canonical printing identity

Columns:
- `id` TEXT PK
- `game_id` TEXT NOT NULL
- `card_id` TEXT NOT NULL
- `set_id` TEXT NOT NULL
- `collector_number` TEXT NOT NULL
- `rarity` TEXT
- `release_date` TEXT
- `image_uris_json` TEXT NOT NULL DEFAULT '{}'
- `finish_keys_json` TEXT NOT NULL DEFAULT '[]'
- `metadata_json` TEXT NOT NULL DEFAULT '{}'
- `created_at_ms` INTEGER NOT NULL
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `game_id -> games.id`
- FK `card_id -> catalog_cards.id`
- FK `set_id -> catalog_sets.id`
- unique `(game_id, set_id, collector_number, card_id)`

Notes:
- this is the expected future anchor for collections and prices
- image and finish storage stays JSON until query needs justify normalization

### `catalog_card_localizations`

Purpose:
- localized card-level data

Columns:
- `card_id` TEXT NOT NULL
- `language_code` TEXT NOT NULL
- `name` TEXT NOT NULL
- `subtype_line` TEXT
- `rules_text` TEXT
- `flavor_text` TEXT
- `search_aliases_json` TEXT NOT NULL DEFAULT '[]'
- `updated_at_ms` INTEGER NOT NULL

PK:
- `(card_id, language_code)`

Constraints:
- FK `card_id -> catalog_cards.id`

Notes:
- card localizations attach to canonical card identity
- language is data, not identity

### `catalog_set_localizations`

Purpose:
- localized set names and optional localized series label

Columns:
- `set_id` TEXT NOT NULL
- `language_code` TEXT NOT NULL
- `name` TEXT NOT NULL
- `series_name` TEXT
- `updated_at_ms` INTEGER NOT NULL

PK:
- `(set_id, language_code)`

Constraints:
- FK `set_id -> catalog_sets.id`

### `provider_mappings`

Purpose:
- explicit bridge between provider ids and canonical local identities

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `game_id` TEXT NOT NULL
- `provider_id` TEXT NOT NULL
- `object_type` TEXT NOT NULL
- `provider_object_id` TEXT NOT NULL
- `provider_object_version` TEXT
- `card_id` TEXT
- `printing_id` TEXT
- `set_id` TEXT
- `mapping_confidence` REAL NOT NULL DEFAULT 1.0
- `mapping_source` TEXT
- `payload_hash` TEXT
- `created_at_ms` INTEGER NOT NULL
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `game_id -> games.id`
- FK `card_id -> catalog_cards.id`
- FK `printing_id -> card_printings.id`
- FK `set_id -> catalog_sets.id`
- unique `(game_id, provider_id, object_type, provider_object_id)`

Notes:
- at least one of `card_id`, `printing_id`, `set_id` must be populated
- this table is critical for migration safety

### `pokemon_printing_metadata`

Purpose:
- first-class Pokemon-specific filter/rules metadata

Columns:
- `printing_id` TEXT PK
- `category` TEXT
- `hp` INTEGER
- `stage` TEXT
- `evolves_from` TEXT
- `regulation_mark` TEXT
- `retreat_cost` INTEGER
- `illustrator` TEXT
- `types_json` TEXT NOT NULL DEFAULT '[]'
- `subtypes_json` TEXT NOT NULL DEFAULT '[]'
- `weaknesses_json` TEXT NOT NULL DEFAULT '[]'
- `resistances_json` TEXT NOT NULL DEFAULT '[]'
- `attacks_json` TEXT NOT NULL DEFAULT '[]'
- `abilities_json` TEXT NOT NULL DEFAULT '[]'
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `printing_id -> card_printings.id`

Decision:
- query-critical fields get dedicated columns
- richer structured metadata stays JSON

### `card_search_documents`

Purpose:
- unified local search materialization for multilingual lookup

Columns:
- `printing_id` TEXT NOT NULL
- `game_id` TEXT NOT NULL
- `language_code` TEXT NOT NULL
- `card_name` TEXT NOT NULL
- `set_name` TEXT
- `collector_number` TEXT
- `search_text` TEXT NOT NULL
- `updated_at_ms` INTEGER NOT NULL

PK:
- `(printing_id, language_code)`

Constraints:
- FK `printing_id -> card_printings.id`
- FK `game_id -> games.id`

Notes:
- this can back FTS later
- keeps search concerns decoupled from canonical storage

### `price_snapshots`

Purpose:
- local price cache independent from catalog provider

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `printing_id` TEXT NOT NULL
- `source_id` TEXT NOT NULL
- `currency_code` TEXT NOT NULL
- `amount` REAL NOT NULL
- `finish_key` TEXT
- `captured_at_ms` INTEGER NOT NULL

Constraints:
- FK `printing_id -> card_printings.id`

Recommended uniqueness:
- unique `(printing_id, source_id, currency_code, COALESCE(finish_key, ''))`

### `collections`

Purpose:
- user collection containers

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `game_id` TEXT NOT NULL
- `name` TEXT NOT NULL
- `type` TEXT NOT NULL
- `filter_json` TEXT
- `created_at_ms` INTEGER NOT NULL
- `updated_at_ms` INTEGER NOT NULL

Constraints:
- FK `game_id -> games.id`

Notes:
- reuses existing semantic types where possible
- later we may split some semantics further, but not required for first migration

### `collection_memberships`

Purpose:
- membership-only relation for lists, wishlist, smart cache, set membership if needed

Columns:
- `collection_id` INTEGER NOT NULL
- `printing_id` TEXT NOT NULL
- `added_at_ms` INTEGER NOT NULL

PK:
- `(collection_id, printing_id)`

Constraints:
- FK `collection_id -> collections.id`
- FK `printing_id -> card_printings.id`

### `collection_inventory`

Purpose:
- ownership-bearing state for printings in collections

Columns:
- `collection_id` INTEGER NOT NULL
- `printing_id` TEXT NOT NULL
- `quantity` INTEGER NOT NULL DEFAULT 0
- `foil` INTEGER NOT NULL DEFAULT 0
- `alt_art` INTEGER NOT NULL DEFAULT 0
- `updated_at_ms` INTEGER NOT NULL

PK:
- `(collection_id, printing_id)`

Constraints:
- FK `collection_id -> collections.id`
- FK `printing_id -> card_printings.id`

Reason for split:
- current `collection_cards` mixes membership and inventory
- the new schema should model them separately

### `migration_backups`

Purpose:
- track critical migration backup artifacts

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `game_id` TEXT NOT NULL
- `source_db_path` TEXT NOT NULL
- `backup_db_path` TEXT NOT NULL
- `source_schema_version` INTEGER
- `target_schema_version` INTEGER
- `created_at_ms` INTEGER NOT NULL
- `status` TEXT NOT NULL

### `migration_id_mapping_audit`

Purpose:
- audit mapping of legacy ids to canonical ids during migration

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `game_id` TEXT NOT NULL
- `legacy_card_id` TEXT NOT NULL
- `provider_id` TEXT
- `resolved_card_id` TEXT
- `resolved_printing_id` TEXT
- `mapping_status` TEXT NOT NULL
- `notes` TEXT
- `created_at_ms` INTEGER NOT NULL

### `migration_failures`

Purpose:
- explicit failure marker and diagnostics

Columns:
- `id` INTEGER PK AUTOINCREMENT
- `game_id` TEXT NOT NULL
- `stage` TEXT NOT NULL
- `error_code` TEXT
- `error_message` TEXT
- `created_at_ms` INTEGER NOT NULL

## Column Vs JSON Decisions

### Dedicated columns

Use dedicated columns when:
- the field is needed in `WHERE`, `JOIN`, or `ORDER BY`
- the field is required for identity
- the field is required for migration logic
- the field is required for common UI rendering

Examples:
- `game_id`
- `card_id`
- `set_id`
- `collector_number`
- `rarity`
- `release_date`
- Pokemon `category`, `hp`, `stage`, `regulation_mark`, `illustrator`

### JSON fields

Use JSON when:
- the structure is nested
- the field is not a primary filter key
- the field is useful for detail screens but not core query paths

Examples:
- Pokemon attacks
- Pokemon abilities
- weaknesses/resistances
- finish keys
- provider payload hashes/metadata

## Search And Query Model

### Text search

Target behavior:
- search by localized name
- fallback to canonical name
- support set name and collector number

Recommended implementation:
- materialize `card_search_documents`
- later attach FTS5 over search text if needed

### Set and collector lookup

Primary access path:
- `card_printings(game_id, set_id, collector_number)`

### Provider resolution

Primary access path:
- `provider_mappings(game_id, provider_id, object_type, provider_object_id)`

### Collection fetch

Primary access path:
- `collections`
- join `collection_memberships` and/or `collection_inventory`
- then join `card_printings`, `catalog_cards`, `catalog_sets`
- then attach localization rows by requested language

## Index Plan

Recommended indices:

- `catalog_cards(game_id, canonical_name)`
- `catalog_sets(game_id, code)`
- `catalog_sets(game_id, canonical_name)`
- `card_printings(game_id, card_id)`
- `card_printings(game_id, set_id, collector_number)`
- `card_printings(game_id, rarity)`
- `catalog_card_localizations(language_code, name)`
- `catalog_set_localizations(language_code, name)`
- `provider_mappings(game_id, provider_id, object_type, provider_object_id)` unique
- `price_snapshots(printing_id, source_id, currency_code, finish_key)`
- `collection_memberships(collection_id, printing_id)`
- `collection_inventory(collection_id, printing_id)`
- `pokemon_printing_metadata(category)`
- `pokemon_printing_metadata(hp)`
- `pokemon_printing_metadata(stage)`
- `pokemon_printing_metadata(regulation_mark)`
- `pokemon_printing_metadata(illustrator)`
- optional later: FTS index on `card_search_documents.search_text`

## Migration Notes

Migration from current storage should happen conceptually in this order:
1. create canonical base tables
2. create provider mappings from current ids
3. populate canonical cards, sets, and printings
4. populate localizations
5. migrate collections
6. split old `collection_cards` into membership and inventory
7. verify counts and referential integrity
8. keep backup until validation succeeds

## Open Questions

These are still deferred:
- whether `series` deserves a first-class table immediately
- whether MTG-specific metadata needs dedicated tables in M2 or can stay transitional
- whether collection membership and inventory should be physically split in the first production migration or staged over two releases

## Recommended Next Step

The next implementation step should not modify the current runtime database yet.

Instead:
- draft the new Drift tables in isolation
- write migration-oriented fixture tests
- then decide whether the first production rollout is:
  - canonical schema behind a new DB file
  - or in-place schema evolution with phased migration
