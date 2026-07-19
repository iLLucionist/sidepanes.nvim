--[[
sidepanes.maps
Purpose: Install pane-local keymaps for markdown and terminal pane buffers.
Does: Binds quick pane switching, built-in smart gf, ask mappings, and markdown wrap toggling with buffer-local scope.
Architecture: Receives behavior through dependency callbacks from the facade so mappings stay declarative and do not own plugin state.
]]

local M = {}
local smart_gf = require("sidepanes.smart_gf")

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

--- Install pane-local normal and visual mappings for one pane buffer.
function M.setup(bufnr, deps)
    deps = deps or {}
    local mappings = pane_mappings(deps)

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

    map(bufnr, "n", mappings.toggle_agent, function()
        deps.toggle_markdown_agent()
    end, "Toggle markdown/agent pane")

    map(bufnr, "n", mappings.toggle_agent_alt, function()
        deps.toggle_markdown_agent()
    end, "Toggle markdown/agent pane")

    map(bufnr, "n", mappings.ipython_alt, function()
        deps.open_terminal("ipython", nil, { root = deps.pane_root(bufnr), focus = true })
    end, "Show IPython pane")

    map(bufnr, "n", mappings.gf, function()
        smart_gf.open()
    end, "Smart go to file from pane")

    map(bufnr, "x", mappings.send_ipython, function()
        deps.send_ipython(visual_opts(bufnr))
    end, "Send selection to IPython")

    map(bufnr, "n", mappings.zoom, function()
        deps.toggle_zoom()
    end, "Toggle sidepanes zoom", { nowait = true })

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
end

return M
