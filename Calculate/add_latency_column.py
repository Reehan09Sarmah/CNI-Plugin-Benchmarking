#!/usr/bin/env python3
"""Add or refresh Latency_ms in latency-size CSV files.

Latency is derived from Transactions_Per_Sec using:
    latency_ms = 1000 / tps

By default, this script processes all files matching:
    Results/*_latency_sizes.csv

Usage:
    python3 Calculate/add_latency_column.py
    python3 Calculate/add_latency_column.py --results-dir Results
    python3 Calculate/add_latency_column.py --dry-run
"""

from __future__ import annotations

import argparse
import csv
import glob
import os
from typing import List


HEADER = ["Payload_Size", "Run", "Transactions_Per_Sec", "Latency_ms"]


def compute_latency_ms(tps_text: str) -> str:
    """Return latency in ms formatted to 4 decimals, or NA for invalid/zero TPS."""
    try:
        tps = float(tps_text.strip())
    except (ValueError, AttributeError):
        return "NA"

    if tps <= 0:
        return "NA"

    return f"{1000.0 / tps:.4f}"


def normalize_row(row: List[str]) -> List[str]:
    """Return a normalized 4-column row with recalculated latency."""
    if len(row) < 3:
        return []

    payload = row[0].strip()
    run = row[1].strip()
    tps = row[2].strip()
    latency = compute_latency_ms(tps)
    return [payload, run, tps, latency]


def process_file(path: str, dry_run: bool = False) -> int:
    """Process one CSV file; returns number of data rows written."""
    with open(path, "r", newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        rows = list(reader)

    if not rows:
        print(f"SKIP (empty): {path}")
        return 0

    data_rows: List[List[str]] = []
    for i, row in enumerate(rows):
        if i == 0:
            continue
        normalized = normalize_row(row)
        if normalized:
            data_rows.append(normalized)

    out_rows = [HEADER] + data_rows

    if dry_run:
        print(f"DRY-RUN: {path} -> rows={len(data_rows)}")
        return len(data_rows)

    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerows(out_rows)

    print(f"UPDATED: {path} -> rows={len(data_rows)}")
    return len(data_rows)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Add/update Latency_ms for *_latency_sizes.csv files"
    )
    parser.add_argument(
        "--results-dir",
        default="Results",
        help="Directory that contains *_latency_sizes.csv (default: Results)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview updates without writing files",
    )
    args = parser.parse_args()

    pattern = os.path.join(args.results_dir, "*_latency_sizes.csv")
    files = sorted(glob.glob(pattern))

    if not files:
        print(f"No files found for pattern: {pattern}")
        return 1

    total_rows = 0
    for path in files:
        total_rows += process_file(path, dry_run=args.dry_run)

    print(f"Done. files={len(files)} data_rows={total_rows}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
