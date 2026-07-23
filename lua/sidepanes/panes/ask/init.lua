--[[
sidepanes.panes.ask
Purpose: Own the persistent ask-pane scratch buffer and pane-mode lifecycle.
Does: Creates/focuses the ask buffer, tracks previous pane state for cancellation, and updates pane chrome.
Architecture: Keeps ask-pane window state separate from the existing floating question editor while reusing Sidepanes' split/window helpers.
]]

local util = require("sidepanes.util")
local ask_prompt = require("sidepanes.ask_prompt")
local ask_policy = require("sidepanes.ask_policy")
local ask_cmdline = require("sidepanes.panes.ask.cmdline")
local ask_controller = require("sidepanes.panes.ask.controller")
local ask_executor = require("sidepanes.panes.ask.executor")
local ask_keymaps = require("sidepanes.panes.ask.keymaps")
local ask_navigation = require("sidepanes.panes.ask.navigation")
local ask_session = require("sidepanes.panes.ask.session")
local ask_target_resolver = require("sidepanes.panes.ask.target_resolver")

local M = {}
local CMDLINE_ENTER_DESC = "Sidepanes ask pane command-line enter"
local DRAFT_STATES = ask_session.STATES
local controller_for

M.DRAFT_STATES = DRAFT_STATES

local function set_draft_state(state, ask, draft_state)
    ask_session.record_state(state, ask, draft_state)
end

local session_adapter = {
    cmdline_enter_desc = CMDLINE_ENTER_DESC,
    cmd_map = function(lhs, mode)
        return vim.fn.maparg(lhs, mode, false, true)
    end,
    create_augroup = function(name, opts)
        return vim.api.nvim_create_augroup(name, opts)
    end,
    create_buf = function(listed, scratch)
        return vim.api.nvim_create_buf(listed, scratch)
    end,
    current_win = function()
        return vim.api.nvim_get_current_win()
    end,
    delete_buf = function(bufnr, opts)
        pcall(vim.api.nvim_buf_delete, bufnr, opts)
    end,
    del_keymap = function(mode, lhs)
        pcall(vim.keymap.del, mode, lhs)
    end,
    get_lines = function(bufnr, start, stop, strict)
        return vim.api.nvim_buf_get_lines(bufnr, start, stop, strict)
    end,
    get_option = function(name, opts)
        return vim.api.nvim_get_option_value(name, opts)
    end,
    mapset = function(mode, abbr, map)
        pcall(vim.fn.mapset, mode, abbr, map)
    end,
    replace_lines_undoable = function(bufnr, lines)
        if not util.valid_buf(bufnr) then
            return
        end

        vim.api.nvim_buf_call(bufnr, function()
            local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
            local reg = vim.fn.getreg("z")
            local regtype = vim.fn.getregtype("z")

            vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
            vim.fn.setreg("z", table.concat(lines, "\n"), "c")
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('ggVG"zp', true, false, true), "xt", false)
            vim.fn.setreg("z", reg, regtype)
            vim.api.nvim_set_option_value("modifiable", modifiable, { buf = bufnr })
        end)
    end,
    schedule = function(callback)
        vim.schedule(callback)
    end,
    set_buf_name = function(bufnr, name)
        pcall(vim.api.nvim_buf_set_name, bufnr, name)
    end,
    set_lines = function(bufnr, start, stop, strict, lines)
        vim.api.nvim_buf_set_lines(bufnr, start, stop, strict, lines)
    end,
    set_option = function(name, value, opts)
        vim.api.nvim_set_option_value(name, value, opts)
    end,
    trim = util.trim,
    valid_buf = util.valid_buf,
    valid_win = util.valid_win,
    win_buf = function(winid)
        return vim.api.nvim_win_get_buf(winid)
    end,
}

local function session(state)
    return ask_session.ensure(state)
end

local function ask_config(state)
    return ask_session.ask_config(state)
end

local function buffer_prompt(ask)
    return ask_session.buffer_prompt(ask, session_adapter)
end

