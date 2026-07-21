--[[
sidepanes.agent_session
Purpose: Recover pane-owned coding-agent sessions after terminal jobs exit.
Does: Tracks OS pids and resumable session ids for Codex and Claude, discovers recent project sessions, and rewrites restart commands to resume.
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

    local metadata = read_json(home_path(".claude", "sessions", tostring(pid) .. ".json"))

    local session_id = metadata and (metadata.sessionId or metadata.session_id) or nil

    if not session_id then
        return nil
    end

    local metadata_root = metadata.cwd or metadata.root

    if metadata_root and root and not same_root(metadata_root, root) then
        return nil
    end

    return session_id
end

local function session_info(path, session_id)
    if not session_id or session_id == "" then
        return nil
    end

    return {
        session_id = session_id,
        updated_at = vim.fn.getftime(path),
    }
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

local function latest_codex_session(root)
    for _, path in ipairs(sorted_files(home_path(".codex", "sessions", "**", "*.jsonl"))) do
        for _, item in ipairs(read_jsonl_head(path)) do
            local payload = item and item.payload or nil

            if item.type == "session_meta" and type(payload) == "table" and same_root(payload.cwd, root) then
                local info = session_info(path, payload.session_id or payload.id)

                if info then
                    return info
                end
            end
        end
    end

    return nil
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

function M.refresh_context(state, ctx)
    if not (ctx and M.is_supported(ctx.tool_name)) then
        return nil
    end

    local session_id = ctx.session_id

    if ctx.tool_name == "claude" then
        session_id = claude_session_from_pid(ctx.pid, ctx.root) or session_id
    end

    if not session_id then
        local latest = M.latest_info_for_root(ctx.tool_name, ctx.root)

        if can_use_latest_for_context(ctx, latest) then
            session_id = latest.session_id
        end
    end

    if not session_id then
        return nil
    end

    ctx.session_id = session_id
    state.agent_sessions = state.agent_sessions or {}
    state.agent_sessions[ctx.key] = {
        tool_name = ctx.tool_name,
        root = ctx.root,
        session_id = session_id,
        pid = ctx.pid,
        pid_running = util.pid_running(ctx.pid),
        updated_at = os.time(),
    }

    return session_id
end

function M.resolve_resume(state, ctx, tool_name, root)
    if not M.is_supported(tool_name) then
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

    if remembered and remembered.session_id and same_root(remembered.root, root) then
        return {
            session_id = remembered.session_id,
            pid = remembered.pid,
            pid_running = util.pid_running(remembered.pid),
            source = "remembered",
        }
    end

    local latest = M.latest_info_for_root(tool_name, root)

    if latest then
        return {
            session_id = latest.session_id,
            pid = nil,
            pid_running = false,
            source = "latest",
        }
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
