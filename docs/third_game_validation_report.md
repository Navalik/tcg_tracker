# Third Game Validation Report

## Scope

This report validates the architecture using a minimal third TCG pilot: `One Piece`.

Implemented scope:
- catalog provider
- set provider
- search provider
- collection support through the existing per-game legacy DB layer

Intentionally excluded from this pilot:
- scanner
- prices
- purchase gating
- full UI game-picker exposure

## Pilot Choice

`One Piece` was chosen because it allows a compact pilot with:
- simple English-only catalog
- low filter complexity
- no immediate requirement for scanner or pricing

The provider is static and local on purpose. This validates architecture seams without coupling the milestone to an unstable or incomplete remote source.

## What Was Validated

### Provider Registry

`ProviderRegistry` now resolves a third concrete bundle for `TcgGameId.onePiece`.

Validated roles:
- `CatalogProvider`
- `CatalogSyncService`
- `SearchProvider`
- `SetProvider`

### Game Registry

`GameRegistry` now exposes `One Piece` as an enabled game definition with:
- dedicated DB file: `one_piece.db`
- dedicated provider bundle
- game-specific capabilities

### Canonical Catalog Store

The canonical store was extended so it no longer assumes Pokemon-only reads.

Validated behaviors:
- replace catalog rows per `gameId`
- fetch sets per `gameId`
- search per `gameId`
- count per `gameId`

### Repository Layer

`GameAwareRepositoryAdapter` now routes non-MTG canonical reads for:
- Pokemon
- One Piece

This confirms the repository layer is not structurally limited to two games.

### Collection Layer

The previous weakness was collection storage: repository calls accepted `gameId`, but the legacy DB adapter still effectively used the currently active singleton DB.

That gap was closed by making the legacy adapter switch DB file based on `GameRegistry` when a `gameId` is explicitly provided.

This is the most important runtime validation of the milestone, because it proves:
- set/search can be game-aware
- collections can also be game-aware
- the architecture is no longer blocked on a single active DB context for repository-driven operations

## Current Pilot Limits

The third game is not yet fully surfaced in the UI runtime because several user-facing flows are still explicitly `mtg/pokemon`:
- `TcgGame`
- `AppTcgGame`
- purchase management
- onboarding
- some settings and home-page selection logic

This is not a failure of the architecture work. It identifies the next seam to generalize if the third game should become user-selectable in production UI.

## Final Assessment

`M11` is validated at the architecture/runtime layer.

What now holds true:
- a third game can have its own provider bundle
- a third game can populate canonical storage
- a third game can be queried through the shared repository layer
- a third game can persist collections in its own DB file

What still remains for production-grade onboarding of more games:
- generic UI/runtime game selection
- generic app settings game keys
- generic purchase/access model
- optional remote provider replacement for the pilot dataset
