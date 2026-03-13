# Provider Lifecycle

## Purpose

This document defines how provider abstractions are expected to behave in the new architecture.

It accompanies:
- [provider_contracts.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/providers/provider_contracts.dart)
- [provider_registry.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/providers/provider_registry.dart)
- [scryfall_mtg_provider_adapter.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/providers/scryfall_mtg_provider_adapter.dart)

## Provider Roles

The provider layer is split by responsibility:

- `CatalogProvider`
  - fetch provider-backed card/printing details
- `CatalogSyncService`
  - expose the latest remote dataset status for sync/import flows
- `SearchProvider`
  - execute provider-backed search for printings/cards
- `SetProvider`
  - expose provider-backed set information
- `DeckRulesProvider`
  - expose format legality and rules-related checks
- `PriceProvider`
  - fetch price snapshots independent from local storage and independent from catalog ownership

## Why The Split Exists

One provider may implement all roles, but the architecture must not assume that.

Examples:
- MTG/Scryfall can cover catalog, set, search, rules, while pricing may be split into a dedicated provider
- a future provider may expose catalog and sets but not prices
- a future local sync service may exist separately from remote search
- a future price-only provider may exist without any catalog/search role

## Lifecycle Expectations

### 1. Registration

Each game is associated declaratively in `ProviderRegistry`.

Current baseline:
- `mtg` -> Scryfall catalog adapter + separate Scryfall price adapter
- `pokemon` -> TCGdex provider bundle

### 2. Resolution

Application services should resolve providers by game, not by hardcoded provider class.

Pattern:
- choose active `TcgGameId`
- ask `ProviderRegistry` for the provider role needed
- fall back only where legacy transition still requires it

### 3. Execution

Providers should:
- return canonical domain objects
- never leak raw payloads as app-facing types
- treat provider ids as external references, not internal truth

### 4. Mapping

Provider adapters are responsible for translating payloads into:
- `CatalogCard`
- `CatalogSet`
- `CardPrintingRef`
- `PriceSnapshot`

Price adapters additionally receive explicit price quote requests:
- target `printingId`
- source-facing `providerObjectId`
- optional currency/finish preferences

### 5. Storage Handoff

Providers do not own local persistence directly.

Expected future direction:
- provider layer fetches/maps remote data
- repository/sync layer persists canonical data locally

## Scryfall MTG Adapter Scope

The initial MTG/Scryfall catalog adapter in this branch supports:
- card/printing fetch by provider id
- set fetch
- name search
- deck legality lookup via Scryfall legalities
- remote bulk dataset descriptor lookup

The transitional MTG price adapter supports:
- snapshot fetch through Scryfall prices
- explicit refresh policy
- no catalog/search responsibilities

This is intentionally enough to validate the contracts without forcing immediate runtime replacement of all existing flows.

## Sync Contract Note

`CatalogSyncService` currently exposes remote dataset status, not full local install orchestration.

Reason:
- local install/import is still tied to existing bulk workflows
- exposing remote catalog metadata is useful now
- it avoids designing a fake abstraction over not-yet-migrated local sync code

This can evolve later into:
- remote status
- install plan
- import execution
- repair/reimport flows

## Registry Rules

`ProviderRegistry` should be:
- declarative
- game-driven
- capable of partial bundles

That means:
- a game may have search but no pricing
- a game may have catalog sync but no scanner rules
- missing capabilities are represented by missing provider roles, not by implicit assumptions

## Transitional Rules

During the current refactor phase:
- provider contracts can coexist with legacy repository/database code
- new architecture work should prefer provider interfaces
- runtime flows may still use legacy implementations until moved intentionally
- MTG may continue using Scryfall for prices, but only through a dedicated price provider boundary

## Next Recommended Follow-up

After this milestone, the next logical steps are:
1. connect provider resolution to a future `GameRegistry`
2. add Pokemon provider contracts and TCGdex adapter
3. start routing specific remote/provider-backed flows through `ProviderRegistry`
