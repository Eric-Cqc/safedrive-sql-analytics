#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MYSQL_USER="root"
DATABASE="safedrive_portfolio_test"
MYSQL_HOST=""
MYSQL_PORT=""
MYSQL_SOCKET=""

usage() {
    cat <<'EOF'
Usage: bash scripts/verify.sh [--mysql-user USER] [--database DB]
                              [--mysql-host HOST] [--mysql-port PORT]
                              [--mysql-socket PATH]

The selected database is dropped and recreated. No other database is touched.
The default connection is the local mysql client connection for user root.
EOF
}

while (($# > 0)); do
    case "$1" in
        --mysql-user)
            (($# >= 2)) || { echo "Missing value for --mysql-user" >&2; exit 64; }
            MYSQL_USER="$2"
            shift 2
            ;;
        --database)
            (($# >= 2)) || { echo "Missing value for --database" >&2; exit 64; }
            DATABASE="$2"
            shift 2
            ;;
        --mysql-host)
            (($# >= 2)) || { echo "Missing value for --mysql-host" >&2; exit 64; }
            MYSQL_HOST="$2"
            shift 2
            ;;
        --mysql-port)
            (($# >= 2)) || { echo "Missing value for --mysql-port" >&2; exit 64; }
            MYSQL_PORT="$2"
            shift 2
            ;;
        --mysql-socket)
            (($# >= 2)) || { echo "Missing value for --mysql-socket" >&2; exit 64; }
            MYSQL_SOCKET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [[ ! "$DATABASE" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Refusing unsafe database identifier: $DATABASE" >&2
    exit 64
fi

case "$DATABASE" in
    information_schema|mysql|performance_schema|sys)
        echo "Refusing to recreate a system database: $DATABASE" >&2
        exit 64
        ;;
esac

if ! command -v mysql >/dev/null 2>&1; then
    echo "BLOCKED-DB: mysql client is not installed or not on PATH" >&2
    exit 2
fi

MYSQL_ARGS=(--user="$MYSQL_USER" --batch --raw)
if [[ -n "$MYSQL_HOST" ]]; then
    MYSQL_ARGS+=(--host="$MYSQL_HOST")
fi
if [[ -n "$MYSQL_PORT" ]]; then
    MYSQL_ARGS+=(--port="$MYSQL_PORT")
fi
if [[ -n "$MYSQL_SOCKET" ]]; then
    MYSQL_ARGS+=(--socket="$MYSQL_SOCKET")
fi

TMP_PARENT="${TMPDIR:-/tmp}"
TMP_ROOT="$(mktemp -d "$TMP_PARENT/safedrive-verify.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

if ! PREFLIGHT_OUTPUT="$(mysql "${MYSQL_ARGS[@]}" --execute='SELECT VERSION();' 2>&1)"; then
    echo "BLOCKED-DB: MySQL connection is unavailable for the selected client settings." >&2
    echo "$PREFLIGHT_OUTPUT" >&2
    exit 2
fi

MYSQL_DB_ARGS=("${MYSQL_ARGS[@]}" --database="$DATABASE")
RESULT_DIR="$ROOT_DIR/results"
mkdir -p "$RESULT_DIR"

run_once() {
    local output_dir="$1"
    local query_file
    local query_name

    mkdir -p "$output_dir"

    if ! mysql "${MYSQL_ARGS[@]}" --execute="DROP DATABASE IF EXISTS \`$DATABASE\`; CREATE DATABASE \`$DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" \
        >"$output_dir/database.log" 2>&1; then
        cat "$output_dir/database.log" >&2
        return 1
    fi

    if ! mysql "${MYSQL_DB_ARGS[@]}" < "$ROOT_DIR/sql/00_schema.sql" >"$output_dir/schema.log" 2>&1; then
        cat "$output_dir/schema.log" >&2
        return 1
    fi
    if ! mysql "${MYSQL_DB_ARGS[@]}" < "$ROOT_DIR/sql/20_trigger.sql" >"$output_dir/trigger.log" 2>&1; then
        cat "$output_dir/trigger.log" >&2
        return 1
    fi
    if ! mysql "${MYSQL_DB_ARGS[@]}" < "$ROOT_DIR/sql/01_seed.sql" >"$output_dir/seed.log" 2>&1; then
        cat "$output_dir/seed.log" >&2
        return 1
    fi

    for query_file in "$ROOT_DIR"/sql/10_queries/q*.sql; do
        query_name="$(basename "$query_file" .sql)"
        if ! mysql "${MYSQL_DB_ARGS[@]}" < "$query_file" >"$output_dir/$query_name.tsv" 2>"$output_dir/$query_name.err"; then
            cat "$output_dir/$query_name.err" >&2
            return 1
        fi
    done

    if ! mysql "${MYSQL_DB_ARGS[@]}" < "$ROOT_DIR/sql/30_assertions.sql" >"$output_dir/assertions.log" 2>&1; then
        cat "$output_dir/assertions.log" >&2
        return 1
    fi
}

RUN_ONE="$TMP_ROOT/run-one"
RUN_TWO="$TMP_ROOT/run-two"

if ! run_once "$RUN_ONE"; then
    echo "FAIL: database load, query execution, or assertions failed (see temporary verifier logs)." >&2
    exit 1
fi

if ! run_once "$RUN_TWO"; then
    echo "FAIL: second database load, query execution, or assertions failed (idempotency run)." >&2
    exit 1
fi

for result_file in "$RUN_ONE"/q*.tsv; do
    result_name="$(basename "$result_file")"
    if ! cmp -s "$result_file" "$RUN_TWO/$result_name"; then
        echo "FAIL: non-identical repeated output for $result_name" >&2
        diff -u "$result_file" "$RUN_TWO/$result_name" >&2 || true
        exit 1
    fi
    cp "$result_file" "$RESULT_DIR/$result_name"
done

echo "PASS: schema, trigger, seed, ten queries, and assertions completed twice."
echo "PASS: repeated query outputs are byte-identical."
for result_file in "$RUN_ONE"/q*.tsv; do
    result_name="$(basename "$result_file")"
    row_count="$(tail -n +2 "$result_file" | wc -l | tr -d ' ')"
    echo "ROWS: $result_name $row_count"
done
