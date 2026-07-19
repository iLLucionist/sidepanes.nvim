#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE="${1:-fast}"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"

run_nvim() {
    name="$1"
    shift

    XDG_CACHE_HOME="${TMP_ROOT}/sidepanes-nvim-cache-${name}" \
        XDG_STATE_HOME="${TMP_ROOT}/sidepanes-nvim-state-${name}" \
        nvim --headless "$@"
}

run_lua() {
    name="$1"
    file="$2"

    run_nvim "$name" \
        -u NONE \
        -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/$file]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
        -c 'qa!'
}

run_fast() {
    run_lua sidepanes-regression sidepanes_regression.lua
    run_lua sidepanes-audit-smoke sidepanes_audit_smoke.lua
    run_lua sidepanes-help-smoke sidepanes_help_smoke.lua
    run_lua sidepanes-docs-contract-smoke sidepanes_docs_contract_smoke.lua
    run_lua sidepanes-checkhealth-smoke sidepanes_checkhealth_smoke.lua
}

case "$MODE" in
    fast)
        run_fast
        ;;
    full)
        run_fast
        run_lua sidepanes-real-cli-smoke sidepanes_real_cli_smoke.lua
        ;;
    *)
        printf 'usage: %s [fast|full]\n' "$0" >&2
        exit 2
        ;;
esac

printf 'sidepanes %s checks passed\n' "$MODE"
