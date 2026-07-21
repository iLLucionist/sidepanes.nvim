--[[
sidepanes.viewer
Purpose: Manage the markdown viewer buffer and its document lifecycle.
Does: Chooses default markdown files, creates and loads the viewer buffer, preserves scroll/cursor view, and switches the pane back to markdown.
Architecture: Owns markdown-buffer behavior while delegating window placement, rendering, mappings, and terminal memory through dependencies.
]]

local util = require("sidepanes.util")

local M = {}
local uv = vim.uv or vim.loop

--- Stop any active markdown reload timer.
local function stop_reload_watcher(state)
    if state.markdown_reload_timer then
        pcall(function()
            state.markdown_reload_timer:stop()
        end)
        pcall(function()
            state.markdown_reload_timer:close()
        end)
    end

    state.markdown_watcher_path = nil
    state.markdown_reload_timer = nil
end

--- Return a stable content fingerprint for detecting markdown changes on disk.
local function file_signature(path, lines)
    if not path or path == "" then
        return nil
    end

    if not lines then
        local ok, read_lines = pcall(vim.fn.readfile, path)

        if not ok then
            return nil
        end

        lines = read_lines
    end

    return vim.fn.sha256(table.concat(lines, "\n"))
end

--- Normalize a line enough for reload position matching.
local function normalized_line(line)
    return util.trim((line or ""):lower():gsub("%s+", " "))
end

--- Return simple word tokens for fuzzy reload position matching.
local function line_tokens(line)
    local tokens = {}

    for token in normalized_line(line):gmatch("[%w_]+") do
        tokens[token] = true
    end

    return tokens
end

--- Count entries in a set-like table.
local function table_size(tbl)
    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

--- Capture the current markdown line and view before a reload.
local function reload_snapshot(state)
    if not util.valid_buf(state.bufnr) then
        return {
            lnum = 1,
            col = 0,
            topline = 1,
            text = "",
        }
    end

    local view = nil

    if util.valid_win(state.winid) and vim.api.nvim_win_get_buf(state.winid) == state.bufnr then
        local ok, saved = pcall(vim.api.nvim_win_call, state.winid, vim.fn.winsaveview)

        if ok then
            view = saved
        end
    elseif state.markdown_view and state.markdown_view.source == state.source then
        view = state.markdown_view.view
    end

    local line_count = vim.api.nvim_buf_line_count(state.bufnr)
    local lnum = math.max(1, math.min(line_count, tonumber(view and view.lnum) or 1))
    local line = vim.api.nvim_buf_get_lines(state.bufnr, lnum - 1, lnum, false)[1] or ""

    return {
        lnum = lnum,
        col = tonumber(view and view.col) or 0,
        topline = tonumber(view and view.topline) or lnum,
        text = line,
    }
end

