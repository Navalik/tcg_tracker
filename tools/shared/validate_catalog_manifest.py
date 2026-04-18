#!/usr/bin/env python3
"""Validate BinderVault catalog bundle manifest files.

This validator is intentionally local and network-free. Use it before publish
to catch contract mistakes in a generated manifest, and keep the Firebase
verifier for post-publish download/size/hash checks.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlparse


SUPPORTED_GAMES = {"pokemon", "mtg"}
SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")


class ManifestValidationError(ValueError):
    pass


def _fail(message: str) -> None:
    raise ManifestValidationError(message)


def _as_dict(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        _fail(f"{label} must be an object.")
    return value


def _as_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        _fail(f"{label} must be an array.")
    return value


def _required_string(obj: dict[str, Any], key: str, label: str) -> str:
    value = obj.get(key)
    if not isinstance(value, str) or not value.strip():
        _fail(f"Missing required string field: {label}.{key}.")
    return value.strip()


def _required_int(obj: dict[str, Any], key: str, label: str) -> int:
    value = obj.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        _fail(f"Missing required integer field: {label}.{key}.")
    return value


def _validate_https_download_url(url: str, label: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or not parsed.netloc:
        _fail(f"{label}.download_url must be an absolute https URL.")
    if parsed.username or parsed.password:
        _fail(f"{label}.download_url must not include credentials.")


def _validate_artifact(
    artifact: Any,
    *,
    label: str,
    manifest_dir: Path,
    game: str,
    require_download_url: bool,
    verify_local_artifacts: bool,
) -> None:
    item = _as_dict(artifact, label)
    name = _required_string(item, "name", label)
    size_bytes = _required_int(item, "size_bytes", label)
    if size_bytes <= 0:
        _fail(f"{label}.size_bytes must be greater than zero.")

    sha256 = _required_string(item, "sha256", label).lower()
    if not SHA256_RE.match(sha256):
        _fail(f"{label}.sha256 must be a 64-character hex digest.")

    path = item.get("path")
    if path is not None:
        if not isinstance(path, str) or not path.strip():
            _fail(f"{label}.path must be a non-empty string when present.")
        path = path.strip()
        if "\\" in path or ".." in Path(path).parts:
            _fail(f"{label}.path must be a normalized relative or Storage path.")
        if path.startswith("catalog/") and not path.startswith(f"catalog/{game}/"):
            _fail(f"{label}.path must stay under catalog/{game}/.")

    download_url = item.get("download_url")
    if require_download_url:
        if not isinstance(download_url, str) or not download_url.strip():
            _fail(f"Missing required string field: {label}.download_url.")
        _validate_https_download_url(download_url.strip(), label)
        decoded_url = unquote(download_url)
        if f"catalog/{game}/" not in decoded_url:
            _fail(f"{label}.download_url must reference catalog/{game}/.")
    elif isinstance(download_url, str) and download_url.strip():
        _validate_https_download_url(download_url.strip(), label)

    if verify_local_artifacts:
        local_candidates = [manifest_dir / name]
        if isinstance(path, str) and path and not path.startswith("catalog/"):
            local_candidates.insert(0, manifest_dir / path)
        local_path = next((candidate for candidate in local_candidates if candidate.is_file()), None)
        if local_path is None:
            _fail(f"{label} local artifact not found for {name}.")
        actual_size = local_path.stat().st_size
        if actual_size != size_bytes:
            _fail(f"{label}.size_bytes mismatch: expected {size_bytes}, got {actual_size}.")
        digest = hashlib.sha256()
        with local_path.open("rb") as input_file:
            for chunk in iter(lambda: input_file.read(1024 * 1024), b""):
                digest.update(chunk)
        actual_sha = digest.hexdigest()
        if actual_sha != sha256:
            _fail(f"{label}.sha256 mismatch: expected {sha256}, got {actual_sha}.")


def validate_manifest(
    manifest: dict[str, Any],
    *,
    game: str,
    manifest_dir: Path,
    require_download_url: bool = False,
    verify_local_artifacts: bool = False,
) -> None:
    if game not in SUPPORTED_GAMES:
        _fail(f"Unsupported game: {game}.")

    bundle = _required_string(manifest, "bundle", "manifest").lower()
    if bundle != game:
        _fail(f"manifest.bundle mismatch: expected {game}, got {bundle}.")
    _required_string(manifest, "version", "manifest")
    _required_int(manifest, "schema_version", "manifest")
    _required_int(manifest, "compatibility_version", "manifest")

    languages = manifest.get("languages")
    if languages is not None:
        for index, language in enumerate(_as_list(languages, "manifest.languages")):
            if not isinstance(language, str) or not language.strip():
                _fail(f"manifest.languages[{index}] must be a non-empty string.")

    top_artifacts = manifest.get("artifacts")
    if top_artifacts is not None:
        for index, artifact in enumerate(_as_list(top_artifacts, "manifest.artifacts")):
            _validate_artifact(
                artifact,
                label=f"manifest.artifacts[{index}]",
                manifest_dir=manifest_dir,
                game=game,
                require_download_url=require_download_url,
                verify_local_artifacts=verify_local_artifacts,
            )

    bundles = _as_list(manifest.get("bundles"), "manifest.bundles")
    if not bundles:
        _fail("manifest.bundles must contain at least one bundle.")

    bundle_ids: set[str] = set()
    for index, raw_bundle in enumerate(bundles):
        label = f"manifest.bundles[{index}]"
        item = _as_dict(raw_bundle, label)
        bundle_id = _required_string(item, "id", label)
        if bundle_id in bundle_ids:
            _fail(f"Duplicate bundle id: {bundle_id}.")
        bundle_ids.add(bundle_id)
        kind = _required_string(item, "kind", label)
        if kind not in {"base", "delta", "legacy", "canonical"}:
            _fail(f"{label}.kind has unsupported value: {kind}.")
        _required_int(item, "schema_version", label)
        _required_int(item, "compatibility_version", label)
        requires = item.get("requires", [])
        for required_id in _as_list(requires, f"{label}.requires"):
            if not isinstance(required_id, str) or not required_id.strip():
                _fail(f"{label}.requires entries must be non-empty strings.")
        artifacts = _as_list(item.get("artifacts"), f"{label}.artifacts")
        if not artifacts:
            _fail(f"{label}.artifacts must contain at least one artifact.")
        for artifact_index, artifact in enumerate(artifacts):
            _validate_artifact(
                artifact,
                label=f"{label}.artifacts[{artifact_index}]",
                manifest_dir=manifest_dir,
                game=game,
                require_download_url=require_download_url,
                verify_local_artifacts=verify_local_artifacts,
            )

    for index, raw_bundle in enumerate(bundles):
        item = _as_dict(raw_bundle, f"manifest.bundles[{index}]")
        for required_id in item.get("requires", []):
            if required_id not in bundle_ids:
                _fail(f"Bundle {item.get('id')} requires unknown bundle {required_id}.")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, help="Path to manifest.json")
    parser.add_argument("--game", choices=sorted(SUPPORTED_GAMES), required=True)
    parser.add_argument(
        "--require-download-url",
        action="store_true",
        help="Require artifact download_url fields, as expected after Firebase staging.",
    )
    parser.add_argument(
        "--verify-local-artifacts",
        action="store_true",
        help="Check local artifact files next to the manifest for size and sha256.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest_path = Path(args.manifest)
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        validate_manifest(
            _as_dict(manifest, "manifest"),
            game=args.game,
            manifest_dir=manifest_path.parent,
            require_download_url=args.require_download_url,
            verify_local_artifacts=args.verify_local_artifacts,
        )
    except ManifestValidationError as error:
        print(f"[manifest] invalid: {error}", file=sys.stderr)
        return 1
    except Exception as error:
        print(f"[manifest] error: {error}", file=sys.stderr)
        return 1
    print(f"[manifest] ok: {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
