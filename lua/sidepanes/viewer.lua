--[[
sidepanes.viewer
Purpose: Manage the markdown viewer buffer and its document lifecycle.
Does: Chooses default markdown files, creates and loads the viewer buffer, preserves scroll/cursor view, and switches the pane back to markdown.
Architecture: Owns markdown-buffer behavior while delegating window placement, rendering, mappings, and terminal memory through dependencies.
]]

local util = require("sidepanes.util")

local M = {}

--- Resolve the default markdown file for the current working tree.
function M.default_path()
    if vim.bo.filetype == "markdown" then
        local current = vim.api.nvim_buf_get_name(0)

        if current ~= "" then
            return current
        end
    end

    local readme = vim.fn.getcwd() .. "/README.md"

    if vim.fn.filereadable(readme) == 1 then
        return readme
    end

    return nil
end

--- Create or return the markdown viewer buffer.
function M.ensure_buf(state)
    if util.valid_buf(state.bufnr) then
        return state.bufnr
    end

    state.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(state.bufnr, "Sidepanes")
    vim.api.nvim_set_option_value("buftype", "", { buf = state.bufnr })
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = state.bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = state.bufnr })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = state.bufnr })

    return state.bufnr
end

--- Save the sidepanes cursor and scroll view for later restoration.
function M.save_view(state)
    if not util.valid_win(state.winid) or not util.valid_buf(state.bufnr) then
        return
    end

    if vim.api.nvim_win_get_buf(state.winid) ~= state.bufnr then
        return
    end

    local ok, view = pcall(vim.api.nvim_win_call, state.winid, vim.fn.winsaveview)

    if ok then
        state.markdown_view = {
            source = state.source,
            view = view,
        }
    end
end

--- Restore the saved markdown cursor and scroll view when possible.
function M.restore_view(state)
    if not util.valid_win(state.winid) or not state.markdown_view then
        return
    end

    if state.markdown_view.source ~= state.source then
        return
    end

    pcall(vim.api.nvim_win_call, state.winid, function()
        vim.fn.winrestview(state.markdown_view.view)
    end)
end

--- Load markdown file contents into the pane buffer.
function M.load_file(state, deps, path)
    local bufnr = M.ensure_buf(state)
    local ok, lines = pcall(vim.fn.readfile, path)

    if not ok then
        vim.notify("Could not read markdown file: " .. path, vim.log.levels.ERROR)
        return false
    end

    state.source = path

    deps.render_markview(bufnr)
    vim.api.nvim_set_option_value("readonly", false, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
    pcall(vim.treesitter.start, bufnr, "markdown")

    deps.reflow_pane_buffer(bufnr)

    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
    vim.api.nvim_set_option_value("readonly", true, { buf = bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    deps.render_markview(bufnr)
    deps.update_sticky_heading()

    return true
end

--- Open a markdown file in the pane without stealing focus.
function M.open(state, deps, path)
    path = util.resolve_path(path) or M.default_path()

    if not path then
        deps.pick()
        return
    end

    if vim.fn.filereadable(path) ~= 1 then
        vim.notify("Markdown file not readable: " .. path, vim.log.levels.ERROR)
        return
    end

    local previous = vim.api.nvim_get_current_win()
    local should_restore_view = state.source == path and state.markdown_view and state.markdown_view.source == path

    state.active_mode = "markdown"
    state.active_terminal_key = nil

    local winid = deps.ensure_win(M.ensure_buf(state), "markdown")

    if not M.load_file(state, deps, path) then
        return
    end

    deps.set_window_options(winid, "markdown")
    deps.update_sticky_heading()
    deps.render_markview(state.bufnr)

    vim.api.nvim_win_call(winid, function()
        if should_restore_view then
            M.restore_view(state)
        else
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            vim.cmd("normal! zt")
        end
    end)
    deps.setup_pane_maps(state.bufnr)

    if util.valid_win(previous) then
        vim.api.nvim_set_current_win(previous)
    end
end

--- Switch the pane back to the markdown viewer.
function M.show_markdown(state, deps)
    if not util.valid_buf(state.bufnr) then
        M.open(state, deps, state.source)

        if state.config.focus_on_switch and util.valid_win(state.winid) then
            local previous = vim.api.nvim_get_current_win()

            if previous ~= state.winid and util.valid_win(previous) then
                state.last_focus_win = previous
            end

            vim.api.nvim_set_current_win(state.winid)
        end

        return
    end

    local previous = vim.api.nvim_get_current_win()

    if state.active_terminal_key then
        deps.remember_terminal_context(state.terminals[state.active_terminal_key])
    end

    state.active_mode = "markdown"
    state.active_terminal_key = nil

    local winid = deps.ensure_win(state.bufnr, "markdown", { focus = state.config.focus_on_switch })

    deps.set_window_options(winid, "markdown")
    deps.update_sticky_heading()
    deps.render_markview(state.bufnr)
    M.restore_view(state)
    deps.setup_pane_maps(state.bufnr)

    if not state.config.focus_on_switch and util.valid_win(previous) then
        vim.api.nvim_set_current_win(previous)
    end
end

--- Toggle the pane, optionally opening a specific markdown file.
function M.toggle(state, deps, path)
    if path and path ~= "" then
        M.open(state, deps, path)
    elseif util.valid_win(state.winid) then
        deps.close_pane()
    else
        M.open(state, deps, state.source)
    end
end

return M
