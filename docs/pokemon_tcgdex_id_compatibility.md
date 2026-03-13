# Pokemon TCGdex ID Compatibility

This document defines the compatibility bridge between the legacy Pokemon collection IDs already stored in production and the new canonical storage imported from TCGdex.

## Core decision

For the first TCGdex migration phase:
- canonical `cardId` is `pokemon:card:tcgdex:<providerObjectId>`
- canonical `printingId` is `pokemon:printing:tcgdex:<providerObjectId>`
- `providerObjectId` is the TCGdex card id, for example `base1-1`

This means card identity and printing identity are still distinct in the model, but currently 1:1 for Pokemon.

This is intentional.

It avoids inventing a fragile cross-printing Pokemon identity before we have a reliable merge strategy for reprints, alt arts, and same-name cards across eras.

## Why this preserves current user data

The existing local Pokemon collections already store ids in the same practical shape:
- `base1-1`
- `swsh1-25`
- `sv1-198`

Those ids are directly reusable as:
- TCGdex `providerObjectId`
- legacy provider mapping id

So the migration path is straightforward:
1. read legacy collection `cardId`
2. resolve `provider_mappings` where `provider_id = pokemon_tcg_api` and `provider_object_id = legacy cardId`
3. map to canonical `printingId`
4. move collection membership to canonical storage

## Provider mappings written during import

For each imported TCGdex Pokemon printing we write:
- `providerId = tcgdex`, `objectType = card`, `providerObjectId = <id>`
- `providerId = tcgdex`, `objectType = printing`, `providerObjectId = <id>`
- `providerId = pokemon_tcg_api`, `objectType = legacy_printing`, `providerObjectId = <id>`

The last mapping is the compatibility bridge.

## Language strategy

Canonical matching language for Pokemon is English:
- English payload drives canonical ids and structured metadata
- Italian payload is imported as additional localization
- if Italian data is missing, canonical English remains the fallback

## Known limitation

This phase does not yet collapse multiple printings of the same conceptual Pokemon card into a single cross-set canonical card identity.

That is deferred on purpose until we have:
- stronger reprint matching rules
- a reviewed migration strategy for same-name cards
- a safe path for collection dedup logic