local function snapshot(state, ask)
    return ask_session.runtime_snapshot(state, ask, session_adapter)
end

local function existing_question(lines)
    if not lines or lines[1] ~= "Question:" then
        return ""
    end

    local stop = #lines

    for index = 2, #lines do
        if lines[index] == "File:" then
            stop = index - 2
            break
        end
    end

    while stop >= 2 and lines[stop] == "" do
        stop = stop - 1
    end

    if stop < 2 then
        return ""
    end

    local result = {}

    for index = 2, stop do
        table.insert(result, lines[index])
    end

    return table.concat(result, "\n")
end

local function reset_session(state, opts)
    ask_session.reset(state, opts, session_adapter)
end

local function pick_target(state, deps, prompt, root, callback)
    local targets = ask_target_resolver.picker_entries({
        picker_entries = deps.terminal_entries(root, 1, { ask_only = true }),
        target_entries = deps.tool_shortcut_entries(root, { ask_only = true }),
    })

    deps.numbered_select(prompt, targets, function(choice)
        if choice then
            callback(choice, ask_target_resolver.REASONS.explicit_target_change)
        end
    end)
end

local function is_non_ask_sidepane_buffer(state, bufnr, ask)
    if ask and bufnr == ask.bufnr then
        return false
    end

    if bufnr == state.bufnr then
        return true
    end

    for _, ctx in pairs(state.terminals or {}) do
        if ctx.bufnr == bufnr then
            return true
        end
    end

    return false
end

local function commandline_enter(state, deps, bufnr)
    local ask = state.ask_pane or {}

    if vim.fn.getcmdtype() ~= ":" then
        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end

    local current_bufnr = vim.api.nvim_get_current_buf()
    local line = util.trim(vim.fn.getcmdline())

    if current_bufnr ~= bufnr then
        if is_non_ask_sidepane_buffer(state, current_bufnr, ask) and ask_policy.is_plain_quit_command(line) then
            return vim.api.nvim_replace_termcodes(ask_cmdline.markdown_return_command(), true, false, true)
        end

        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end

    if ask.bufnr ~= bufnr then
        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end

    local command = ask_cmdline.ask_pane_command_for_line(line, bufnr)

    if command then
        ask.cmdline_action_handled = true
        return vim.api.nvim_replace_termcodes(command, true, false, true)
    end

    return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
end

local function install_commandline_enter(state, deps, bufnr)
    local ask = session(state)

    if ask.cmdline_enter_setup then
        return
    end

    ask.previous_cmdline_enter = vim.fn.maparg("<CR>", "c", false, true)
    ask.cmdline_enter_setup = true

    vim.keymap.set("c", "<CR>", function()
        return commandline_enter(state, deps, bufnr)
    end, {
        expr = true,
        silent = true,
        desc = CMDLINE_ENTER_DESC,
    })
end

local function pane_mappings(deps)
    if deps.pane_mappings then
        return deps.pane_mappings() or {}
    end

    return {}
end

--- Return the current ask-pane session table.
function M.session(state)
    return session(state)
end

--- Create or return the ask-pane scratch buffer.
function M.ensure_buf(state)
    return ask_session.ensure_buffer(state, session_adapter)
end

