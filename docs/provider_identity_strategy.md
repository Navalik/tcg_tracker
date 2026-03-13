# Provider Identity Strategy

## Purpose

This document defines the identity and provider-mapping strategy required for the new storage and migration plan.

It exists because the current app still relies heavily on provider-shaped ids, especially in collections and local storage.

## Current State

Current reality:
- MTG data is effectively keyed by Scryfall printing ids.
- Pokemon data is imported into the same generic `cards` table.
- User collections currently reference legacy `cardId` values directly.
- No explicit provider mapping table exists.

This is the main risk area for storage refactor and migration.

## Identity Layers

The target architecture should distinguish these layers.

### 1. Game identity

Identifies the TCG domain itself.

Examples:
- `mtg`
- `pokemon`

### 2. Canonical card identity

Represents the game-level conceptual card, independent from provider payload and language.

Examples:
- MTG oracle-like concept
- Pokemon canonical card concept for the chosen provider/domain model

### 3. Printing identity

Represents a specific printed card version within a set/release context.

This is the level most user collections will usually need.

### 4. Provider identity

Represents external provider ids that map into canonical card or printing identities.

Examples:
- Scryfall ids
- TCGdex ids
- future provider ids

## Frozen Decisions

### PI-01: Provider ids are adapters, not canonical truth

No provider id should define the internal app model directly.

Implications:
- local schema needs explicit provider mapping tables
- provider ids may remain useful for sync and migration
- provider changes must not force a rewrite of collection semantics

### PI-02: Collections should target stable app identities

Collections should eventually reference app-owned canonical printing references, not raw provider ids.

Implications:
- migration from old `cardId` is mandatory
- collection compatibility is a storage release gate

### PI-03: Card identity and printing identity are different

These concepts must not be collapsed.

Implications:
- search may deduplicate at card level or printing level depending on UX
- prices usually attach to printings
- localized metadata may attach differently depending on game/domain choice

### PI-04: Language is not identity

Localized variants must not create fake card identity layers unless a game truly models them as distinct printings.

## Transitional Mapping Strategy

### MTG

Current source identity:
- Scryfall printing id in local `cards.id`

Transition direction:
- preserve current ids through a provider mapping table
- derive canonical card identity and printing identity from existing imported data
- collections migrate via mapping from old `cards.id` to new printing ref

### Pokemon

Current source identity:
- imported Pokemon id normalized into generic `cards.id`

Transition direction:
- define canonical Pokemon card/printing model first
- keep old imported ids as legacy provider mapping entries
- migrate existing collections through explicit compatibility mapping

## Required Mapping Concepts

The target storage needs mapping concepts equivalent to:
- `provider`
- `provider_object_type`
- `provider_object_id`
- `game_id`
- `canonical_card_id`
- `printing_id`
- `mapping_confidence`
- `mapping_source`

Useful optional metadata:
- `provider_payload_hash`
- `first_seen_at`
- `last_seen_at`
- `migration_notes`

## Migration Requirements

The migration plan must answer these cases:
- old collection entry maps exactly to one new printing
- old entry maps to one canonical card but multiple possible printings
- old entry points to data no longer present in new provider
- provider changed naming/set semantics
- localized variants create ambiguity

Required rule:
- no silent loss of collection membership

If exact mapping is impossible:
- preserve entry in a migration backup structure
- record ambiguity
- surface controlled fallback behavior

## Provider-specific Notes

### Scryfall

Useful as transition source for:
- MTG printing ids
- set codes
- current collection compatibility

Not acceptable as long-term app-owned identity model.

### TCGdex

Intended future Pokemon source.

The exact mapping design must preserve:
- card identity
- printing identity
- set identity
- local/provider ids required for scanner and collection compatibility

## Practical Rules For This Refactor

For the `0.5.x` storage redesign:
- never introduce new features that deepen direct dependence on `ScryfallDatabase` ids
- every new storage proposal must name canonical identity and provider identity separately
- any migration design must explicitly state how old collection rows are mapped

## Out Of Scope Here

This document does not finalize:
- exact table names
- exact column names
- exact mapping rules for every provider
- exact Pokemon TCGdex identity choice

Those belong to M1, M2, and M2.5 deliverables.
