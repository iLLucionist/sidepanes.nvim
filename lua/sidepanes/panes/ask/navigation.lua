--[[
sidepanes.panes.ask.navigation
Purpose: Handle ask-pane citation navigation and source jumps.
Does: Moves between File/Selection headers and opens the cited source outside the Sidepanes window when possible.
Architecture: Imperative pane helper; callers own session lifecycle and keymap registration.
]]

local util = require("sidepanes.util")

local M = {}

local function current_ask_buf(state)
    local ask = state.ask_pane or {}

    if util.valid_buf(ask.bufnr) then
        return ask.bufnr
    end

    return nil
end

local function header_pattern(kind)
    if kind == "file" then
        return "^File:$"
    end

    return "^Selection:$"
end

--- Jump between File or Selection headers inside the ask pane.
function M.jump_header(state, kind, direction)
    local bufnr = current_ask_buf(state)

    if not bufnr or not util.valid_win(state.winid) or vim.api.nvim_win_get_buf(state.winid) ~= bufnr then
        return
    end

    local pattern = header_pattern(kind)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local cursor = vim.api.nvim_win_get_cursor(state.winid)[1]
    local step = direction == "previous" and -1 or 1
    local index = cursor + step

    while index >= 1 and index <= #lines do
        if lines[index]:match(pattern) then
            vim.api.nvim_win_set_cursor(state.winid, { index, 0 })
            return true
        end

        index = index + step
    end

    return false
end

local function parse_file_line(line)
    local file, root = (line or ""):match("^(.-)%s+%((root: .-)%)$")

    if root then
        return file, root:gsub("^root: ", "")
    end

    return line, nil
end

local function citation_under_cursor(state)
    local bufnr = current_ask_buf(state)

    if not bufnr or not util.valid_win(state.winid) then
        return nil
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local cursor = vim.api.nvim_win_get_cursor(state.winid)[1]
    local file = nil
    local root = nil
    local start_lnum = nil
    local file_index = nil

    for index = math.min(cursor, #lines), 1, -1 do
        if lines[index] == "Selection:" then
            local range = lines[index + 1] or ""
            start_lnum = tonumber(range:match("^lines%s+(%d+)%-%d+$")) or start_lnum
        elseif lines[index] == "File:" then
            file, root = parse_file_line(lines[index + 1])
            file_index = index
            break
        end
    end

    if not file or file == "" then
        return nil
    end

    if not start_lnum and file_index then
        for index = file_index + 1, #lines do
            if lines[index] == "File:" then
                break
            elseif lines[index] == "Selection:" then
                local range = lines[index + 1] or ""

                start_lnum = tonumber(range:match("^lines%s+(%d+)%-%d+$")) or start_lnum
                break
            end
        end
    end

    return {
        file = file,
        root = root or (state.ask_pane or {}).root,
        lnum = start_lnum or 1,
    }
end

local function resolve_citation_path(citation)
    local file = citation.file

    if not file then
        return nil
    end

    if file:sub(1, 1) == "/" or file:sub(1, 1) == "~" then
        return vim.fn.fnamemodify(file, ":p")
    end

    if citation.root and citation.root ~= "" then
        return vim.fn.fnamemodify(citation.root .. "/" .. file, ":p")
    end

    return vim.fn.fnamemodify(file, ":p")
end

local function target_window(state)
    if util.valid_win(state.last_focus_win) and state.last_focus_win ~= state.winid then
        return state.last_focus_win
    end

    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        if winid ~= state.winid then
            return winid
        end
    end

    return state.winid
end

--- Open the cited source file and jump to the cited start line.
function M.source_jump(state)
    local citation = citation_under_cursor(state)

    if not citation then
        vim.notify("No ask citation under cursor", vim.log.levels.WARN)
        return false
    end

    local path = resolve_citation_path(citation)

    if not path or vim.fn.filereadable(path) ~= 1 then
        vim.notify("Ask citation file not readable: " .. tostring(path or citation.file), vim.log.levels.WARN)
        return false
    end

    local winid = target_window(state)

    if util.valid_win(winid) then
        vim.api.nvim_set_current_win(winid)
    end

    vim.cmd.edit(vim.fn.fnameescape(path))
    pcall(vim.api.nvim_win_set_cursor, 0, { citation.lnum, 0 })

    return true
end

return M
