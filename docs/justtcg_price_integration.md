# JustTCG Price Integration

## Purpose

This document defines how a future `JustTCG` integration should enter the app without changing the canonical card domain.

It complements:
- [provider_contracts.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/providers/provider_contracts.dart)
- [scryfall_mtg_price_provider_adapter.dart](c:/Users/Naval/Documents/TGC/tcg_tracker/lib/providers/scryfall_mtg_price_provider_adapter.dart)
- [provider_lifecycle.md](c:/Users/Naval/Documents/TGC/tcg_tracker/docs/provider_lifecycle.md)

## Core Rule

`JustTCG` must be integrated as a `PriceProvider`, not as a catalog provider.

That means:
- no card identity comes from `JustTCG`
- no set identity comes from `JustTCG`
- no collection membership is keyed by `JustTCG`
- `JustTCG` only returns `PriceSnapshot` values for already-known printings

## Why

The canonical model already separates:
- `CatalogCard`
- `CatalogSet`
- `CardPrintingRef`
- `PriceSnapshot`

Prices are volatile and provider-specific.
Card identity must remain stable even if the app changes price source.

## Expected Integration Shape

Future adapter:
- `JustTcgPriceProviderAdapter implements PriceProvider`

Expected responsibilities:
- accept `PriceQuoteRequest`
- resolve remote quote data using `providerObjectId` or future mapping metadata
- map quote values to `PriceSnapshot`
- expose `PriceRefreshPolicy`

Expected non-responsibilities:
- search cards
- fetch sets
- define legality
- create canonical card ids

## Required Mapping Inputs

A `JustTCG` adapter should work from:
- `printingId`
- `providerObjectId` when available
- future `provider_mappings`

If `JustTCG` requires its own remote ids, they should be stored in canonical mapping tables as external references, never as canonical primary ids.

## Refresh Policy

`JustTCG` should define its own `PriceRefreshPolicy`, for example:
- shorter TTL than Scryfall if data is more volatile
- provider-specific concurrency limits
- stale-read allowance based on API reliability

Policy belongs to the price adapter, not to catalog code.

## Storage Rule

Persisted local price data remains:
- `PriceSnapshot`
- attached to `printingId`
- tagged with `sourceId`

This allows:
- side-by-side providers in transition
- source-aware debugging
- future source comparisons

## Migration Strategy

Recommended sequence:
1. keep Scryfall price adapter as default MTG provider
2. add `JustTcgPriceProviderAdapter`
3. register it in `ProviderRegistry` for selected games when ready
4. switch runtime refresh orchestration to resolve price provider by game
5. keep canonical storage unchanged

## Non-Goals

`JustTCG` integration should not require:
- changing `CatalogCard`
- changing `CatalogSet`
- changing `CardPrintingRef`
- changing collection schemas
- changing search UIs

If an integration requires those, the design is leaking price concerns into the catalog domain.
