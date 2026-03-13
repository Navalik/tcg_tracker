# Capability Matrix

## Purpose

This document defines the capability-driven view of games for the new architecture.
It reflects current behavior and the intended target model.

## Capability Categories

### Core Catalog

- `catalog.install`
- `catalog.reimport`
- `catalog.update_check`
- `catalog.multilingual_storage`
- `catalog.provider_mapping`

### Search

- `search.name`
- `search.localized_name`
- `search.collector_number`
- `search.advanced_filters`
- `search.offline_full_fidelity`

### Collections

- `collections.custom`
- `collections.smart`
- `collections.set_collections`
- `collections.wishlist`
- `collections.deck`
- `collections.sideboard`

### Pricing

- `pricing.supported`
- `pricing.local_snapshots`
- `pricing.provider_refresh`

### Scanner

- `scanner.ocr`
- `scanner.game_specific_matching`
- `scanner.multilingual_matching`

### Rules And Metadata

- `deck.rules`
- `game_specific_filters`
- `game_specific_metadata`

## Current State Matrix

| Capability | MTG current | Pokemon current | Notes |
| --- | --- | --- | --- |
| `catalog.install` | yes | yes | MTG via Scryfall bulk; Pokemon via custom dataset import |
| `catalog.reimport` | yes | yes | Both exposed in settings |
| `catalog.update_check` | yes | yes | Different implementations |
| `catalog.multilingual_storage` | partial | no | MTG supports selected languages; Pokemon currently forced to English |
| `catalog.provider_mapping` | no | no | Missing as explicit concept |
| `search.name` | yes | yes | Shared generic search pipeline |
| `search.localized_name` | partial | no | MTG has partial printed-name support; Pokemon lacks real localized support |
| `search.collector_number` | yes | yes | Shared generic search logic |
| `search.advanced_filters` | partial | partial | Shared `CollectionFilter`, not capability-driven |
| `search.offline_full_fidelity` | partial | partial | Depends on dataset/profile and current storage compromises |
| `collections.custom` | yes | yes | Shared implementation |
| `collections.smart` | yes | yes | Shared implementation, not game-specialized |
| `collections.set_collections` | yes | yes | Shared implementation |
| `collections.wishlist` | yes | yes | Shared implementation |
| `collections.deck` | yes | yes | Shared implementation with game-specific behavior in scattered logic |
| `collections.sideboard` | yes | no/partial | MTG-native concept; Pokemon should be capability-driven |
| `pricing.supported` | yes | no | Current price layer is MTG/Scryfall-oriented |
| `pricing.local_snapshots` | yes | no | Stored on generic `cards` table |
| `pricing.provider_refresh` | yes | no | `PriceRepository` is MTG-oriented |
| `scanner.ocr` | yes | yes | Existing scanner flows exist |
| `scanner.game_specific_matching` | partial | partial | Current logic is heuristic-heavy |
| `scanner.multilingual_matching` | no | no | Not modeled correctly |
| `deck.rules` | partial | partial | Rules exist, but not as clean provider/capability contracts |
| `game_specific_filters` | weak | weak | Too much generic/shared filter behavior |
| `game_specific_metadata` | partial | partial | Pokemon metadata currently compressed into generic fields |

## Target State Matrix

| Capability | MTG target | Pokemon target | Notes |
| --- | --- | --- | --- |
| `catalog.install` | yes | yes | Via provider-backed sync services |
| `catalog.reimport` | yes | yes | Same contract, different provider implementation |
| `catalog.update_check` | yes | yes | Per-provider update logic |
| `catalog.multilingual_storage` | yes | yes | Native schema support |
| `catalog.provider_mapping` | yes | yes | Required for migration and future provider changes |
| `search.name` | yes | yes | Canonical |
| `search.localized_name` | yes | yes | Required |
| `search.collector_number` | yes | yes | Required |
| `search.advanced_filters` | yes | yes | Capability-driven and game-specific |
| `search.offline_full_fidelity` | yes | yes | Subject to installed dataset/profile |
| `collections.custom` | yes | yes | Shared repository API |
| `collections.smart` | yes | yes | Filter semantics game-aware |
| `collections.set_collections` | yes | yes | Provider-agnostic |
| `collections.wishlist` | yes | yes | Provider-agnostic |
| `collections.deck` | yes | yes | Rules and validation per game |
| `collections.sideboard` | capability-based | capability-based | Not globally assumed |
| `pricing.supported` | yes | optional | Decoupled from catalog |
| `pricing.local_snapshots` | yes | optional | Depends on provider/business decision |
| `pricing.provider_refresh` | yes | optional | Pluggable per game |
| `scanner.ocr` | yes | yes | Shared shell |
| `scanner.game_specific_matching` | yes | yes | Dedicated resolver behavior |
| `scanner.multilingual_matching` | target | target | Depends on final language strategy |
| `deck.rules` | yes | yes | Behind rules provider |
| `game_specific_filters` | yes | yes | Required |
| `game_specific_metadata` | yes | yes | Required |

## Proposed First-class Game Metadata

Each game should eventually declare:
- `gameId`
- `displayName`
- `requiresPurchase`
- `catalogProvider`
- `priceProvider`
- `supportedUiLanguages`
- `supportedCardLanguages`
- `supportsPricing`
- `supportsDecks`
- `supportsSideboard`
- `supportsScanner`
- `supportsLocalizedSearch`
- `filterCapabilities`
- `metadataCapabilities`

## Immediate Refactor Notes

The most problematic current gaps are:
- no explicit provider mapping capability
- no explicit multilingual catalog capability
- no clean separation between MTG and Pokemon filter semantics
- sideboard and pricing assumptions are still too MTG-shaped

These gaps must be addressed before onboarding a third game.
