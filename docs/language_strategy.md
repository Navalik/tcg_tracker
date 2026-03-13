# Language Strategy

## Purpose

This document defines the target language strategy for catalog data, search, and UI.
It is grounded in the current state of the app and meant to guide the storage refactor.

## Current State

Current facts in code:
- UI locales supported today: `en`, `it`.
- App settings normalize card languages per game.
- MTG allows multiple selected card languages, always including `en`.
- Pokemon is currently constrained to `en` in practice.
- Search behavior still contains legacy assumptions built around current storage limits.

## Terminology

- `UI locale`
  - language used by app interface
- `catalog language`
  - language of localized card/set content stored in local DB
- `canonical language`
  - language chosen as stable identity/matching baseline for a game
- `fallback language`
  - language used when requested localized content is unavailable

## Frozen Decisions

### LS-01: UI locale and catalog language are separate concerns

The app UI language must not imply that matching card data exists in the same language.

Implications:
- A user can run the app in Italian while the catalog is only partially localized.
- Search and display layers must handle fallback explicitly.

### LS-02: English remains the minimum fallback, not the full model

Today the app effectively guarantees `en`.
That is acceptable as a transitional fallback, not as the target architecture.

Implications:
- New schema must not encode assumptions that only English exists.
- `en` remains a safe fallback during migration.

### LS-03: Language support must be per game

Supported card languages differ by game and provider.

Implications:
- Supported catalog languages must be declared per game/provider.
- Settings and search must stop relying on one global language list.

### LS-04: Localized data should attach to canonical identities

Localized text is not a separate card identity.

Implications:
- Canonical card identity and printing identity must stay stable across languages.
- Localized names/texts should be stored as attached localized records.

## Canonical Language Direction

### MTG

Transitional canonical language:
- English-centric identity remains acceptable during migration because current ids come from Scryfall printings.

Target direction:
- Canonical identity must be provider-agnostic and independent from localized printed names.

### Pokemon

Target canonical language:
- do not hardcode UI language as canonical matching language
- choose a provider-stable identity model first
- localized names become attached data, not identity

For Pokemon this likely means:
- canonical card/printing identity based on provider-stable identifiers
- localized card text and set text stored separately

## Search Behavior Rules

Target search rules:
- search should accept query in requested language
- search should also consider canonical and fallback names
- ordering should prefer matches in active requested language
- fallback matches should still be returned when localized data is missing

Required behavior:
- exact localized match beats fallback match
- exact canonical match beats loose fallback match
- collector/set lookup stays language-independent

## Storage Direction

The target schema should support:
- localized card names
- localized set names
- localized descriptive text
- explicit language code on localized rows
- multiple localized rows attached to the same canonical identity

This implies separate storage concepts such as:
- canonical card
- printing
- card localization
- set localization

## UI And Product Rules

### UI locale

Current UI locales:
- `en`
- `it`

Target:
- UI locale list can grow independently from catalog language support

### Card language selection

Current behavior:
- language selection is stored per game
- English is always included
- Pokemon currently blocks Italian card content

Target:
- per-game language availability comes from provider/game capabilities
- selection UI should reflect real provider support
- unsupported languages should not appear as fake options

## Transitional Rules For This Refactor

During the `0.5.x` transition:
- keep `en` as mandatory fallback
- preserve current MTG behavior
- do not pretend Pokemon multilingual support exists until storage and provider support are real
- remove new hardcoded `en` assumptions from new architecture work

## Open Design Questions For Later Milestones

These are not finalized here:
- exact canonical language for Pokemon matching under TCGdex
- how much localized rules text is required offline for first release
- how to rank multilingual fuzzy search results
- how to expose partially installed language datasets in UI
