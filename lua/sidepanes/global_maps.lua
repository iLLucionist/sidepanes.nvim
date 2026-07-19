--[[
sidepanes.global_maps
Purpose: Install optional global keymaps for the sidepanes public API.
Does: Binds configured normal and visual mode mappings for pane switching, asking, IPython sending, focus, and zoom actions.
Architecture: Complements pane-local maps.lua by handling user-configured global mappings through the facade table.
]]

local M = {}

--- Install one global keymap unless the configured lhs is disabled.
local function map(mode, lhs, rhs, desc)
    if not lhs then
        return
    end

    vim.keymap.set(mode, lhs, rhs, { desc = desc })
end

--- Build current-buffer options for normal-mode actions.
local function current_opts()
    return {
        bufnr = vim.api.nvim_get_current_buf(),
    }
end

--- Build visual-selection options for ask and send mappings.
local function visual_opts()
    return {
        bufnr = vim.api.nvim_get_current_buf(),
        visual = true,
        visual_mode = vim.fn.mode(1),
    }
end

--- Install configured global sidepanes keymaps.
function M.setup(api, mappings)
    if not mappings or mappings == false then
        return
    end

    map("n", mappings.toggle, function()
        api.toggle()
    end, "Toggle sidepanes")

    map("n", mappings.pick, function()
        api.pick()
    end, "Pick sidepanes document")

    map("n", mappings.headings, function()
        api.pick_headings()
    end, "Pick markdown heading")

    map("n", mappings.markdown, function()
        api.show_markdown()
    end, "Show markdown viewer")

    map("n", mappings.codex, function()
        api.open_terminal("codex", nil, vim.tbl_extend("force", current_opts(), { focus = true }))
    end, "Show Codex pane")

    map("n", mappings.claude, function()
        api.open_terminal("claude", nil, vim.tbl_extend("force", current_opts(), { focus = true }))
    end, "Show Claude pane")

    map("n", mappings.ipython, function()
        api.open_ipython(vim.tbl_extend("force", current_opts(), { focus = true }))
    end, "Show IPython pane")

    map("n", mappings.restart_ipython, function()
        api.restart_ipython(vim.tbl_extend("force", current_opts(), { focus = true }))
    end, "Restart IPython pane")

    map("n", mappings.send_ipython, function()
        api.send_ipython(vim.tbl_extend("force", current_opts(), {
            line1 = vim.fn.line("."),
            line2 = vim.fn.line("."),
        }))
    end, "Send line to IPython")

    map("x", mappings.send_ipython, function()
        api.send_ipython(visual_opts())
    end, "Send selection to IPython")

    map("n", mappings.clear_ipython, function()
        api.clear_ipython(current_opts())
    end, "Clear IPython pane")

    map("n", mappings.focus, function()
        api.focus_toggle()
    end, "Toggle sidepanes focus")

    map("n", mappings.zoom, function()
        api.toggle_zoom()
    end, "Toggle sidepanes zoom")

    map("n", mappings.width_previous, function()
        api.snap_width("previous")
    end, "Decrease sidepanes width to snap point")

    map("n", mappings.width_next, function()
        api.snap_width("next")
    end, "Increase sidepanes width to snap point")

    map("n", mappings.width_picker, function()
        api.width_picker()
    end, "Pick sidepanes width")

    map("n", mappings.sticky_relative_width, function()
        api.toggle_sticky_relative_width()
    end, "Toggle sidepanes sticky relative width")

    map("n", mappings.switch, function()
        api.switch_picker()
    end, "Switch sidepanes")

    map("x", mappings.ask, function()
        api.ask_picker(visual_opts())
    end, "Ask sidepanes target")

    map("x", mappings.ask_last, function()
        api.ask_last_coding_agent(visual_opts())
    end, "Ask last coding agent")

    map("x", mappings.ask_codex, function()
        api.ask_current_coding_agent("codex", visual_opts())
    end, "Ask current Codex pane")

    map("x", mappings.ask_claude, function()
        api.ask_current_coding_agent("claude", visual_opts())
    end, "Ask current Claude pane")
end

return M
