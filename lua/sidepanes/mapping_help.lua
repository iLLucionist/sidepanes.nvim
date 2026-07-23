--[[
sidepanes.mapping_help
Purpose: Build and display interactive Sidepanes mapping help.
Does: Formats normalized runtime mappings/commands by current pane context and opens a small Markdown help buffer.
Architecture: Keeps mapping rows and geometry helpers testable; Neovim UI effects are isolated to open().
]]

local util = require("sidepanes.util")

local M = {}

local pane_rows = {
    markdown = {
        { key = "markdown", mode = "n", label = "Show Markdown pane" },
        { key = "codex", mode = "n", label = "Show Codex pane" },
        { key = "claude", mode = "n", label = "Show Claude pane" },
        { key = "ipython", mode = "n", label = "Show IPython pane" },
        { key = "toggle_terminal", mode = "n", label = "Toggle Markdown/terminal pane" },
        { key = "toggle_terminal_alt", mode = "n", label = "Toggle Markdown/terminal pane" },
        { key = "headings", mode = "n", label = "Pick Markdown heading" },
        { key = "gf", mode = "n", label = "Open file under cursor" },
        { key = "zoom", mode = "n", label = "Toggle pane zoom" },
        { key = "ask_pane", mode = "n", label = "Show ask pane" },
        { key = "help", mode = "n", label = "Show mapping help" },
        { key = "send_ipython", mode = "x", label = "Send selection to IPython" },
        { key = "ask_last", mode = "x", label = "Ask last coding agent" },
        { key = "ask_codex", mode = "x", label = "Ask Codex" },
        { key = "ask_claude", mode = "x", label = "Ask Claude" },
    },
    terminal = {
        { key = "markdown", mode = "n", label = "Show Markdown pane" },
        { key = "codex", mode = "n", label = "Show Codex pane" },
        { key = "claude", mode = "n", label = "Show Claude pane" },
        { key = "ipython", mode = "n", label = "Show IPython pane" },
        { key = "toggle_terminal", mode = "n/t", label = "Toggle Markdown/terminal pane" },
        { key = "toggle_terminal_alt", mode = "n/t", label = "Toggle Markdown/terminal pane" },
        { key = "ipython_alt", mode = "n", label = "Show IPython pane" },
        { key = "gf", mode = "n", label = "Open file under cursor" },
        { key = "zoom", mode = "n", label = "Toggle pane zoom" },
        { key = "ask_pane", mode = "n", label = "Show ask pane" },
        { key = "help", mode = "n", label = "Show mapping help" },
        { key = "send_ipython", mode = "x", label = "Send selection to IPython" },
        { key = "ask_last", mode = "x", label = "Ask last coding agent" },
        { key = "ask_codex", mode = "x", label = "Ask Codex" },
        { key = "ask_claude", mode = "x", label = "Ask Claude" },
    },
    ask = {
        { key = "ask_model_picker", mode = "n", label = "Change ask target" },
        { key = "ask_model_picker_alt", mode = "n", label = "Change ask target" },
        { key = "ask_source", mode = "n", label = "Open citation source" },
        { key = "ask_next_file", mode = "n", label = "Next cited file" },
        { key = "ask_previous_file", mode = "n", label = "Previous cited file" },
        { key = "ask_next_selection", mode = "n", label = "Next selection" },
        { key = "ask_previous_selection", mode = "n", label = "Previous selection" },
        { key = "ask_submit", mode = "n/i", label = "Submit ask prompt" },
        { key = "ask_send", mode = "n", label = "Finish ask prompt" },
        { key = "ask_send_alt", mode = "n", label = "Finish ask prompt" },
        { key = "help", mode = "n", label = "Show mapping help" },
        { key = "ask_last", mode = "x", label = "Ask last coding agent" },
        { key = "ask_codex", mode = "x", label = "Ask Codex" },
        { key = "ask_claude", mode = "x", label = "Ask Claude" },
    },
}

