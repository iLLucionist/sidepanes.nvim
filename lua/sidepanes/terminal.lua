--[[
sidepanes.terminal
Purpose: Own pane-managed terminal sessions for tools and IPython.
Does: Starts/reuses terminal jobs by project root, tracks active sessions and presets, sends prompts/code, switches models, and shuts jobs down.
Architecture: Implements terminal behavior behind the public facade, using entries/util helpers and injected window/selection callbacks.
]]

local entries = require("sidepanes.entries")
local agent_session = require("sidepanes.agent_session")
local util = require("sidepanes.util")

local M = {}

local function same_root(a, b)
    if not (a and b) then
        return false
    end

    return util.normalize_project_root(a):gsub("/$", "") == util.normalize_project_root(b):gsub("/$", "")
end

local function context_matches_root(ctx, root)
    return not root or (ctx and same_root(ctx.root, root))
end

local function recovery_message(ctx)
    local tool_label = ctx.tool_label or ctx.tool_name or "Agent"
    local details = { "session id " .. tostring(ctx.session_id) }

    if ctx.resume_pid then
        local previous = "previous PID " .. tostring(ctx.resume_pid)

        if ctx.resume_pid_running then
            previous = previous .. " still appears alive"
        end

        table.insert(details, previous)
    end

    if ctx.pid then
        table.insert(details, "new PID " .. tostring(ctx.pid))
    end

    return "Recovered/resumed a lost " .. tool_label .. " session: " .. table.concat(details, ", ")
end

local function configured_resume_badge_ms(state)
    local timeout = tonumber(state.config.agent_resume_badge_ms) or 0

    return math.max(0, math.floor(timeout))
end

local function now_ms()
    local uv = vim.uv or vim.loop

    return uv and uv.now and uv.now() or (os.time() * 1000)
end

local function resume_failure_timeout_ms(state)
    local config = state and state.config or {}
    local timeout = tonumber(config.agent_resume_failure_timeout_ms)

    if timeout == nil then
        timeout = 750
    end

    return math.max(0, math.floor(timeout))
end

local function resume_failure_action(state)
    local config = state and state.config or {}
    local action = config.agent_resume_failure_action

    if action == "notify" or action == "ignore" then
        return action
    end

    return "fresh"
end

local function clear_resume_badge_for_context(ctx, deps)
    if not (ctx and ctx.resume_badge_visible) then
        return false
    end

    ctx.resume_badge_visible = false
    ctx.resume_badge_armed = false
    ctx.resume_badge_token = (ctx.resume_badge_token or 0) + 1
    deps.update_sticky_heading()

    return true
end

--- Clear the temporary recovered/resumed marker in the pane winbar.
function M.clear_resume_badge(state, deps, ctx)
    ctx = ctx or (state.active_terminal_key and state.terminals[state.active_terminal_key] or nil)

    return clear_resume_badge_for_context(ctx, deps)
end

local function mark_recovered(ctx, state, deps)
    ctx.resume_badge_visible = true
    ctx.resume_badge_armed = false
    ctx.resume_badge_token = (ctx.resume_badge_token or 0) + 1

    local token = ctx.resume_badge_token
    local badge_ms = configured_resume_badge_ms(state)

    deps.update_sticky_heading()
    vim.defer_fn(function()
        if ctx.resume_badge_token == token then
            ctx.resume_badge_armed = true
        end
    end, 100)

    if badge_ms > 0 then
        vim.defer_fn(function()
            if ctx.resume_badge_token == token and state.terminals[ctx.key] == ctx then
                M.clear_resume_badge(state, deps, ctx)
            end
        end, badge_ms)
    end
end

--- Find the pane terminal context for a buffer.
function M.context_for_buf(state, bufnr)
    for _, ctx in pairs(state.terminals) do
        if ctx.bufnr == bufnr then
            return ctx
        end
    end

    return nil
end

--- Return whether a terminal context still has a live job and buffer.
function M.is_running(ctx)
    return ctx and util.valid_buf(ctx.bufnr) and util.is_running(ctx.job_id)
end

--- Return whether a tool is one of the conversational coding agents.
function M.is_coding_agent_tool(tool_name)
    return tool_name == "codex" or tool_name == "claude"
