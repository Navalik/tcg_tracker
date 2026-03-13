# Migration Plan

## Purpose

This document defines the migration safety strategy for the storage refactor that will move the app from the current provider-shaped storage into the new canonical storage model.

It is written against the current production baseline on branch `pokemon-db-refactor`.

## Current Production Reality

Today the app has these important migration constraints:
- physical DB split by game: `scryfall.db` and `pokemon.db`
- current Drift schema version: `9`
- current app-level migration track version: `1`
- collections and collection memberships still reference legacy `cardId` values directly
- MTG and Pokemon still reuse the same broad `cards` table shape
- the runtime still depends on `ScryfallDatabase` as the access layer

This means the storage redesign is not a simple schema bump. It is a data-shape migration with identity remapping risk.

## Goals

The migration system must guarantee:
- preservation of user collections
- preservation of owned quantities and membership semantics
- explicit mapping from legacy `cardId` to new printing identity
- temporary backup before destructive migration phases
- deterministic fallback if migration fails
- no silent loss of cards

## Migration Scope

The migration must cover:
- legacy `collections`
- legacy `collection_cards`
- legacy card/provider ids currently used by those rows
- game-specific differences between MTG and Pokemon

The migration does not need to preserve:
- legacy internal storage shape
- provider-shaped ids as primary local identities

## Existing DB Versions To Consider

Known schema path in the current codebase:
- Drift schema `1`
- Drift schema `2`
- Drift schema `3`
- Drift schema `4`
- Drift schema `5`
- Drift schema `6`
- Drift schema `7`
- Drift schema `8`
- Drift schema `9`

Known app-level migration track:
- app DB version `1`

Risk focus:
- users landing from any schema `< 9`
- users already on `9` who must later move to canonical storage
- users with Pokemon collections imported under the current lightweight model

## Migration Strategy

### Phase A: Preflight

Before starting a critical storage migration:
- detect active game DB file
- open DB in maintenance mode
- read schema version and app migration metadata
- collect counts and audit metrics:
  - collection count
  - collection card row count
  - owned quantity totals per collection
  - distinct legacy `cardId` count

If preflight fails:
- do not start destructive migration
- surface safe error state
- preserve original DB untouched

### Phase B: Temporary local backup

Before the first destructive step:
- copy the physical DB file to a temporary backup path in app documents
- record:
  - source file name
  - original schema version
  - migration target version
  - backup timestamp
  - backup checksum if practical

Backup lifetime:
- keep until migration success is committed and post-checks pass
- clean up only after successful verification or after explicit retention policy

### Phase C: Identity mapping

The migration must build an explicit mapping layer:
- legacy `cardId`
- game id
- resolved canonical card id
- resolved canonical printing id
- mapping status
- ambiguity flag

Required outcomes per row:
- `resolved`
- `resolved_with_fallback`
- `ambiguous`
- `missing`

Rules:
- `resolved` and `resolved_with_fallback` may migrate automatically
- `ambiguous` and `missing` must never be silently discarded

### Phase D: Collection migration

Collections must migrate before memberships are rewritten.

Required preservation:
- collection identity
- collection name
- collection type semantics
- smart filter payloads where still supported
- wishlist/deck/custom meaning

After collection migration, collection membership rows are migrated from legacy `cardId` to canonical `printingId`.

### Phase E: Post-migration verification

Required checks:
- collection count before/after is consistent modulo intentional normalization rules
- no unexpected drop in total membership rows
- owned quantity totals for ownership-bearing collections remain consistent
- every migrated membership row references an existing canonical printing
- backup exists until verification succeeds

If verification fails:
- mark migration as failed
- prevent destructive continuation
- restore from backup or keep app in recovery-required state

## Mapping Strategy: Legacy `cardId` To New Printing Identity

### MTG

Legacy source:
- current `cards.id`, effectively Scryfall printing ids

Strategy:
- create provider mapping entry from old Scryfall id
- resolve to canonical printing identity
- migrate `collection_cards.card_id` to the new printing key

### Pokemon

Legacy source:
- current imported Pokemon ids stored in `cards.id`

Strategy:
- preserve current imported id as legacy provider mapping
- resolve to new Pokemon canonical printing identity
- if TCGdex mapping is not exact, use controlled fallback strategy

### Ambiguity handling

If one legacy id maps to multiple possible printings:
- do not drop the row
- persist ambiguity record
- keep it in migration backup/audit tables
- surface it for controlled follow-up handling

## Backup And Rollback Strategy

### Backup

Minimum requirement:
- full DB file copy before critical migration

Optional but recommended:
- lightweight JSON audit summary for collections and counts

### Rollback

Rollback path:
1. close active DB handle
2. replace current DB file with backup
3. record migration failure marker
4. keep app in safe degraded state until next launch or recovery flow

### Failure behavior

If migration fails:
- do not continue with partially upgraded data as if success happened
- do not delete backup
- surface telemetry/logging with migration stage and reason

## Automated Test Strategy

The migration suite must cover:
- upgrade from legacy schema versions
- preservation of collections
- preservation of ownership-bearing quantities
- backup/audit artifacts for destructive normalization
- no silent row loss outside explicitly normalized collection types

Mandatory scenarios:
- upgrade from a real legacy schema baseline
- duplicate/dirty collection data normalization
- collection card id trimming and dedup
- wishlist/set/smart collection cleanup rules
- deck/owned collection preservation

## Current Automated Coverage Added In This Branch

Automated tests currently cover:
- upgrade from schema version `8` to `9`
- creation of legacy backup tables
- merge of duplicate `all` collections
- trimming/dedup of legacy `cardId` values
- preservation of deck-owned quantities
- cleanup behavior for wishlist, smart, and set collections

This is not yet the final canonical-storage migration suite. It is the first safety baseline.

## Release Gate For Canonical Storage Migration

The future storage migration must not ship unless:
- migration tests pass
- collection integrity checks pass
- backup/rollback path is implemented
- legacy id to printing mapping strategy is implemented for MTG and Pokemon
- migration telemetry is in place

## Follow-up Work

This document is a bridge toward later milestones:
- `M2` canonical storage design
- `M2.5` full migration implementation
- `M3` repository transition

Still required later:
- exact canonical table migration sequence
- exact temporary mapping table design
- exact recovery UI/telemetry behavior
- tests for canonical storage migration, not only current v8 -> v9 normalization