local global_rows = {
    { key = "toggle", mode = "n", label = "Toggle Sidepanes" },
    { key = "pick", mode = "n", label = "Pick Markdown document" },
    { key = "headings", mode = "n", label = "Pick Markdown heading" },
    { key = "markdown", mode = "n", label = "Show Markdown viewer" },
    { key = "codex", mode = "n", label = "Show Codex pane" },
    { key = "claude", mode = "n", label = "Show Claude pane" },
    { key = "ipython", mode = "n", label = "Show IPython pane" },
    { key = "restart_ipython", mode = "n", label = "Restart IPython" },
    { key = "send_ipython", mode = "n/x", label = "Send to IPython" },
    { key = "clear_ipython", mode = "n", label = "Clear IPython" },
    { key = "focus", mode = "n", label = "Toggle Sidepanes focus" },
    { key = "zoom", mode = "n", label = "Toggle Sidepanes zoom" },
    { key = "width_previous", mode = "n", label = "Previous width snap point" },
    { key = "width_next", mode = "n", label = "Next width snap point" },
    { key = "width_picker", mode = "n", label = "Pick width" },
    { key = "sticky_relative_width", mode = "n", label = "Toggle sticky relative width" },
    { key = "switch", mode = "n", label = "Switch Sidepanes" },
    { key = "ask_pane", mode = "n", label = "Show ask pane" },
    { key = "ask", mode = "x", label = "Ask target picker" },
    { key = "ask_last", mode = "x", label = "Ask last coding agent" },
    { key = "ask_codex", mode = "x", label = "Ask Codex" },
    { key = "ask_claude", mode = "x", label = "Ask Claude" },
}

local command_rows = {
    markdown = {
        ":Sidepanes",
        ":Sidepanes headings",
        ":Sidepanes mappings",
        ":SidepanesMappings",
    },
    terminal = {
        ":Sidepanes markdown",
        ":Sidepanes tool {tool} [preset]",
        ":Sidepanes mappings",
        ":SidepanesMappings",
    },
    ask = {
        ":Sidepanes ask-status",
        ":Sidepanes submit-question",
        ":Sidepanes mappings",
        ":SidepanesMappings",
    },
}

local function display_lhs(value)
    if value == false or value == nil then
        return nil
    end

    return tostring(value)
end

local function mapping_rows(source, rows)
    local result = {}

    for _, row in ipairs(rows or {}) do
        local lhs = display_lhs(source and source[row.key])

        if lhs then
            table.insert(result, {
                lhs = lhs,
                mode = row.mode,
                label = row.label,
            })
        end
    end

    return result
end

local function pane_kind(state, opts)
    opts = opts or {}

    if opts.kind then
        return opts.kind
    end

    local bufnr = opts.bufnr

    if state.ask_pane and bufnr and bufnr == state.ask_pane.bufnr then
        return "ask"
    end

    if bufnr and bufnr == state.bufnr then
        return "markdown"
    end

    if state.active_mode == "ask" then
        return "ask"
    end

    if state.active_mode == "markdown" then
        return "markdown"
    end

    return "terminal"
end

local function title_for_kind(kind)
    if kind == "ask" then
        return "Ask Pane Mappings"
    elseif kind == "terminal" then
        return "Terminal Pane Mappings"
    end

    return "Markdown Pane Mappings"
end

local function append_mapping_section(lines, title, rows)
    table.insert(lines, "## " .. title)
    table.insert(lines, "")

    if #rows == 0 then
        table.insert(lines, "- No active mappings.")
        table.insert(lines, "")
        return
    end

    for _, row in ipairs(rows) do
        table.insert(lines, ("- `%s` (%s): %s"):format(row.lhs, row.mode, row.label))
    end

    table.insert(lines, "")
end

local function append_command_section(lines, kind)
    table.insert(lines, "## Relevant Commands")
    table.insert(lines, "")

    for _, command in ipairs(command_rows[kind] or command_rows.markdown) do
        table.insert(lines, "- `" .. command .. "`")
    end

    table.insert(lines, "")
end