--- Show or focus the persistent ask pane.
function M.show(state, deps, opts)
    opts = opts or {}

    ask_session.capture_previous(state)

    if state.active_mode == "markdown" then
        deps.save_markdown_view()
    elseif state.active_terminal_key then
        deps.remember_terminal_context(state.terminals[state.active_terminal_key])
    end

    local bufnr = M.ensure_buf(state)
    local ask = session(state)

    if not ask.lifecycle_setup then
        ask.lifecycle_setup = true

        local mappings = pane_mappings(deps)

        ask_keymaps.setup(bufnr, mappings, {
            change_target = function()
                M.change_target(state, deps, bufnr)
            end,
            submit_now = function()
                M.submit_now(state, deps, bufnr)
            end,
            finish_quit = function()
                M.finish_quit(state, deps, bufnr)
            end,
            undo_edit = function()
                M.undo_edit(state, deps, bufnr)
            end,
        })

        vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            group = ask.augroup,
            buffer = bufnr,
            callback = function()
                local live = state.ask_pane or {}

                if live.bufnr == bufnr and not live.resetting then
                    if ask_session.restore_undo_if_matching(state, live, session_adapter) then
                        deps.update_sticky_heading()
                        return
                    end

                    ask_session.clear_stale_undo_restore(state, live, session_adapter)
                    set_draft_state(state, live, DRAFT_STATES.draft_modified)
                    deps.update_sticky_heading()
                end
            end,
        })

        vim.api.nvim_create_autocmd("BufWriteCmd", {
            group = ask.augroup,
            buffer = bufnr,
            callback = function()
                M.write_draft(state, deps, bufnr)
                vim.notify("Ask prompt written. Quit to send.", vim.log.levels.INFO)
            end,
        })

        vim.api.nvim_create_autocmd("CmdlineChanged", {
            group = ask.augroup,
            callback = function()
                if vim.fn.getcmdtype() == ":" and vim.api.nvim_get_current_buf() == bufnr then
                    session(state).last_cmdline = util.trim(vim.fn.getcmdline())
                end
            end,
        })

        vim.api.nvim_create_autocmd("CmdlineLeave", {
            group = ask.augroup,
            callback = function()
                local live = state.ask_pane or {}

                if live.bufnr ~= bufnr then
                    return
                end

                if live.cmdline_action_handled then
                    live.cmdline_action_handled = nil
                    live.last_cmdline = nil
                    return
                end

                local intent = ask_policy.commandline_intent(live.last_cmdline)

                live.last_cmdline = nil

                if intent then
                    vim.schedule(function()
                        local controller = controller_for(state, deps, bufnr)

                        controller.run_intent(intent)
                    end)
                end
            end,
        })

        vim.api.nvim_create_autocmd("BufWipeout", {
            group = ask.augroup,
            buffer = bufnr,
            callback = function()
                local live = state.ask_pane or {}

                if live.resetting or live.bufnr ~= bufnr then
                    pcall(vim.api.nvim_del_augroup_by_id, ask.augroup)
                    return
                end

                M.cancel_draft(state, deps, bufnr)
                pcall(vim.api.nvim_del_augroup_by_id, ask.augroup)
            end,
        })
    end

    install_commandline_enter(state, deps, bufnr)

    if opts.reset_unmodified then
        ask_session.clear_unmodified_buffer(state, ask, session_adapter)
    end

    state.active_mode = "ask"
    state.active_terminal_key = nil

    local focus = opts.focus

    if focus == nil then
        focus = true
    end

    local winid = deps.ensure_win(bufnr, "ask", { focus = focus })

    deps.set_window_options(winid, "ask")
    deps.setup_pane_maps(bufnr)
    deps.update_sticky_heading()

    return bufnr, winid
end

--- Undo an ask-pane edit and repair session metadata when a fresh reset is undone.
function M.undo_edit(state, deps, bufnr)
    bufnr = bufnr or session(state).bufnr

    if not util.valid_buf(bufnr) then
        return
    end

    vim.api.nvim_buf_call(bufnr, function()
        local count = vim.v.count or 0
        local prefix = count > 0 and tostring(count) or ""

        vim.cmd("silent keepjumps normal! " .. prefix .. "u")
    end)

    local live = state.ask_pane or {}

    if live.bufnr == bufnr and ask_session.restore_undo_if_matching(state, live, session_adapter) then
        deps.update_sticky_heading()
    elseif live.bufnr == bufnr then
        ask_session.clear_stale_undo_restore(state, live, session_adapter)

        if ask_session.refresh_after_undo(state, live, session_adapter) then
            deps.update_sticky_heading()
        end
    end
end

