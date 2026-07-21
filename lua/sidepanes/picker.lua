--[[
sidepanes.picker
Purpose: Render the plugin's lightweight numeric/letter picker.
Does: Displays entries in a floating buffer, highlights current/running items, and accepts single-key or multi-digit choices without Enter.
Architecture: Provides a dependency-free picker primitive used by pane switching and ask target selection.
]]

local util = require("sidepanes.util")

local M = {}

--- Close the picker floating window when it is still visible.
local function close_window(winid)
    if util.valid_win(winid) then
        vim.api.nvim_win_close(winid, true)
    end
end

--- Return the exact entry and prefix state for a partially typed picker key.
local function key_state(by_key, prefix)
    local exact = by_key[prefix]
    local has_prefix = false
    local has_longer = false

    for key in pairs(by_key) do
        if vim.startswith(key, prefix) then
            has_prefix = true

            if #key > #prefix then
                has_longer = true
            end
        end
    end

    return exact, has_prefix, has_longer
end

--- Read a picker choice, allowing multi-character numeric choices without Enter.
local function read_choice(by_key, getcharstr)
    local typed = ""
    getcharstr = getcharstr or vim.fn.getcharstr

    while true do
        local ok, char = pcall(getcharstr)

        if not ok then
            return nil
        end

        if char == "\27" or char == "q" then
            return nil
        end

        typed = typed .. char

        local exact, has_prefix, has_longer = key_state(by_key, typed)

        if exact and not has_longer then
            return exact
        end

        if exact and has_longer then
            for _ = 1, 30 do
                local ok_next, next_char = pcall(getcharstr, 0)

                if not ok_next then
                    return nil
                end

                if next_char and next_char ~= "" then
                    typed = typed .. next_char
                    exact, has_prefix, has_longer = key_state(by_key, typed)

                    if exact and not has_longer then
                        return exact
                    end

                    break
                end

                vim.cmd("sleep 10m")
            end

            exact = key_state(by_key, typed)

            if exact then
                return exact
            end
        end

        if not has_prefix then
            return nil
        end
    end
end

--- Render a picker and invoke the callback with the selected entry.
function M.numbered_select(prompt, entries, callback, state)
    if #entries == 0 then
        return
    end

    local width = math.max(40, vim.fn.strdisplaywidth(prompt) + 4)
    local lines = { prompt }
    local active_lines = {}

    for i, entry in ipairs(entries) do
        local prefix = entry.current and "* " or "  "
        local suffix = ""

        if entry.current and entry.active then
            suffix = "  [current session]"
        elseif entry.current then
            suffix = "  [current]"
        elseif entry.running then
            suffix = "  [session]"
        end

        local line = string.format("%s  %s%s%s", entry.key or tostring(entry.index), prefix, entry.label, suffix)

        width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
        table.insert(lines, line)

        if entry.current and not entry.shortcut then
            table.insert(active_lines, #lines - 1)
        end

        if entry.shortcut and entries[i + 1] and not entries[i + 1].shortcut then
            table.insert(lines, "")
        end
    end

    width = math.min(width, math.max(40, vim.o.columns - 8))

    local bufnr = vim.api.nvim_create_buf(false, true)
    local height = #lines
    local winid = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        width = width,
        height = height,
        style = "minimal",
        border = "single",
    })

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    vim.api.nvim_buf_add_highlight(bufnr, -1, "Title", 0, 0, -1)

    for _, line_index in ipairs(active_lines) do
        vim.api.nvim_buf_add_highlight(bufnr, -1, "Search", line_index, 0, -1)
    end

    local by_key = {}

    for _, entry in ipairs(entries) do
        by_key[entry.key or tostring(entry.index)] = entry
    end

    vim.cmd("redraw")

    local choice = nil

    if state and state._test_next_choice then
        choice = by_key[tostring(state._test_next_choice)]
        state._test_next_choice = nil
    else
        choice = read_choice(by_key, state and state._test_getcharstr)
    end

    close_window(winid)

    if choice then
        callback(choice)
    end
end

return M