end

--- Remember the latest active terminal and per-tool coding-agent terminal.
function M.remember_context(state, ctx)
    if not ctx then
        return
    end

    state.last_terminal_key = ctx.key

    if M.is_coding_agent_tool(ctx.tool_name) then
        state.last_coding_agent_terminal_key = ctx.key
        state.last_tool_terminal_keys[ctx.tool_name] = ctx.key
    end
end

--- Build a picker entry representing an already-running terminal context.
function M.entry_for_context(state, ctx)
    local tool = (state.config.tools or {})[ctx.tool_name] or {}

    return {
        kind = "terminal",
        tool_name = ctx.tool_name,
        preset_name = ctx.preset_name,
        root = ctx.root,
        terminal_key = ctx.key,
        label = (tool.label or ctx.tool_label or ctx.tool_name) .. " current: " .. (ctx.preset_label or ctx.preset_name or "Default"),
        running = true,
        current = true,
        active = state.active_terminal_key == ctx.key,
    }
end

--- Find the best running terminal context for a tool and optional root.
function M.context_for_tool(state, tool_name, root)
    local last_key = state.last_tool_terminal_keys and state.last_tool_terminal_keys[tool_name] or nil
    local last_ctx = last_key and state.terminals[last_key] or nil

    if last_ctx and last_ctx.tool_name == tool_name and M.is_running(last_ctx) and context_matches_root(last_ctx, root) then
        return last_ctx
    end

    local root_ctx = root and state.terminals[util.terminal_key(tool_name, root)] or nil

    if root_ctx and M.is_running(root_ctx) then
        return root_ctx
    end

    for _, ctx in pairs(state.terminals or {}) do
        if ctx.tool_name == tool_name and M.is_running(ctx) and context_matches_root(ctx, root) then
            return ctx
        end
    end

    return nil
end

--- Find the most recently used running Codex or Claude context.
function M.last_coding_agent_context(state, root)
    local last_ctx = state.last_coding_agent_terminal_key and state.terminals[state.last_coding_agent_terminal_key] or nil

    if last_ctx and M.is_coding_agent_tool(last_ctx.tool_name) and M.is_running(last_ctx) and context_matches_root(last_ctx, root) then
        return last_ctx
    end

    local active_ctx = state.active_terminal_key and state.terminals[state.active_terminal_key] or nil

    if active_ctx and M.is_coding_agent_tool(active_ctx.tool_name) and M.is_running(active_ctx) and context_matches_root(active_ctx, root) then
        return active_ctx
    end

    for _, tool_name in ipairs({ "codex", "claude" }) do
        local ctx = M.context_for_tool(state, tool_name, root)

        if ctx then
            return ctx
        end
    end

    return nil
end

