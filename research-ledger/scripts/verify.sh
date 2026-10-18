#!/usr/bin/env bash
set -Eeuo pipefail
TASK_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$TASK_ROOT/scripts/verify_mysql.py" "$@"
