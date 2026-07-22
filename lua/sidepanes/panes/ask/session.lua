--[[
sidepanes.panes.ask.session
Purpose: Build a coherent ask session snapshot from raw ask-pane state.
Does: Keeps raw mutable pane state separate from serializable facts, labels, and lifecycle history helpers.
Architecture: Pure snapshot/selectors plus small state-history mutation helpers; no Neovim API calls.
]]

local ask_policy = require("sidepanes.ask_policy")

local M = {}

local STATES = ask_policy.STATES

M.STATES = STATES

local function ask_config(opts)
    opts = opts or {}

    if type(opts.ask_config) == "table" then
        return opts.ask_config
    end

    if type(opts.config) == "table" and type(opts.config.ask) == "table" then
        return opts.config.ask
    end

    return {}
end

local function buffer_facts(opts)
    opts = opts or {}

    if type(opts.buffer) == "table" then
        return opts.buffer
    end

    return {
        live_prompt = opts.live_prompt,
        modified = opts.dirty_buffer or opts.modified,
        valid = opts.valid_buffer or opts.valid_buf,
    }
end

local function window_facts(opts)
    opts = opts or {}

    if type(opts.window) == "table" then
        return opts.window
    end

    return {
        active = opts.active_window,
        valid = opts.valid_window or opts.valid_win,
    }
end

local function previous_mode(previous)
    if type(previous) ~= "table" then
        return nil
    end

    return previous.active_mode or previous.active_terminal_key
end

local function target_label(entry)
    if type(entry) ~= "table" then
        return "No target"
    end

    return entry.label or entry.preset_label or entry.tool_label or "No target"
end

local function target_root(raw)
    raw = raw or {}

    if raw.root then
        return raw.root
    end

    if type(raw.entry) == "table" then
        return raw.entry.root
    end

    return nil
end

local function counts(citations)
    local citation_count = 0
    local files = {}
    local file_count = 0

    for _, citation in ipairs(type(citations) == "table" and citations or {}) do
        citation_count = citation_count + 1

        local key = citation.path or citation.file

        if key and not files[key] then
            files[key] = true
            file_count = file_count + 1
        end
    end

    return citation_count, file_count
end

local function active_session(raw, buffer)
    return type(raw) == "table" and raw.bufnr ~= nil and buffer.valid == true
end

function M.record_state(state, raw, draft_state)
    if type(raw) ~= "table" then
        return
    end

    raw.draft_state = draft_state

    if type(state) == "table" then
        state.ask_pane_last_state = draft_state
        state.ask_pane_state_history = state.ask_pane_state_history or {}
        table.insert(state.ask_pane_state_history, draft_state)
    end
end

function M.snapshot(raw, opts)
    opts = opts or {}
    raw = type(raw) == "table" and raw or {}

    local config = ask_config(opts)
    local buffer = buffer_facts(opts)
    local window = window_facts(opts)
    local citation_count, file_count = counts(raw.citations)
    local active = active_session(raw, buffer)
    local draft_state = active and (raw.draft_state or STATES.ready_empty) or nil

    return {
        active = active,
        active_window = window.active == true,
        citation_count = citation_count,
        dirty_buffer = buffer.modified == true,
        draft_state = draft_state,
        file_count = file_count,
        live_prompt = buffer.live_prompt or "",
        picker_mode = config.model_picker or opts.picker_mode,
        picker_shown = raw.model_picker_shown == true,
        previous_pane_mode = previous_mode(raw.previous),
        target_reason = raw.target_reason,
        target_label = target_label(raw.entry),
        target_root = target_root(raw),
        valid_buffer = buffer.valid == true,
        valid_window = window.valid == true,
        written_prompt = raw.written_prompt,
    }
end

function M.lifecycle_facts(snapshot)
    snapshot = snapshot or {}

    return {
        active_target = snapshot.target_label,
        dirty_buffer = snapshot.dirty_buffer == true,
        live_prompt = snapshot.live_prompt or "",
        picker_mode = snapshot.picker_mode,
        previous_pane = snapshot.previous_pane_mode,
        target_reason = snapshot.target_reason,
        valid_buffer = snapshot.valid_buffer == true,
        written_prompt = snapshot.written_prompt,
    }
end