--- Start a new pane-owned terminal job for a tool and project root.
function M.start(state, deps, tool_name, preset_name, root)
    local tool = (state.config.tools or {})[tool_name]

    if not tool then
        vim.notify("Unknown pane tool: " .. tostring(tool_name), vim.log.levels.ERROR)
        return nil
    end

    local preset = entries.preset_by_name(tool, preset_name)
    local key = util.terminal_key(tool_name, root)
    local existing = state.terminals[key]

    if existing and util.valid_buf(existing.bufnr) and util.is_running(existing.job_id) then
        return existing, false
    end

    local initial_latest = agent_session.is_supported(tool_name) and agent_session.can_infer_from_transcripts(state.config) and agent_session.latest_info_for_root(tool_name, root) or nil
    local resume = agent_session.resolve_resume(state, existing, tool_name, root)
    local resume_id = resume and resume.session_id or nil
    local cmd = util.command_list(tool, preset, root)
    local resuming = false

    cmd, resuming = agent_session.resume_command(tool_name, cmd, resume_id)

    if not resuming then
        resume = nil
        resume_id = nil
    end

    local ctx = {
        key = key,
        tool_name = tool_name,
        tool_label = tool.label or tool_name,
        preset_name = preset.name or "default",
        preset_label = preset.label or preset.name or "Default",
        preset = preset,
        root = root,
        job_id = nil,
        pid = nil,
        started_at = os.time(),
        started_at_ms = now_ms(),
        initial_latest_session_id = initial_latest and initial_latest.session_id or nil,
        session_id = resume_id,
        resumed = resuming,
        resume_source = resume and resume.source or nil,
        resume_pid = resume and resume.pid or nil,
        resume_pid_running = resume and resume.pid_running or false,
        resume_badge_visible = false,
        resume_badge_armed = false,
        resume_badge_token = 0,
        send_delay_ms = tool.send_delay_ms or 700,
    }

    cmd = agent_session.prepare_command(state, ctx, cmd)

    if not util.executable_exists(cmd[1]) then
        vim.notify("Pane tool executable not found: " .. tostring(cmd[1]), vim.log.levels.ERROR)
        return nil
    end

    local bufnr = vim.api.nvim_create_buf(false, true)

    ctx.bufnr = bufnr

    pcall(vim.api.nvim_buf_set_name, bufnr, "Pane://" .. util.sanitize_name(key))
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr })
    deps.setup_pane_maps(bufnr)

    state.active_mode = tool_name
    state.active_terminal_key = key
    M.remember_context(state, ctx)
    deps.ensure_win(bufnr, "terminal", { focus = false })

    vim.api.nvim_win_call(state.winid, function()
        vim.api.nvim_set_current_buf(bufnr)
        ctx.job_id = vim.fn.termopen(cmd, {
            cwd = root,
            on_exit = function(_, exit_code)
                local failure_action = resume_failure_action(state)
                local failure_timeout = resume_failure_timeout_ms(state)

                if ctx.resumed and failure_action ~= "ignore" and not ctx.shutdown_requested and exit_code ~= 0 and not ctx.resume_retry_attempted and now_ms() - (ctx.started_at_ms or 0) <= failure_timeout then
                    ctx.resume_retry_attempted = true
                    agent_session.forget_session(state, ctx.tool_name, ctx.root)
                    vim.schedule(function()
                        if state.terminals[key] == ctx then
                            state.terminals[key] = nil
                        end

                        if failure_action == "fresh" then
                            vim.notify("Recovered " .. (ctx.tool_label or ctx.tool_name or "agent") .. " session exited quickly; cleared stale resume id and starting fresh.", vim.log.levels.WARN)
                            M.start(state, deps, tool_name, preset_name, root)
                        else
                            vim.notify("Recovered " .. (ctx.tool_label or ctx.tool_name or "agent") .. " session exited quickly; cleared stale resume id.", vim.log.levels.WARN)
                            deps.update_sticky_heading()
                        end
                    end)
                    return
                end

                agent_session.refresh_context(state, ctx)
                deps.update_sticky_heading()
            end,
        })
    end)

    if not ctx.job_id or ctx.job_id <= 0 then
        vim.notify("Could not start pane tool: " .. table.concat(cmd, " "), vim.log.levels.ERROR)
        return nil
    end

    ctx.pid = util.job_pid(ctx.job_id)
    state.terminals[key] = ctx

    if resuming then
        mark_recovered(ctx, state, deps)
        vim.notify(recovery_message(ctx), vim.log.levels.INFO)
    end

    if agent_session.is_supported(tool_name) then
        agent_session.refresh_context(state, ctx)
        vim.defer_fn(function()
            if state.terminals[key] == ctx then
                agent_session.refresh_context(state, ctx)
                deps.update_sticky_heading()
            end
        end, 1000)
    end

    return ctx, true
end

--- Open or focus a pane terminal, reusing an existing session when possible.
function M.open(state, deps, tool_name, preset_name, opts)
    opts = opts or {}

    if state.active_mode == "markdown" then
        deps.save_markdown_view()
    end

    local root = opts.root or deps.pane_root(opts.bufnr or vim.api.nvim_get_current_buf())
    local tool = (state.config.tools or {})[tool_name]

    if not tool then
        vim.notify("Unknown pane tool: " .. tostring(tool_name), vim.log.levels.ERROR)
        return nil
    end

    local preset = entries.preset_by_name(tool, preset_name)
    local key = util.terminal_key(tool_name, root)
    local ctx = state.terminals[key]
    local started = false

    if not M.is_running(ctx) then
        ctx, started = M.start(state, deps, tool_name, preset.name, root)
    end

    if not ctx then
        return nil
    end

    ctx.requested_preset = preset
    state.active_mode = tool_name
    state.active_terminal_key = ctx.key
    M.remember_context(state, ctx)
    deps.setup_pane_maps(ctx.bufnr)
    local focus = opts.focus == nil and state.config.focus_on_switch or opts.focus

    deps.ensure_win(ctx.bufnr, "terminal", { focus = focus })

    if focus and util.valid_win(state.winid) and vim.api.nvim_get_current_win() == state.winid and vim.api.nvim_win_get_buf(state.winid) == ctx.bufnr then
        pcall(vim.cmd, "startinsert")
    end

    deps.update_sticky_heading()

    return ctx, started
