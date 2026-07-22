--[[
sidepanes.winbar
Purpose: Maintain the pane winbar title for markdown and terminal modes.
Does: Shows the active markdown heading or terminal identity, includes zoom state, truncates labels, and refreshes on movement/resize events.
Architecture: Bridges heading.lua formatting with shared pane state; init.lua installs its autocmd group through this module.
]]

local heading = require("sidepanes.heading")
local ask_pane = require("sidepanes.ask_pane")
local ask_session = require("sidepanes.ask_session")
local util = require("sidepanes.util")

local M = {}
local reload_badge_group = "SidepanesReloaded"
local resume_badge_group = "SidepanesResumed"
local reload_badge_key_ns = vim.api.nvim_create_namespace("SidepanesReloadBadgeKeys")

local function color_hex(value)
    if type(value) ~= "number" then
        return nil
    end

    return string.format("#%06x", value)
end

local function hex_color(value)
    if type(value) == "string" and value:match("^#%x%x%x%x%x%x$") then
        return value
    end

    return color_hex(value)
end

local function get_hl(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })

    if ok then
        return hl
    end

    ok, hl = pcall(vim.api.nvim_get_hl_by_name, name, true)

    if ok then
        return hl
    end

    return {}
end

local function hl_color(name, role)
    if type(name) ~= "string" then
        return nil
    end

    local group, explicit_role = name:match("^(.*)([Ff][Gg])$")

    if explicit_role then
        local hl = get_hl(group)
        return hl.fg
    end

    group, explicit_role = name:match("^(.*)([Bb][Gg])$")

    if explicit_role then
        local hl = get_hl(group)
        return hl.bg
    end

    local hl = get_hl(name)

    if role == "bg" then
        return hl.bg or hl.fg
    end

    return hl.fg or hl.bg
end

local function resolve_badge_color(value, role, fallback)
    return hex_color(value) or color_hex(hl_color(value, role)) or fallback
end

local function reload_badge_config(state)
    local config = state.config.reload_badge

    if type(config) ~= "table" then
        config = {}
    end

    local hl = type(config.hl) == "table" and config.hl or {}

    return config, hl
end

local function setup_reload_badge_hl(state)
    local _, hl = reload_badge_config(state)

    vim.api.nvim_set_hl(0, reload_badge_group, {
        fg = resolve_badge_color(hl.fg, "fg", "#1f1f1f"),
        bg = resolve_badge_color(hl.bg, "bg", "#f0c674"),
        bold = hl.bold ~= false,
    })
end

local function resume_badge_config(state)
    local config = state.config.agent_resume_badge

    if type(config) ~= "table" then
        config = {}
    end

    local hl = type(config.hl) == "table" and config.hl or {}

    return config, hl
end

local function setup_resume_badge_hl(state)
    local _, hl = resume_badge_config(state)

    vim.api.nvim_set_hl(0, resume_badge_group, {
        fg = resolve_badge_color(hl.fg, "fg", "#1f1f1f"),
        bg = resolve_badge_color(hl.bg, "bg", "#7aa2f7"),
        bold = hl.bold ~= false,
    })
end

local function should_clear_reload_badge(state)
    local badge = state.config.reload_badge

    if type(badge) == "table" and badge.clear_on_interaction == false then
        return false
    end

    return state.markdown_reloaded
        and state.markdown_reload_badge_armed ~= false
        and state.active_mode == "markdown"
        and util.valid_win(state.winid)
        and vim.api.nvim_get_current_win() == state.winid
        and vim.api.nvim_win_get_buf(state.winid) == state.bufnr
end

local function active_terminal_context(state)
    return state.active_terminal_key and state.terminals[state.active_terminal_key] or nil
end

local function should_clear_resume_badge(state)
    local badge = state.config.agent_resume_badge
    local ctx = active_terminal_context(state)

    if type(badge) == "table" and badge.clear_on_interaction == false then
        return false
    end

    return ctx
        and ctx.resume_badge_visible
        and ctx.resume_badge_armed ~= false
        and state.active_mode ~= "markdown"
        and util.valid_win(state.winid)
        and vim.api.nvim_get_current_win() == state.winid
        and vim.api.nvim_win_get_buf(state.winid) == ctx.bufnr
end

--- Build the winbar title for the active terminal pane.
local function terminal_title(state)
    local ctx = active_terminal_context(state)

    if not ctx then
        return "Pane"
    end

    return ctx.tool_label .. ": " .. ctx.preset_label .. " - " .. util.root_label(ctx.root)
end

local function ask_title(state)
    return ask_session.format_title(ask_pane.snapshot(state))
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

    if state.active_mode == "ask" then
        local max_width = math.max(10, vim.api.nvim_win_get_width(state.winid) - 4)
        local title = ask_title(state)

        if state.zoomed then
            title = title .. " [zoom]"
        end

        local label = heading.truncate_display(title, max_width)

        vim.api.nvim_set_option_value("winbar", "%#WinBar# " .. heading.statusline_escape(label) .. " %*", { win = state.winid })
        return
    end

    if state.active_mode ~= "markdown" then
        local max_width = math.max(10, vim.api.nvim_win_get_width(state.winid) - 4)
        local title = terminal_title(state)

        if state.zoomed then
            title = title .. " [zoom]"
        end

        local label = heading.truncate_display(title, max_width)
        local prefix = ""
        local ctx = active_terminal_context(state)

        if ctx and ctx.resume_badge_visible then
            local badge = resume_badge_config(state)
            local text = badge.text or "[RESUMED]"

            setup_resume_badge_hl(state)
            prefix = "%#" .. resume_badge_group .. "# " .. heading.statusline_escape(text) .. " %#WinBar#"
        end

        vim.api.nvim_set_option_value("winbar", prefix .. "%#WinBar# " .. heading.statusline_escape(label) .. " %*", { win = state.winid })
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
    local prefix = ""

    if state.markdown_reloaded then
        local badge = reload_badge_config(state)
        local text = badge.text or "[RELOADED]"

        setup_reload_badge_hl(state)
        prefix = "%#" .. reload_badge_group .. "# " .. heading.statusline_escape(text) .. " %#WinBar#"
    end

    vim.api.nvim_set_option_value("winbar", prefix .. "%#WinBar# " .. heading.statusline_escape(label) .. " %*", { win = state.winid })
end

--- Install autocmds that keep the sticky heading current.
function M.setup_autocmds(state, group, deps)
    vim.api.nvim_create_autocmd({ "WinScrolled", "WinResized", "BufWinEnter", "CursorMoved", "CursorMovedI" }, {
        group = group,
        callback = function()
            M.update(state)
        end,
    })

    if deps and (deps.clear_reload_badge or deps.clear_resume_badge) then
        vim.on_key(nil, reload_badge_key_ns)
        vim.on_key(function(key)
            if key == "" then
                return
            end

            vim.schedule(function()
                if deps.clear_reload_badge and should_clear_reload_badge(state) then
                    deps.clear_reload_badge()
                end

                if deps.clear_resume_badge and should_clear_resume_badge(state) then
                    deps.clear_resume_badge()
                end
            end)
        end, reload_badge_key_ns)
    end
end

return M
