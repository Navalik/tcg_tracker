# Architecture Decisions

## Scope

This document freezes the architectural baseline for the `0.5.x` refactor cycle.
It is written against the current codebase on branch `pokemon-db-refactor`.

## Current Baseline

The app is already multi-game at runtime, but not yet multi-TCG in architecture.

Current facts:
- Game switching is implemented through `TcgEnvironmentController`.
- MTG uses `scryfall.db`.
- Pokemon uses `pokemon.db`.
- Both games currently reuse the same Drift schema centered on the `cards` table.
- The local access layer is still conceptually centered on `ScryfallDatabase`.
- Pokemon import is custom, but normalized into the MTG-oriented `cards` table.
- Search, filter, collection, and pricing flows are mostly shared and query the same generic storage shape.

## Frozen Decisions

### AD-01: Provider-agnostic local model

The internal app model must stop being shaped by Scryfall payloads.

Implications:
- Provider payloads are input adapters, not internal truth.
- The new local schema must represent app concepts first.
- `ScryfallDatabase` becomes a legacy access layer to be replaced gradually.

### AD-02: Catalog and price are separate domains

Catalog provider and price provider are different responsibilities.

Implications:
- Card/set identity cannot depend on current price source.
- Price snapshots must remain attachable to canonical card/printing identities.
- MTG may continue using Scryfall for prices in transition, but only behind a dedicated price layer.

### AD-03: Pokemon becomes first-class

Pokemon is no longer treated as a reduced variant of MTG storage.

Implications:
- Pokemon-specific metadata must be modeled intentionally.
- Search and filtering must stop relying on MTG assumptions.
- The future provider target for Pokemon is `TCGdex`, not the current import compromise.

### AD-04: Multilingual storage is real, not cosmetic

Language support must exist in schema and query design, not only in UI labels.

Implications:
- Localized card data and localized set data require dedicated storage strategy.
- Search must support canonical and localized names.
- Fallback rules must be explicit and consistent.
- Hardcoded `en` assumptions must be treated as temporary legacy behavior.

### AD-05: Game capability is declared, not inferred by scattered `if`

Game-specific feature availability must be driven by central metadata.

Implications:
- Filters, scanner behavior, deck rules, supported languages, and pricing support must be capability-driven.
- UI should stop branching on raw `if (game == ...)` where possible.
- Game configuration, purchase gating, providers, and capabilities must be separated concerns.

### AD-06: Canonical storage must support future games

The target architecture must support onboarding a third TCG without rewriting the core model.

Implications:
- Storage cannot be hardcoded around MTG-only fields.
- Game-specific metadata should be modeled with a clear strategy:
  dedicated columns when query-critical, structured JSON when secondary.
- Provider mapping tables are required.

### AD-07: Migration safety is mandatory

This refactor touches production user data and cannot rely on best-effort migration.

Implications:
- Backup/fallback strategy is part of the design, not an afterthought.
- Collection integrity is a release gate.
- Mapping from old card ids to new canonical identities must be explicit.

## Target Boundaries

The refactor should separate these domains:

- `Catalog`
  - canonical cards
  - printings
  - sets
  - localized data
  - provider mappings
- `Collections`
  - user collections
  - membership
  - owned quantities
  - wishlist/deck/custom semantics
- `Search`
  - text search
  - filter definitions
  - pagination/sort
- `Pricing`
  - provider-specific price fetch
  - local snapshots
  - refresh policy
- `Scanner`
  - OCR
  - resolver/matching
  - game-specific fallback rules
- `Game Registry`
  - game metadata
  - capabilities
  - provider associations
  - purchase requirements

## Immediate Refactor Priority

The first releasable block is:
- architecture freeze
- domain model
- canonical storage design
- migration safety
- repository neutralization

Not part of the first block:
- full TCGdex rollout
- scanner rewrite
- third game onboarding
- full UI modularization

## Legacy Constraints To Respect

These current realities must be handled during transition:
- `ScryfallDatabase` is used directly by UI and services.
- Collection logic depends heavily on existing `cardId` values.
- Price snapshots are stored directly on `cards`.
- Pokemon currently stores only English local card data.
- Current game switching depends on different physical DB files.

## Transitional Strategy

The migration should be incremental.

Recommended sequence:
1. Freeze architecture and domain decisions.
2. Define canonical domain objects.
3. Design the new storage schema.
4. Design migration safety and id mapping.
5. Introduce provider-agnostic repositories.
6. Move MTG and Pokemon behind provider contracts.

## Out Of Scope For This Document

This document does not finalize:
- exact Drift schema
- exact domain class signatures
- exact migration SQL
- exact TCGdex adapter implementation

Those belong to later deliverables.