function M.status_data(snapshot)
    snapshot = snapshot or {}

    return {
        active = snapshot.active == true,
        citation_count = snapshot.citation_count or 0,
        dirty_buffer = snapshot.dirty_buffer == true,
        draft_state = snapshot.draft_state,
        file_count = snapshot.file_count or 0,
        modified = snapshot.dirty_buffer == true,
        picker_mode = snapshot.picker_mode,
        picker_shown = snapshot.picker_shown == true,
        previous_pane_mode = snapshot.previous_pane_mode,
        target_reason = snapshot.target_reason,
        target_label = snapshot.target_label or "No target",
        target_root = snapshot.target_root,
        written = snapshot.written_prompt ~= nil,
    }
end

function M.format_title(snapshot)
    local status = M.status_data(snapshot)
    local draft = status.draft_state or "inactive"

    return "Ask: " .. status.target_label .. " - " .. draft
end

function M.ensure(state)
    state.ask_pane = state.ask_pane or {}
    state.ask_pane.citations = state.ask_pane.citations or {}

    return state.ask_pane
end

function M.ask_config(state)
    return type(state.config) == "table" and type(state.config.ask) == "table" and state.config.ask or {}
end

function M.buffer_prompt(raw, adapter)
    if not adapter.valid_buf(raw.bufnr) then
        return ""
    end

    return adapter.trim(table.concat(adapter.get_lines(raw.bufnr, 0, -1, false), "\n"))
end

function M.runtime_snapshot(state, raw, adapter)
    raw = raw or state.ask_pane or {}

    local valid_buf = adapter.valid_buf(raw.bufnr)
    local valid_win = adapter.valid_win(state.winid)
    local active_window = false

    if valid_buf and valid_win then
        active_window = adapter.current_win() == state.winid and adapter.win_buf(state.winid) == raw.bufnr
    end

    return M.snapshot(raw, {
        config = state.config,
        buffer = {
            live_prompt = valid_buf and M.buffer_prompt(raw, adapter) or "",
            modified = valid_buf and adapter.get_option("modified", { buf = raw.bufnr }) or false,
            valid = valid_buf,
        },
        window = {
            active = active_window,
            valid = valid_win,
        },
    })
end

function M.restore_commandline_enter(raw, adapter)
    if not raw or not raw.cmdline_enter_setup then
        return
    end

    local current = adapter.cmd_map("<CR>", "c")

    if type(current) == "table" and current.desc == adapter.cmdline_enter_desc then
        if raw.previous_cmdline_enter and next(raw.previous_cmdline_enter) ~= nil then
            adapter.mapset("c", false, raw.previous_cmdline_enter)
        else
            adapter.del_keymap("c", "<CR>")
        end
    end

    raw.cmdline_enter_setup = nil
    raw.previous_cmdline_enter = nil
end

function M.reset(state, opts, adapter)
    opts = opts or {}
    local raw = state.ask_pane or {}
    local bufnr = raw.bufnr

    raw.resetting = true
    M.restore_commandline_enter(raw, adapter)
    state.ask_pane = {}

    local function delete_buffer()
        if adapter.valid_buf(bufnr) then
            adapter.delete_buf(bufnr, { force = true })
        end
    end

    if opts.defer_delete then
        adapter.schedule(delete_buffer)
    else
        delete_buffer()
    end
end

function M.capture_previous(state)
    if state.active_mode == "ask" then
        return
    end

    local raw = M.ensure(state)

    raw.previous = {
        active_mode = state.active_mode,
        active_terminal_key = state.active_terminal_key,
        bufnr = state.active_mode == "markdown" and state.bufnr or nil,
    }
end

function M.ensure_buffer(state, adapter)
    local raw = M.ensure(state)

    if adapter.valid_buf(raw.bufnr) then
        return raw.bufnr
    end

    local bufnr = adapter.create_buf(false, true)
    local augroup = adapter.create_augroup("SidepanesAskPane" .. bufnr, { clear = true })

    raw.bufnr = bufnr
    raw.augroup = augroup
    raw.citations = {}
    raw.written_prompt = nil
    raw.ready = true
    state.ask_pane_state_history = {}
    M.record_state(state, raw, STATES.ready_empty)

    adapter.set_buf_name(bufnr, "Pane Question")
    adapter.set_option("buftype", "acwrite", { buf = bufnr })
    adapter.set_option("bufhidden", "hide", { buf = bufnr })
    adapter.set_option("swapfile", false, { buf = bufnr })
    adapter.set_option("filetype", "markdown", { buf = bufnr })
    adapter.set_lines(bufnr, 0, -1, false, { "Question:", "" })
    adapter.set_option("modified", false, { buf = bufnr })

    return bufnr
end

return M
