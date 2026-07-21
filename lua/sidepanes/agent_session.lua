--[[
sidepanes.agent_session
Purpose: Recover pane-owned coding-agent sessions after terminal jobs exit.
Does: Tracks OS pids and resumable session ids for Codex and Claude, refreshes pane-owned contexts from tool metadata, and rewrites restart commands to resume.
Architecture: Keeps tool-specific persistence details out of terminal.lua while exposing small pure helpers for command construction and state updates.
]]

local util = require("sidepanes.util")

local M = {}

local supported_tools = {
    claude = true,
    codex = true,
}

local function home_path(...)
    local home = vim.env.HOME or vim.fn.expand("~")

    return table.concat({ home, ... }, "/")
end

local function read_json(path)
    if not path or vim.fn.filereadable(path) ~= 1 then
        return nil
    end

    local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))

    if ok and type(decoded) == "table" then
        return decoded
    end

    return nil
end

local function now_ms()
    local uv = vim.uv or vim.loop

    return uv and uv.now and uv.now() or (os.time() * 1000)
end

local function write_json(path, value)
    if not path then
        return false
    end

    local dir = vim.fn.fnamemodify(path, ":p:h")

    vim.fn.mkdir(dir, "p")

    local ok, encoded = pcall(vim.json.encode, value)

    if not ok then
        return false
    end

    local uv = vim.uv or vim.loop
    local token = tostring(uv and uv.hrtime and uv.hrtime() or os.time())
    local tmp = path .. ".tmp." .. tostring(vim.fn.getpid()) .. "." .. token

    if vim.fn.writefile({ encoded }, tmp) ~= 0 then
        return false
    end

    pcall(vim.fn.setfperm, tmp, "rw-------")

    if vim.fn.rename(tmp, path) ~= 0 then
        pcall(vim.fn.delete, tmp)
        return false
    end

    pcall(vim.fn.setfperm, path, "rw-------")

    return true
end

local function read_jsonl_head(path)
    if not path or vim.fn.filereadable(path) ~= 1 then
        return {}
    end

    local items = {}

    for _, line in ipairs(vim.fn.readfile(path, "", 20)) do
        if line ~= "" then
            local ok, decoded = pcall(vim.json.decode, line)

            if ok and type(decoded) == "table" then
                table.insert(items, decoded)
            end
        end
    end

    return items
end

local function normalize_root(root)
    return (util.normalize_project_root(root):gsub("/$", ""))
end

local function same_root(a, b)
    return a and b and normalize_root(a) == normalize_root(b)
end

local function sorted_files(pattern)
    local files = vim.fn.glob(pattern, false, true)

    table.sort(files, function(a, b)
        return vim.fn.getftime(a) > vim.fn.getftime(b)
    end)

    return files
end

local function claude_project_dir(root)
    return (normalize_root(root):gsub("/", "-"))
end

local function claude_session_from_pid(pid, root)
    if not pid then
        return nil
    end

    local metadata_path = home_path(".claude", "sessions", tostring(pid) .. ".json")
    local metadata = read_json(metadata_path)

    local session_id = metadata and (metadata.sessionId or metadata.session_id) or nil

    if not session_id then
        return nil
    end

    local metadata_root = metadata.cwd or metadata.root

    if metadata_root and root and not same_root(metadata_root, root) then
        return nil
    end

    return session_id, {
        metadata_path = metadata_path,
        captured_cwd = metadata_root,
    }
end

local function session_info(path, session_id, extra)
    if not session_id or session_id == "" then
        return nil
    end

    local info = {
        session_id = session_id,
        updated_at = vim.fn.getftime(path),
        transcript_path = path,
    }

    if type(extra) == "table" then
        info = vim.tbl_extend("force", info, extra)
    end

    return info
end

local function latest_claude_session(root)
    local dir = home_path(".claude", "projects", claude_project_dir(root))

    for _, path in ipairs(sorted_files(dir .. "/*.jsonl")) do
        local session_id = vim.fn.fnamemodify(path, ":t:r")

        if session_id and session_id ~= "" then
            return session_info(path, session_id)
        end
    end

    return nil