--- Pick the best line in a reloaded buffer for the pre-reload cursor line.
local function best_reload_line(lines, snapshot)
    if #lines == 0 then
        return 1
    end

    local old_lnum = math.max(1, math.min(#lines, snapshot and snapshot.lnum or 1))
    local target = normalized_line(snapshot and snapshot.text or "")

    if target ~= "" then
        local exact_lnum = nil
        local exact_distance = nil

        for index, line in ipairs(lines) do
            if normalized_line(line) == target then
                local distance = math.abs(index - old_lnum)

                if not exact_distance or distance < exact_distance then
                    exact_lnum = index
                    exact_distance = distance
                end
            end
        end

        if exact_lnum then
            return exact_lnum
        end

        local target_tokens = line_tokens(target)
        local target_count = table_size(target_tokens)

        if target_count > 0 then
            local best_lnum = nil
            local best_score = 0

            for index, line in ipairs(lines) do
                local tokens = line_tokens(line)
                local token_count = table_size(tokens)
                local shared = 0

                for token in pairs(target_tokens) do
                    if tokens[token] then
                        shared = shared + 1
                    end
                end

                local denominator = math.max(target_count, token_count)
                local score = denominator > 0 and shared / denominator or 0

                if score >= 0.4 and (score > best_score or (score == best_score and math.abs(index - old_lnum) < math.abs((best_lnum or old_lnum) - old_lnum))) then
                    best_lnum = index
                    best_score = score
                end
            end

            if best_lnum then
                return best_lnum
            end
        end
    end

    return old_lnum
end

--- Restore the cursor near the pre-reload location.
local function restore_after_reload(state, snapshot)
    if not util.valid_buf(state.bufnr) then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(state.bufnr, 0, -1, false)
    local lnum = best_reload_line(lines, snapshot)
    local line = lines[lnum] or ""
    local col = math.max(0, math.min(snapshot.col or 0, #line))
    local topline_delta = math.max(0, (snapshot.lnum or lnum) - (snapshot.topline or snapshot.lnum or lnum))
    local topline = math.max(1, lnum - topline_delta)
    local view = {
        lnum = lnum,
        col = col,
        topline = topline,
    }

    state.markdown_view = {
        source = state.source,
        view = view,
    }

    if util.valid_win(state.winid) and vim.api.nvim_win_get_buf(state.winid) == state.bufnr then
        pcall(vim.api.nvim_win_call, state.winid, function()
            vim.fn.winrestview(view)
        end)
    end
end

local function configured_interval_ms(state)
    local interval = tonumber(state.config.reload_interval_ms) or 1000

    return math.max(100, math.floor(interval))
end

local function configured_badge_ms(state)
    local timeout = tonumber(state.config.reload_badge_ms) or 0

    return math.max(0, math.floor(timeout))
end

local function configured_badge_min_display_ms(state)
    local badge = type(state.config.reload_badge) == "table" and state.config.reload_badge or {}
    local timeout = tonumber(badge.min_display_ms) or 0

    return math.max(0, math.floor(timeout))
end

--- Clear the temporary reload marker in the pane winbar.
function M.clear_reload_badge(state, deps)
    if not state.markdown_reloaded then
        return false
    end

    state.markdown_reloaded = false
    state.markdown_reload_badge_armed = false
    state.markdown_reload_token = (state.markdown_reload_token or 0) + 1
    deps.update_sticky_heading()

    return true
end

--- Show a temporary reloaded marker in the pane winbar.
local function mark_reloaded(state, deps)
    state.markdown_reloaded = true
    state.markdown_reload_badge_armed = false
    state.markdown_reload_token = (state.markdown_reload_token or 0) + 1

    local token = state.markdown_reload_token
    local badge_ms = configured_badge_ms(state)
    local min_display_ms = configured_badge_min_display_ms(state)

    deps.update_sticky_heading()
    vim.defer_fn(function()
        if state.markdown_reload_token == token then
            state.markdown_reload_badge_armed = true
        end
    end, min_display_ms)

    if badge_ms > 0 then
        vim.defer_fn(function()
            if state.markdown_reload_token == token then
                M.clear_reload_badge(state, deps)
            end
        end, badge_ms)
    end
end

--- Watch the current markdown source for filesystem changes.
local function start_reload_watcher(state, deps, path)
    if not uv or state.config.auto_reload == false then
        stop_reload_watcher(state)
        return
    end

    if state.markdown_watcher_path == path and state.markdown_reload_timer then
        return
    end

    stop_reload_watcher(state)

    state.markdown_watcher_path = path

    local function schedule_check()
        vim.schedule(function()
            if state.source ~= path or state.config.auto_reload == false then
                return
            end

            M.check_reload(state, deps)
        end)
    end

    if uv.new_timer then
        local timer = uv.new_timer()
        local interval = configured_interval_ms(state)

        if timer then
            local ok = timer:start(interval, interval, function()
                schedule_check()
            end)

            if ok == 0 then
                state.markdown_reload_timer = timer
                pcall(function()
                    timer:unref()
                end)
            else
                pcall(function()
                    timer:close()
                end)
            end
        end
    end
end

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
    state.markdown_file_signature = file_signature(path, lines)

    start_reload_watcher(state, deps, path)

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

--- Reload the current markdown file if its on-disk contents changed.
function M.check_reload(state, deps)
    if state.config.auto_reload == false or not state.source or state.source == "" then
        stop_reload_watcher(state)
        return false
    end

    if vim.fn.filereadable(state.source) ~= 1 then
        return false
    end

    local signature = file_signature(state.source)

    if not signature then
        return false
    end

    if not state.markdown_file_signature then
        state.markdown_file_signature = signature
        return false
    end

    if signature == state.markdown_file_signature then
        return false
    end

    local snapshot = reload_snapshot(state)

    if not M.load_file(state, deps, state.source) then
        return false
    end

    restore_after_reload(state, snapshot)
    mark_reloaded(state, deps)

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
    state.markdown_reloaded = false
    state.markdown_reload_badge_armed = false

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
    local reloaded = M.check_reload(state, deps)
    deps.update_sticky_heading()
    deps.render_markview(state.bufnr)
    if not reloaded then
        M.restore_view(state)
    end
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
