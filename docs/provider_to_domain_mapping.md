# Provider To Domain Mapping

## Purpose

This document defines the conceptual mapping from provider payloads to the canonical domain models introduced in [domain_models.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/domain/domain_models.dart).

It is not the final storage schema and not the final sync contract. It is the conceptual bridge needed before M2 and M2.5.

## Target Domain Objects

The canonical model is split into these main concepts:
- `CatalogCard`
- `CatalogSet`
- `CardPrintingRef`
- `LocalizedCardData`
- `LocalizedSetData`
- `PriceSnapshot`
- `ProviderMapping`
- `PokemonCardMetadata`
- `CoreCardFilter`
- `PokemonCardFilter`

## Identity Rules

### Canonical card identity

`CatalogCard.cardId` is the stable app-owned card identity.

It represents the conceptual card, not a provider payload row and not a localized name.

### Printing identity

`CardPrintingRef.printingId` is the stable app-owned printing identity.

It represents a specific printing inside a set/release context and is the expected long-term anchor for collections and prices.

### Localization identity

`LocalizedCardData` and `LocalizedSetData` attach to canonical identities.

Language is attached data, not a separate card identity.

## MTG / Scryfall Mapping

### `CatalogCard`

Suggested conceptual source:
- Scryfall oracle-like concept where possible
- fallback to current stored record if transition data is incomplete

Mapped fields:
- `gameId`: `TcgGameId.mtg`
- `canonicalName`: canonical card/oracle name
- `sortName`: normalized search/sort name if needed
- `metadata`: non-core MTG attributes that are not yet first-class

### `CatalogSet`

Mapped from Scryfall set payload:
- `code`
- `canonicalName`
- `releaseDate`
- optional series/block metadata in `metadata`

### `CardPrintingRef`

Mapped from Scryfall printing row:
- `collectorNumber`
- `rarity`
- `releaseDate`
- `imageUris`
- `finishKeys`

Provider mappings:
- `providerId = CatalogProviderId.scryfall`
- `objectType = printing`
- `providerObjectId = current Scryfall card id`

### `LocalizedCardData`

Mapped from:
- canonical name
- printed name
- oracle text
- printed text where available

### `PriceSnapshot`

Mapped from current or future price layer:
- source `scryfall` or other source
- attached to `printingId`, not to provider payload identity long term

## Pokemon / Current Dataset Mapping

### `CatalogCard`

Current source is the imported normalized Pokemon payload, but this is transitional.

Mapped fields:
- `gameId`: `TcgGameId.pokemon`
- `canonicalName`: stable card name for canonical matching
- `pokemon`: partially populated from current Pokemon metadata

### `CatalogSet`

Mapped from current imported set fields:
- `code`
- `canonicalName`
- `releaseDate`

### `CardPrintingRef`

Mapped from current imported record:
- `collectorNumber`
- `rarity`
- `imageUris`
- provider mapping using current imported pokemon id

### `LocalizedCardData`

Current dataset limitation:
- effectively only English local content is available in the app today

Transitional rule:
- populate English localization only
- do not treat this limitation as a permanent domain assumption

### `PokemonCardMetadata`

Current importer can already partially fill:
- `category`
- `types`
- `subtypes`
- `illustrator`
- `attacks`
- rough attack energy cost

Fields currently weak/missing should remain part of the target domain:
- `hp`
- `stage`
- `evolvesFrom`
- `regulationMark`
- `retreatCost`
- `weaknesses`
- `resistances`
- `abilities`

## Pokemon / TCGdex Target Mapping

TCGdex should become the target Pokemon provider after storage and repository groundwork is complete.

Expected mapping direction:

### `CatalogCard`
- stable Pokemon card identity
- canonical name
- card-level Pokemon metadata

### `CatalogSet`
- set identity
- set code / local id / release data
- optional series relationship

### `CardPrintingRef`
- printing-specific collector/local id
- rarity
- image references
- set membership

### `LocalizedCardData`
- localized names
- localized descriptive texts
- localized aliases when useful for search

### `LocalizedSetData`
- localized set names
- localized series names if provided

### `ProviderMapping`
- `providerId = CatalogProviderId.tcgdex`
- mappings for card, set, and printing level where needed

## Common Vs Game-specific Data

### Common

These belong in core domain:
- game id
- card id
- set id
- printing id
- canonical name
- localized names
- collector number
- rarity
- release date
- image uris
- price snapshots
- provider mappings

### Game-specific

These remain game-specific and should not pollute the generic model:
- Pokemon attacks/abilities/weaknesses/resistances
- Pokemon regulation mark and stage
- MTG legalities, mana cost, power/toughness/loyalty

Rule of thumb:
- if a field drives core cross-game behavior, elevate it
- if it drives game-specific filter/rules behavior, model it in game metadata
- if it is useful but secondary, keep it in structured metadata until promoted

## Filter Mapping

### Core filters

`CoreCardFilter` should cover:
- text query
- languages
- sets
- rarity
- collector number
- artist
- sort

### Pokemon filters

`PokemonCardFilter` should cover:
- category
- types
- subtypes
- regulation marks
- energy types
- hp range
- stage
- illustrator

## Migration Relevance

This model exists to support later migration design.

The critical migration bridge is:
- old provider-shaped ids map to `ProviderMapping`
- `ProviderMapping` resolves to canonical `CardPrintingRef`
- user collections eventually move from old `cardId` to app-owned printing identity

This is the key path that preserves user data while allowing provider-neutral storage.
