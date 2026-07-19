#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

exec "$SCRIPT_DIR/run_sidepanes_checks.sh" "${1:-fast}"