--- Change the target entry for the active ask pane.
function M.change_target(state, deps, bufnr)
    local ask = session(state)

    if bufnr and ask.bufnr ~= bufnr then
        return
    end

    local root = ask.root or vim.fn.getcwd()

    pick_target(state, deps, "Question target", root, function(choice, reason)
        ask.entry = choice
        ask.root = choice.root or ask.root or root
        ask.target_reason = reason
        deps.update_sticky_heading()

        if util.valid_win(state.winid) and util.valid_buf(ask.bufnr) and vim.api.nvim_win_get_buf(state.winid) == ask.bufnr then
            vim.api.nvim_set_current_win(state.winid)
        end
    end)
end

--- Write the current ask-pane prompt draft.
function M.write_draft(state, deps, bufnr)
    local ask = state.ask_pane or {}

    if bufnr and ask.bufnr ~= bufnr then
        return
    end

    ask.written_prompt = buffer_prompt(ask)
    ask.ready = false
    set_draft_state(state, ask, DRAFT_STATES.draft_written)
    vim.api.nvim_set_option_value("modified", false, { buf = ask.bufnr })
    deps.update_sticky_heading()
end

local function send_prompt(state, deps, prompt)
    local ask = session(state)
    local entry = ask.entry

    if not entry then
        vim.notify("No ask target selected", vim.log.levels.WARN)
        set_draft_state(state, ask, DRAFT_STATES.send_failed)
        return false
    end

    set_draft_state(state, ask, DRAFT_STATES.sending_terminal)

    local ctx, started = deps.open_terminal(entry.tool_name, entry.preset_name, {
        bufnr = ask.origin and ask.origin.bufnr or nil,
        root = entry.root or ask.root,
        focus = true,
    })

    if ctx then
        deps.send_prompt_to_terminal(ctx, entry, prompt, started)
        set_draft_state(state, ask, DRAFT_STATES.sent)
        reset_session(state)
        return true
    end

    vim.notify("Ask prompt was not sent; target terminal did not open", vim.log.levels.WARN)
    set_draft_state(state, ask, DRAFT_STATES.send_failed)
    deps.update_sticky_heading()
    return false
end

local function lifecycle_facts(state, ask)
    return ask_session.lifecycle_facts(snapshot(state, ask))
end

--- Return the current serializable ask session snapshot.
function M.snapshot(state)
    return snapshot(state, state.ask_pane or {})
end

--- Return policy-facing lifecycle facts from the current ask session snapshot.
function M.lifecycle_facts(state)
    return lifecycle_facts(state, state.ask_pane or {})
end

local function open_before_send_picker(state, deps, ask, prompt)
    set_draft_state(state, ask, DRAFT_STATES.sending_picker)
    deps.update_sticky_heading()
    local root = ask.root or vim.fn.getcwd()
    local decision = ask_target_resolver.before_send({
        picker_entries = deps.terminal_entries(root, 1, { ask_only = true }),
        picker_mode = ask_config(state).model_picker,
        root = root,
        target_entries = deps.tool_shortcut_entries(root, { ask_only = true }),
    })

    deps.numbered_select("Question target", decision.entries or {}, function(choice)
        if not choice then
            return
        end

        ask.entry = choice
        ask.root = choice.root or ask.root
        ask.target_reason = decision.reason
        send_prompt(state, deps, prompt)
    end)
end

controller_for = function(state, deps, bufnr)
    local ask = state.ask_pane or {}

    return ask_controller.create({
        executor = ask_executor,
        facts = function()
            return lifecycle_facts(state, ask)
        end,
        handlers = {
            notify_no_prompt = function()
                vim.notify("No ask pane prompt to submit", vim.log.levels.WARN)
            end,
            mark_draft_modified = function()
                set_draft_state(state, ask, DRAFT_STATES.draft_modified)
            end,
            write_draft = function()
                M.write_draft(state, deps, ask.bufnr)
            end,
            cancel_draft = function()
                M.cancel_draft(state, deps, ask.bufnr)
            end,
            open_before_send_picker = function(prompt)
                open_before_send_picker(state, deps, ask, prompt)
            end,
            send_prompt = function(prompt)
                return send_prompt(state, deps, prompt)
            end,
            change_target = function()
                return M.change_target(state, deps, bufnr or ask.bufnr)
            end,
        },
    })
