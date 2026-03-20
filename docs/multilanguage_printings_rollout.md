# Multi-Language Printings Rollout

This document defines the BinderVault runtime migration from legacy single-row card storage to canonical multi-language, multi-printing storage.

Scope:
- all TCGs, not only Pokemon
- English, Italian, and future Asian languages
- search, collections, inventory, filters, scanner, and details

## Goal

Move from:
- one legacy `cards` row with a single `lang`
- collections tied to `card_id`

To:
- one canonical card identity
- many printings
- many localized texts
- inventory and collections tied to `printingId`

This is the target rule:
- same conceptual card across languages is not one owned object
- each owned printing is a separate object
- UI may group them, storage must not fuse them

## Why

The current hybrid model causes structural bugs:
- set collections can show a set from canonical storage but populate from legacy storage
- one-language filters can hide printings that exist in another enabled language
- details and color metadata may be incomplete if the legacy row is sparse
- `en/it` assumptions do not scale to `ja`, `ko`, `zh-Hant`, `zh-Hans`, etc.

## Target Data Model

The runtime target is already aligned with the canonical schema draft:
- `catalog_cards`
- `catalog_sets`
- `card_printings`
- `catalog_card_localizations`
- `catalog_set_localizations`
- `provider_mappings`
- game-specific printing metadata tables
- collection membership and inventory bound to `printingId`

Operational meanings:
- `catalog_cards`: conceptual identity inside one game
- `card_printings`: concrete owned/searchable printings
- `catalog_card_localizations`: names and rules text per language
- `catalog_set_localizations`: set names per language
- `collection_memberships` and `collection_inventory`: ownership data per printing

## Non-Negotiable Decisions

1. `languageCode` must become an open string, not a closed enum.
2. Inventory must reference `printingId`, not `cardId`.
3. Language filters must be first-class filters for every TCG.
4. Display language preference and inventory language scope must be separate concepts.
5. Canonical storage becomes the source of truth for Pokemon and Magic runtime reads.

## Language Model

We need three distinct concepts:

1. App UI language
- controls labels and default display priority
- examples: `en`, `it`

2. Installed card languages
- defines which localized catalogs are present offline
- examples: `en`, `it`, `ja`

3. Active filter languages
- defines which printings are visible in search and collections
- examples: `{en, it}` for a mixed collection

These must not be collapsed into one setting.

## User-Facing Behavior

Inventory:
- `Pikachu Base Set EN`
- `Pikachu Set Base IT`
- separate owned rows

Search:
- returns printings in all active languages
- supports explicit language filter
- can later offer optional grouping by conceptual card

Set collections:
- by default include all enabled card languages
- can be narrowed with a language filter if the user wants a one-language set view

Smart collections:
- `languages` becomes a standard filter dimension

Details:
- resolved by printing first
- localized text chosen by the actual printing language
- fallback metadata can still come from canonical printing metadata

## Technical Rollout

### Phase 1: Domain Cleanup

Files:
- `lib/domain/domain_models.dart`
- `lib/services/game_registry.dart`
- `lib/services/app_settings.dart`

Tasks:
- replace `TcgCardLanguage` runtime dependence with `String languageCode`
- keep a temporary compatibility mapper for existing `en/it` paths
- make supported language lists data-driven per game

Deliverable:
- no runtime code assumes only `en` and `it`

### Phase 2: Canonical Runtime Reads

Files:
- `lib/repositories/game_aware_repository_adapter.dart`
- `lib/db/canonical_catalog_store.dart`
- search/detail adapters and collection readers

Tasks:
- route Magic and Pokemon reads through canonical storage
- remove hybrid cases where canonical storage feeds set/search while legacy storage feeds collections
- add canonical query helpers for:
  - fetch collection cards by `printingId`
  - fetch card details by `printingId`
  - fetch set totals by language scope

Deliverable:
- one runtime source of truth for search, set names, details, and filtering

### Phase 3: Collection and Inventory Migration

Files:
- `lib/db/app_database.dart`
- migration scripts
- inventory and collection services

Tasks:
- introduce canonical collection tables at runtime
- migrate legacy `collection_cards(card_id)` ownership to `collection_inventory(printingId)`
- use `provider_mappings` plus legacy compatibility rules to resolve old entries
- preserve quantity, foil, alt art, and timestamps

Deliverable:
- collections and inventory no longer depend on legacy `card_id`

### Phase 4: Filter Migration

Files:
- `lib/models.dart`
- search/filter UIs
- collection filter builders

Tasks:
- keep `languages` as a real multi-select filter for all games
- ensure set collections default to all enabled languages
- make grouping independent from filtering

Deliverable:
- language handling is consistent across Magic and Pokemon

### Phase 5: UI Stabilization

Files:
- home
- collection details
- search results
- card details
- scanner flows

Tasks:
- decide whether list tiles show one row per printing or grouped rows
- add language chips/badges where needed
- ensure details always reflect the actual printing language

Deliverable:
- predictable UI behavior for mixed-language collections

## Transitional Compatibility

Until migration is complete:
- keep legacy storage readable
- do not keep adding new language logic only in the legacy DB
- new features should prefer canonical helpers

Temporary rule:
- legacy rows may still exist
- canonical storage is preferred whenever a runtime read can be served from it

## Risks

1. Existing collections may contain legacy ids with ambiguous language resolution.
2. Search result identity may change if we stop collapsing printings.
3. Scanner flows may need explicit language selection for better disambiguation.
4. Exports/imports will need a version bump to include `printingId` and `languageCode`.

## First Implementation Slice

Recommended first coding slice:

1. make language codes string-based in the domain and settings layer
2. add canonical read APIs for collection cards and details by `printingId`
3. create runtime canonical collection inventory tables
4. migrate Pokemon and Magic set collections to canonical-backed reads
5. only then adapt the UI filters and grouping

## Branching

This work should stay on a dedicated branch:
- `feature/multilanguage-printings`

No unrelated feature work should be mixed into this branch unless required for migration safety.
