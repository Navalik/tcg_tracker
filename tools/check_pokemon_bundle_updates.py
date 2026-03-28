#!/usr/bin/env python3
"""
Check whether the Pokemon source checkout has changed since the last bundle
manifest that was exported/published.

Default comparison target:
  https://github.com/Navalik/tcg_tracker/releases/latest/download/manifest.json

Typical usage:
  python tools/check_pokemon_bundle_updates.py ^
    --source-dir C:\path\to\cards-database
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


DEFAULT_MANIFEST_URL = (
    "https://github.com/Navalik/tcg_tracker/releases/latest/download/manifest.json"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", required=True, help="Local git checkout.")
    parser.add_argument(
        "--manifest-url",
        default=DEFAULT_MANIFEST_URL,
        help="Published manifest URL to compare against.",
    )
    parser.add_argument(
        "--manifest-path",
        default="",
        help="Optional local manifest.json path. Overrides --manifest-url.",
    )
    parser.add_argument(
        "--no-fetch",
        action="store_true",
        help="Do not fetch the source repo before checking upstream.",
    )
    return parser.parse_args()


def run_git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def load_manifest(args: argparse.Namespace) -> Dict[str, Any]:
    if args.manifest_path:
        return json.loads(Path(args.manifest_path).read_text(encoding="utf-8"))
    with urllib.request.urlopen(args.manifest_url, timeout=20) as response:
        return json.loads(response.read().decode("utf-8"))


def short_commit(value: Optional[str]) -> str:
    normalized = (value or "").strip()
    if not normalized:
        return "-"
    return normalized[:12]


def commits_match(left: Optional[str], right: Optional[str]) -> bool:
    a = (left or "").strip().lower()
    b = (right or "").strip().lower()
    if not a or not b:
        return False
    return a == b or a.startswith(b) or b.startswith(a)


def normalize_repo(value: Optional[str]) -> str:
    text = (value or "").strip().lower()
    if text.endswith(".git"):
        text = text[:-4]
    return text.rstrip("/")


def manifest_source(manifest: Dict[str, Any]) -> Dict[str, str]:
    source = manifest.get("source")
    if not isinstance(source, dict):
        return {}
    return {
        "kind": str(source.get("kind") or "").strip(),
        "repo": str(source.get("repo") or "").strip(),
        "ref": str(source.get("ref") or "").strip(),
        "commit": str(source.get("commit") or "").strip(),
    }


def main() -> int:
    args = parse_args()
    repo = Path(args.source_dir).resolve()
    if not repo.exists():
        print(f"[error] source dir not found: {repo}")
        return 2

    if not args.no_fetch:
        subprocess.run(
            ["git", "-C", str(repo), "fetch", "--quiet", "--tags", "origin"],
            capture_output=True,
            text=True,
        )

    manifest = load_manifest(args)
    source = manifest_source(manifest)

    local_repo = run_git(repo, "config", "--get", "remote.origin.url")
    local_branch = run_git(repo, "rev-parse", "--abbrev-ref", "HEAD")
    local_head = run_git(repo, "rev-parse", "HEAD")
    upstream_ref = run_git(repo, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    upstream_head = run_git(repo, "rev-parse", "@{u}") if upstream_ref else ""
    ahead_behind = run_git(repo, "rev-list", "--left-right", "--count", "HEAD...@{u}") if upstream_ref else ""

    print("Pokemon bundle source check")
    print(f"source dir: {repo}")
    print(f"local repo: {local_repo or '-'}")
    print(f"local ref:  {local_branch or '-'}")
    print(f"local head: {short_commit(local_head)}")
    print(f"upstream:   {upstream_ref or '-'}")
    print(f"upstream head: {short_commit(upstream_head)}")
    print()
    print("Last exported bundle")
    print(f"version: {manifest.get('version', '-')}")
    print(f"source repo: {source.get('repo') or '-'}")
    print(f"source ref:  {source.get('ref') or '-'}")
    print(f"source head: {short_commit(source.get('commit'))}")
    print()

    exported_commit = source.get("commit", "").strip()
    if not exported_commit:
        print(
            "[warning] The last exported manifest does not contain source commit metadata."
        )
        print(
            "          Publish one new bundle generated with the updated builder,"
        )
        print(
            "          then this tool will be able to compare exports precisely."
        )
        return 1

    repo_matches = (
        normalize_repo(local_repo) == normalize_repo(source.get("repo"))
        if local_repo and source.get("repo")
        else True
    )
    if not repo_matches:
        print("[warning] Local checkout repo differs from the repo recorded in the bundle.")

    compare_target = upstream_head or local_head
    compare_label = "upstream" if upstream_head else "local"
    if not compare_target:
        print("[error] Could not determine a git commit to compare.")
        return 2

    if commits_match(compare_target, exported_commit):
        print(f"[ok] No new source changes vs last export ({compare_label} matches bundle).")
        if ahead_behind:
            behind, ahead = ahead_behind.split()
            print(f"[info] local vs upstream: behind={behind} ahead={ahead}")
        return 0

    print(
        f"[update] New source changes detected: {short_commit(exported_commit)} -> {short_commit(compare_target)}"
    )
    if ahead_behind:
        behind, ahead = ahead_behind.split()
        print(f"[info] local vs upstream: behind={behind} ahead={ahead}")
        if upstream_head and local_head != upstream_head:
            print("[hint] Local checkout is not aligned with upstream.")
    return 10


if __name__ == "__main__":
    sys.exit(main())
