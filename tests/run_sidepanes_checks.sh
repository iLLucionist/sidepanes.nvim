#!/usr/bin/env sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MODE="${1:-fast}"
TMP_ROOT="${TMPDIR:-/tmp}"
TMP_ROOT="${TMP_ROOT%/}"

clean_nvim_state() {
    name="$1"

    rm -rf "${TMP_ROOT}/sidepanes-nvim-cache-${name}" "${TMP_ROOT}/sidepanes-nvim-state-${name}"
}

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

    clean_nvim_state "$name"
    run_nvim "$name" \
        -u NONE \
        -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/$file]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
	        -c 'qa!'
}

run_lifecycle() {
    name="sidepanes-agent-lifecycle"
    base="${TMP_ROOT}/${name}-$$"
    home="$base/home"
    root="$base/project"
    bin="$base/bin"
    args="$base/args.txt"
    memory="$base/memory.txt"
    session_id="codex-lifecycle-session"
    fake_codex="$bin/codex"

    clean_nvim_state "$name"
    mkdir -p "$home" "$root/.git" "$bin"
    cat > "$fake_codex" <<'EOF'
#!/bin/sh
set -eu
printf '%s\n' "$@" >> "$SIDEPANES_AGENT_ARGS_FILE"
last=''
for arg in "$@"; do
    last="$arg"
done
if [ "${1:-}" = "resume" ]; then
    printf 'resumed %s\n' "$last"
    if [ -f "$SIDEPANES_AGENT_MEMORY_FILE" ]; then
        printf 'memory: %s\n' "$(cat "$SIDEPANES_AGENT_MEMORY_FILE")"
    fi
    sleep 10
    exit 0
fi
mkdir -p "$HOME/.codex/sessions/2026/07/21"
printf '{"type":"session_meta","payload":{"session_id":"%s","cwd":"%s"}}\n' "$SIDEPANES_AGENT_SESSION_ID" "$PWD" > "$HOME/.codex/sessions/2026/07/21/rollout-sidepanes-lifecycle.jsonl"
while IFS= read -r line; do
    case "$line" in
        remember*)
            printf '%s\n' "$line" > "$SIDEPANES_AGENT_MEMORY_FILE"
            printf 'stored %s\n' "$line"
            ;;
        /quit*)
            exit 0
            ;;
    esac
done
EOF
    chmod +x "$fake_codex"

    HOME="$home" \
        SIDEPANES_AGENT_ROOT="$root" \
        SIDEPANES_FAKE_CODEX="$fake_codex" \
        SIDEPANES_AGENT_ARGS_FILE="$args" \
        SIDEPANES_AGENT_MEMORY_FILE="$memory" \
        SIDEPANES_AGENT_SESSION_ID="$session_id" \
        run_nvim "$name" \
            -u NONE \
            -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/sidepanes_agent_lifecycle_first.lua]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
            -c 'qa!'

    : > "$args"

    HOME="$home" \
        SIDEPANES_AGENT_ROOT="$root" \
        SIDEPANES_FAKE_CODEX="$fake_codex" \
        SIDEPANES_AGENT_ARGS_FILE="$args" \
        SIDEPANES_AGENT_MEMORY_FILE="$memory" \
        SIDEPANES_AGENT_SESSION_ID="$session_id" \
        run_nvim "$name" \
            -u NONE \
            -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/sidepanes_agent_lifecycle_second.lua]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
            -c 'qa!'
}

run_registry_concurrency() {
    name="sidepanes-registry-concurrency"
    base="${TMP_ROOT}/${name}-$$"
    state="$base/state"
    store="$state/agent_sessions.json"
    root_one="$base/project-one"
    root_two="$base/project-two"
    session_one="codex-concurrent-session"
    session_two="claude-concurrent-session"

    clean_nvim_state "$name-one"
    clean_nvim_state "$name-two"
    clean_nvim_state "$name-verify"
    rm -rf "$base"
    mkdir -p "$state" "$root_one/.git" "$root_two/.git" "$store.lock"
    printf '{"pid":0,"created_at_ms":9999999999999}\n' > "$store.lock/owner.json"

    SIDEPANES_REGISTRY_STORE="$store" \
        SIDEPANES_REGISTRY_ROOT="$root_one" \
        SIDEPANES_REGISTRY_TOOL="codex" \
        SIDEPANES_REGISTRY_SESSION="$session_one" \
        SIDEPANES_REGISTRY_UPDATED_AT="100" \
        run_nvim "$name-one" \
            -u NONE \
            -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/sidepanes_registry_writer.lua]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
            -c 'qa!' &
    writer_one=$!

    SIDEPANES_REGISTRY_STORE="$store" \
        SIDEPANES_REGISTRY_ROOT="$root_two" \
        SIDEPANES_REGISTRY_TOOL="claude" \
        SIDEPANES_REGISTRY_SESSION="$session_two" \
        SIDEPANES_REGISTRY_UPDATED_AT="200" \
        run_nvim "$name-two" \
            -u NONE \
            -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/sidepanes_registry_writer.lua]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
            -c 'qa!' &
    writer_two=$!

    sleep 0.2
    rm -rf "$store.lock"

    wait "$writer_one"
    wait "$writer_two"

    SIDEPANES_REGISTRY_STORE="$store" \
        SIDEPANES_REGISTRY_ROOT_ONE="$root_one" \
        SIDEPANES_REGISTRY_ROOT_TWO="$root_two" \
        SIDEPANES_REGISTRY_SESSION_ONE="$session_one" \
        SIDEPANES_REGISTRY_SESSION_TWO="$session_two" \
        run_nvim "$name-verify" \
            -u NONE \
            -c "lua local ok, err = xpcall(function() dofile([[$ROOT_DIR/tests/sidepanes_registry_concurrency_verify.lua]]) end, debug.traceback); if not ok then io.stderr:write(err .. '\n'); vim.cmd('cquit') end" \
            -c 'qa!'
}

run_fast() {
    run_lua sidepanes-regression sidepanes_regression.lua
    run_lifecycle
    run_registry_concurrency
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