end

local function codex_sessions(root)
    local sessions = {}

    for _, path in ipairs(sorted_files(home_path(".codex", "sessions", "**", "*.jsonl"))) do
        for _, item in ipairs(read_jsonl_head(path)) do
            local payload = item and item.payload or nil

            if item.type == "session_meta" and type(payload) == "table" and same_root(payload.cwd, root) then
                local info = session_info(path, payload.session_id or payload.id, {
                    captured_cwd = payload.cwd,
                })

                if info then
                    table.insert(sessions, info)
                end
            end
        end
    end

    return sessions
end

local function latest_codex_session(root)
    return codex_sessions(root)[1]
end

local function contains_flag(cmd, flags)
    for _, value in ipairs(cmd or {}) do
        if flags[value] then
            return true
        end
    end

    return false
end

local function command_matches_tool(tool_name, cmd)
    local executable = cmd and cmd[1]

    return type(executable) == "string" and vim.fn.fnamemodify(executable, ":t") == tool_name
end

local function resume_options(config)
    config = config or {}

    return {
        auto_resume = config.agent_auto_resume ~= false,
        infer_from_transcripts = config.agent_resume_infer_from_transcripts ~= false,
        use_claude_pid_metadata = config.agent_resume_use_claude_pid_metadata ~= false,
        mechanisms = config.agent_resume_mechanisms,
        store_path = config.agent_resume_store_path,
        store_lock_timeout_ms = config.agent_resume_store_lock_timeout_ms,
        store_lock_stale_ms = config.agent_resume_store_lock_stale_ms,
        resolver = config.agent_resume_resolver,
    }
end

local function mechanism_enabled(config, tool_name, mechanism)
    local mechanisms = resume_options(config).mechanisms

    if mechanisms == false then
        return false
    end

    local tool_mechanisms = type(mechanisms) == "table" and mechanisms[tool_name] or nil

    if tool_mechanisms == false then
        return false
    elseif tool_mechanisms == nil then
        if tool_name == "claude" then
            tool_mechanisms = { "hook", "pid_metadata", "transcript" }
        elseif tool_name == "codex" then
            tool_mechanisms = { "transcript" }
        else
            tool_mechanisms = {}
        end
    end

    for _, candidate in ipairs(tool_mechanisms) do
        if candidate == mechanism then
            return true
        end
    end

    return false
end

local function state_dir()
    return vim.fn.stdpath("state") .. "/sidepanes"
end

local function store_path(config)
    local configured = resume_options(config).store_path

    if configured == false then
        return nil
    elseif type(configured) == "string" and configured ~= "" then
        return vim.fn.fnamemodify(configured, ":p")
    end

    return state_dir() .. "/agent_sessions.json"
end

local function lock_path(path)
    return path .. ".lock"
end

local function lock_age_ms(path)
    local owner = read_json(path .. "/owner.json")

    if type(owner) == "table" and type(owner.created_at_ms) == "number" then
        return now_ms() - owner.created_at_ms
    end

    local mtime = vim.fn.getftime(path)

    if mtime > 0 then
        return now_ms() - (mtime * 1000)
    end

    return 0
end

local function acquire_store_lock(path, config)
    local options = resume_options(config)
    local timeout_ms = math.max(0, tonumber(options.store_lock_timeout_ms) or 1000)
    local stale_ms = math.max(0, tonumber(options.store_lock_stale_ms) or 10000)
    local lock = lock_path(path)
    local deadline = now_ms() + timeout_ms

    vim.fn.mkdir(vim.fn.fnamemodify(path, ":p:h"), "p")

    while true do
        local ok, created = pcall(vim.fn.mkdir, lock)

        if ok and created == 1 then
            write_json(lock .. "/owner.json", {
                pid = vim.fn.getpid(),
                created_at_ms = now_ms(),
            })

            return lock
        end

        if stale_ms > 0 and vim.fn.isdirectory(lock) == 1 and lock_age_ms(lock) > stale_ms then
            pcall(vim.fn.delete, lock, "rf")
        elseif now_ms() >= deadline then
            return nil
        else
            vim.wait(math.min(25, math.max(1, deadline - now_ms())), function()
                return false
            end)
        end
    end
