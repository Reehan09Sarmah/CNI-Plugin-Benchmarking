#!/usr/bin/env python3
"""Add or refresh Latency_ms in latency_sizes CSV files.

For each CSV matching Results/*_latency_sizes.csv, this script ensures a
4-column schema:

    Payload_Size,Run,Transactions_Per_Sec,Latency_ms

Latency is derived as:

    Latency_ms = 1000 / Transactions_Per_Sec

Usage examples:
    python3 Calculate/latency_tps_to_ms.py
    python3 Calculate/latency_tps_to_ms.py --root /home/user/GRS_Project
    python3 Calculate/latency_tps_to_ms.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Iterable


def compute_latency_ms(tps_raw: str) -> str:
    """Convert TPS to latency in milliseconds."""
    try:
        tps = float(tps_raw.strip())
    except (TypeError, ValueError):
        return "NA"

    if tps <= 0:
        return "NA"

    return f"{1000.0 / tps:.4f}"


def normalize_file(csv_path: Path, dry_run: bool = False) -> bool:
    """Normalize one latency_sizes CSV file. Returns True if changed."""
    with csv_path.open("r", newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))

    if not rows:
        return False

    header = [h.strip() for h in rows[0]]
    expected_header = ["Payload_Size", "Run", "Transactions_Per_Sec", "Latency_ms"]

    new_rows: list[list[str]] = [expected_header]

    for row in rows[1:]:
        if not row or all(not col.strip() for col in row):
            continue

        payload = row[0].strip() if len(row) > 0 else ""
        run = row[1].strip() if len(row) > 1 else ""
        tps = row[2].strip() if len(row) > 2 else ""
        latency_ms = compute_latency_ms(tps)

        new_rows.append([payload, run, tps, latency_ms])

    changed = rows != new_rows or header != expected_header

    if changed and not dry_run:
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerows(new_rows)

    return changed


def find_latency_files(root: Path) -> Iterable[Path]:
    results_dir = root / "Results"
    return sorted(results_dir.glob("*_latency_sizes.csv"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Add/refresh Latency_ms in latency_sizes CSVs.")
    parser.add_argument(
        "--root",
        default=".",
        help="Project root containing Results/ (default: current directory)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would change without writing files",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    files = list(find_latency_files(root))

    if not files:
        print(f"No files found under: {root / 'Results'}")
        return 1

    changed_count = 0
    for csv_path in files:
        changed = normalize_file(csv_path, dry_run=args.dry_run)
        status = "CHANGED" if changed else "OK"
        if args.dry_run and changed:
            status = "WOULD_CHANGE"
        print(f"[{status}] {csv_path}")
        if changed:
            changed_count += 1

    mode = "Dry run" if args.dry_run else "Run"
    print(f"{mode} complete. {changed_count}/{len(files)} file(s) updated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
