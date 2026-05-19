#!/usr/bin/env python3
"""Audit vibe-map goal issue counts against GitHub.

For every goal with `gh_query`, compare the stored `issue_count` with the
actual GitHub issue search count. This mirrors the company region-map drift
check while keeping the MoonBit CLI free of process/gh dependencies.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path


SEARCH_THROTTLE_SEC = 2.1


def gh_search_count(query: str) -> int:
    cmd = [
        "gh",
        "api",
        "-X",
        "GET",
        "search/issues",
        "-f",
        f"q={query}",
        "-f",
        "per_page=1",
        "-q",
        ".total_count",
    ]
    result = subprocess.run(cmd, check=True, capture_output=True, text=True)
    time.sleep(SEARCH_THROTTLE_SEC)
    return int(result.stdout.strip())


def audit(path: Path) -> tuple[list[tuple[str, int, int | str]], int, int]:
    doc = json.loads(path.read_text())
    goals = doc.get("goals", [])
    drift: list[tuple[str, int, int | str]] = []
    queried = 0
    skipped = 0
    for goal in goals:
        query = goal.get("gh_query")
        if not query:
            skipped += 1
            continue
        queried += 1
        expected = int(goal.get("issue_count") or 0)
        try:
            actual = gh_search_count(query)
        except subprocess.CalledProcessError as exc:
            drift.append(
                (goal.get("id", "?"), expected, "ERROR: " + exc.stderr.strip()[:120])
            )
            continue
        if actual != expected:
            drift.append((goal.get("id", "?"), expected, actual))
    return drift, queried, skipped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default="vibe-map.json")
    parser.add_argument("--strict", action="store_true", help="exit 1 when drift is detected")
    parser.add_argument("--markdown", action="store_true", help="emit a markdown report")
    args = parser.parse_args()

    if not shutil.which("gh"):
        print("ERROR: gh CLI not found on PATH", file=sys.stderr)
        return 2

    path = Path(args.file)
    drift, queried, skipped = audit(path)

    if args.markdown:
        print("# Vibe Region Map Drift Audit\n")
        print(f"- File: `{path}`")
        print(f"- Goals with `gh_query`: **{queried}**")
        print(f"- Goals without `gh_query`: **{skipped}**")
        print(f"- Drift detected: **{len(drift)}**\n")
        if drift:
            print("| goal | issue_count | actual GitHub count |")
            print("| --- | --- | --- |")
            for goal_id, expected, actual in drift:
                print(f"| `{goal_id}` | {expected} | {actual} |")
        else:
            print("No drift.")
    else:
        print(f"Goals with gh_query: {queried}")
        print(f"Goals without gh_query: {skipped}")
        print(f"Drift: {len(drift)}")
        for goal_id, expected, actual in drift:
            print(f"  - {goal_id}: json={expected} actual={actual}")

    return 1 if drift and args.strict else 0


if __name__ == "__main__":
    sys.exit(main())
