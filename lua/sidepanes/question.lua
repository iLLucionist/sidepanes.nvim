--[[
sidepanes.question
Purpose: Manage the editable ask prompt workflow for coding-agent terminals.
Does: Captures selection context, opens the scratch prompt editor, tracks write-then-quit semantics, switches targets, and sends prompts.
Architecture: Orchestrates selection, picker, and terminal callbacks while keeping prompt-buffer state in the shared plugin state table.
]]

local util = require("sidepanes.util")
local selection = require("sidepanes.selection")
local ask_pane = require("sidepanes.panes.ask")
local ask_cmdline = require("sidepanes.panes.ask.cmdline")
local ask_route = require("sidepanes.ask_route")
local ask_target_resolver = require("sidepanes.panes.ask.target_resolver")

local M = {}

--- Capture enough pane/window state to restore after question editing.
local function capture_origin(state)
    local winid = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = { 1, 0 }
    local view = nil

    pcall(function()
        cursor = vim.api.nvim_win_get_cursor(winid)
    end)

    pcall(function()
        view = vim.fn.winsaveview()
    end)

    return {
        winid = winid,
        bufnr = bufnr,
        cursor = cursor,
        view = view,
        pane_active_mode = state.active_mode,
        pane_active_terminal_key = state.active_terminal_key,
    }
end

--- Restore focus and pane state after closing a question editor.
local function restore_origin(state, deps, origin)
    if not origin or not util.valid_win(origin.winid) then
        return
    end

    if origin.winid == state.winid then
        state.active_mode = origin.pane_active_mode
        state.active_terminal_key = origin.pane_active_terminal_key

        if util.valid_buf(origin.bufnr) then
            if not pcall(vim.api.nvim_win_set_buf, origin.winid, origin.bufnr) then
                pcall(vim.cmd, "hide")
                pcall(vim.api.nvim_win_set_buf, origin.winid, origin.bufnr)
            end
        end

        deps.set_window_options(origin.winid, state.active_mode == "markdown" and "markdown" or "terminal")
        deps.update_sticky_heading()
    elseif util.valid_buf(origin.bufnr) then
        if not pcall(vim.api.nvim_win_set_buf, origin.winid, origin.bufnr) then
            pcall(vim.cmd, "hide")
            pcall(vim.api.nvim_win_set_buf, origin.winid, origin.bufnr)
        end
    end

    pcall(vim.api.nvim_set_current_win, origin.winid)

    if origin.view then
        pcall(vim.fn.winrestview, origin.view)
    else
        pcall(vim.api.nvim_win_set_cursor, origin.winid, origin.cursor)
    end
end

local function ask_target_entries(deps, root)
    return deps.tool_shortcut_entries(root, { ask_only = true })
end

local function ask_picker_entries(deps, root)
    return ask_target_resolver.picker_entries({
        picker_entries = deps.terminal_entries(root, 1, { ask_only = true }),
        target_entries = ask_target_entries(deps, root),
    })
end

--- Build ask target entries and invoke a callback for the selected entry.
local function pick_target(state, deps, prompt, context, callback)
    local targets = ask_picker_entries(deps, context.root)

    deps.numbered_select(prompt, targets, function(choice)
        if choice then
            callback(choice, ask_target_resolver.REASONS.explicit_target_change)
        end
    end)
end

local function ask_uses_pane(state)
    return type(state.config.ask) == "table" and state.config.ask.ui == "pane"
end

local function ask_pane_deps(deps)
    if deps.ask_pane_deps then
        return deps.ask_pane_deps()
    end

    return deps
end

local function ask_pane_default_entry(state, deps, context)
    local ask = ask_pane.session(state)

    local ctx = deps.last_coding_agent_context(context.root)
    local last_entry = ctx and deps.entry_for_terminal_context(ctx) or nil
    local decision = ask_target_resolver.resolve({
        active_entry = ask.entry,
        last_entry = last_entry,
        root = context.root,
        target_entries = ask_target_entries(deps, context.root),
    })

    return decision.entry, decision.reason