end

local function release_store_lock(lock)
    if lock then
        pcall(vim.fn.delete, lock, "rf")
    end
end

local function registry_sessions(decoded)
    if type(decoded) ~= "table" then
        return {}
    end

    return type(decoded.sessions) == "table" and decoded.sessions or decoded
end

local function valid_session_record(session)
    return type(session) == "table" and type(session.session_id) == "string" and session.session_id ~= "" and type(session.root) == "string" and type(session.tool_name) == "string"
end

local function session_updated_at(session)
    return tonumber(session and session.updated_at) or 0
end

local function normalized_session_record(session)
    local copy = vim.deepcopy(session)

    copy.root = normalize_root(copy.root)
    copy.key = util.terminal_key(copy.tool_name, copy.root)

    return copy
end

local function merge_sessions(base, incoming)
    local merged = vim.deepcopy(base or {})

    for key, session in pairs(incoming or {}) do
        if valid_session_record(session) then
            session = normalized_session_record(session)
            key = session.key or key

            if not valid_session_record(merged[key]) or session_updated_at(session) >= session_updated_at(merged[key]) then
                merged[key] = session
            end
        end
    end

    return merged
end

local function capture_dir()
    return state_dir() .. "/agent-capture"
end

local function capture_paths(ctx)
    local uv = vim.uv or vim.loop
    local token = ctx.capture_token or tostring(uv and uv.hrtime and uv.hrtime() or os.time())

    ctx.capture_token = token

    local name = vim.fn.sha256((ctx.key or (ctx.tool_name .. "::" .. tostring(ctx.root))) .. "::" .. token)
    local dir = capture_dir()

    return {
        data = dir .. "/" .. name .. ".json",
        settings = dir .. "/" .. name .. "-settings.json",
        script = dir .. "/" .. name .. "-capture.sh",
    }
end

local function copy_tail(cmd, start_index)
    local result = {}

    for index = start_index, #cmd do
        table.insert(result, cmd[index])
    end

    return result
end

function M.is_supported(tool_name)
    return supported_tools[tool_name] == true
end

function M.latest_for_root(tool_name, root)
    local info = M.latest_info_for_root(tool_name, root)

    return info and info.session_id or nil
end

function M.latest_info_for_root(tool_name, root)
    if tool_name == "claude" then
        return latest_claude_session(root)
    elseif tool_name == "codex" then
        return latest_codex_session(root)
    end

    return nil
end

function M.session_infos_for_root(tool_name, root)
    if tool_name == "claude" then
        local latest = latest_claude_session(root)

        return latest and { latest } or {}
    elseif tool_name == "codex" then
        return codex_sessions(root)
    end

    return {}
end

function M.can_infer_from_transcripts(config)
    return resume_options(config).infer_from_transcripts
end

function M.load_store(state)
    local path = store_path(state and state.config or nil)
    local decoded = read_json(path)

    if type(decoded) ~= "table" then
        return false
    end

    state.agent_sessions = state.agent_sessions or {}
    state.agent_sessions = merge_sessions(state.agent_sessions, registry_sessions(decoded))

    return true
end

function M.save_store(state)
    local path = store_path(state and state.config or nil)

    if not path then
        return false
    end

    local lock = acquire_store_lock(path, state and state.config or nil)

    if not lock then
        return false
    end

    local ok, result = pcall(function()
        local existing = registry_sessions(read_json(path))
        local sessions = merge_sessions(existing, state.agent_sessions or {})

        for key, deleted_at in pairs(state.agent_session_tombstones or {}) do
            if not sessions[key] or session_updated_at(sessions[key]) <= deleted_at then
                sessions[key] = nil
            end
        end

        state.agent_sessions = sessions

        return write_json(path, {
            version = 1,
            sessions = sessions,
        })
    end)

    release_store_lock(lock)

    return ok and result == true
