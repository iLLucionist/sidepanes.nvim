--[[
sidepanes.maps
Purpose: Install pane-local keymaps for markdown and terminal pane buffers.
Does: Binds quick pane switching, built-in smart gf, ask mappings, and markdown wrap toggling with buffer-local scope.
Architecture: Receives behavior through dependency callbacks from the facade so mappings stay declarative and do not own plugin state.
]]

local M = {}
local smart_gf = require("sidepanes.smart_gf")
local ask_policy = require("sidepanes.ask_policy")
local ask_cmdline = require("sidepanes.ask_cmdline")
local CMDLINE_ENTER_DESC = "Sidepanes pane command-line enter"
local pane_buffers = {}
local cmdline_enter_installed = false

local function global_normal_map(lhs)
    if not lhs then
        return nil
    end

    for _, item in ipairs(vim.api.nvim_get_keymap("n")) do
        if item.lhs == lhs then
            return item
        end
    end

    return nil
end

local function install_commandline_enter(deps)
    local current = vim.fn.maparg("<CR>", "c", false, true)

    if type(current) == "table" and current.desc == "Sidepanes ask pane command-line enter" then
        return
    end

    if cmdline_enter_installed and type(current) == "table" and current.desc == CMDLINE_ENTER_DESC then
        return
    end

    cmdline_enter_installed = true

    vim.keymap.set("c", "<CR>", function()
        if vim.fn.getcmdtype() ~= ":" then
            return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local ask_bufnr = deps.ask_bufnr and deps.ask_bufnr()

        if pane_buffers[bufnr] and bufnr ~= ask_bufnr and ask_policy.is_plain_quit_command(vim.trim(vim.fn.getcmdline())) then
            return vim.api.nvim_replace_termcodes(ask_cmdline.markdown_return_command(), true, false, true)
        end

        return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
    end, {
        expr = true,
        silent = true,
        desc = CMDLINE_ENTER_DESC,
    })
end

--- Install one buffer-local pane mapping.
local function map(bufnr, mode, lhs, rhs, desc, opts)
    if not lhs then
        return
    end

    opts = opts or {}

    vim.keymap.set(mode, lhs, rhs, {
        buffer = bufnr,
        desc = desc,
        silent = true,
        nowait = opts.nowait,
    })
end

--- Build visual-selection options for pane ask mappings.
local function visual_opts(bufnr)
    return {
        bufnr = bufnr,
        visual = true,
        visual_mode = vim.fn.mode(1),
    }
end

--- Return pane-local mapping config, falling back to an empty table.
local function pane_mappings(deps)
    if not deps.pane_mappings then
        return {}
    end

    return deps.pane_mappings() or {}
end

--- Prefer terminal-named mappings while keeping old agent-named keys working.
local function mapping(mappings, preferred, legacy)
    if mappings[preferred] ~= nil then
        return mappings[preferred]
    end

    return mappings[legacy]
end

--- Toggle between Markdown and terminal through either old or new deps.
local function toggle_markdown_terminal(deps)
    local toggle = deps.toggle_markdown_terminal or deps.toggle_markdown_agent

    if toggle then
        toggle()
    end
end

--- Install terminal-mode toggle mappings that are safe to use while typing in a terminal.
local function setup_terminal_maps(bufnr, deps, mappings)
    if bufnr == deps.markdown_bufnr() then
        return
    end

    map(bufnr, "t", mapping(mappings, "toggle_terminal", "toggle_agent"), function()
        toggle_markdown_terminal(deps)
    end, "Toggle markdown/terminal pane", { nowait = true })

    map(bufnr, "t", mapping(mappings, "toggle_terminal_alt", "toggle_agent_alt"), function()
        toggle_markdown_terminal(deps)
    end, "Toggle markdown/terminal pane", { nowait = true })
end

local function setup_plain_quit_shadows(bufnr, deps, mappings, is_ask)
    if is_ask then
        return
    end

    local seen = {}

    for _, lhs in ipairs({ mappings.ask_send, mappings.ask_send_alt }) do
        for _, candidate in ipairs(lhs and ask_policy.lhs_candidates(lhs, {
            leader = vim.g.mapleader or "\\",
            localleader = vim.g.maplocalleader or "\\",
        }) or {}) do
            if not seen[candidate] then
                seen[candidate] = true

                local existing = global_normal_map(candidate)

                if existing and ask_policy.is_plain_quit_rhs(existing.rhs) then
                    map(bufnr, "n", candidate, function()
                        deps.show_markdown()
                    end, "Return Sidepanes pane to Markdown", { nowait = true })
                end
            end
        end
    end