end

local function ask_pane_existing_or_default(state, deps, context, origin)
    local entry, reason = ask_pane_default_entry(state, deps, context)

    if entry then
        M.ask_with_entry(state, deps, entry, { context = context, origin = origin, target_reason = reason })
        return true
    end

    return false
end

--- Open the editable ask prompt scratch buffer.
local function open_buffer(state, deps, entry, context, origin)
    origin = origin or capture_origin(state)

    local scratch = vim.api.nvim_create_buf(false, true)
    local augroup = vim.api.nvim_create_augroup("SidepanesQuestion" .. scratch, { clear = true })
    local scratch_win = nil
    local sent = false
    local buffer_state = {
        entry = entry,
        written_prompt = nil,
    }
    local initial_prompt = selection.prompt_template(context)

    pcall(vim.api.nvim_buf_set_name, scratch, "Pane Question://" .. util.sanitize_name(entry.label))
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = scratch })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = scratch })
    vim.api.nvim_set_option_value("swapfile", false, { buf = scratch })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = scratch })
    vim.api.nvim_buf_set_lines(scratch, 0, -1, false, vim.split(initial_prompt, "\n", { plain = true }))
    vim.api.nvim_set_option_value("modified", false, { buf = scratch })

    local width = math.max(50, math.floor(vim.o.columns * 0.78))
    local height = math.max(12, math.floor(vim.o.lines * 0.72))

    local function target_label()
        return buffer_state.entry and buffer_state.entry.label or entry.label
    end

    local function update_prompt_chrome()
        if not util.valid_win(scratch_win) then
            return
        end

        local title = " Question for " .. target_label() .. " "
        local footer = " M/<Tab>: model  :wq send  :w draft  :q cancel  target: " .. target_label() .. " "

        pcall(vim.api.nvim_win_set_config, scratch_win, {
            title = title,
            title_pos = "center",
            footer = footer,
            footer_pos = "center",
        })
        vim.api.nvim_set_option_value("winbar", "%#WinBar# " .. deps.statusline_escape("Question target: " .. target_label()) .. " %*", { win = scratch_win })
    end

    scratch_win = vim.api.nvim_open_win(scratch, true, {
        relative = "editor",
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        width = width,
        height = height,
        style = "minimal",
        border = "single",
        title = " Question for " .. target_label() .. " ",
        title_pos = "center",
        footer = " M/<Tab>: model  :wq send  :w draft  :q cancel  target: " .. target_label() .. " ",
        footer_pos = "center",
    })

    pcall(vim.api.nvim_win_set_cursor, scratch_win, { 2, 0 })
    update_prompt_chrome()

    local function buffer_prompt()
        return util.trim(table.concat(vim.api.nvim_buf_get_lines(scratch, 0, -1, false), "\n"))
    end

    local function close_scratch()
        if util.valid_win(scratch_win) then
            pcall(vim.api.nvim_win_close, scratch_win, true)
        end

        if util.valid_buf(scratch) then
            pcall(vim.api.nvim_buf_delete, scratch, { force = true })
        end
    end

    local function cancel(opts)
        opts = opts or {}

        if sent then
            return
        end

        sent = true
        vim.api.nvim_set_option_value("modified", false, { buf = scratch })
        restore_origin(state, deps, origin)

        if not opts.from_wipeout then
            close_scratch()
        end
    end

    local function finish(opts)
        opts = opts or {}

        if sent then
            return
        end

        local has_unwritten_changes = util.valid_buf(scratch) and vim.api.nvim_get_option_value("modified", { buf = scratch })

        if has_unwritten_changes then
            cancel(opts)
            return
        end

        local prompt = buffer_state.written_prompt

        if not prompt or prompt == util.trim(initial_prompt) then
            cancel(opts)
            return
        end

        if prompt == "" then
            vim.notify("Empty prompt; ask cancelled", vim.log.levels.INFO)
            cancel(opts)
            return
        end

        sent = true
        vim.api.nvim_set_option_value("modified", false, { buf = scratch })
        restore_origin(state, deps, origin)

        local current_entry = buffer_state.entry or entry
        local ctx, started = deps.open_terminal(current_entry.tool_name, current_entry.preset_name, {
            bufnr = context.bufnr,
            root = current_entry.root or context.root,
            focus = true,
        })

        if ctx then
            deps.send_prompt_to_terminal(ctx, current_entry, prompt, started)
        end

        if not opts.from_wipeout then
            close_scratch()
        end
    end

    local function write_prompt()
        if sent then
            return
        end

        buffer_state.written_prompt = buffer_prompt()
        vim.api.nvim_set_option_value("modified", false, { buf = scratch })
    end

    buffer_state.cancel = cancel
    buffer_state.finish = finish
    buffer_state.write_prompt = write_prompt
    state.question_buffers[scratch] = buffer_state

    local function change_target()
        pick_target(state, deps, "Question target", context, function(choice)
            buffer_state.entry = choice
            update_prompt_chrome()

            if util.valid_win(scratch_win) then
                vim.api.nvim_set_current_win(scratch_win)
            end
        end)
    end

    buffer_state.change_target = change_target

    local function commandline_enter()
        local line = util.trim(vim.fn.getcmdline())
        local command = ask_cmdline.floating_question_command_for_line(line, scratch)

        if command then
            return vim.api.nvim_replace_termcodes(command, true, false, true)
        end

        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end

    vim.keymap.set("c", "<CR>", commandline_enter, { buffer = scratch, expr = true, silent = true })
    vim.keymap.set("n", "q", finish, { buffer = scratch, silent = true, desc = "Finish pane question" })
    vim.keymap.set("n", "M", function()
        M.change_target(state, scratch)
    end, { buffer = scratch, silent = true, desc = "Change pane question target" })
    vim.keymap.set("n", "<Tab>", function()
        M.change_target(state, scratch)
    end, { buffer = scratch, silent = true, desc = "Change pane question target" })

    vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = augroup,
        buffer = scratch,
        callback = function()
            if sent then
                return
            end

            write_prompt()
            vim.notify("Question written. Quit to send.", vim.log.levels.INFO)
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = augroup,
        buffer = scratch,
        callback = function()
            if not sent then
                finish({ from_wipeout = true })
            end

            state.question_buffers[scratch] = nil
            pcall(vim.api.nvim_del_augroup_by_id, augroup)
        end,
    })

    vim.cmd("startinsert")