end

local function remember_session(state, ctx, session_id, source, evidence)
    ctx.session_id = session_id
    state.agent_sessions = state.agent_sessions or {}
    local key = util.terminal_key(ctx.tool_name, ctx.root)
    local previous = state.agent_sessions[key] or state.agent_sessions[ctx.key]
    local record = {
        key = key,
        tool_name = ctx.tool_name,
        root = normalize_root(ctx.root),
        session_id = session_id,
        pid = ctx.pid,
        pid_running = util.pid_running(ctx.pid),
        source = source,
        updated_at = os.time(),
    }

    if type(evidence) == "table" then
        record.transcript_path = evidence.transcript_path
        record.metadata_path = evidence.metadata_path
        record.capture_path = evidence.capture_path
        record.captured_cwd = evidence.captured_cwd
        record.resolver_state = evidence.resolver_state
    elseif previous and previous.session_id == session_id then
        record.transcript_path = previous.transcript_path
        record.metadata_path = previous.metadata_path
        record.capture_path = previous.capture_path
        record.captured_cwd = previous.captured_cwd
        record.resolver_state = previous.resolver_state
        record.source = previous.source or source
    end

    record = normalized_session_record(record)
    state.agent_sessions[record.key] = record
    M.save_store(state)
end

local function session_from_capture(ctx)
    local capture = ctx and ctx.session_capture or nil
    local data = capture and read_json(capture.path) or nil

    if type(data) ~= "table" then
        return nil
    end

    local session_id = data.session_id or data.sessionId
    local root = data.cwd or data.root or (data.workspace and (data.workspace.project_dir or data.workspace.current_dir))

    if session_id and (not root or same_root(root, ctx.root)) then
        return session_id, {
            capture_path = capture.path,
            transcript_path = data.transcript_path,
            captured_cwd = root,
        }
    end

    return nil
end

local function resolver_session_id(result)
    if type(result) == "string" then
        return result
    elseif type(result) == "table" then
        return result.session_id or result.sessionId or result.id
    end

    return nil
end

local function resolver_evidence(result)
    if type(result) ~= "table" then
        return nil
    end

    local evidence = type(result.evidence) == "table" and vim.deepcopy(result.evidence) or {}

    evidence.transcript_path = evidence.transcript_path or result.transcript_path
    evidence.metadata_path = evidence.metadata_path or result.metadata_path
    evidence.capture_path = evidence.capture_path or result.capture_path
    evidence.captured_cwd = evidence.captured_cwd or result.cwd or result.root
    evidence.resolver_state = evidence.resolver_state or result.resolver_state

    return evidence
end

local function resolver_context(ctx)
    return {
        key = ctx.key,
        tool_name = ctx.tool_name,
        root = ctx.root,
        session_id = ctx.session_id,
        pid = ctx.pid,
        job_id = ctx.job_id,
        bufnr = ctx.bufnr,
        started_at = ctx.started_at,
        started_at_ms = ctx.started_at_ms,
        resumed = ctx.resumed,
        resume_source = ctx.resume_source,
    }
end

local function call_custom_resolver(state, ctx, purpose, record)
    local resolver = resume_options(state and state.config or nil).resolver

    if type(resolver) ~= "function" then
        return nil
    end

    local public_ctx = resolver_context(ctx)
    local ok, session_id = pcall(resolver, public_ctx.tool_name, public_ctx, {
        root = ctx.root,
        key = ctx.key,
        purpose = purpose,
        remembered = record,
    })

    if ok then
        return session_id
    end

    return nil
end

local function session_from_custom_resolver(state, ctx)
    local result = call_custom_resolver(state, ctx, "capture")
    local session_id = resolver_session_id(result)

    if type(session_id) == "string" and session_id ~= "" then
        return session_id, resolver_evidence(result)
    end

    return nil
end

