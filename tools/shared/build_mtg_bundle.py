#!/usr/bin/env python3
"""Build a Firebase-hosted MTG bundle from Scryfall bulk data.

The generated JSON payloads intentionally keep the same compact Scryfall-card
shape used by the current app importer, so the mobile client can switch hosts
without a catalog schema rewrite.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator


BULK_ENDPOINT = "https://api.scryfall.com/bulk-data"
DEFAULT_OUTPUT_DIR = "dist/mtg_bundle_firebase"
DEFAULT_CACHE_DIR = "dist/mtg_bulk_cache"
SCHEMA_VERSION = 1
COMPATIBILITY_VERSION = 1
CANONICAL_SCHEMA_VERSION = 2
CANONICAL_COMPATIBILITY_VERSION = 2
CANONICAL_PROFILE = "full"


def safe_version_token(value: str) -> str:
    return (
        value.strip()
        .replace("-", "")
        .replace(":", "")
        .replace(".", "")
        .replace("+", "")
        .replace("Z", "Z")
    )


def compact_scryfall_card(card: dict[str, Any]) -> dict[str, Any]:
    compact: dict[str, Any] = {}

    def copy_scalar(key: str) -> None:
        value = card.get(key)
        if value is not None:
            compact[key] = value

    for key in [
        "id",
        "name",
        "oracle_id",
        "set",
        "set_name",
        "collector_number",
        "rarity",
        "type_line",
        "printed_type_line",
        "mana_cost",
        "oracle_text",
        "printed_text",
        "cmc",
        "artist",
        "power",
        "toughness",
        "loyalty",
        "lang",
        "released_at",
        "printed_name",
        "set_type",
        "layout",
    ]:
        copy_scalar(key)

    colors = card.get("colors")
    if isinstance(colors, list):
        compact["colors"] = [value for value in colors if isinstance(value, str)]

    color_identity = card.get("color_identity")
    if isinstance(color_identity, list):
        compact["color_identity"] = [
            value for value in color_identity if isinstance(value, str)
        ]

    image_uris = card.get("image_uris")
    if isinstance(image_uris, dict):
        compact["image_uris"] = dict(image_uris)

    card_faces = card.get("card_faces")
    if isinstance(card_faces, list):
        normalized_faces: list[dict[str, Any]] = []
        for face in card_faces:
            if not isinstance(face, dict):
                continue
            minimal_face: dict[str, Any] = {}
            for key in [
                "name",
                "printed_name",
                "type_line",
                "printed_type_line",
                "oracle_text",
                "printed_text",
                "mana_cost",
                "image_uris",
                "colors",
                "color_identity",
                "artist",
                "power",
                "toughness",
                "loyalty",
            ]:
                value = face.get(key)
                if value is not None:
                    minimal_face[key] = value
            if minimal_face:
                normalized_faces.append(minimal_face)
        if normalized_faces:
            compact["card_faces"] = normalized_faces

    prices = card.get("prices")
    if isinstance(prices, dict):
        minimal_prices = {
            key: prices[key]
            for key in ["usd", "usd_foil", "usd_etched", "eur", "eur_foil", "tix"]
            if prices.get(key) is not None
        }
        if minimal_prices:
            compact["prices"] = minimal_prices

    legalities = card.get("legalities")
    if isinstance(legalities, dict):
        compact["legalities"] = dict(legalities)

    return compact


def slugify_token(value: str) -> str:
    normalized = []
    previous_dash = False
    for char in value.strip().lower():
      if char.isalnum():
          normalized.append(char)
          previous_dash = False
      else:
          if not previous_dash:
              normalized.append("-")
              previous_dash = True
    return "".join(normalized).strip("-")


def canonical_card_id(card: dict[str, Any]) -> str:
    oracle_id = str(card.get("oracle_id") or "").strip().lower()
    if oracle_id:
        return f"mtg:card:scryfall_oracle:{oracle_id}"
    fallback = str(card.get("id") or "").strip().lower()
    if fallback:
        return f"mtg:card:scryfall:{fallback}"
    name = slugify_token(str(card.get("name") or "").strip())
    if name:
        return f"mtg:card:name:{name}"
    return "mtg:card:unknown"


def canonical_set_id(card: dict[str, Any]) -> str:
    set_code = str(card.get("set") or "").strip().lower()
    return f"mtg:set:{set_code}" if set_code else "mtg:set:unknown"


def canonical_printing_id(card: dict[str, Any]) -> str:
    printing_id = str(card.get("id") or "").strip().lower()
    return f"mtg:printing:scryfall:{printing_id}" if printing_id else "mtg:printing:unknown"


def localized_card_data(card: dict[str, Any], *, card_id: str, language: str) -> dict[str, Any]:
    name = str(card.get("printed_name") or card.get("name") or "").strip()
    subtype_line = str(card.get("printed_type_line") or card.get("type_line") or "").strip()
    rules_text = str(card.get("printed_text") or card.get("oracle_text") or "").strip()
    flavor_text = str(card.get("flavor_text") or "").strip()
    search_aliases = []
    canonical_name = str(card.get("name") or "").strip()
    if canonical_name and canonical_name.lower() != name.lower():
        search_aliases.append(canonical_name)
    return {
        "card_id": card_id,
        "language": language,
        "name": name or canonical_name,
        "subtype_line": subtype_line or None,
        "rules_text": rules_text or None,
        "flavor_text": flavor_text or None,
        "search_aliases": search_aliases,
    }


def localized_set_data(card: dict[str, Any], *, set_id: str, language: str) -> dict[str, Any]:
    set_name = str(card.get("set_name") or "").strip()
    return {
        "set_id": set_id,
        "language": language,
        "name": set_name,
        "series_name": None,
    }


def card_metadata(card: dict[str, Any]) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    for key in [
        "mana_cost",
        "type_line",
        "colors",
        "color_identity",
        "artist",
        "power",
        "toughness",
        "loyalty",
        "layout",
    ]:
        value = card.get(key)
        if value is not None:
            metadata[key] = value
    legalities = card.get("legalities")
    if isinstance(legalities, dict):
        metadata["legalities"] = legalities
    return metadata


def set_metadata(card: dict[str, Any]) -> dict[str, Any]:
    metadata: dict[str, Any] = {}
    set_type = card.get("set_type")
    if set_type is not None:
        metadata["set_type"] = set_type
    card_count = card.get("printed_size") or card.get("card_count")
    if card_count is not None:
        metadata["card_count"] = card_count
    return metadata


def printing_metadata(card: dict[str, Any], *, language: str) -> dict[str, Any]:
    metadata: dict[str, Any] = {"lang": language}
    scryfall_uri = card.get("scryfall_uri")
    if scryfall_uri is not None:
        metadata["scryfall_uri"] = scryfall_uri
    layout = card.get("layout")
    if layout is not None:
        metadata["layout"] = layout
    return metadata


def image_uris(card: dict[str, Any]) -> dict[str, str]:
    raw = card.get("image_uris")
    if not isinstance(raw, dict):
        return {}
    result: dict[str, str] = {}
    for key, value in raw.items():
        key_text = str(key).strip()
        value_text = str(value or "").strip()
        if key_text and value_text:
            result[key_text] = value_text
    return result


def finish_keys(card: dict[str, Any]) -> list[str]:
    raw = card.get("finishes")
    if not isinstance(raw, list):
        return []
    result = sorted(
        {
            str(item).strip().lower()
            for item in raw
            if str(item).strip()
        }
    )
    return result


def provider_mapping(provider_object_id: str, *, object_type: str) -> dict[str, Any]:
    return {
        "provider_id": "scryfall",
        "object_type": object_type,
        "provider_object_id": provider_object_id,
        "provider_object_version": None,
        "mapping_confidence": 1.0,
    }


def add_price_snapshots(
    snapshots: dict[tuple[str, str, str | None], dict[str, Any]],
    *,
    card: dict[str, Any],
    printing_id: str,
    captured_at: str,
) -> None:
    prices = card.get("prices")
    if not isinstance(prices, dict):
        return
    entries = [
        ("usd", None),
        ("usd_foil", "foil"),
        ("usd_etched", "etched"),
        ("eur", None),
        ("eur_foil", "foil"),
        ("tix", None),
    ]
    for price_key, finish_key in entries:
        raw_amount = prices.get(price_key)
        amount_text = str(raw_amount or "").strip()
        if not amount_text:
            continue
        try:
            amount = float(amount_text)
        except ValueError:
            continue
        currency = "tix" if price_key == "tix" else price_key.split("_", 1)[0]
        snapshots[(printing_id, currency, finish_key)] = {
            "printing_id": printing_id,
            "source_id": "scryfall",
            "currency_code": currency,
            "amount": amount,
            "captured_at": captured_at,
            "finish_key": finish_key,
        }


def build_canonical_batch(cards: list[dict[str, Any]], *, language: str, captured_at: str) -> dict[str, Any]:
    cards_by_id: dict[str, dict[str, Any]] = {}
    sets_by_id: dict[str, dict[str, Any]] = {}
    printings_by_id: dict[str, dict[str, Any]] = {}
    card_localizations: dict[tuple[str, str], dict[str, Any]] = {}
    set_localizations: dict[tuple[str, str], dict[str, Any]] = {}
    provider_mappings: dict[tuple[str, str, str, str], dict[str, Any]] = {}
    price_snapshots: dict[tuple[str, str, str | None], dict[str, Any]] = {}

    for card in cards:
        card_id = canonical_card_id(card)
        set_id = canonical_set_id(card)
        printing_id = canonical_printing_id(card)
        provider_object_id = str(card.get("id") or "").strip().lower()
        oracle_id = str(card.get("oracle_id") or "").strip().lower()
        set_code = str(card.get("set") or "").strip().lower()
        card_name = str(card.get("name") or "").strip()
        set_name = str(card.get("set_name") or "").strip()
        collector_number = str(card.get("collector_number") or "").strip()
        released_at = str(card.get("released_at") or "").strip() or None

        localized_card = localized_card_data(card, card_id=card_id, language=language)
        localized_set = localized_set_data(card, set_id=set_id, language=language)

        cards_by_id[card_id] = {
            "card_id": card_id,
            "game_id": "mtg",
            "canonical_name": card_name or localized_card["name"],
            "sort_name": None,
            "default_localized_data": localized_card,
            "localized_data": [localized_card],
            "metadata": card_metadata(card),
            "pokemon": None,
        }
        sets_by_id[set_id] = {
            "set_id": set_id,
            "game_id": "mtg",
            "code": set_code,
            "canonical_name": set_name,
            "series_id": None,
            "release_date": released_at,
            "default_localized_data": localized_set,
            "localized_data": [localized_set],
            "metadata": set_metadata(card),
        }
        printings_by_id[printing_id] = {
            "printing_id": printing_id,
            "card_id": card_id,
            "set_id": set_id,
            "game_id": "mtg",
            "collector_number": collector_number,
            "language_code": language,
            "provider_mappings": [provider_mapping(provider_object_id, object_type="printing")],
            "rarity": str(card.get("rarity") or "").strip() or None,
            "release_date": released_at,
            "image_uris": image_uris(card),
            "finish_keys": finish_keys(card),
            "metadata": printing_metadata(card, language=language),
        }
        card_localizations[(card_id, language)] = localized_card
        set_localizations[(set_id, language)] = localized_set

        if oracle_id:
            provider_mappings[("scryfall", "card", oracle_id, card_id)] = {
                "mapping": provider_mapping(oracle_id, object_type="card"),
                "card_id": card_id,
                "printing_id": None,
                "set_id": None,
            }
        if set_code:
            provider_mappings[("scryfall", "set", set_code, set_id)] = {
                "mapping": provider_mapping(set_code, object_type="set"),
                "card_id": None,
                "printing_id": None,
                "set_id": set_id,
            }
        if provider_object_id:
            provider_mappings[("scryfall", "printing", provider_object_id, printing_id)] = {
                "mapping": provider_mapping(provider_object_id, object_type="printing"),
                "card_id": card_id,
                "printing_id": printing_id,
                "set_id": set_id,
            }

        add_price_snapshots(
            price_snapshots,
            card=card,
            printing_id=printing_id,
            captured_at=captured_at,
        )

    return {
        "cards": list(cards_by_id.values()),
        "sets": list(sets_by_id.values()),
        "printings": list(printings_by_id.values()),
        "card_localizations": list(card_localizations.values()),
        "set_localizations": list(set_localizations.values()),
        "provider_mappings": list(provider_mappings.values()),
        "price_snapshots": list(price_snapshots.values()),
    }


def write_json_gzip(payload: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="") as output:
        json.dump(payload, output, ensure_ascii=False, separators=(",", ":"))


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "accept": "application/json",
            "user-agent": "bindervault-mtg-bundle-builder/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def resolve_bulk_entry(bulk_type: str) -> dict[str, Any]:
    payload = fetch_json(BULK_ENDPOINT)
    data = payload.get("data")
    if not isinstance(data, list):
        raise RuntimeError("Scryfall bulk endpoint returned no data list.")
    for item in data:
        if isinstance(item, dict) and item.get("type") == bulk_type:
            return item
    raise RuntimeError(f"Scryfall bulk type not found: {bulk_type}")


def download_file(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f"{destination.name}.", suffix=".download", dir=str(destination.parent)
    )
    os.close(fd)
    tmp_path = Path(tmp_name)
    try:
        request = urllib.request.Request(
            url, headers={"user-agent": "bindervault-mtg-bundle-builder/1.0"}
        )
        with urllib.request.urlopen(request, timeout=120) as response:
            with tmp_path.open("wb") as output:
                shutil.copyfileobj(response, output)
        tmp_path.replace(destination)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def ensure_bulk_file(
    *,
    bulk_entry: dict[str, Any],
    bulk_type: str,
    cache_dir: Path,
    force_download: bool,
) -> Path:
    updated_at = str(bulk_entry.get("updated_at") or "").strip()
    download_uri = str(bulk_entry.get("download_uri") or "").strip()
    if not updated_at or not download_uri:
        raise RuntimeError("Scryfall bulk entry is missing updated_at/download_uri.")

    safe_updated_at = safe_version_token(updated_at)
    target = cache_dir / f"scryfall_{bulk_type}_{safe_updated_at}.json"
    metadata_path = cache_dir / f"scryfall_{bulk_type}_latest.json"
    if force_download or not target.exists():
        print(f"[mtg] downloading {bulk_type} bulk: {download_uri}")
        download_file(download_uri, target)
    else:
        print(f"[mtg] using cached {bulk_type} bulk: {target}")

    cache_dir.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(
        json.dumps(
            {
                "bulk_type": bulk_type,
                "updated_at": updated_at,
                "download_uri": download_uri,
                "path": str(target),
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    return target


def write_json_array_gzip(cards: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(path, "wt", encoding="utf-8", newline="") as output:
        json.dump(cards, output, ensure_ascii=False, separators=(",", ":"))


def iter_json_array_objects(path: Path) -> Iterator[dict[str, Any]]:
    decoder = json.JSONDecoder()
    buffer = ""
    in_array = False
    with path.open("r", encoding="utf-8") as input_file:
        while True:
            chunk = input_file.read(1024 * 1024)
            if not chunk:
                break
            buffer += chunk
            while True:
                stripped = buffer.lstrip()
                if not in_array:
                    if not stripped:
                        buffer = stripped
                        break
                    if stripped[0] != "[":
                        raise RuntimeError(
                            "Expected Scryfall bulk payload to be a JSON array."
                        )
                    in_array = True
                    buffer = stripped[1:]
                    continue

                buffer = buffer.lstrip()
                if not buffer:
                    break
                if buffer[0] == ",":
                    buffer = buffer[1:]
                    continue
                if buffer[0] == "]":
                    return
                try:
                    value, end = decoder.raw_decode(buffer)
                except json.JSONDecodeError:
                    break
                buffer = buffer[end:]
                if isinstance(value, dict):
                    yield value

    tail = buffer.strip()
    if tail and tail != "]":
        raise RuntimeError("Scryfall bulk payload ended before JSON array closed.")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        for chunk in iter(lambda: input_file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def artifact_entry(path: Path) -> dict[str, Any]:
    return {
        "name": path.name,
        "path": path.name,
        "size_bytes": path.stat().st_size,
        "sha256": sha256_file(path),
    }


def canonical_artifact_payload(
    batch: dict[str, Any],
    *,
    language_signature: str,
) -> dict[str, Any]:
    return {
        "schema_version": CANONICAL_SCHEMA_VERSION,
        "compatibility_version": CANONICAL_COMPATIBILITY_VERSION,
        "profile": CANONICAL_PROFILE,
        "languages_signature": language_signature,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "batch": batch,
    }


def build_bundle(
    *,
    source_path: Path,
    output_dir: Path,
    version: str,
    languages: list[str],
    bulk_entry: dict[str, Any],
    bulk_type: str,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    language_sets = {language: [] for language in languages}
    counts = {language: 0 for language in languages}

    print(f"[mtg] reading {source_path}")
    for item in iter_json_array_objects(source_path):
        language = str(item.get("lang") or "").strip().lower()
        if language not in language_sets:
            continue
        language_sets[language].append(compact_scryfall_card(item))
        counts[language] += 1

    bundles: list[dict[str, Any]] = []
    all_artifacts: list[dict[str, Any]] = []
    canonical_bundles: list[dict[str, Any]] = []
    canonical_artifacts: list[dict[str, Any]] = []
    canonical_counts: dict[str, dict[str, int]] = {}
    captured_at = str(bulk_entry.get("updated_at") or datetime.now(timezone.utc).isoformat())
    for index, language in enumerate(languages):
        kind = "base" if language == "en" else "delta"
        bundle_id = f"{kind}_{language}"
        artifact_name = f"mtg_{kind}_{language}.json.gz"
        artifact_path = output_dir / artifact_name
        write_json_array_gzip(language_sets[language], artifact_path)
        artifact = artifact_entry(artifact_path)
        all_artifacts.append(artifact)
        bundles.append(
            {
                "id": bundle_id,
                "kind": kind,
                "schema_version": SCHEMA_VERSION,
                "compatibility_version": COMPATIBILITY_VERSION,
                "language": language,
                "requires": [] if index == 0 else ["base_en"],
                "counts": {"cards": counts[language]},
                "artifacts": [artifact],
            }
        )
        print(f"[mtg] wrote {artifact_name}: {counts[language]} cards")

        canonical_batch = build_canonical_batch(
            language_sets[language],
            language=language,
            captured_at=captured_at,
        )
        canonical_payload = canonical_artifact_payload(
            canonical_batch,
            language_signature=language,
        )
        canonical_artifact_name = f"canonical_catalog_snapshot_{language}.json.gz"
        canonical_artifact_path = output_dir / canonical_artifact_name
        write_json_gzip(canonical_payload, canonical_artifact_path)
        canonical_artifact = artifact_entry(canonical_artifact_path)
        canonical_artifacts.append(canonical_artifact)
        canonical_bundle_id = f"canonical_{kind}_{language}"
        canonical_bundles.append(
            {
                "id": canonical_bundle_id,
                "kind": kind,
                "schema_version": CANONICAL_SCHEMA_VERSION,
                "compatibility_version": CANONICAL_COMPATIBILITY_VERSION,
                "profile": CANONICAL_PROFILE,
                "languages": [language],
                "requires": [] if index == 0 else ["canonical_base_en"],
                "counts": {
                    "cards": len(canonical_batch["cards"]),
                    "sets": len(canonical_batch["sets"]),
                    "printings": len(canonical_batch["printings"]),
                    "card_localizations": len(canonical_batch["card_localizations"]),
                    "set_localizations": len(canonical_batch["set_localizations"]),
                    "provider_mappings": len(canonical_batch["provider_mappings"]),
                    "price_snapshots": len(canonical_batch["price_snapshots"]),
                },
                "artifacts": [canonical_artifact],
            }
        )
        canonical_counts[language] = canonical_bundles[-1]["counts"]
        print(
            "[mtg] wrote "
            f"{canonical_artifact_name}: "
            f"{len(canonical_batch['cards'])} cards, "
            f"{len(canonical_batch['printings'])} printings"
        )

    manifest = {
        "bundle": "mtg",
        "version": version,
        "schema_version": SCHEMA_VERSION,
        "compatibility_version": COMPATIBILITY_VERSION,
        "mode": "base_plus_delta",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": {
            "kind": "scryfall_bulk",
            "bulk_type": bulk_type,
            "updated_at": bulk_entry.get("updated_at"),
            "download_uri": bulk_entry.get("download_uri"),
            "size_bytes": bulk_entry.get("size"),
        },
        "languages": languages,
        "counts": counts,
        "artifacts": all_artifacts,
        "bundles": bundles,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"[mtg] wrote manifest.json version={version}")

    canonical_manifest = {
        "bundle": "mtg",
        "version": version,
        "schema_version": CANONICAL_SCHEMA_VERSION,
        "compatibility_version": CANONICAL_COMPATIBILITY_VERSION,
        "profile": CANONICAL_PROFILE,
        "mode": "canonical_base_plus_delta",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": {
            "kind": "scryfall_bulk",
            "bulk_type": bulk_type,
            "updated_at": bulk_entry.get("updated_at"),
            "download_uri": bulk_entry.get("download_uri"),
            "size_bytes": bulk_entry.get("size"),
        },
        "languages": languages,
        "counts": canonical_counts,
        "artifacts": canonical_artifacts,
        "bundles": canonical_bundles,
    }
    (output_dir / "manifest_canonical.json").write_text(
        json.dumps(canonical_manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"[mtg] wrote manifest_canonical.json version={version}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--cache-dir", default=DEFAULT_CACHE_DIR)
    parser.add_argument("--bulk-type", default="all_cards")
    parser.add_argument("--languages", default="en,it")
    parser.add_argument("--version", default="")
    parser.add_argument("--force-download", action="store_true")
    parser.add_argument("--force-build", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    languages = [
        item.strip().lower()
        for item in args.languages.split(",")
        if item.strip()
    ]
    if "en" not in languages:
        raise RuntimeError("MTG bundle requires English as the base language.")
    if languages[0] != "en":
        languages = ["en", *[language for language in languages if language != "en"]]

    output_dir = Path(args.output_dir)
    cache_dir = Path(args.cache_dir)
    bulk_entry = resolve_bulk_entry(args.bulk_type)
    updated_at = str(bulk_entry.get("updated_at") or "").strip()
    if not updated_at:
        raise RuntimeError("Scryfall bulk updated_at is missing.")
    version = args.version.strip()
    if not version:
        source_part = safe_version_token(updated_at)
        version = f"{source_part}-full-base-delta-compat1"

    existing_manifest = output_dir / "manifest.json"
    if existing_manifest.exists() and not args.force_build:
        try:
            existing = json.loads(existing_manifest.read_text(encoding="utf-8"))
            source = existing.get("source") if isinstance(existing, dict) else None
            if (
                isinstance(source, dict)
                and source.get("updated_at") == updated_at
                and existing.get("version") == version
            ):
                print("[mtg] existing bundle is current; use --force-build to rebuild")
                return 0
        except Exception:
            pass

    source_path = ensure_bulk_file(
        bulk_entry=bulk_entry,
        bulk_type=args.bulk_type,
        cache_dir=cache_dir,
        force_download=args.force_download,
    )
    if output_dir.exists():
        shutil.rmtree(output_dir)
    build_bundle(
        source_path=source_path,
        output_dir=output_dir,
        version=version,
        languages=languages,
        bulk_entry=bulk_entry,
        bulk_type=args.bulk_type,
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"[mtg] error: {error}", file=sys.stderr)
        raise SystemExit(1)