function M.help_config(config)
    local help = type(config.help) == "table" and config.help or {}
    local mappings = type(config.mappings) == "table" and config.mappings or {}
    local pane = type(mappings.pane) == "table" and mappings.pane or {}
    local mapping = help.mapping

    if pane.help ~= nil then
        mapping = pane.help
    end

    return {
        winbar = help.winbar ~= false,
        mapping = mapping,
        scope = help.scope or "pane_first",
    }
end

function M.winbar_hint(config)
    local help = M.help_config(config or {})

    if not help.winbar or not help.mapping then
        return nil
    end

    return tostring(help.mapping) .. " help"
end

function M.lines(state, opts)
    opts = opts or {}

    local config = state.config or {}
    local mappings = type(config.mappings) == "table" and config.mappings or {}
    local pane_mappings = type(mappings.pane) == "table" and mappings.pane or {}
    local global_mappings = type(mappings.global) == "table" and mappings.global or {}
    local kind = pane_kind(state, opts)
    local lines = {
        "# Sidepanes Mapping Help",
        "",
    }

    append_mapping_section(lines, title_for_kind(kind), mapping_rows(pane_mappings, pane_rows[kind]))
    append_mapping_section(lines, "Global Sidepanes Mappings", mapping_rows(global_mappings, global_rows))
    append_command_section(lines, kind)

    return lines
end

function M.float_geometry(pane, editor)
    pane = pane or {}
    editor = editor or {}

    local pane_width = tonumber(pane.width) or 0
    local pane_height = tonumber(pane.height) or 0
    local editor_width = tonumber(editor.width) or vim.o.columns
    local editor_height = tonumber(editor.height) or vim.o.lines

    if pane_width < 32 or pane_height < 8 then
        local width = math.max(28, math.min(72, editor_width - 4))
        local height = math.max(6, math.min(20, editor_height - 4))

        return {
            relative = "editor",
            width = width,
            height = height,
            row = math.max(0, math.floor((editor_height - height) / 2)),
            col = math.max(0, math.floor((editor_width - width) / 2)),
        }
    end

    local width = math.max(28, math.min(pane_width - 4, 72))
    local height = math.max(6, math.min(pane_height - 4, 20))
    local pane_row = tonumber(pane.row) or 0
    local pane_col = tonumber(pane.col) or 0

    return {
        relative = "editor",
        width = width,
        height = height,
        row = math.max(0, pane_row + math.floor((pane_height - height) / 2)),
        col = math.max(0, pane_col + math.floor((pane_width - width) / 2)),
    }
end

local function pane_geometry(state)
    local row, col = unpack(vim.api.nvim_win_get_position(state.winid))

    return {
        row = row,
        col = col,
        width = vim.api.nvim_win_get_width(state.winid),
        height = vim.api.nvim_win_get_height(state.winid),
    }
end

function M.open(state, opts)
    opts = opts or {}

    if not util.valid_win(state.winid) then
        vim.notify("Sidepanes is not open.", vim.log.levels.WARN)
        return nil
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    local lines = M.lines(state, {
        bufnr = opts.bufnr or vim.api.nvim_get_current_buf(),
        kind = opts.kind,
    })

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })

    local geometry = M.float_geometry(pane_geometry(state), {
        width = vim.o.columns,
        height = vim.o.lines,
    })

    local winid = vim.api.nvim_open_win(bufnr, true, {
        relative = geometry.relative,
        row = geometry.row,
        col = geometry.col,
        width = geometry.width,
        height = geometry.height,
        style = "minimal",
        border = "rounded",
        title = " Sidepanes help ",
        title_pos = "center",
    })

    vim.api.nvim_set_option_value("wrap", true, { win = winid })
    vim.api.nvim_set_option_value("winbar", "", { win = winid })
    pcall(vim.keymap.set, "n", "q", "<cmd>close<CR>", { buffer = bufnr, silent = true, desc = "Close Sidepanes help" })
    pcall(vim.keymap.set, "n", "<Esc>", "<cmd>close<CR>", { buffer = bufnr, silent = true, desc = "Close Sidepanes help" })

    return {
        bufnr = bufnr,
        winid = winid,
        lines = lines,
        geometry = geometry,
    }
end

return M