function M.prepare_command(state, ctx, cmd)
    if not (ctx and ctx.tool_name == "claude" and mechanism_enabled(state and state.config or nil, "claude", "hook")) then
        return cmd
    end

    if not command_matches_tool("claude", cmd) or contains_flag(cmd, { ["--settings"] = true }) then
        return cmd
    end

    local paths = capture_paths(ctx)
    local script = {
        "#!/bin/sh",
        "set -eu",
        "tmp=" .. vim.fn.shellescape(paths.data .. ".tmp"),
        "cat > \"$tmp\"",
        "mv \"$tmp\" " .. vim.fn.shellescape(paths.data),
    }

    vim.fn.mkdir(vim.fn.fnamemodify(paths.script, ":p:h"), "p")
    vim.fn.writefile(script, paths.script)
    vim.fn.setfperm(paths.script, "rwx------")
    write_json(paths.settings, {
        hooks = {
            SessionStart = {
                {
                    hooks = {
                        {
                            type = "command",
                            command = vim.fn.shellescape(paths.script),
                        },
                    },
                },
            },
        },
    })

    ctx.session_capture = {
        type = "claude_hook",
        path = paths.data,
        settings_path = paths.settings,
        script_path = paths.script,
    }

    local result = { cmd[1], "--settings", paths.settings }

    vim.list_extend(result, copy_tail(cmd, 2))

    return result
end

local function can_use_latest_for_context(ctx, latest)
    if not latest then
        return false
    end

    if ctx.initial_latest_session_id and latest.session_id == ctx.initial_latest_session_id then
        return false
    end

    if not (ctx.job_id and util.is_running(ctx.job_id)) then
        return true
    end

    return not ctx.started_at or latest.updated_at >= ctx.started_at - 1
end

local function capture_matches(record, root)
    local data = read_json(record.capture_path)

    if type(data) ~= "table" then
        return false
    end

    local session_id = data.session_id or data.sessionId
    local captured_root = data.cwd or data.root or (data.workspace and (data.workspace.project_dir or data.workspace.current_dir))

    return session_id == record.session_id and (not captured_root or same_root(captured_root, root))
end

local function metadata_matches(record, root)
    local data = read_json(record.metadata_path)

    if type(data) ~= "table" then
        return false
    end

    local session_id = data.sessionId or data.session_id
    local metadata_root = data.cwd or data.root

    return session_id == record.session_id and (not metadata_root or same_root(metadata_root, root))
end

local function claude_transcript_matches(record, root)
    if vim.fn.filereadable(record.transcript_path or "") ~= 1 then
        return false
    end

    local session_id = vim.fn.fnamemodify(record.transcript_path, ":t:r")
    local project_dir = vim.fn.fnamemodify(vim.fn.fnamemodify(record.transcript_path, ":h"), ":t")

    return session_id == record.session_id and project_dir == claude_project_dir(root)
end

local function codex_transcript_matches(record, root)
    if vim.fn.filereadable(record.transcript_path or "") ~= 1 then
        return false
    end

    for _, item in ipairs(read_jsonl_head(record.transcript_path)) do
        local payload = item and item.payload or nil

        if item.type == "session_meta" and type(payload) == "table" and (payload.session_id == record.session_id or payload.id == record.session_id) and same_root(payload.cwd, root) then
            return true
        end
    end

    return false
end

local function resolver_matches(state, record, root)
    local ctx = {
        key = util.terminal_key(record.tool_name, root),
        tool_name = record.tool_name,
        root = normalize_root(root),
        session_id = record.session_id,
    }
    local result = call_custom_resolver(state, ctx, "validate", record)

    if result == true then
        return true
    elseif type(result) == "table" and result.valid ~= nil then
        return result.valid == true
    end

    local session_id = resolver_session_id(result)

    return type(session_id) == "string" and session_id == record.session_id
end

local function remembered_session_valid(state, record, root)
    if not (valid_session_record(record) and same_root(record.root, root)) then
        return false
    end

    local resolver_record = record.source == "resolver"

    if resolver_record and not resolver_matches(state, record, root) then
        return false
    end

    if record.capture_path then
        return capture_matches(record, root)
    end

    if record.metadata_path then
        return metadata_matches(record, root)
    end

    if record.transcript_path and record.tool_name == "claude" then
        return claude_transcript_matches(record, root)
    elseif record.transcript_path and record.tool_name == "codex" then
        return codex_transcript_matches(record, root)
    end

    return resolver_record
