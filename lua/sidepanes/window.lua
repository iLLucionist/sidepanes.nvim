--[[
sidepanes.window
Purpose: Own side-pane window sizing, options, focus, and zoom behavior.
Does: Computes pane/text widths, creates or reuses the side split, applies markdown/terminal-local window options, and tracks focus restoration.
Architecture: Isolates Neovim window side effects from viewer, terminal, and switcher logic through dependency callbacks.
]]

local util = require("sidepanes.util")
local api = require("sidepanes.api")

local M = {}

--- Return the user-selected wrap state or configured wrap default.
function M.preferred_wrap(state)
    if state.wrap_enabled == nil then
        return state.config.wrap
    end

    return state.wrap_enabled
end

--- Return the wrap state after considering pane state.
function M.effective_wrap(state)
    return M.preferred_wrap(state)
end

--- Compute the pane width for normal or zoomed layout.
function M.width(state)
    if not state.zoomed then
        if state.config.sticky_relative_width and state.relative_width then
            return api.width_from_spec(state.relative_width) or state.config.width
        end

        return state.config.width
    end

    local reserved = math.max(1, tonumber(vim.o.winminwidth) or 1)
    local separator = 1
    local max_width = vim.o.columns - reserved - separator

    return math.max(state.config.width, max_width)
end

--- Compute the text reflow width available inside the pane.
function M.text_width(state, winid)
    winid = winid or state.winid

    if not util.valid_win(winid) then
        return nil
    end

    local width = vim.api.nvim_win_get_width(winid)

    if vim.api.nvim_get_option_value("number", { win = winid }) then
        width = width - vim.api.nvim_get_option_value("numberwidth", { win = winid })
    end

    local text_width = math.max(20, width - state.config.reflow_margin)

    if state.zoomed and state.config.zoom_text_width and state.config.zoom_text_width > 0 then
        return math.min(text_width, state.config.zoom_text_width)
    end

    return text_width
end

--- Apply pane-local window options for markdown or terminal mode.
function M.set_options(state, deps, winid, mode)
    mode = mode or state.active_mode

    local wrap = M.effective_wrap(state)

    vim.api.nvim_set_option_value("winfixwidth", true, { win = winid })
    vim.api.nvim_set_option_value("number", mode == "markdown", { win = winid })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
    vim.api.nvim_set_option_value("wrap", mode == "markdown" and wrap or false, { win = winid })
    vim.api.nvim_set_option_value("linebreak", mode == "markdown" and wrap or false, { win = winid })
    vim.api.nvim_set_option_value("breakindent", mode == "markdown" and wrap or false, { win = winid })
    vim.api.nvim_set_option_value("showbreak", "  ", { win = winid })
    vim.api.nvim_set_option_value("cursorline", mode == "markdown", { win = winid })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winid })
    vim.api.nvim_set_option_value("foldcolumn", "0", { win = winid })
    vim.api.nvim_set_option_value("colorcolumn", "", { win = winid })
    vim.api.nvim_set_option_value("conceallevel", mode == "markdown" and 3 or 0, { win = winid })
    vim.api.nvim_set_option_value("concealcursor", mode == "markdown" and "nvic" or "", { win = winid })
    deps.update_sticky_heading()
end

