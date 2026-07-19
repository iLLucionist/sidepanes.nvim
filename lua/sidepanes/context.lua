--[[
sidepanes.context
Purpose: Centralize pane-aware context lookup for buffers, roots, and selections.
Does: Identifies pane-owned buffers, resolves the project root for markdown and terminal panes, and builds send/ask selection context.
Architecture: Sits between the public facade and the selection/terminal/util modules so state-dependent lookups stay in one place.
]]

local selection = require("sidepanes.selection")
local terminal = require("sidepanes.terminal")
local util = require("sidepanes.util")

local M = {}

--- Find the pane terminal context for a buffer.
function M.terminal_context_for_buf(state, bufnr)
    return terminal.context_for_buf(state, bufnr)
end

--- Return whether a buffer belongs to the pane or one of its terminals.
function M.is_pane_buf(state, bufnr)
    if not util.valid_buf(bufnr) then
        return false
    end

    if bufnr == state.bufnr then
        return true
    end

    for _, ctx in pairs(state.terminals or {}) do
        if bufnr == ctx.bufnr then
            return true
        end
    end

    return false
end

--- Resolve the project root associated with a pane, terminal, or normal buffer.
function M.pane_root(state, bufnr)
    local terminal_ctx = M.terminal_context_for_buf(state, bufnr)

    if terminal_ctx then
        return terminal_ctx.root
    end

    if bufnr == state.bufnr and state.source then
        return util.project_root_for_path(state.source)
    end

    return util.project_root(bufnr)
end

--- Capture text, file, root, and snippet language for a send/ask action.
function M.selection_context(state, opts)
    return selection.context(opts, {
        pane_bufnr = state.bufnr,
        source = state.source,
        terminal_context_for_buf = function(bufnr)
            return M.terminal_context_for_buf(state, bufnr)
        end,
    })
end

return M