end

--- Run the ask-pane quit lifecycle: cancel unwritten drafts and send written drafts.
function M.finish_quit(state, deps, bufnr)
    local ask = state.ask_pane or {}

    if bufnr and ask.bufnr ~= bufnr then
        return false
    end

    return controller_for(state, deps, bufnr or ask.bufnr).finish_quit()
end

--- Write and send the active ask-pane prompt.
function M.submit_now(state, deps, bufnr)
    local ask = state.ask_pane or {}

    if bufnr and ask.bufnr ~= bufnr then
        return false
    end

    return controller_for(state, deps, bufnr or ask.bufnr).submit_now()
end

local function restore_previous(state, deps, previous)
    if previous and previous.active_mode == "markdown" then
        deps.show_markdown()
        return
    end

    if previous and previous.active_terminal_key then
        local ctx = state.terminals[previous.active_terminal_key]

        if ctx then
            deps.open_terminal(ctx.tool_name, ctx.preset_name, {
                root = ctx.root,
                focus = true,
            })
            return
        end
    end

    deps.show_markdown()
end

--- Cancel the current ask-pane prompt and restore the previous pane mode.
function M.cancel_draft(state, deps, bufnr)
    local ask = state.ask_pane or {}

    if bufnr and ask.bufnr ~= bufnr then
        return
    end

    local previous = ask.previous
    local ask_bufnr = ask.bufnr

    if util.valid_buf(ask_bufnr) then
        vim.api.nvim_set_option_value("modified", false, { buf = ask_bufnr })
    end

    set_draft_state(state, ask, DRAFT_STATES.cancelled)
    restore_previous(state, deps, previous)
    reset_session(state, { defer_delete = true })
end

--- Add a captured context to the ask pane, creating the prompt if needed.
function M.add_context(state, deps, entry, context, opts)
    opts = opts or {}

    if not entry or entry.kind ~= "terminal" or not context then
        return
    end

    local origin = opts.origin
    local ask = session(state)
    local bufnr = M.ensure_buf(state)
    local target_root = ask.root or entry.root or context.root
    local citation = ask_prompt.citation_from_context(context, { target_root = target_root })
    local config = ask_config(state)
    local duplicate_policy = opts.duplicate_policy or config.duplicate_policy or "skip"

    ask.entry = entry
    ask.root = target_root
    ask.target_reason = opts.target_reason or ask.target_reason
    ask.origin = origin or ask.origin
    ask.ready = false
    set_draft_state(state, ask, DRAFT_STATES.draft_modified)

    if #(ask.citations or {}) == 0 then
        local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local prompt = ask_prompt.format_prompt(context, existing_question(current), { target_root = target_root })

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(prompt, "\n", { plain = true }))
    else
        local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local updated, meta = ask_prompt.add_citation(current, context, {
            duplicate_policy = duplicate_policy,
            target_root = target_root,
        })

        if meta.added == false then
            vim.notify("Duplicate ask citation skipped: " .. citation.file .. " lines " .. citation.start_lnum .. "-" .. citation.end_lnum, vim.log.levels.INFO)
            M.show(state, deps, { focus = state.config.focus_on_ask })
            return false
        end

        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, updated)
    end

    table.insert(ask.citations, citation)
    ask.written_prompt = nil
    vim.api.nvim_set_option_value("modified", true, { buf = bufnr })
    M.show(state, deps, { focus = state.config.focus_on_ask })

    if config.model_picker == "after_open" and not ask.model_picker_shown then
        ask.model_picker_shown = true
        M.change_target(state, deps, bufnr)
    end

    return true
end

--- Jump between File or Selection headers inside the ask pane.
function M.jump_header(state, kind, direction)
    return ask_navigation.jump_header(state, kind, direction)
end

--- Open the cited source file and jump to the cited start line.
function M.source_jump(state)
    return ask_navigation.source_jump(state)
end

return M