--- Create or reuse the side pane window for a buffer and mode.
function M.ensure(state, deps, bufnr, mode, opts)
    opts = opts or {}
    bufnr = bufnr or deps.ensure_buf()
    mode = mode or state.active_mode

    if util.valid_win(state.winid) then
        if util.valid_buf(bufnr) and vim.api.nvim_win_get_buf(state.winid) ~= bufnr then
            vim.api.nvim_win_set_buf(state.winid, bufnr)
        end

        vim.api.nvim_win_set_width(state.winid, M.width(state))
        M.set_options(state, deps, state.winid, mode)

        if opts.focus then
            local previous = vim.api.nvim_get_current_win()

            if previous ~= state.winid and util.valid_win(previous) then
                state.last_focus_win = previous
            end

            vim.api.nvim_set_current_win(state.winid)
        end

        return state.winid
    end

    local previous = vim.api.nvim_get_current_win()

    vim.cmd("botright vertical " .. M.width(state) .. "split")
    state.winid = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(state.winid, bufnr)
    vim.api.nvim_win_set_width(state.winid, M.width(state))
    M.set_options(state, deps, state.winid, mode)
    deps.update_sticky_heading()

    if mode == "markdown" then
        deps.render_markview(bufnr)
    end

    if opts.focus then
        if util.valid_win(previous) and previous ~= state.winid then
            state.last_focus_win = previous
        end

        vim.api.nvim_set_current_win(state.winid)
    elseif util.valid_win(previous) then
        vim.api.nvim_set_current_win(previous)
    end

    return state.winid
end

--- Re-apply wrap settings and refresh markdown rendering if needed.
function M.apply_wrap_state(state, deps)
    if not util.valid_win(state.winid) or not util.valid_buf(state.bufnr) then
        return
    end

    local before = vim.wo[state.winid].wrap

    M.set_options(state, deps, state.winid)

    if before ~= vim.wo[state.winid].wrap then
        deps.render_markview(state.bufnr)
    end
end

--- Close the pane window while preserving buffers and state.
function M.close(state, deps)
    if util.valid_win(state.winid) then
        if state.active_mode == "markdown" then
            deps.save_markdown_view()
        end

        vim.api.nvim_win_close(state.winid, true)
    end

    state.winid = nil
end

--- Return whether the pane window is currently open.
function M.is_open(state)
    return util.valid_win(state.winid)
end

--- Toggle focus between the pane and the last normal window.
function M.focus_toggle(state, deps)
    local current = vim.api.nvim_get_current_win()

    if util.valid_win(state.winid) and current == state.winid then
        if util.valid_win(state.last_focus_win) then
            vim.api.nvim_set_current_win(state.last_focus_win)
        else
            vim.cmd("wincmd p")
        end

        return
    end

    if util.valid_win(current) then
        state.last_focus_win = current
    end

    if util.valid_win(state.winid) then
        vim.api.nvim_set_current_win(state.winid)
        return
    end

    deps.open_markdown(state.source)

    if util.valid_win(state.winid) then
        vim.api.nvim_set_current_win(state.winid)
    end
end

--- Toggle the pane between normal width and zoom width.
function M.toggle_zoom(state, deps)
    state.zoomed = not state.zoomed

    if not util.valid_win(state.winid) then
        return
    end

    local previous = vim.api.nvim_get_current_win()

    if state.zoomed and previous ~= state.winid and util.valid_win(previous) then
        state.last_focus_win = previous
    end

    if state.active_mode == "markdown" then
        deps.save_markdown_view()
    end

    pcall(vim.api.nvim_win_set_width, state.winid, M.width(state))
    M.set_options(state, deps, state.winid, state.active_mode == "markdown" and "markdown" or "terminal")

    if state.active_mode == "markdown" and util.valid_buf(state.bufnr) then
        deps.reflow_pane_buffer(state.bufnr)
        deps.render_markview(state.bufnr)
        deps.restore_markdown_view()
    end

    deps.update_sticky_heading()

    if state.zoomed then
        vim.api.nvim_set_current_win(state.winid)
    end

    vim.notify("Pane zoom " .. (state.zoomed and "on" or "off"), vim.log.levels.INFO)
end

--- Remember the most recent normal window outside the pane.
function M.record_focus_win(state, deps, winid)
    winid = winid or vim.api.nvim_get_current_win()

    if not util.valid_win(winid) or winid == state.winid then
        return
    end

    local config = vim.api.nvim_win_get_config(winid)

    if config.relative and config.relative ~= "" then
        return
    end

    if deps.is_pane_buf(vim.api.nvim_win_get_buf(winid)) then
        return
    end

    state.last_focus_win = winid
end

return M