end

--- Install pane-local normal and visual mappings for one pane buffer.
function M.setup(bufnr, deps)
    deps = deps or {}
    pane_buffers[bufnr] = true
    install_commandline_enter(deps)

    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = bufnr,
        callback = function()
            pane_buffers[bufnr] = nil
        end,
    })

    local mappings = pane_mappings(deps)
    local is_ask = deps.ask_bufnr and bufnr == deps.ask_bufnr()

    map(bufnr, "n", mappings.markdown, function()
        deps.show_markdown()
    end, "Show sidepanes", { nowait = true })

    map(bufnr, "n", mappings.codex, function()
        deps.open_terminal("codex", nil, { root = deps.pane_root(bufnr), focus = true })
    end, "Show Codex pane", { nowait = true })

    map(bufnr, "n", mappings.claude, function()
        deps.open_terminal("claude", nil, { root = deps.pane_root(bufnr), focus = true })
    end, "Show Claude pane", { nowait = true })

    map(bufnr, "n", mappings.ipython, function()
        deps.open_terminal("ipython", nil, { root = deps.pane_root(bufnr), focus = true })
    end, "Show IPython pane", { nowait = true })

    map(bufnr, "n", mapping(mappings, "toggle_terminal", "toggle_agent"), function()
        toggle_markdown_terminal(deps)
    end, "Toggle markdown/terminal pane")

    map(bufnr, "n", mapping(mappings, "toggle_terminal_alt", "toggle_agent_alt"), function()
        toggle_markdown_terminal(deps)
    end, "Toggle markdown/terminal pane")

    map(bufnr, "n", mappings.ipython_alt, function()
        deps.open_terminal("ipython", nil, { root = deps.pane_root(bufnr), focus = true })
    end, "Show IPython pane")

    if bufnr == deps.markdown_bufnr() and deps.pick_headings then
        map(bufnr, "n", mappings.headings, function()
            deps.pick_headings()
        end, "Pick Markdown heading")
    end

    if is_ask then
        map(bufnr, "n", mapping(mappings, "ask_source", "gf"), function()
            deps.ask_source_jump()
        end, "Open ask citation source")
    else
        map(bufnr, "n", mappings.gf, function()
            smart_gf.open()
        end, "Smart go to file from pane")
    end

    map(bufnr, "x", mappings.send_ipython, function()
        deps.send_ipython(visual_opts(bufnr))
    end, "Send selection to IPython")

    map(bufnr, "n", mappings.zoom, function()
        deps.toggle_zoom()
    end, "Toggle sidepanes zoom", { nowait = true })

    map(bufnr, "n", mappings.ask_pane, function()
        deps.show_ask_pane({ focus = true })
    end, "Show ask pane", { nowait = true })

    if is_ask then
        map(bufnr, "n", mappings.ask_next_file, function()
            deps.ask_jump_header("file", "next")
        end, "Next ask file")

        map(bufnr, "n", mappings.ask_previous_file, function()
            deps.ask_jump_header("file", "previous")
        end, "Previous ask file")

        map(bufnr, "n", mappings.ask_next_selection, function()
            deps.ask_jump_header("selection", "next")
        end, "Next ask selection")

        map(bufnr, "n", mappings.ask_previous_selection, function()
            deps.ask_jump_header("selection", "previous")
        end, "Previous ask selection")
    end

    map(bufnr, "x", mappings.ask_last, function()
        deps.ask_last_coding_agent(visual_opts(bufnr))
    end, "Ask last coding agent")

    map(bufnr, "x", mappings.ask_codex, function()
        deps.ask_current_coding_agent("codex", visual_opts(bufnr))
    end, "Ask current Codex pane")

    map(bufnr, "x", mappings.ask_claude, function()
        deps.ask_current_coding_agent("claude", visual_opts(bufnr))
    end, "Ask current Claude pane")

    if bufnr == deps.markdown_bufnr() then
        map(bufnr, "n", deps.wrap_toggle_key(), function()
            deps.toggle_wrap()
        end, "Toggle sidepanes wrap")
    end

    setup_terminal_maps(bufnr, deps, mappings)
    setup_plain_quit_shadows(bufnr, deps, mappings, is_ask)
end

return M
