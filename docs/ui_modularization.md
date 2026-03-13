## UI modularization

This branch starts the UI split away from the legacy `lib/parts` bucket.

### Feature ownership

- `lib/features/home/`
  - home dashboard, collection entrypoints, scanner launch points
- `lib/features/collections/`
  - collection detail pages, set collections, deck-specific collection UI
- `lib/features/search/`
  - card search sheets and reusable search flows
- `lib/features/settings/`
  - app settings, backup, data management
- `lib/features/billing/`
  - Plus / purchase UI

### Rules for follow-up slices

- Prefer feature-local widgets before adding more code to `main.dart`.
- Avoid new `if (game == ...)` UI branches when the decision can come from repositories, filter definitions, or game capabilities.
- Reusable cross-feature visuals stay outside feature folders only when they are truly shared.
- New scanner/search/deck flows should live under their feature folder even if they still use `part` during the transition.

### Current transition state

- Main entrypoint still hosts the shared library for legacy `part` integration.
- Feature pages were moved to feature folders without behavior changes.
- Next slices should extract scanner page and filter builder page out of `home` into dedicated scanner/search modules.
