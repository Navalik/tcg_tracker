#!/usr/bin/env python3
"""
Build offline Pokemon bundle artifacts from a local data checkout.

Outputs:
  - canonical_catalog_snapshot.json.gz
  - pokemon_legacy.db.gz
  - manifest.json

The script is intentionally local-first: no app-side heavy processing required.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import gzip
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


SUPPORTED_LANGS = {"en", "it", "fr", "de", "es", "pt", "ja", "ko", "zh"}
TCGDEX_API_BASE = "https://api.tcgdex.net/v2"
CANONICAL_SNAPSHOT_SCHEMA_VERSION = 2
POKEMON_BUNDLE_COMPATIBILITY_VERSION = 2


@dataclass
class LocalizedName:
    language: str
    name: str
    subtype_line: Optional[str] = None
    rules_text: Optional[str] = None
    flavor_text: Optional[str] = None


@dataclass
class PrintingRecord:
    printing_id: str
    card_id: str
    provider_object_id: str
    set_code: str
    set_name_by_lang: Dict[str, str] = field(default_factory=dict)
    set_release_date: Optional[str] = None
    set_total: Optional[int] = None
    collector_number: str = ""
    rarity: Optional[str] = None
    image_small: Optional[str] = None
    image_large: Optional[str] = None
    artist: Optional[str] = None
    colors: List[str] = field(default_factory=list)
    color_identity: List[str] = field(default_factory=list)
    mana_value: Optional[float] = None
    localized_names: Dict[str, LocalizedName] = field(default_factory=dict)
    pokemon_meta: Dict[str, Any] = field(default_factory=dict)
    source_raw: Dict[str, Any] = field(default_factory=dict)


def _canonical_card_id(provider_object_id: str) -> str:
    return f"pokemon:card:tcgdex:{provider_object_id.lower()}"


def _canonical_printing_id(provider_object_id: str) -> str:
    return f"pokemon:printing:tcgdex:{provider_object_id.lower()}"


def _json_load(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _normalize_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _normalize_language(value: Optional[str]) -> str:
    if not value:
        return ""
    return value.strip().lower()


def _detect_language_from_path(path: Path) -> str:
    tokens = [p.lower() for p in path.parts]
    for token in tokens:
        if token in SUPPORTED_LANGS:
            return token
    return ""


def _safe_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except Exception:
        return None


def _safe_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    s = str(value).strip()
    if not s:
        return None
    digits = "".join(ch for ch in s if ch.isdigit())
    if not digits:
        return None
    try:
        return int(digits)
    except Exception:
        return None


def _normalize_collector(value: Any) -> str:
    raw = _normalize_text(value)
    if not raw:
        return ""
    raw = raw.replace("#", "").replace("No.", "").strip()
    if "/" in raw:
        raw = raw.split("/", 1)[0].strip()
    return raw.lower()


def _extract_set_code(card: Dict[str, Any], file_path: Path) -> str:
    set_obj = card.get("set")
    candidates: List[str] = []
    if isinstance(set_obj, dict):
        candidates.extend(
            [
                _normalize_text(set_obj.get("id")),
                _normalize_text(set_obj.get("code")),
                _normalize_text(set_obj.get("ptcgoCode")),
            ]
        )
    candidates.extend(
        [
            _normalize_text(card.get("setCode")),
            _normalize_text(card.get("set_id")),
            _normalize_text(card.get("set")),
        ]
    )
    card_id = _normalize_text(card.get("id"))
    if "-" in card_id:
        candidates.append(card_id.split("-", 1)[0])

    stem = file_path.stem.lower()
    if stem not in {"cards", "sets", "set"}:
        candidates.append(stem)

    for c in candidates:
        c = c.strip().lower()
        if c and c not in {"en", "it"}:
            return c
    return "unknown"


def _extract_set_name(card: Dict[str, Any]) -> str:
    set_obj = card.get("set")
    if isinstance(set_obj, dict):
        name = _normalize_text(set_obj.get("name"))
        if name:
            return name
    return _normalize_text(card.get("set_name"))


def _extract_release_date(card: Dict[str, Any]) -> Optional[str]:
    set_obj = card.get("set")
    date = None
    if isinstance(set_obj, dict):
        date = _normalize_text(set_obj.get("releaseDate"))
    if not date:
        date = _normalize_text(card.get("released_at"))
    if not date:
        return None
    # Keep YYYY-MM-DD or ISO-ish input as-is.
    return date


def _extract_collector(card: Dict[str, Any]) -> str:
    return (
        _normalize_collector(card.get("collector_number"))
        or _normalize_collector(card.get("number"))
        or _normalize_collector(card.get("localId"))
    )


def _extract_card_name(card: Dict[str, Any]) -> str:
    return _normalize_text(card.get("name"))


def _extract_images(card: Dict[str, Any]) -> Tuple[Optional[str], Optional[str]]:
    images = card.get("images")
    if isinstance(images, dict):
        small = _normalize_text(images.get("small")) or None
        large = (
            _normalize_text(images.get("large"))
            or _normalize_text(images.get("high"))
            or _normalize_text(images.get("normal"))
            or None
        )
        return small, large
    image = card.get("image")
    if isinstance(image, str):
        return image, image
    return None, None


def _extract_types(card: Dict[str, Any]) -> List[str]:
    value = card.get("types")
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    return []


def _to_color_codes(types: Iterable[str]) -> List[str]:
    mapping = {
        "grass": "G",
        "fire": "R",
        "water": "U",
        "lightning": "L",
        "electric": "L",
        "psychic": "P",
        "darkness": "D",
        "fighting": "F",
        "metal": "M",
        "dragon": "N",
        "fairy": "Y",
        "colorless": "C",
    }
    out: List[str] = []
    seen = set()
    for t in types:
        code = mapping.get(t.strip().lower())
        if not code or code in seen:
            continue
        seen.add(code)
        out.append(code)
    return out


def _extract_subtype_line(card: Dict[str, Any]) -> Optional[str]:
    parts: List[str] = []
    category = _normalize_text(card.get("category"))
    if category:
        parts.append(category)
    subtypes = card.get("subtypes")
    if isinstance(subtypes, list) and subtypes:
        joined = ", ".join(str(v).strip() for v in subtypes if str(v).strip())
        if joined:
            parts.append(f"({joined})")
    text = " ".join(parts).strip()
    return text or None


def _is_card_object(obj: Dict[str, Any]) -> bool:
    # Loose heuristics to support multiple upstream formats.
    if "name" not in obj:
        return False
    if "id" in obj:
        return True
    if "number" in obj and "set" in obj:
        return True
    return False


def _iter_card_objects(payload: Any) -> Iterable[Dict[str, Any]]:
    if isinstance(payload, dict):
        if _is_card_object(payload):
            yield payload
            return
        cards = payload.get("cards")
        if isinstance(cards, list):
            for item in cards:
                if isinstance(item, dict) and _is_card_object(item):
                    yield item
            return
    if isinstance(payload, list):
        for item in payload:
            if isinstance(item, dict) and _is_card_object(item):
                yield item


def _load_records(source_dir: Path, languages: List[str]) -> Dict[str, PrintingRecord]:
    records: Dict[str, PrintingRecord] = {}
    json_files = sorted(source_dir.rglob("*.json"))
    if not json_files:
        raise RuntimeError(f"No JSON files found under: {source_dir}")

    for idx, path in enumerate(json_files, 1):
        try:
            payload = _json_load(path)
        except Exception:
            continue

        language_from_path = _detect_language_from_path(path)
        for card in _iter_card_objects(payload):
            language = _normalize_language(
                _normalize_text(card.get("language")) or language_from_path
            )
            if language and language not in languages:
                continue

            set_code = _extract_set_code(card, path)
            collector = _extract_collector(card)
            name = _extract_card_name(card)
            if not name:
                continue

            raw_id = _normalize_text(card.get("id"))
            provider_object_id = raw_id or f"{set_code}-{collector or name.lower()}"
            printing_id = _canonical_printing_id(provider_object_id)
            card_id = _canonical_card_id(provider_object_id)

            record = records.get(printing_id)
            if record is None:
                small, large = _extract_images(card)
                types = _extract_types(card)
                colors = _to_color_codes(types)
                record = PrintingRecord(
                    printing_id=printing_id,
                    card_id=card_id,
                    provider_object_id=provider_object_id,
                    set_code=set_code,
                    collector_number=collector,
                    rarity=_normalize_text(card.get("rarity")) or None,
                    image_small=small,
                    image_large=large,
                    artist=_normalize_text(card.get("illustrator")) or None,
                    colors=colors,
                    color_identity=list(colors),
                    mana_value=_safe_float(card.get("convertedRetreatCost")),
                    set_release_date=_extract_release_date(card),
                    set_total=_safe_int(
                        (card.get("set") or {}).get("cardCount")
                        if isinstance(card.get("set"), dict)
                        else None
                    ),
                    pokemon_meta={
                        "category": _normalize_text(card.get("category")) or None,
                        "hp": _safe_int(card.get("hp")),
                        "types": types,
                        "subtypes": card.get("subtypes") if isinstance(card.get("subtypes"), list) else [],
                        "stage": _normalize_text(card.get("stage")) or None,
                        "evolves_from": _normalize_text(card.get("evolveFrom")) or None,
                        "regulation_mark": _normalize_text(card.get("regulationMark")) or None,
                        "retreat_cost": _safe_int(card.get("retreat")),
                        "weaknesses": card.get("weaknesses") if isinstance(card.get("weaknesses"), list) else [],
                        "resistances": card.get("resistances") if isinstance(card.get("resistances"), list) else [],
                        "attacks": card.get("attacks") if isinstance(card.get("attacks"), list) else [],
                        "abilities": card.get("abilities") if isinstance(card.get("abilities"), list) else [],
                        "illustrator": _normalize_text(card.get("illustrator")) or None,
                    },
                    source_raw=card,
                )
                records[printing_id] = record

            set_name = _extract_set_name(card)
            if set_name:
                lang_key = language or "en"
                record.set_name_by_lang.setdefault(lang_key, set_name)

            localized = LocalizedName(
                language=language or "en",
                name=name,
                subtype_line=_extract_subtype_line(card),
                rules_text=_normalize_text(card.get("effect")) or None,
                flavor_text=_normalize_text(card.get("description")) or None,
            )
            record.localized_names[localized.language] = localized

        if idx % 2000 == 0:
            print(f"[scan] processed {idx}/{len(json_files)} json files")

    return records


def _download_to_temp(url: str) -> Path:
    fd, tmp_path = tempfile.mkstemp(prefix="pokemon_bundle_", suffix=".zip")
    os.close(fd)
    tmp = Path(tmp_path)
    print(f"[download] {url}")
    with urllib.request.urlopen(url) as resp, tmp.open("wb") as out:
        while True:
            chunk = resp.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
    return tmp


def _load_records_from_zip(zip_source: str, languages: List[str]) -> Dict[str, PrintingRecord]:
    cleanup_tmp = False
    if zip_source.lower().startswith("http://") or zip_source.lower().startswith("https://"):
        zip_path = _download_to_temp(zip_source)
        cleanup_tmp = True
    else:
        zip_path = Path(zip_source).resolve()
        if not zip_path.exists():
            raise RuntimeError(f"zip source not found: {zip_path}")

    records: Dict[str, PrintingRecord] = {}
    try:
        with zipfile.ZipFile(zip_path, "r") as zf:
            members = [m for m in zf.infolist() if not m.is_dir() and m.filename.lower().endswith(".json")]
            if not members:
                raise RuntimeError("no .json entries found in zip source")
            for idx, member in enumerate(members, 1):
                try:
                    with zf.open(member, "r") as f:
                        raw = f.read()
                    payload = json.loads(raw.decode("utf-8", errors="replace"))
                except Exception:
                    continue

                fake_path = Path(member.filename)
                language_from_path = _detect_language_from_path(fake_path)
                for card in _iter_card_objects(payload):
                    language = _normalize_language(
                        _normalize_text(card.get("language")) or language_from_path
                    )
                    if language and language not in languages:
                        continue

                    set_code = _extract_set_code(card, fake_path)
                    collector = _extract_collector(card)
                    name = _extract_card_name(card)
                    if not name:
                        continue

                    raw_id = _normalize_text(card.get("id"))
                    provider_object_id = raw_id or f"{set_code}-{collector or name.lower()}"
                    printing_id = _canonical_printing_id(provider_object_id)
                    card_id = _canonical_card_id(provider_object_id)

                    record = records.get(printing_id)
                    if record is None:
                        small, large = _extract_images(card)
                        types = _extract_types(card)
                        colors = _to_color_codes(types)
                        record = PrintingRecord(
                            printing_id=printing_id,
                            card_id=card_id,
                            provider_object_id=provider_object_id,
                            set_code=set_code,
                            collector_number=collector,
                            rarity=_normalize_text(card.get("rarity")) or None,
                            image_small=small,
                            image_large=large,
                            artist=_normalize_text(card.get("illustrator")) or None,
                            colors=colors,
                            color_identity=list(colors),
                            mana_value=_safe_float(card.get("convertedRetreatCost")),
                            set_release_date=_extract_release_date(card),
                            set_total=_safe_int(
                                (card.get("set") or {}).get("cardCount")
                                if isinstance(card.get("set"), dict)
                                else None
                            ),
                            pokemon_meta={
                                "category": _normalize_text(card.get("category")) or None,
                                "hp": _safe_int(card.get("hp")),
                                "types": types,
                                "subtypes": card.get("subtypes") if isinstance(card.get("subtypes"), list) else [],
                                "stage": _normalize_text(card.get("stage")) or None,
                                "evolves_from": _normalize_text(card.get("evolveFrom")) or None,
                                "regulation_mark": _normalize_text(card.get("regulationMark")) or None,
                                "retreat_cost": _safe_int(card.get("retreat")),
                                "weaknesses": card.get("weaknesses") if isinstance(card.get("weaknesses"), list) else [],
                                "resistances": card.get("resistances") if isinstance(card.get("resistances"), list) else [],
                                "attacks": card.get("attacks") if isinstance(card.get("attacks"), list) else [],
                                "abilities": card.get("abilities") if isinstance(card.get("abilities"), list) else [],
                                "illustrator": _normalize_text(card.get("illustrator")) or None,
                            },
                            source_raw=card,
                        )
                        records[printing_id] = record

                    set_name = _extract_set_name(card)
                    if set_name:
                        lang_key = language or "en"
                        record.set_name_by_lang.setdefault(lang_key, set_name)

                    localized = LocalizedName(
                        language=language or "en",
                        name=name,
                        subtype_line=_extract_subtype_line(card),
                        rules_text=_normalize_text(card.get("effect")) or None,
                        flavor_text=_normalize_text(card.get("description")) or None,
                    )
                    record.localized_names[localized.language] = localized

                if idx % 4000 == 0:
                    print(f"[scan] processed {idx}/{len(members)} zip entries")
    finally:
        if cleanup_tmp:
            try:
                zip_path.unlink(missing_ok=True)
            except Exception:
                pass
    return records


def _http_get_json(url: str, *, timeout_sec: int = 35, retries: int = 4) -> Any:
    last_error: Optional[Exception] = None
    headers = {"User-Agent": "tcg-tracker-bundle-builder/1.0"}
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout_sec) as resp:
                raw = resp.read()
            return json.loads(raw.decode("utf-8"))
        except Exception as exc:
            last_error = exc
            if attempt < retries:
                time.sleep(min(6, attempt * 1.2))
    if last_error is not None:
        raise last_error
    raise RuntimeError(f"failed to fetch json: {url}")


def _normalize_tcgdex_image(image_url: str) -> Tuple[Optional[str], Optional[str]]:
    image = _normalize_text(image_url)
    if not image:
        return None, None
    # TCGdex provides a base asset URL; keep same URL for both sizes.
    return image, image


def _extract_tcgdex_subtype_line(card: Dict[str, Any]) -> Optional[str]:
    stage = _normalize_text(card.get("stage"))
    trainer_type = _normalize_text(card.get("trainerType"))
    if trainer_type:
        return trainer_type
    if stage:
        return stage
    return None


def _extract_tcgdex_rules_text(card: Dict[str, Any]) -> Optional[str]:
    effect = _normalize_text(card.get("effect"))
    if effect:
        return effect
    abilities = card.get("abilities")
    if isinstance(abilities, list):
        parts: List[str] = []
        for ability in abilities:
            if not isinstance(ability, dict):
                continue
            name = _normalize_text(ability.get("name"))
            text = _normalize_text(ability.get("effect") or ability.get("text"))
            if name and text:
                parts.append(f"{name}: {text}")
            elif text:
                parts.append(text)
        if parts:
            return " | ".join(parts)
    return None


def _load_records_from_tcgdex_api(
    *,
    languages: List[str],
    workers: int = 8,
    max_sets_per_lang: int = 0,
    max_cards_per_lang: int = 0,
) -> Dict[str, PrintingRecord]:
    records: Dict[str, PrintingRecord] = {}
    set_meta_by_lang: Dict[str, Dict[str, Dict[str, Any]]] = {}
    card_ids_by_lang: Dict[str, List[str]] = {}

    for lang in languages:
        sets_url = f"{TCGDEX_API_BASE}/{lang}/sets"
        print(f"[api] fetching sets list lang={lang}")
        sets_payload = _http_get_json(sets_url)
        if not isinstance(sets_payload, list):
            raise RuntimeError(f"invalid sets payload for lang={lang}")
        set_ids = [
            _normalize_text(item.get("id")).strip()
            for item in sets_payload
            if isinstance(item, dict)
        ]
        set_ids = [sid for sid in set_ids if sid]
        if max_sets_per_lang > 0:
            set_ids = set_ids[:max_sets_per_lang]
        set_meta: Dict[str, Dict[str, Any]] = {}
        card_ids: List[str] = []
        for idx, set_id in enumerate(set_ids, 1):
            detail_url = f"{TCGDEX_API_BASE}/{lang}/sets/{set_id}"
            try:
                detail = _http_get_json(detail_url)
            except Exception:
                continue
            if not isinstance(detail, dict):
                continue
            cards = detail.get("cards")
            ids_for_set: List[str] = []
            if isinstance(cards, list):
                for card in cards:
                    if not isinstance(card, dict):
                        continue
                    cid = _normalize_text(card.get("id")).strip()
                    if cid:
                        ids_for_set.append(cid)
                        card_ids.append(cid)
            set_meta[set_id.lower()] = {
                "name": _normalize_text(detail.get("name")),
                "release_date": _normalize_text(detail.get("releaseDate")) or None,
                "total": _safe_int((detail.get("cardCount") or {}).get("total"))
                if isinstance(detail.get("cardCount"), dict)
                else None,
                "card_ids": ids_for_set,
            }
            if idx % 25 == 0:
                print(f"[api] lang={lang} sets {idx}/{len(set_ids)}")
        deduped_ids = sorted(set(card_ids))
        if max_cards_per_lang > 0:
            deduped_ids = deduped_ids[:max_cards_per_lang]
        set_meta_by_lang[lang] = set_meta
        card_ids_by_lang[lang] = deduped_ids
        print(f"[api] lang={lang} set_count={len(set_meta)} card_ids={len(deduped_ids)}")

    def fetch_card(lang: str, card_id: str) -> Tuple[str, str, Optional[Dict[str, Any]]]:
        url = f"{TCGDEX_API_BASE}/{lang}/cards/{card_id}"
        try:
            payload = _http_get_json(url)
            if isinstance(payload, dict):
                return lang, card_id, payload
            return lang, card_id, None
        except Exception:
            return lang, card_id, None

    for lang in languages:
        ids = card_ids_by_lang.get(lang, [])
        if not ids:
            continue
        print(f"[api] fetching card details lang={lang} count={len(ids)} workers={workers}")
        done = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
            futures = [executor.submit(fetch_card, lang, cid) for cid in ids]
            for fut in concurrent.futures.as_completed(futures):
                done += 1
                lg, _cid, card = fut.result()
                if not card:
                    if done % 500 == 0:
                        print(f"[api] lang={lg} details {done}/{len(ids)}")
                    continue
                card_id = _normalize_text(card.get("id")).strip()
                if not card_id:
                    if done % 500 == 0:
                        print(f"[api] lang={lg} details {done}/{len(ids)}")
                    continue
                provider_object_id = card_id
                printing_id = _canonical_printing_id(provider_object_id)
                canonical_card_id = _canonical_card_id(provider_object_id)
                set_obj = card.get("set") if isinstance(card.get("set"), dict) else {}
                set_code = _normalize_text(set_obj.get("id")).lower()
                if not set_code and "-" in printing_id:
                    set_code = provider_object_id.lower().split("-", 1)[0]
                if not set_code:
                    set_code = "unknown"

                small_image, large_image = _normalize_tcgdex_image(_normalize_text(card.get("image")))
                types = [str(v) for v in (card.get("types") if isinstance(card.get("types"), list) else [])]
                colors = _to_color_codes(types)
                set_meta = set_meta_by_lang.get(lg, {}).get(set_code, {})
                set_name = _normalize_text(set_obj.get("name")) or _normalize_text(set_meta.get("name"))
                collector = _normalize_collector(card.get("localId") or card.get("number"))

                record = records.get(printing_id)
                if record is None:
                    record = PrintingRecord(
                        printing_id=printing_id,
                        card_id=canonical_card_id,
                        provider_object_id=provider_object_id,
                        set_code=set_code,
                        collector_number=collector,
                        rarity=_normalize_text(card.get("rarity")) or None,
                        image_small=small_image,
                        image_large=large_image,
                        artist=_normalize_text(card.get("illustrator")) or None,
                        colors=list(colors),
                        color_identity=list(colors),
                        mana_value=_safe_float(card.get("hp")),
                        set_release_date=_normalize_text(set_meta.get("release_date")) or None,
                        set_total=_safe_int(set_meta.get("total")),
                        pokemon_meta={
                            "category": _normalize_text(card.get("category")) or None,
                            "stage": _normalize_text(card.get("stage")) or None,
                            "trainerType": _normalize_text(card.get("trainerType")) or None,
                            "regulationMark": _normalize_text(card.get("regulationMark")) or None,
                            "hp": _normalize_text(card.get("hp")) or None,
                            "retreat": _safe_int(card.get("retreat")),
                            "dexId": card.get("dexId") if isinstance(card.get("dexId"), list) else [],
                            "types": types,
                            "abilities": card.get("abilities") if isinstance(card.get("abilities"), list) else [],
                            "attacks": card.get("attacks") if isinstance(card.get("attacks"), list) else [],
                            "weaknesses": card.get("weaknesses") if isinstance(card.get("weaknesses"), list) else [],
                            "resistances": card.get("resistances") if isinstance(card.get("resistances"), list) else [],
                            "effect": _normalize_text(card.get("effect")) or None,
                        },
                        source_raw=card,
                    )
                    records[printing_id] = record

                if set_name:
                    record.set_name_by_lang[lg] = set_name
                localized = LocalizedName(
                    language=lg,
                    name=_normalize_text(card.get("name")) or provider_object_id,
                    subtype_line=_extract_tcgdex_subtype_line(card),
                    rules_text=_extract_tcgdex_rules_text(card),
                    flavor_text=_normalize_text(card.get("description")) or None,
                )
                record.localized_names[lg] = localized
                if done % 500 == 0:
                    print(f"[api] lang={lg} details {done}/{len(ids)}")

    return records


def _choose_primary_localized(
    localized_by_lang: Dict[str, LocalizedName], languages: List[str]
) -> LocalizedName:
    for code in languages:
        if code in localized_by_lang:
            return localized_by_lang[code]
    if "en" in localized_by_lang:
        return localized_by_lang["en"]
    return next(iter(localized_by_lang.values()))


def _build_canonical_snapshot(
    records: Dict[str, PrintingRecord],
    profile: str,
    languages: List[str],
) -> Dict[str, Any]:
    cards: List[Dict[str, Any]] = []
    sets_by_code: Dict[str, Dict[str, Any]] = {}
    printings: List[Dict[str, Any]] = []
    card_localizations: List[Dict[str, Any]] = []
    set_localizations: List[Dict[str, Any]] = []
    provider_mappings: List[Dict[str, Any]] = []

    for record in records.values():
        if not record.localized_names:
            continue
        primary = _choose_primary_localized(record.localized_names, languages)
        set_id = f"pokemon_set:{record.set_code}"
        set_name = (
            record.set_name_by_lang.get(primary.language)
            or record.set_name_by_lang.get("en")
            or record.set_code.upper()
        )
        if record.set_code not in sets_by_code:
            sets_by_code[record.set_code] = {
                "set_id": set_id,
                "game_id": "pokemon",
                "code": record.set_code,
                "canonical_name": set_name,
                "series_id": None,
                "release_date": record.set_release_date,
                "default_localized_data": {
                    "set_id": set_id,
                    "language": primary.language,
                    "name": set_name,
                    "series_name": None,
                },
                "localized_data": [],
                "metadata": {"card_count": record.set_total},
            }
        for lang, localized_set_name in sorted(record.set_name_by_lang.items()):
            set_localizations.append(
                {
                    "set_id": set_id,
                    "language": lang,
                    "name": localized_set_name,
                    "series_name": None,
                }
            )

        cards.append(
            {
                "card_id": record.card_id,
                "game_id": "pokemon",
                "canonical_name": primary.name,
                "sort_name": primary.name.lower(),
                "default_localized_data": {
                    "card_id": record.card_id,
                    "language": primary.language,
                    "name": primary.name,
                    "subtype_line": primary.subtype_line,
                    "rules_text": primary.rules_text,
                    "flavor_text": primary.flavor_text,
                    "search_aliases": [],
                },
                "localized_data": [],
                "metadata": {"source_provider_object_id": record.provider_object_id},
                "pokemon": record.pokemon_meta,
            }
        )

        for localized in sorted(record.localized_names.values(), key=lambda x: x.language):
            card_localizations.append(
                {
                    "card_id": record.card_id,
                    "language": localized.language,
                    "name": localized.name,
                    "subtype_line": localized.subtype_line,
                    "rules_text": localized.rules_text,
                    "flavor_text": localized.flavor_text,
                    "search_aliases": [],
                }
            )

        card_mapping = {
            "provider_id": "tcgdex",
            "object_type": "card",
            "provider_object_id": record.provider_object_id,
            "provider_object_version": None,
            "mapping_confidence": 1.0,
        }
        printing_mapping = {
            "provider_id": "tcgdex",
            "object_type": "printing",
            "provider_object_id": record.provider_object_id,
            "provider_object_version": None,
            "mapping_confidence": 1.0,
        }
        legacy_mapping = {
            "provider_id": "pokemon_tcg_api",
            "object_type": "legacy_printing",
            "provider_object_id": record.provider_object_id,
            "provider_object_version": None,
            "mapping_confidence": 1.0,
        }
        printings.append(
            {
                "printing_id": record.printing_id,
                "card_id": record.card_id,
                "set_id": set_id,
                "game_id": "pokemon",
                "collector_number": record.collector_number,
                "provider_mappings": [card_mapping, printing_mapping, legacy_mapping],
                "rarity": record.rarity,
                "release_date": record.set_release_date,
                "image_uris": {
                    k: v
                    for k, v in {
                        "small": record.image_small,
                        "normal": record.image_large,
                    }.items()
                    if v
                },
                "finish_keys": [],
                "metadata": {"set_code": record.set_code},
            }
        )
        provider_mappings.append(
            {
                "mapping": card_mapping,
                "card_id": record.card_id,
                "printing_id": record.printing_id,
                "set_id": set_id,
            }
        )
        provider_mappings.append(
            {
                "mapping": printing_mapping,
                "card_id": record.card_id,
                "printing_id": record.printing_id,
                "set_id": set_id,
            }
        )
        provider_mappings.append(
            {
                "mapping": legacy_mapping,
                "card_id": record.card_id,
                "printing_id": record.printing_id,
                "set_id": set_id,
            }
        )

    batch = {
        "cards": cards,
        "sets": list(sets_by_code.values()),
        "printings": printings,
        "card_localizations": card_localizations,
        "set_localizations": set_localizations,
        "provider_mappings": provider_mappings,
        "price_snapshots": [],
    }
    return {
        "schema_version": CANONICAL_SNAPSHOT_SCHEMA_VERSION,
        "compatibility_version": POKEMON_BUNDLE_COMPATIBILITY_VERSION,
        "profile": profile,
        "languages_signature": ",".join(sorted(set(languages))),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "batch": batch,
    }


def _create_legacy_db(db_path: Path, records: Dict[str, PrintingRecord], languages: List[str]) -> int:
    if db_path.exists():
        db_path.unlink()
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    cur = conn.cursor()

    cur.executescript(
        """
        CREATE TABLE cards (
          id TEXT PRIMARY KEY,
          oracle_id TEXT,
          name TEXT NOT NULL,
          set_code TEXT,
          set_name TEXT,
          set_total INTEGER,
          collector_number TEXT,
          rarity TEXT,
          type_line TEXT,
          mana_cost TEXT,
          oracle_text TEXT,
          cmc REAL,
          colors TEXT,
          color_identity TEXT,
          artist TEXT,
          power TEXT,
          toughness TEXT,
          loyalty TEXT,
          lang TEXT,
          released_at TEXT,
          image_uris TEXT,
          card_faces TEXT,
          card_json TEXT,
          price_usd TEXT,
          price_usd_foil TEXT,
          price_usd_etched TEXT,
          price_eur TEXT,
          price_eur_foil TEXT,
          price_tix TEXT,
          prices_updated_at INTEGER
        );
        CREATE TABLE collections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'custom',
          filter_json TEXT
        );
        CREATE TABLE collection_cards (
          collection_id INTEGER NOT NULL,
          card_id TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          foil INTEGER NOT NULL DEFAULT 0,
          alt_art INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (collection_id, card_id)
        );
        CREATE INDEX cards_name_idx ON cards(name);
        CREATE INDEX cards_set_idx ON cards(set_code);
        CREATE INDEX cards_number_idx ON cards(collector_number);
        CREATE INDEX cards_oracle_idx ON cards(oracle_id);
        CREATE TABLE cards_printed_search (
          card_id TEXT PRIMARY KEY,
          lang TEXT NOT NULL,
          display_name TEXT NOT NULL,
          folded_name TEXT NOT NULL
        );
        CREATE INDEX cards_printed_search_lang_folded_idx ON cards_printed_search(lang, folded_name);
        CREATE INDEX cards_printed_search_folded_idx ON cards_printed_search(folded_name);
        CREATE VIRTUAL TABLE cards_fts USING fts5(
          name,
          lang,
          content='cards',
          content_rowid='rowid'
        );
        CREATE VIRTUAL TABLE cards_printed_fts USING fts5(
          display_name,
          card_id UNINDEXED,
          lang UNINDEXED,
          tokenize = 'unicode61 remove_diacritics 2'
        );
        """
    )

    inserted = 0
    for record in records.values():
        if not record.localized_names:
            continue
        localized = _choose_primary_localized(record.localized_names, languages)
        set_name = (
            record.set_name_by_lang.get(localized.language)
            or record.set_name_by_lang.get("en")
            or record.set_code.upper()
        )
        name = localized.name
        if not name:
            continue
        image_uris = {}
        if record.image_small:
            image_uris["small"] = record.image_small
        if record.image_large:
            image_uris["normal"] = record.image_large
        aliases = sorted(
            {
                n.name
                for n in record.localized_names.values()
                if n.name and n.name.lower() != name.lower()
            }
        )
        card_json = {
            "id": record.provider_object_id,
            "name": name,
            "set_code": record.set_code,
            "collector_number": record.collector_number,
            "lang": localized.language,
            "printed_name": name,
            "search_aliases_flat": " ".join(aliases),
            "pokemon": record.pokemon_meta,
        }
        cur.execute(
            """
            INSERT OR REPLACE INTO cards (
              id, oracle_id, name, set_code, set_name, set_total, collector_number,
              rarity, type_line, mana_cost, oracle_text, cmc, colors, color_identity,
              artist, power, toughness, loyalty, lang, released_at, image_uris,
              card_faces, card_json, price_usd, price_usd_foil, price_usd_etched,
              price_eur, price_eur_foil, price_tix, prices_updated_at
            )
            VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, '', '', ?, ?, ?, ?, '', '', '', ?, ?, ?, NULL, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
            """,
            (
                record.provider_object_id,
                name,
                record.set_code,
                set_name,
                record.set_total,
                record.collector_number,
                record.rarity,
                localized.subtype_line or "",
                record.mana_value,
                json.dumps(record.colors) if record.colors else None,
                json.dumps(record.color_identity) if record.color_identity else None,
                record.artist,
                localized.language,
                record.set_release_date,
                json.dumps(image_uris) if image_uris else None,
                json.dumps(card_json, ensure_ascii=False),
            ),
        )
        inserted += 1

    cur.execute("INSERT INTO cards_fts(cards_fts) VALUES('rebuild')")
    cur.execute("DELETE FROM cards_printed_search")
    cur.execute(
        """
        INSERT OR REPLACE INTO cards_printed_search(card_id, lang, display_name, folded_name)
        SELECT
          id,
          lower(COALESCE(NULLIF(trim(lang), ''), 'en')),
          COALESCE(NULLIF(TRIM(json_extract(card_json, '$.printed_name')), ''), name),
          replace(replace(replace(replace(replace(replace(lower(
            COALESCE(NULLIF(TRIM(json_extract(card_json, '$.printed_name')), ''), name)
            || ' ' ||
            COALESCE(NULLIF(TRIM(json_extract(card_json, '$.search_aliases_flat')), ''), '')
          ), ',', ''), ' ', ''), '-', ''), char(39), ''), char(8217), ''), char(34), '')
        FROM cards
        """
    )
    cur.execute("DELETE FROM cards_printed_fts")
    cur.execute(
        """
        INSERT INTO cards_printed_fts(display_name, card_id, lang)
        SELECT display_name, card_id, lang FROM cards_printed_search
        """
    )
    conn.commit()
    cur.execute("VACUUM")
    conn.commit()
    conn.close()
    return inserted


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _gzip_file(src: Path, dst: Path) -> None:
    with src.open("rb") as f_in, gzip.open(dst, "wb", compresslevel=9) as f_out:
        for chunk in iter(lambda: f_in.read(1024 * 1024), b""):
            f_out.write(chunk)


def _write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def parse_args(argv: List[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build Pokemon bundle artifacts from local JSON source.")
    parser.add_argument("--source-dir", help="Local source directory containing JSON files.")
    parser.add_argument(
        "--source-zip",
        help="Zip file path or URL containing JSON files (recommended on Windows for tcgdex/distribution).",
    )
    parser.add_argument(
        "--source-tcgdex-api",
        action="store_true",
        help="Use TCGdex API as source (complete but much slower).",
    )
    parser.add_argument(
        "--output-dir",
        default="dist/pokemon_bundle",
        help="Output directory for generated artifacts.",
    )
    parser.add_argument(
        "--profile",
        default="full",
        choices=["starter", "standard", "expanded", "full"],
        help="Bundle profile label for manifest/snapshot metadata.",
    )
    parser.add_argument(
        "--languages",
        default="en,it",
        help="Comma-separated language priority list (default: en,it).",
    )
    parser.add_argument(
        "--version",
        default=datetime.now(timezone.utc).strftime("%Y%m%d%H%M"),
        help="Bundle version tag used in manifest.",
    )
    parser.add_argument(
        "--source-repo",
        default="",
        help="Optional source repository URL/name recorded in the manifest.",
    )
    parser.add_argument(
        "--source-ref",
        default="",
        help="Optional source git ref/branch/tag recorded in the manifest.",
    )
    parser.add_argument(
        "--source-commit",
        default="",
        help="Optional source git commit SHA recorded in the manifest.",
    )
    parser.add_argument(
        "--language-bundles",
        default="",
        help=(
            "Comma-separated list of per-language bundles to generate "
            "(example: en,it). When set, the script creates one bundle per "
            "language with suffixed file names."
        ),
    )
    parser.add_argument(
        "--package-layout",
        default="base-delta",
        choices=["base-delta", "split"],
        help=(
            "Aggregate manifest layout used when --language-bundles is set. "
            "'base-delta' marks EN as base bundle and others as deltas."
        ),
    )
    parser.add_argument(
        "--api-workers",
        type=int,
        default=8,
        help="Max worker threads when --source-tcgdex-api is used.",
    )
    parser.add_argument(
        "--api-max-sets",
        type=int,
        default=0,
        help="Optional cap of sets per language for smoke tests (0 = all).",
    )
    parser.add_argument(
        "--api-max-cards",
        type=int,
        default=0,
        help="Optional cap of cards per language for smoke tests (0 = all).",
    )
    return parser.parse_args(argv)


def _load_records_from_args(args: argparse.Namespace, languages: List[str]) -> Dict[str, PrintingRecord]:
    records: Dict[str, PrintingRecord]
    if args.source_tcgdex_api:
        print(f"[build] source=tcgdex-api workers={args.api_workers}")
        records = _load_records_from_tcgdex_api(
            languages=languages,
            workers=max(1, int(args.api_workers)),
            max_sets_per_lang=max(0, int(args.api_max_sets)),
            max_cards_per_lang=max(0, int(args.api_max_cards)),
        )
    elif args.source_zip:
        print(f"[build] source-zip={args.source_zip}")
        records = _load_records_from_zip(zip_source=args.source_zip, languages=languages)
    elif args.source_dir:
        source_dir = Path(args.source_dir).resolve()
        if not source_dir.exists():
            print(f"[error] source dir not found: {source_dir}", file=sys.stderr)
            return {}
        print(f"[build] source={source_dir}")
        records = _load_records(source_dir=source_dir, languages=languages)
        if not records:
            ts_count = len(list(source_dir.rglob("*.ts")))
            if ts_count > 0:
                print(
                    "[hint] source appears to be TypeScript dataset (cards-database). "
                    "Use --source-zip with tcgdex/distribution zip URL instead.",
                    file=sys.stderr,
                )
    else:
        print("[error] provide --source-dir or --source-zip or --source-tcgdex-api", file=sys.stderr)
        return {}
    return records


def _run_git(path: Path, *args: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(path), *args],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return ""
    return result.stdout.strip()


def _detect_source_metadata(args: argparse.Namespace) -> Dict[str, Any]:
    source_repo = (args.source_repo or "").strip()
    source_ref = (args.source_ref or "").strip()
    source_commit = (args.source_commit or "").strip()
    source_kind = "unknown"

    if args.source_tcgdex_api:
        source_kind = "tcgdex_api"
        if not source_repo:
            source_repo = TCGDEX_API_BASE
    elif args.source_zip:
        source_kind = "zip"
        if not source_repo:
            source_repo = str(args.source_zip).strip()
    elif args.source_dir:
        source_kind = "directory"
        source_dir = Path(args.source_dir).resolve()
        if source_dir.exists():
            detected_repo = _run_git(source_dir, "config", "--get", "remote.origin.url")
            detected_ref = _run_git(source_dir, "rev-parse", "--abbrev-ref", "HEAD")
            detected_commit = _run_git(source_dir, "rev-parse", "HEAD")
            if detected_repo and not source_repo:
                source_repo = detected_repo
            if detected_ref and detected_ref != "HEAD" and not source_ref:
                source_ref = detected_ref
            if detected_commit and not source_commit:
                source_commit = detected_commit
            if detected_repo or detected_ref or detected_commit:
                source_kind = "git_checkout"

    return {
        "kind": source_kind,
        "repo": source_repo or None,
        "ref": source_ref or None,
        "commit": source_commit or None,
    }


def _build_bundle_artifacts(
    *,
    output_dir: Path,
    records: Dict[str, PrintingRecord],
    profile: str,
    languages: List[str],
    version: str,
    source_metadata: Dict[str, Any],
    suffix: str = "",
) -> Dict[str, Any]:
    # Canonical snapshot payload + gzip.
    snapshot_payload = _build_canonical_snapshot(
        records=records,
        profile=profile,
        languages=languages,
    )
    suffix_part = f"_{suffix}" if suffix else ""
    snapshot_json = output_dir / f"canonical_catalog_snapshot{suffix_part}.json"
    _write_json(snapshot_json, snapshot_payload)
    snapshot_gz = output_dir / f"canonical_catalog_snapshot{suffix_part}.json.gz"
    _gzip_file(snapshot_json, snapshot_gz)
    print(f"[build] wrote {snapshot_gz.name}")

    # Legacy sqlite db + gzip.
    legacy_db = output_dir / f"pokemon_legacy{suffix_part}.db"
    inserted_rows = _create_legacy_db(legacy_db, records=records, languages=languages)
    legacy_gz = output_dir / f"pokemon_legacy{suffix_part}.db.gz"
    _gzip_file(legacy_db, legacy_gz)
    print(f"[build] wrote {legacy_gz.name} rows={inserted_rows}")

    manifest = {
        "bundle": "pokemon",
        "version": version,
        "schema_version": CANONICAL_SNAPSHOT_SCHEMA_VERSION,
        "compatibility_version": POKEMON_BUNDLE_COMPATIBILITY_VERSION,
        "profile": profile,
        "languages": sorted(set(languages)),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": source_metadata,
        "counts": {
            "printings": len(records),
            "legacy_cards_rows": inserted_rows,
            "canonical_cards": len(snapshot_payload["batch"]["cards"]),
            "canonical_sets": len(snapshot_payload["batch"]["sets"]),
        },
        "artifacts": [
            {
                "name": snapshot_gz.name,
                "path": snapshot_gz.name,
                "size_bytes": snapshot_gz.stat().st_size,
                "sha256": _sha256_file(snapshot_gz),
            },
            {
                "name": legacy_gz.name,
                "path": legacy_gz.name,
                "size_bytes": legacy_gz.stat().st_size,
                "sha256": _sha256_file(legacy_gz),
            },
        ],
    }
    manifest_name = f"manifest{suffix_part}.json"
    manifest_path = output_dir / manifest_name
    _write_json(manifest_path, manifest)
    print(f"[build] wrote {manifest_path.name}")
    return manifest


def main(argv: List[str]) -> int:
    args = parse_args(argv)
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    source_metadata = _detect_source_metadata(args)

    languages = [
        lang.strip().lower()
        for lang in args.languages.split(",")
        if lang.strip()
    ]
    if not languages:
        languages = ["en", "it"]

    split_languages = [
        lang.strip().lower()
        for lang in args.language_bundles.split(",")
        if lang.strip()
    ]
    if split_languages:
        generated: Dict[str, Dict[str, Any]] = {}
        for lang in sorted(set(split_languages)):
            if lang not in SUPPORTED_LANGS:
                print(f"[warn] skipping unsupported language bundle: {lang}")
                continue
            bundle_languages = [lang]
            print(f"[build] profile={args.profile} bundle={lang} languages={','.join(bundle_languages)}")
            records = _load_records_from_args(args, bundle_languages)
            if not records:
                print(
                    f"[error] no card records detected for language bundle: {lang}",
                    file=sys.stderr,
                )
                return 3
            print(f"[build] parsed printings ({lang})={len(records)}")
            generated[lang] = _build_bundle_artifacts(
                output_dir=output_dir,
                records=records,
                profile=args.profile,
                languages=bundle_languages,
                version=args.version,
                source_metadata=source_metadata,
                suffix=lang,
            )
        if not generated:
            print("[error] no language bundles generated", file=sys.stderr)
            return 4
        bundle_entries: List[Dict[str, Any]] = []
        if args.package_layout == "base-delta":
            if "en" not in generated:
                print(
                    "[error] base-delta layout requires 'en' in --language-bundles",
                    file=sys.stderr,
                )
                return 5
            for lang, payload in sorted(generated.items()):
                kind = "base" if lang == "en" else "delta"
                requires = [] if kind == "base" else ["base_en"]
                bundle_entries.append(
                    {
                        "id": f"{kind}_{lang}",
                        "kind": kind,
                        "schema_version": payload.get("schema_version"),
                        "compatibility_version": payload.get("compatibility_version"),
                        "language": lang,
                        "requires": requires,
                        "profile": payload.get("profile"),
                        "languages": payload.get("languages"),
                        "counts": payload.get("counts"),
                        "artifacts": payload.get("artifacts"),
                        "manifest_path": f"manifest_{lang}.json",
                    }
                )
            aggregate_mode = "base_plus_delta"
        else:
            for lang, payload in sorted(generated.items()):
                bundle_entries.append(
                    {
                        "id": f"bundle_{lang}",
                        "kind": "bundle",
                        "schema_version": payload.get("schema_version"),
                        "compatibility_version": payload.get("compatibility_version"),
                        "language": lang,
                        "requires": [],
                        "profile": payload.get("profile"),
                        "languages": payload.get("languages"),
                        "counts": payload.get("counts"),
                        "artifacts": payload.get("artifacts"),
                        "manifest_path": f"manifest_{lang}.json",
                    }
                )
            aggregate_mode = "split_by_language"
        aggregate = {
            "bundle": "pokemon",
            "version": args.version,
            "schema_version": CANONICAL_SNAPSHOT_SCHEMA_VERSION,
            "compatibility_version": POKEMON_BUNDLE_COMPATIBILITY_VERSION,
            "mode": aggregate_mode,
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "source": source_metadata,
            "bundles": bundle_entries,
        }
        aggregate_path = output_dir / "manifest.json"
        _write_json(aggregate_path, aggregate)
        print(f"[build] wrote {aggregate_path.name}")
    else:
        print(f"[build] profile={args.profile} languages={','.join(languages)}")
        records = _load_records_from_args(args, languages)
        if not records:
            print("[error] no card records detected from source json files", file=sys.stderr)
            return 3
        print(f"[build] parsed printings={len(records)}")
        _build_bundle_artifacts(
            output_dir=output_dir,
            records=records,
            profile=args.profile,
            languages=languages,
            version=args.version,
            source_metadata=source_metadata,
        )

    print("[done] bundle artifacts ready")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