end

--- Cancel and close a question editor buffer.
function M.cancel(state, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffer_state = state.question_buffers[bufnr]

    if buffer_state and buffer_state.cancel then
        buffer_state.cancel()
    end
end

--- Finish a question editor, sending only after a write.
function M.finish(state, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffer_state = state.question_buffers[bufnr]

    if buffer_state and buffer_state.finish then
        buffer_state.finish()
    end
end

--- Mark a question editor as written and update its cached prompt.
function M.write(state, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffer_state = state.question_buffers[bufnr]

    if buffer_state and buffer_state.write_prompt then
        buffer_state.write_prompt()
    end
end

--- Open the target picker from inside a question editor.
function M.change_target(state, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local buffer_state = state.question_buffers[bufnr]

    if buffer_state and buffer_state.change_target then
        buffer_state.change_target()
    end
end

--- Ask a specific picker entry using a captured or fresh context.
function M.ask_with_entry(state, deps, entry, opts)
    opts = opts or {}

    if not entry or entry.kind ~= "terminal" then
        return
    end

    local context = opts.context or deps.selection_context(opts)

    if not context then
        return
    end

    if ask_uses_pane(state) then
        local ask = ask_pane.session(state)
        local pane_deps = ask_pane_deps(deps)

        if
            ask_route.auto_append_blocked({
                auto_append = state.config.ask.auto_append,
                active_buf = ask.bufnr,
                citation_count = #(ask.citations or {}),
            })
        then
            ask_pane.show(state, pane_deps, { focus = state.config.focus_on_ask })
            return
        end

        ask_pane.add_context(state, pane_deps, entry, context, { origin = opts.origin, target_reason = opts.target_reason })
        return
    end

    open_buffer(state, deps, entry, context, opts.origin)
end

--- Append the current selection to the ask pane, creating one if needed.
function M.append_to_ask(state, deps, opts)
    opts = opts or {}

    local origin = capture_origin(state)
    local context = deps.selection_context(opts)

    if not context then
        return
    end

    if ask_uses_pane(state) then
        local entry, reason = ask_pane_default_entry(state, deps, context)

        if entry then
            ask_pane.add_context(state, ask_pane_deps(deps), entry, context, { origin = origin, target_reason = reason })
            return
        end
    end

    pick_target(state, deps, "Ask", context, function(choice)
        ask_pane.add_context(state, ask_pane_deps(deps), choice, context, {
            origin = origin,
            target_reason = ask_target_resolver.REASONS.explicit_target_change,
        })
    end)
end

--- Capture selection and ask via the target picker.
function M.ask_picker(state, deps, opts)
    opts = opts or {}

    local origin = capture_origin(state)
    local context = deps.selection_context(opts)

    if not context then
        return
    end

    if ask_uses_pane(state) and ask_pane_existing_or_default(state, deps, context, origin) then
        return
    end

    pick_target(state, deps, "Ask", context, function(choice, reason)
        M.ask_with_entry(state, deps, choice, { context = context, origin = origin, target_reason = reason })
    end)
end

--- Ask the most recently used Codex or Claude terminal.
function M.ask_last_coding_agent(state, deps, opts)
    opts = opts or {}

    local origin = capture_origin(state)
    local context = deps.selection_context(opts)

    if not context then
        return
    end

    if ask_uses_pane(state) and ask_pane_existing_or_default(state, deps, context, origin) then
        return
    end

    local ctx = deps.last_coding_agent_context(context.root)

    if not ctx then
        pick_target(state, deps, "Ask", context, function(choice, reason)
            M.ask_with_entry(state, deps, choice, { context = context, origin = origin, target_reason = reason })
        end)
        return
    end

    M.ask_with_entry(state, deps, deps.entry_for_terminal_context(ctx), {
        context = context,
        origin = origin,
        target_reason = ask_target_resolver.REASONS.last_coding_agent,
    })
end

--- Ask the current/default terminal for a specific coding agent.
function M.ask_current_coding_agent(state, deps, tool_name, opts)
    opts = opts or {}

    if not deps.is_coding_agent_tool(tool_name) then
        vim.notify("Unknown coding agent pane: " .. tostring(tool_name), vim.log.levels.ERROR)
        return
    end

    local origin = capture_origin(state)
    local context = deps.selection_context(opts)

    if not context then
        return
    end

    local ctx = deps.terminal_context_for_tool(tool_name, context.root)

    if not ctx then
        pick_target(state, deps, "Ask", context, function(choice, reason)
            M.ask_with_entry(state, deps, choice, { context = context, origin = origin, target_reason = reason })
        end)
        return
    end

    M.ask_with_entry(state, deps, deps.entry_for_terminal_context(ctx), {
        context = context,
        origin = origin,
        target_reason = ask_target_resolver.REASONS.last_coding_agent,
    })
end

--- Ask a specific tool and optional preset.
function M.ask(state, deps, tool_name, preset_name, opts)
    opts = opts or {}

    local tool = (state.config.tools or {})[tool_name]

    if not tool then
        vim.notify("Unknown pane tool: " .. tostring(tool_name), vim.log.levels.ERROR)
        return
    end

    local preset = deps.preset_by_name(tool, preset_name)
    local ask_opts = vim.tbl_extend("force", {}, opts, {
        target_reason = opts.target_reason or ask_target_resolver.REASONS.explicit_target,
    })

    M.ask_with_entry(state, deps, {
        kind = "terminal",
        tool_name = tool_name,
        preset_name = preset.name,
        label = (tool.label or tool_name) .. ": " .. (preset.label or preset.name or "Default"),
    }, ask_opts)
end

return M