end

--- Show the most recently used pane terminal, falling back to Codex when needed.
---
--- This follows state.last_terminal_key, so the remembered terminal can be Codex, Claude,
--- IPython, or a configured custom terminal. If that terminal is still running, it is reused.
--- If it is not running, Sidepanes opens the remembered tool/preset when available, otherwise
--- it opens Codex with its default preset. This is a navigation convenience, not an audit log.
function M.show_last_terminal(state, deps, opts)
    opts = opts or {}

    local ctx = state.last_terminal_key and state.terminals[state.last_terminal_key] or nil

    if M.is_running(ctx) then
        M.open(state, deps, ctx.tool_name, ctx.preset_name, {
            root = ctx.root,
            focus = opts.focus == nil and state.config.focus_on_switch or opts.focus,
        })
        return
    end

    local root = opts.root or deps.pane_root(vim.api.nvim_get_current_buf())
    local tool_name = ctx and ctx.tool_name or "codex"
    local preset_name = ctx and ctx.preset_name or nil

    M.open(state, deps, tool_name, preset_name, {
        root = root,
        focus = opts.focus == nil and state.config.focus_on_switch or opts.focus,
    })
end

--- Format the in-terminal command that switches a running tool preset.
function M.format_switch_command(tool, preset)
    if not tool or not preset then
        return nil
    end

    local template = preset.switch_command or tool.switch_command

    if type(template) == "function" then
        return template(preset, tool)
    end

    if type(template) ~= "string" or template == "" then
        return nil
    end

    local values = {
        model = preset.model or preset.name or "",
        effort = preset.effort or "",
        speed = preset.speed or "normal",
        label = preset.label or preset.name or "",
        name = preset.name or "",
    }

    return (template:gsub("{([%w_]+)}", function(key)
        return values[key] or ""
    end):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Send text to a terminal job using bracketed paste.
function M.send_to_terminal(ctx, prompt, started)
    local delay = started and ctx.send_delay_ms or 50

    vim.defer_fn(function()
        if not util.is_running(ctx.job_id) then
            vim.notify(ctx.tool_label .. " terminal is not running", vim.log.levels.ERROR)
            return
        end

        vim.fn.chansend(ctx.job_id, "\27[200~" .. prompt .. "\27[201~\r")
    end, delay)
end

--- Send an ask prompt, switching model first when needed.
function M.send_prompt(state, ctx, entry, prompt, started)
    local tool = (state.config.tools or {})[ctx.tool_name]
    local preset = tool and entries.preset_by_name(tool, entry and entry.preset_name or ctx.preset_name) or ctx.preset
    local needs_switch = not started and preset and ctx.preset_name ~= preset.name
    local switch_command = needs_switch and M.format_switch_command(tool, preset) or nil

    if switch_command and switch_command ~= "" then
        vim.defer_fn(function()
            if not util.is_running(ctx.job_id) then
                vim.notify(ctx.tool_label .. " terminal is not running", vim.log.levels.ERROR)
                return
            end

            vim.fn.chansend(ctx.job_id, switch_command .. "\r")
        end, 50)
    end

    if preset then
        ctx.preset = preset
        ctx.preset_name = preset.name or "default"
        ctx.preset_label = preset.label or preset.name or "Default"
    end

    local prompt_delay = switch_command and 350 or nil

    if prompt_delay then
        vim.defer_fn(function()
            M.send_to_terminal(ctx, prompt, false)
        end, prompt_delay)
    else
        M.send_to_terminal(ctx, prompt, started)
    end
end

--- Resolve the project root used for IPython operations.
function M.ipython_root(deps, opts)
    opts = opts or {}

    return opts.root or deps.pane_root(opts.bufnr or vim.api.nvim_get_current_buf())
end

--- Open or focus the IPython pane terminal.
function M.open_ipython(state, deps, opts)
    opts = opts or {}

    return M.open(state, deps, "ipython", nil, {
        root = M.ipython_root(deps, opts),
        bufnr = opts.bufnr,
        focus = opts.focus,
    })
end

--- Send the current line or selection to IPython.
function M.send_ipython(state, deps, opts)
    opts = opts or {}

    local context = deps.selection_context(opts)

    if not context then
        return
    end

    local ctx, started = M.open(state, deps, "ipython", nil, {
        root = context.root,
        bufnr = context.bufnr,
        focus = opts.focus == true,
    })

    if ctx then
        M.send_to_terminal(ctx, context.text, started)
    end

    if opts.visual and opts.exit_visual ~= false then
        local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)

        vim.api.nvim_feedkeys(esc, "n", false)
    end
