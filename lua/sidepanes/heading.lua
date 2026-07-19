--[[
sidepanes.heading
Purpose: Parse and format markdown heading text for pane display.
Does: Escapes statusline text, truncates display labels, and finds the nearest active ATX or Setext heading above the viewport.
Architecture: Supports winbar.lua with pure heading/statusline helpers that do not own pane state.
]]

local util = require("sidepanes.util")

local M = {}

--- Escape percent signs so text is safe in statusline-like options.
function M.statusline_escape(text)
    return text:gsub("%%", "%%%%")
end

--- Truncate display text to fit inside a target display width.
function M.truncate_display(text, max_width)
    if vim.fn.strdisplaywidth(text) <= max_width then
        return text
    end

    local ellipsis = "..."
    local chars = vim.fn.strchars(text)

    while chars > 0 do
        local candidate = vim.fn.strcharpart(text, 0, chars) .. ellipsis

        if vim.fn.strdisplaywidth(candidate) <= max_width then
            return candidate
        end

        chars = chars - 1
    end

    return ellipsis
end

--- Parse an ATX markdown heading line.
local function atx_heading(line)
    local markers, title = line:match("^%s*(#+)%s+(.+)%s*$")

    if not markers or #markers > 6 then
        return nil
    end

    title = util.trim(title:gsub("%s+#+%s*$", ""))

    if title == "" then
        return nil
    end

    return #markers, title
end

--- Parse a Setext markdown heading from a title and underline line.
local function setext_heading(title_line, underline_line)
    if not underline_line then
        return nil
    end

    local marker = underline_line:match("^%s*(=+)%s*$")

    if marker then
        marker = "="
    else
        marker = underline_line:match("^%s*(-+)%s*$") and "-"
    end

    if not marker then
        return nil
    end

    local title = util.trim(title_line)

    if title == "" then
        return nil
    end

    return marker == "=" and 1 or 2, title
end

--- Find the nearest markdown heading visible above the window top.
function M.active_heading(winid)
    if not util.valid_win(winid) then
        return nil
    end

    local bufnr = vim.api.nvim_win_get_buf(winid)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local topline = vim.api.nvim_win_call(winid, function()
        return vim.fn.line("w0")
    end)
    local last_needed = math.min(line_count, topline + 1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, last_needed, false)

    for index = math.min(topline, #lines), 1, -1 do
        local level, title = atx_heading(lines[index])

        if level then
            return level, title
        end

        level, title = setext_heading(lines[index], lines[index + 1])

        if level then
            return level, title
        end

        if index > 1 then
            level, title = setext_heading(lines[index - 1], lines[index])

            if level then
                return level, title
            end
        end
    end

    return nil
end

return M
