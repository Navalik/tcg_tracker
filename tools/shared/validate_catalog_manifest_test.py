#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import tempfile
import unittest
from pathlib import Path

from validate_catalog_manifest import ManifestValidationError, validate_manifest


def _artifact(path: Path) -> dict[str, object]:
    return {
        "name": path.name,
        "path": path.name,
        "size_bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


class CatalogManifestValidatorTest(unittest.TestCase):
    def test_validates_local_base_delta_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            base = root / "mtg_base_en.json.gz"
            delta = root / "mtg_delta_it.json.gz"
            base.write_bytes(b"base")
            delta.write_bytes(b"delta")

            manifest = {
                "bundle": "mtg",
                "version": "20260417T0920027840000-full-base-delta-compat1",
                "schema_version": 1,
                "compatibility_version": 1,
                "languages": ["en", "it"],
                "bundles": [
                    {
                        "id": "base_en",
                        "kind": "base",
                        "schema_version": 1,
                        "compatibility_version": 1,
                        "language": "en",
                        "requires": [],
                        "artifacts": [_artifact(base)],
                    },
                    {
                        "id": "delta_it",
                        "kind": "delta",
                        "schema_version": 1,
                        "compatibility_version": 1,
                        "language": "it",
                        "requires": ["base_en"],
                        "artifacts": [_artifact(delta)],
                    },
                ],
            }

            validate_manifest(
                manifest,
                game="mtg",
                manifest_dir=root,
                verify_local_artifacts=True,
            )

    def test_rejects_unknown_required_bundle(self) -> None:
        manifest = {
            "bundle": "pokemon",
            "version": "20260417-full-base-delta-compat2",
            "schema_version": 2,
            "compatibility_version": 2,
            "bundles": [
                {
                    "id": "delta_it",
                    "kind": "delta",
                    "schema_version": 2,
                    "compatibility_version": 2,
                    "requires": ["base_en"],
                    "artifacts": [
                        {
                            "name": "canonical_catalog_snapshot_it.json.gz",
                            "path": "catalog/pokemon/releases/v/canonical_catalog_snapshot_it.json.gz",
                            "size_bytes": 10,
                            "sha256": "a" * 64,
                            "download_url": "https://firebasestorage.googleapis.com/v0/b/b/o/catalog%2Fpokemon%2Freleases%2Fv%2Fcanonical_catalog_snapshot_it.json.gz?alt=media",
                        }
                    ],
                }
            ],
        }

        with self.assertRaisesRegex(ManifestValidationError, "unknown bundle"):
            validate_manifest(
                manifest,
                game="pokemon",
                manifest_dir=Path("."),
                require_download_url=True,
            )

    def test_rejects_wrong_game_path(self) -> None:
        manifest = {
            "bundle": "mtg",
            "version": "v",
            "schema_version": 1,
            "compatibility_version": 1,
            "bundles": [
                {
                    "id": "base_en",
                    "kind": "base",
                    "schema_version": 1,
                    "compatibility_version": 1,
                    "requires": [],
                    "artifacts": [
                        {
                            "name": "mtg_base_en.json.gz",
                            "path": "catalog/pokemon/releases/v/mtg_base_en.json.gz",
                            "size_bytes": 1,
                            "sha256": "b" * 64,
                        }
                    ],
                }
            ],
        }

        with self.assertRaisesRegex(ManifestValidationError, "catalog/mtg"):
            validate_manifest(manifest, game="mtg", manifest_dir=Path("."))


if __name__ == "__main__":
    unittest.main()