end

--- Clear the running IPython terminal screen.
function M.clear_ipython(state, deps, opts)
    opts = opts or {}

    local root = M.ipython_root(deps, opts)
    local ctx = state.terminals[util.terminal_key("ipython", root)]

    if not M.is_running(ctx) then
        vim.notify("No IPython pane running for " .. util.root_label(root), vim.log.levels.WARN)
        return
    end

    vim.fn.chansend(ctx.job_id, "\12")
end

--- Restart the IPython pane terminal for the current root.
function M.restart_ipython(state, deps, opts)
    opts = opts or {}

    local root = M.ipython_root(deps, opts)
    local key = util.terminal_key("ipython", root)
    local ctx = state.terminals[key]

    if ctx then
        if util.is_running(ctx.job_id) then
            pcall(vim.fn.jobstop, ctx.job_id)
        end

        if util.valid_buf(ctx.bufnr) then
            pcall(vim.api.nvim_buf_delete, ctx.bufnr, { force = true })
        end

        state.terminals[key] = nil
    end

    return M.open(state, deps, "ipython", nil, {
        root = root,
        bufnr = opts.bufnr,
        focus = opts.focus == nil or opts.focus,
    })
end

--- Resolve the polite shutdown command for a terminal context.
local function shutdown_command(state, ctx)
    local tool = (state.config.tools or {})[ctx.tool_name]

    if not tool then
        return nil
    end

    local command = tool.shutdown_command or tool.exit_command

    if type(command) == "function" then
        command = command(ctx, tool)
    end

    return command
end

--- Resolve the shutdown timeout for a terminal context.
local function shutdown_timeout(state, ctx, opts)
    local tool = (state.config.tools or {})[ctx.tool_name] or {}

    return opts.timeout_ms or tool.shutdown_timeout_ms or state.config.shutdown_timeout_ms or 300
end

--- Gracefully stop one terminal, then force-stop if needed.
local function shutdown_one(state, ctx, opts)
    opts = opts or {}

    if not (ctx and ctx.job_id and util.is_running(ctx.job_id)) then
        return
    end

    local timeout = shutdown_timeout(state, ctx, opts)
    local command = shutdown_command(state, ctx)

    ctx.shutdown_requested = true

    if command and command ~= "" then
        pcall(vim.fn.chansend, ctx.job_id, command)
        vim.wait(timeout, function()
            return not util.is_running(ctx.job_id)
        end, 20)
    end

    if util.is_running(ctx.job_id) then
        pcall(vim.fn.jobstop, ctx.job_id)
        vim.wait(timeout, function()
            return not util.is_running(ctx.job_id)
        end, 20)
    end
end

--- Shut down all pane-owned terminal sessions.
function M.shutdown_terminals(state, opts)
    opts = opts or {}

    for key, ctx in pairs(state.terminals or {}) do
        shutdown_one(state, ctx, opts)

        if not util.is_running(ctx.job_id) then
            agent_session.refresh_context(state, ctx)
            state.terminals[key] = nil
        end
    end
end

return M
