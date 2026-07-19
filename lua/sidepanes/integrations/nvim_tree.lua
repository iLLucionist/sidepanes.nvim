--[[
sidepanes.integrations.nvim_tree
Purpose: Provide an nvim-tree window picker that avoids opening files inside Sidepanes-owned windows.
Does: Filters pane, terminal, floating, sidebar, help, quickfix, and plugin windows while preferring the alternate normal window.
Architecture: Keeps third-party plugin integration code outside user config and outside the core Sidepanes window module.
]]

local M = {}

local excluded_buftypes = {
    nofile = true,
    terminal = true,
    help = true,
}

local excluded_filetypes = {
    NvimTree = true,
    notify = true,
    lazy = true,
    qf = true,
    diff = true,
    fugitive = true,
    fugitiveblame = true,
}

--- Return whether a window is a valid nvim-tree file-open target.
function M.usable_window(sidepanes, winid)
    if not vim.api.nvim_win_is_valid(winid) then
        return false
    end

    if sidepanes and winid == sidepanes.winid then
        return false
    end

    local config = vim.api.nvim_win_get_config(winid)

    if not config.focusable or config.hide or config.external then
        return false
    end

    local bufnr = vim.api.nvim_win_get_buf(winid)

    if sidepanes and bufnr == sidepanes.bufnr then
        return false
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
    local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

    if excluded_buftypes[buftype] then
        return false
    end

    if excluded_filetypes[filetype] then
        return false
    end

    return true
end

--- Return the best window id for nvim-tree to use when opening a file.
function M.file_target_picker()
    local ok, sidepanes = pcall(require, "sidepanes")
    local pane_state = ok and sidepanes._state and sidepanes._state() or nil
    local alternate_winid = vim.fn.win_getid(vim.fn.winnr("#"))
    local candidates = {}

    if M.usable_window(pane_state, alternate_winid) then
        return alternate_winid
    end

    for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if M.usable_window(pane_state, winid) then
            table.insert(candidates, winid)
        end
    end

    return candidates[1] or -1
end

return M