end

function M.forget_session(state, tool_name, root)
    local key = util.terminal_key(tool_name, root)

    if not (state and state.agent_sessions and state.agent_sessions[key]) then
        return false
    end

    state.agent_sessions[key] = nil
    state.agent_session_tombstones = state.agent_session_tombstones or {}
    state.agent_session_tombstones[key] = os.time()
    M.save_store(state)

    return true
end

function M.refresh_context(state, ctx)
    if not (ctx and M.is_supported(ctx.tool_name)) then
        return nil
    end

    local options = resume_options(state and state.config or nil)
    local session_id = ctx.session_id
    local source = ctx.session_id and "context" or nil
    local evidence = nil

    if not session_id then
        session_id, evidence = session_from_capture(ctx)
        source = session_id and "capture" or nil
    end

    if not session_id then
        session_id, evidence = session_from_custom_resolver(state, ctx)
        source = session_id and "resolver" or nil
    end

    if options.use_claude_pid_metadata and not session_id and ctx.tool_name == "claude" and mechanism_enabled(state and state.config or nil, "claude", "pid_metadata") then
        session_id, evidence = claude_session_from_pid(ctx.pid, ctx.root)
        source = session_id and "pid_metadata" or nil
    end

    if options.infer_from_transcripts and not session_id and mechanism_enabled(state and state.config or nil, ctx.tool_name, "transcript") then
        local matches = {}

        for _, candidate in ipairs(M.session_infos_for_root(ctx.tool_name, ctx.root)) do
            if can_use_latest_for_context(ctx, candidate) then
                table.insert(matches, candidate)
            end
        end

        if #matches == 1 then
            session_id = matches[1].session_id
            evidence = matches[1]
            source = "transcript"
        end
    end

    if not session_id then
        return nil
    end

    remember_session(state, ctx, session_id, source, evidence)

    return session_id
end

function M.resolve_resume(state, ctx, tool_name, root)
    if not M.is_supported(tool_name) then
        return nil
    end

    if not resume_options(state and state.config or nil).auto_resume then
        return nil
    end

    if ctx then
        local refreshed = M.refresh_context(state, ctx)

        if refreshed then
            return {
                session_id = refreshed,
                pid = ctx.pid,
                pid_running = util.pid_running(ctx.pid),
                source = "context",
            }
        end
    end

    local key = util.terminal_key(tool_name, root)
    local remembered = state.agent_sessions and state.agent_sessions[key] or nil

    if remembered and remembered_session_valid(state, remembered, root) then
        return {
            session_id = remembered.session_id,
            pid = remembered.pid,
            pid_running = util.pid_running(remembered.pid),
            source = "remembered",
        }
    elseif remembered then
        M.forget_session(state, tool_name, root)
    end

    return nil
end

function M.resolve_resume_id(state, ctx, tool_name, root)
    local resume = M.resolve_resume(state, ctx, tool_name, root)

    return resume and resume.session_id or nil
end

function M.resume_command(tool_name, cmd, session_id)
    if not (M.is_supported(tool_name) and session_id and session_id ~= "") then
        return cmd, false
    end

    if not command_matches_tool(tool_name, cmd) then
        return cmd, false
    end

    if tool_name == "claude" then
        if contains_flag(cmd, { ["--resume"] = true, ["-r"] = true }) then
            return cmd, false
        end

        local result = { cmd[1], "--resume", session_id }

        vim.list_extend(result, copy_tail(cmd, 2))

        return result, true
    elseif tool_name == "codex" then
        if cmd[2] == "resume" then
            return cmd, false
        end

        local result = { cmd[1], "resume" }

        vim.list_extend(result, copy_tail(cmd, 2))
        table.insert(result, session_id)

        return result, true
    end

    return cmd, false
end

return M
