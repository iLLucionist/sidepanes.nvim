--[[
sidepanes.render
Purpose: Handle markdown rendering refreshes and automatic reflow.
Does: Re-runs markview rendering, invokes internal or external markdown reflow, and updates wrap state.
Architecture: Encapsulates buffer formatting/render side effects behind dependency callbacks for pane width and window options.
]]

local util = require("sidepanes.util")

local M = {}

--- Re-render markview decorations for a markdown buffer.
function M.markview(bufnr)
    local ok, markview = pcall(require, "markview")

    if not ok then
        return
    end

    pcall(markview.clear, bufnr)
    pcall(markview.render, bufnr, { enable = true, hybrid_mode = false })
end

--- Reflow the sidepanes buffer using configured internal or external formatting.
function M.reflow_buffer(state, deps, bufnr, opts)
    opts = opts or {}
    bufnr = bufnr or state.bufnr

    if not state.config.auto_reflow or not util.valid_buf(bufnr) then
        return
    end

    local ok, markdown_reflow = pcall(require, "sidepanes.markdown_reflow")

    if not ok then
        return
    end

    local readonly = vim.api.nvim_get_option_value("readonly", { buf = bufnr })
    local modifiable = vim.api.nvim_get_option_value("modifiable", { buf = bufnr })

    vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    markdown_reflow.reflow_buffer(bufnr, {
        width = deps.text_width(),
        force = true,
        external_reflow_cmd = state.config.external_reflow_cmd,
        external_reflow_fallback = state.config.external_reflow_fallback,
        external_reflow_protect_tables = state.config.external_reflow_protect_tables,
        notify = opts.notify == true,
    })
    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", readonly, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", modifiable, { buf = bufnr })
end

--- Re-apply wrap settings and refresh markdown rendering if needed.
function M.apply_wrap_state(state, deps)
    if not util.valid_win(state.winid) or not util.valid_buf(state.bufnr) then
        return
    end

    local before = vim.wo[state.winid].wrap

    deps.set_window_options(state.winid)

    if before ~= vim.wo[state.winid].wrap then
        M.markview(state.bufnr)
    end
end

--- Toggle wrapping in the markdown viewer pane.
function M.toggle_wrap(state, deps)
    state.wrap_enabled = not deps.preferred_wrap()
    M.apply_wrap_state(state, deps)
end

return M
