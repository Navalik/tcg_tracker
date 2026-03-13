# Legacy DB Touchpoints

## Purpose

This document tracks direct `ScryfallDatabase` usages that still exist after introducing the repository layer.

It is a migration aid, not a complaint list.

## Already Routed Through Repositories

Current branch has moved these read-only paths in `collection_detail_search`:
- text search by name
- advanced filter search
- filter-only search
- available set lookup
- set name lookup for missing selected sets

These now go through:
- `SearchRepository`
- `SetRepository`

## Remaining Direct Touchpoints

Major remaining areas still calling `ScryfallDatabase` directly:

### Search-related

- [home_page.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/parts/home_page.dart)
  - scanner/name-based printing resolution
  - filter/search flows in home
- [collection_detail_page.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/parts/collection_detail_page.dart)
  - counts, set lookups, legality checks, quantities

### Collection mutation and ownership logic

- [collection_detail_page.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/parts/collection_detail_page.dart)
- [inventory_service.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/services/inventory_service.dart)

### Settings and maintenance

- [settings_page.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/parts/settings_page.dart)
  - reimport/reset/maintenance flows

### Import and migration internals

- [pokemon_bulk_service.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/services/pokemon_bulk_service.dart)
- [app_database.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/db/app_database.dart)

### Pricing bridge

- runtime price refresh still depends on:
  - [price_repository.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/services/price_repository.dart)
  - [app_database.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/db/app_database.dart)

## Recommended Next Migration Targets

Recommended order:
1. `home_page` read-only search/set flows
2. `collection_detail_page` read-only catalog/search counts
3. collection writes and inventory flows
4. settings maintenance paths
5. importer and migration-only DB paths

## Rule Going Forward

New feature code should prefer repository interfaces.

Direct `ScryfallDatabase` usage is still acceptable only for:
- migration tooling
- importer internals
- not-yet-migrated legacy flows
