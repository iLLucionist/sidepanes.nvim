--[[
sidepanes.winbar
Purpose: Maintain the pane winbar title for markdown and terminal modes.
Does: Shows the active markdown heading or terminal identity, includes zoom state, truncates labels, and refreshes on movement/resize events.
Architecture: Bridges heading.lua formatting with shared pane state; init.lua installs its autocmd group through this module.
]]

local heading = require("sidepanes.heading")
local util = require("sidepanes.util")

local M = {}

--- Build the winbar title for the active terminal pane.
local function terminal_title(state)
    local ctx = state.active_terminal_key and state.terminals[state.active_terminal_key] or nil

    if not ctx then
        return "Pane"
    end

    return ctx.tool_label .. ": " .. ctx.preset_label .. " - " .. util.root_label(ctx.root)
end

--- Refresh the pane winbar for markdown heading or terminal identity.
function M.update(state)
    if not util.valid_win(state.winid) then
        return
    end

    if not state.config.sticky_heading then
        vim.api.nvim_set_option_value("winbar", "", { win = state.winid })
        return
    end

    if state.active_mode ~= "markdown" then
        local max_width = math.max(10, vim.api.nvim_win_get_width(state.winid) - 4)
        local title = terminal_title(state)

        if state.zoomed then
            title = title .. " [zoom]"
        end

        local label = heading.truncate_display(title, max_width)

        vim.api.nvim_set_option_value("winbar", "%#WinBar# " .. heading.statusline_escape(label) .. " %*", { win = state.winid })
        return
    end

    local level, title = heading.active_heading(state.winid)

    if not title then
        title = state.source and vim.fn.fnamemodify(state.source, ":t") or "Sidepanes"
    else
        title = string.rep("#", level) .. " " .. title
    end

    title = "Markdown: " .. title

    if state.zoomed then
        title = title .. " [zoom]"
    end

    local max_width = math.max(10, vim.api.nvim_win_get_width(state.winid) - 4)
    local label = heading.truncate_display(title, max_width)

    vim.api.nvim_set_option_value("winbar", "%#WinBar# " .. heading.statusline_escape(label) .. " %*", { win = state.winid })
end

--- Install autocmds that keep the sticky heading current.
function M.setup_autocmds(state, group)
    vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "BufWinEnter", "CursorMoved" }, {
        group = group,
        callback = function()
            M.update(state)
        end,
    })
end

return M
