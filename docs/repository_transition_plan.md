# Repository Transition Plan

## Purpose

This document defines how to deprecate direct use of `ScryfallDatabase` without breaking the current app behavior.

It accompanies the new repository interfaces introduced under `lib/repositories/`.

## New Repository Surfaces

The repository layer is split into:
- `CatalogRepository`
- `SetRepository`
- `SearchRepository`
- `CollectionRepository`
- `PriceRepository`

Current transitional adapter:
- `LegacyScryfallRepositoryAdapter`

## Why This Layer Exists

Today the UI and services depend directly on `ScryfallDatabase`.
That creates three problems:
- storage details leak into UI code
- provider-shaped assumptions spread into feature logic
- migrating to canonical storage would require a big-bang rewrite

The repository layer is the seam that lets us move incrementally.

## Immediate Strategy

### Phase 1: Introduce interfaces

Done in this branch:
- repository interfaces exist
- a transitional adapter delegates to current DB/services
- no user-facing behavior changes yet

### Phase 2: Route new code through repositories

Rule from now on:
- new feature/refactor code should depend on repository interfaces
- avoid adding new direct `ScryfallDatabase.instance` calls unless strictly necessary

### Phase 3: Migrate feature areas gradually

Recommended order:
1. search flows
2. collection list/detail reads
3. collection mutations
4. pricing reads/refresh
5. settings and maintenance flows

Reason:
- search and collection reads have the broadest exposure
- mutation flows need more care because they affect persistence semantics

### Phase 4: Introduce canonical repository implementations

When canonical storage is ready:
- add new repository implementations backed by canonical schema
- keep adapter compatibility side by side during transition
- switch feature modules one area at a time

### Phase 5: Deprecate `ScryfallDatabase`

`ScryfallDatabase` should move to:
- legacy adapter support
- migration utilities
- temporary fallback paths only

Eventually it should no longer be the primary application-facing API.

## Deprecation Rules

### Allowed direct usages for now

Still acceptable temporarily:
- migration tooling
- importer internals
- legacy-only maintenance code
- areas not yet routed through repositories

### Disallowed direction

Avoid introducing new direct DB exposure in:
- new UI code
- new search/filter logic
- new collection orchestration code
- new provider abstraction work

## Game Isolation Rule

Repository methods already accept optional `gameId`.
The legacy adapter ignores it for now because game isolation is still handled by:
- `TcgEnvironmentController`
- `ScryfallDatabase.setDatabaseFileName(...)`

This is intentional:
- it preserves current behavior
- it keeps the repository API ready for canonical multi-game implementations

## Price Layer Note

There is already an existing runtime `PriceRepository` in `lib/services/price_repository.dart`.

The new repository interface under `lib/repositories/price_repository.dart` is a storage-facing abstraction.
The current adapter bridges the new API to:
- `ScryfallDatabase.fetchCardPriceSnapshot`
- `ScryfallDatabase.updateCardPrices`
- legacy price refresh orchestration

This naming overlap is transitional and acceptable for now because the layers serve different roles.

## Recommended Next Code Migration

Best next target:
- search UI flows

Reason:
- they are read-heavy
- they exercise game/language/filter seams
- they benefit immediately from having a neutral abstraction

## End State

The end state should look like this:
- UI depends on repository interfaces
- repositories depend on canonical local schema
- provider sync/import code depends on provider contracts
- `ScryfallDatabase` is no longer app-facing
