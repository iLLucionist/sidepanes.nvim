--[[
sidepanes.question
Purpose: Manage the editable ask prompt workflow for coding-agent terminals.
Does: Captures selection context, opens the scratch prompt editor, tracks write-then-quit semantics, switches targets, and sends prompts.
Architecture: Orchestrates selection, picker, and terminal callbacks while keeping prompt-buffer state in the shared plugin state table.
]]

local util = require("sidepanes.util")
local selection = require("sidepanes.selection")

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

--- Build ask target entries and invoke a callback for the selected entry.
local function pick_target(state, deps, prompt, context, callback)
    local targets = deps.tool_shortcut_entries(context.root, { ask_only = true })

    vim.list_extend(targets, deps.terminal_entries(context.root, 1, { ask_only = true }))

    deps.numbered_select(prompt, targets, function(choice)
        if choice then
            callback(choice)
        end
    end)
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

        if line == "q" or line == "q!" or line == "quit" or line == "quit!" then
            return vim.api.nvim_replace_termcodes(
                '<C-u>lua require("sidepanes.internal").finish_question(' .. scratch .. ')<CR>',
                true,
                false,
                true
            )
        end

        if line == "wq" or line == "wq!" or line == "x" or line == "xit" or line == "exit" then
            return vim.api.nvim_replace_termcodes(
                '<C-u>lua require("sidepanes.internal").write_question(' .. scratch .. '); require("sidepanes.internal").finish_question(' .. scratch .. ')<CR>',
                true,
                false,
                true
            )
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

    open_buffer(state, deps, entry, context, opts.origin)
end

--- Capture selection and ask via the target picker.
function M.ask_picker(state, deps, opts)
    opts = opts or {}

    local origin = capture_origin(state)
    local context = deps.selection_context(opts)

    if not context then
        return
    end

    pick_target(state, deps, "Ask", context, function(choice)
        M.ask_with_entry(state, deps, choice, { context = context, origin = origin })
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

    local ctx = deps.last_coding_agent_context(context.root)

    if not ctx then
        pick_target(state, deps, "Ask", context, function(choice)
            M.ask_with_entry(state, deps, choice, { context = context, origin = origin })
        end)
        return
    end

    M.ask_with_entry(state, deps, deps.entry_for_terminal_context(ctx), { context = context, origin = origin })
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
        pick_target(state, deps, "Ask", context, function(choice)
            M.ask_with_entry(state, deps, choice, { context = context, origin = origin })
        end)
        return
    end

    M.ask_with_entry(state, deps, deps.entry_for_terminal_context(ctx), { context = context, origin = origin })
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

    M.ask_with_entry(state, deps, {
        kind = "terminal",
        tool_name = tool_name,
        preset_name = preset.name,
        label = (tool.label or tool_name) .. ": " .. (preset.label or preset.name or "Default"),
    }, opts)
end

return M
