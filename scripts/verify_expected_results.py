#!/usr/bin/env python3
"""Validate committed TSV snapshots and optionally compare a fresh output directory.

The live database verifier is scripts/verify.sh. This read-only companion keeps a
small, independent contract for the committed result snapshots, so the public
tree can still be checked when a local MySQL socket is unavailable.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


EXPECTED_HEADERS = {
    "q01.tsv": [
        "customer_id",
        "customer_name",
        "completed_service_requests",
        "total_incidents",
        "high_severity_incidents",
        "high_severity_ratio",
    ],
    "q02.tsv": [
        "driver_id",
        "driver_name",
        "successful_assignments",
        "paid_revenue",
    ],
    "q03.tsv": [
        "partner_name",
        "pickup_location",
        "dropoff_location",
        "pattern_count",
        "route_rank",
    ],
    "q04.tsv": [
        "order_id",
        "scheduled_start",
        "start_time",
        "late_minutes",
        "driver_id",
        "driver_name",
        "near_orders",
    ],
    "q05.tsv": [
        "driver_id",
        "driver_name",
        "trigger_avg_rating",
        "recomputed_avg_rating",
        "rating_count",
    ],
    "q06.tsv": [
        "customer_name",
        "order_id",
        "request_time",
        "pickup_location",
        "dropoff_location",
        "service_type",
    ],
    "q07.tsv": [
        "service_type",
        "avg_rating",
        "review_count",
        "min_rating",
        "max_rating",
    ],
    "q08.tsv": [
        "customer_name",
        "membership_tier",
        "total_orders",
        "vehicle_count",
        "orders_per_vehicle",
        "repeat_purchase_rate",
    ],
    "q09.tsv": [
        "brand_id",
        "brand_name",
        "model_id",
        "model_name",
        "vehicle_count",
    ],
    "q10.tsv": [
        "order_id",
        "customer_id",
        "customer_name",
        "phone",
        "quoted_fee",
        "payment_time",
        "hours_since_request",
    ],
}

EXPECTED_ROW_COUNTS = {
    "q01.tsv": 3,
    "q02.tsv": 6,
    "q03.tsv": 6,
    "q04.tsv": 10,
    "q05.tsv": 6,
    "q06.tsv": 5,
    "q07.tsv": 3,
    "q08.tsv": 4,
    "q09.tsv": 5,
    "q10.tsv": 2,
}

EXPECTED_SENTINELS = {
    "q01.tsv": [("1", "Customer 001"), ("2", "Customer 002"), ("3", "Customer 003")],
    "q05.tsv": [("1", "Driver 001", "4.50", "4.50"), ("6", "Driver 006", "4.00", "4.00")],
    "q08.tsv": [("Customer 003", "corporate", "2", "1"), ("Customer 002", "normal", "3", "2")],
    "q10.tsv": [("10", "4", "Customer 004"), ("8", "3", "Customer 003")],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--candidate-dir",
        type=Path,
        help="Optional fresh output directory to compare byte-for-byte with committed results.",
    )
    parser.add_argument(
        "--results-dir",
        type=Path,
        help="Override the committed results directory (primarily for tests).",
    )
    return parser.parse_args()


def read_tsv(path: Path) -> tuple[list[str], list[list[str]]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.reader(handle, delimiter="\t"))
    if not rows:
        raise ValueError(f"empty TSV: {path}")
    return rows[0], rows[1:]


def contains_sentinel(rows: list[list[str]], sentinel: tuple[str, ...]) -> bool:
    return any(tuple(row[: len(sentinel)]) == sentinel for row in rows)


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[1]
    results_dir = (args.results_dir or root / "results").resolve()

    expected_files = set(EXPECTED_HEADERS)
    actual_files = {path.name for path in results_dir.glob("q*.tsv")}
    if actual_files != expected_files:
        missing = sorted(expected_files - actual_files)
        extra = sorted(actual_files - expected_files)
        if missing:
            print(f"FAIL: missing result files: {', '.join(missing)}")
        if extra:
            print(f"FAIL: unexpected result files: {', '.join(extra)}")
        return 1

    for filename, expected_header in EXPECTED_HEADERS.items():
        path = results_dir / filename
        try:
            header, rows = read_tsv(path)
        except (OSError, ValueError, csv.Error) as exc:
            print(f"FAIL: {exc}")
            return 1
        if header != expected_header:
            print(f"FAIL: {filename} header mismatch: {header!r}")
            return 1
        if len(rows) != EXPECTED_ROW_COUNTS[filename]:
            print(
                f"FAIL: {filename} expected {EXPECTED_ROW_COUNTS[filename]} rows, "
                f"found {len(rows)}"
            )
            return 1
        if any(len(row) != len(expected_header) for row in rows):
            print(f"FAIL: {filename} has a row with the wrong column count")
            return 1
        for sentinel in EXPECTED_SENTINELS.get(filename, []):
            if not contains_sentinel(rows, sentinel):
                print(f"FAIL: {filename} missing expected row prefix {sentinel!r}")
                return 1

    if args.candidate_dir:
        candidate_dir = args.candidate_dir.resolve()
        for filename in sorted(expected_files):
            committed = results_dir / filename
            candidate = candidate_dir / filename
            if not candidate.is_file():
                print(f"FAIL: candidate output missing {candidate}")
                return 1
            if committed.read_bytes() != candidate.read_bytes():
                print(f"FAIL: candidate output differs from committed {filename}")
                return 1

    for filename in sorted(expected_files):
        print(f"PASS: {filename} ({EXPECTED_ROW_COUNTS[filename]} rows)")
    if args.candidate_dir:
        print("PASS: candidate outputs match committed TSVs byte-for-byte")
    else:
        print("PASS: committed TSV snapshots match the deterministic fixture contract")
    return 0


if __name__ == "__main__":
    sys.exit(main())
