--[[
sidepanes.lifecycle
Purpose: Manage plugin setup-time configuration and global lifecycle autocmds.
Does: Merges user options and installs focus tracking plus graceful terminal shutdown on Neovim exit.
Architecture: Keeps autocmd setup separate from init.lua while delegating user-facing config expansion to config.lua.
]]

local config = require("sidepanes.config")
local validation = require("sidepanes.validation")

local M = {}

--- Merge user configuration and install pane lifecycle autocmds.
function M.setup(state, groups, deps, opts)
    local normalized, metadata = config.normalize(state.config, opts or {})

    state.config = normalized

    if metadata.width.error then
        vim.notify("Invalid Sidepanes width: " .. metadata.width.error, vim.log.levels.WARN)
    end

    if metadata.width.configured then
        if state.config.sticky_relative_width and metadata.width.relative_width then
            state.relative_width = metadata.width.relative_width
        else
            state.relative_width = nil
        end
    elseif not state.config.sticky_relative_width then
        state.relative_width = nil
    end

    validation.notify(state.config)

    vim.api.nvim_clear_autocmds({ group = groups.focus })
    vim.api.nvim_create_autocmd("WinEnter", {
        group = groups.focus,
        callback = function()
            deps.record_focus_win()
        end,
    })

    if groups.resize and deps.refresh_width then
        vim.api.nvim_clear_autocmds({ group = groups.resize })
        vim.api.nvim_create_autocmd("VimResized", {
            group = groups.resize,
            callback = function()
                deps.refresh_width()
            end,
        })
    end

    vim.api.nvim_clear_autocmds({ group = groups.shutdown })
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = groups.shutdown,
        callback = function()
            if state.config.shutdown_on_exit then
                deps.shutdown_terminals()
            end
        end,
    })
end

return M
