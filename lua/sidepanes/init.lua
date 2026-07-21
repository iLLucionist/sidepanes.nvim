--[[
sidepanes.init
Purpose: Expose the public API while keeping mutable pane state internal.
Does: Wires together viewer, window, render, switcher, terminal, question, commands, lifecycle, mappings, and picker modules.
Architecture: Uses an internal state table for focused submodules and returns a smaller facade for user config, commands, and mappings.
]]

-- =============================================================================
-- MODULE IMPORTS
-- =============================================================================


local defaults = require("sidepanes.defaults")
local agent_session = require("sidepanes.agent_session")
local api_helpers = require("sidepanes.api")
local commands = require("sidepanes.commands")
local context = require("sidepanes.context")
local document_picker = require("sidepanes.document_picker")
local entries = require("sidepanes.entries")
local global_maps = require("sidepanes.global_maps")
local heading = require("sidepanes.heading")
local heading_picker = require("sidepanes.heading_picker")
local lifecycle = require("sidepanes.lifecycle")
local maps = require("sidepanes.maps")
local picker = require("sidepanes.picker")
local question = require("sidepanes.question")
local render = require("sidepanes.render")
local switcher = require("sidepanes.switcher")
local terminal = require("sidepanes.terminal")
local util = require("sidepanes.util")
local pane_window = require("sidepanes.window")
local viewer = require("sidepanes.viewer")
local width = require("sidepanes.width")
local winbar = require("sidepanes.winbar")


-- =============================================================================
-- INTERNAL MODULE STATE
-- =============================================================================


local M = {
    winid = nil,
    bufnr = nil,
    source = nil,
    wrap_enabled = nil,
    relative_width = nil,
    active_mode = "markdown",
    active_terminal_key = nil,
    last_terminal_key = nil,
    last_coding_agent_terminal_key = nil,
    last_tool_terminal_keys = {},
    last_focus_win = nil,
    zoomed = false,
    markdown_view = nil,
    markdown_file_signature = nil,
    markdown_reloaded = false,
    markdown_reload_badge_armed = false,
    markdown_reload_token = 0,
    markdown_watcher_path = nil,
    markdown_reload_timer = nil,
    terminals = {},
    agent_sessions = {},
    question_buffers = {},
    config = vim.deepcopy(defaults.config),
}


-- =============================================================================
-- AUTOCMD GROUPS
-- =============================================================================


local sticky_heading_group = vim.api.nvim_create_augroup("SidepanesStickyHeading", { clear = true })
local focus_group = vim.api.nvim_create_augroup("SidepanesFocus", { clear = true })
local shutdown_group = vim.api.nvim_create_augroup("SidepanesShutdown", { clear = true })
local resize_group = vim.api.nvim_create_augroup("SidepanesResize", { clear = true })
local reload_group = vim.api.nvim_create_augroup("SidepanesReload", { clear = true })


-- =============================================================================
-- SHARED ALIASES
-- =============================================================================


local statusline_escape = heading.statusline_escape


-- =============================================================================
-- PICKER AND CONTEXT HELPERS
-- =============================================================================


--- Show a numbered/lettered picker and pass the selected entry to a callback.
local function numbered_select(prompt, entries, callback)
    picker.numbered_select(prompt, entries, callback, M)
end

--- Return whether a buffer belongs to the pane or one of its terminals.
local function is_pane_buf(bufnr)
    return context.is_pane_buf(M, bufnr)
end

--- Remember the most recent normal window outside the pane.
local function record_focus_win(winid)
    pane_window.record_focus_win(M, {
        is_pane_buf = is_pane_buf,
    }, winid)
end

--- Find the pane terminal context for a buffer.
local function terminal_context_for_buf(bufnr)
    return context.terminal_context_for_buf(M, bufnr)
end

--- Return whether a terminal context still has a live job and buffer.
local function terminal_is_running(ctx)
    return terminal.is_running(ctx)
end

--- Return whether a tool is one of the conversational coding agents.
local function is_coding_agent_tool(tool_name)
    return terminal.is_coding_agent_tool(tool_name)
end

--- Remember the latest active terminal and per-tool coding-agent terminal.
local function remember_terminal_context(ctx)
    terminal.remember_context(M, ctx)
end

--- Build a picker entry representing an already-running terminal context.
local function entry_for_terminal_context(ctx)
    return terminal.entry_for_context(M, ctx)
end

--- Find the best running terminal context for a tool and optional root.
local function terminal_context_for_tool(tool_name, root)
    return terminal.context_for_tool(M, tool_name, root)
end

--- Find the most recently used running Codex or Claude context.
local function last_coding_agent_context(root)
    return terminal.last_coding_agent_context(M, root)
end


-- =============================================================================
-- VIEWER STATE AND HEADING HELPERS
-- =============================================================================


--- Return the user-selected wrap state or configured wrap default.
local function preferred_wrap()
    return pane_window.preferred_wrap(M)
end

--- Compute the text reflow width available inside the pane.
local function pane_text_width(winid)
    return pane_window.text_width(M, winid)
end

--- Save the sidepanes cursor and scroll view for later restoration.
local function save_markdown_view()
    viewer.save_view(M)
end

--- Restore the saved markdown cursor and scroll view when possible.
local function restore_markdown_view()
    viewer.restore_view(M)
end

--- Refresh the pane winbar for markdown heading or terminal identity.
local function update_sticky_heading()
    winbar.update(M)
end

--- Clear the temporary markdown reload badge.
local function clear_markdown_reload_badge()
    viewer.clear_reload_badge(M, {
        update_sticky_heading = update_sticky_heading,
    })
end

--- Clear the temporary recovered/resumed agent badge.
local function clear_agent_resume_badge()
    terminal.clear_resume_badge(M, {
        update_sticky_heading = update_sticky_heading,
    })
end

--- Install autocmds that keep the sticky heading current.
local function setup_sticky_heading_autocmds()
    winbar.setup_autocmds(M, sticky_heading_group, {
        clear_reload_badge = clear_markdown_reload_badge,
        clear_resume_badge = clear_agent_resume_badge,
    })
end

--- Create or return the markdown viewer buffer.
local function ensure_buf()
    return viewer.ensure_buf(M)
end


-- =============================================================================
-- FORWARD DECLARATIONS FOR MUTUALLY-DEPENDENT MODULE CALLBACKS
-- =============================================================================


local render_markview
local setup_pane_maps
local window_deps
local viewer_deps
local render_deps
local switcher_deps

--- Reload the markdown viewer if its source file changed on disk.
local function check_markdown_reload()
    viewer.check_reload(M, viewer_deps())
end


-- =============================================================================
-- WINDOW, RENDER, AND ROOT HELPERS
-- =============================================================================


--- Apply pane-local window options for markdown or terminal mode.
local function set_window_options(winid, mode)
    pane_window.set_options(M, window_deps(), winid, mode)
end

--- Re-render markview decorations for a markdown buffer.
render_markview = function(bufnr)
    render.markview(bufnr)
end

--- Reflow the sidepanes buffer using configured internal or external formatting.
local function reflow_pane_buffer(bufnr, opts)
    render.reflow_buffer(M, render_deps(), bufnr, opts)
end

--- Resolve the project root associated with a pane buffer.
local function pane_root(bufnr)
    return context.pane_root(M, bufnr)
end


-- =============================================================================
-- PANE-LOCAL KEYMAPS
-- =============================================================================


--- Install pane-local mappings on a markdown or terminal pane buffer.
setup_pane_maps = function(bufnr)
    maps.setup(bufnr, {
        ask_current_coding_agent = M.ask_current_coding_agent,
        ask_last_coding_agent = M.ask_last_coding_agent,
        markdown_bufnr = function()
            return M.bufnr
        end,
        open_terminal = M.open_terminal,
        pane_mappings = function()
            return M.config.mappings and M.config.mappings.pane
        end,
        pane_root = pane_root,
        send_ipython = M.send_ipython,
        show_markdown = M.show_markdown,
        toggle_markdown_terminal = M.toggle_markdown_terminal,
        toggle_markdown_agent = M.toggle_markdown_terminal,
        toggle_zoom = M.toggle_zoom,
        toggle_wrap = M.toggle_wrap,
        wrap_toggle_key = function()
            return M.config.wrap_toggle_key
        end,
    })
end


-- =============================================================================
-- DEPENDENCY FACTORIES
-- =============================================================================


--- Build window module callbacks that still belong to pane/viewer state.
window_deps = function()
    return {
        ensure_buf = ensure_buf,
        is_pane_buf = is_pane_buf,
        open_markdown = M.open,
        reflow_pane_buffer = reflow_pane_buffer,
        render_markview = render_markview,
        restore_markdown_view = restore_markdown_view,
        save_markdown_view = save_markdown_view,
        update_sticky_heading = update_sticky_heading,
    }
end

--- Create or reuse the side pane window for a buffer and mode.
local function ensure_win(bufnr, mode, opts)
    return pane_window.ensure(M, window_deps(), bufnr, mode, opts)
end

--- Build render module callbacks that still belong to pane/window state.
render_deps = function()
    return {
        preferred_wrap = preferred_wrap,
        set_window_options = set_window_options,
        text_width = pane_text_width,
    }
end


-- =============================================================================
-- VIEWER DEPENDENCY FACTORY AND WRAP API
-- =============================================================================


--- Toggle wrapping in the markdown viewer pane.
function M.toggle_wrap()
    render.toggle_wrap(M, render_deps())
end

--- Build viewer module callbacks that still belong to pane/window/render state.
viewer_deps = function()
    return {
        close_pane = M.close,
        ensure_win = ensure_win,
        pick = M.pick,
        reflow_pane_buffer = reflow_pane_buffer,
        remember_terminal_context = remember_terminal_context,
        render_markview = render_markview,
        set_window_options = set_window_options,
        setup_pane_maps = setup_pane_maps,
        update_sticky_heading = update_sticky_heading,
    }
end


-- =============================================================================
-- MARKDOWN VIEWER AND PANE WINDOW API
-- =============================================================================


--- Open a markdown file in the pane without stealing focus.
function M.open(path)
    viewer.open(M, viewer_deps(), path)
end

--- Switch the pane back to the markdown viewer.
function M.show_markdown()
    viewer.show_markdown(M, viewer_deps())
end

--- Close the pane window while preserving buffers and state.
function M.close()
    pane_window.close(M, window_deps())
end

--- Toggle the pane, optionally opening a specific markdown file.
function M.toggle(path)
    viewer.toggle(M, viewer_deps(), path)
end

--- Return whether the pane window is currently open.
function M.is_open()
    return pane_window.is_open(M)
end

--- Toggle focus between the pane and the last normal window.
function M.focus_toggle()
    pane_window.focus_toggle(M, window_deps())
end

--- Toggle the pane between normal width and zoom width.
function M.toggle_zoom()
    pane_window.toggle_zoom(M, window_deps())
end

--- Return the current text width used for markdown reflow.
function M.text_width()
    return pane_text_width()
end

--- Build width module callbacks that still belong to pane/window/render state.
local function width_deps()
    return {
        numbered_select = numbered_select,
        reflow_pane_buffer = reflow_pane_buffer,
        render_markview = render_markview,
        restore_markdown_view = restore_markdown_view,
        save_markdown_view = save_markdown_view,
        set_window_options = set_window_options,
        update_sticky_heading = update_sticky_heading,
    }
end

--- Return the effective normal pane width in columns.
function M.get_width()
    return width.get(M)
end

--- Set the normal pane width from columns, a percentage, or a screen fraction.
function M.set_width(value)
    return width.set(M, width_deps(), value)
end

--- Adjust the normal pane width by a column delta.
function M.adjust_width(delta)
    return width.adjust(M, width_deps(), delta)
end

--- Move the normal pane width to the next or previous configured snap point.
function M.snap_width(direction)
    return width.snap(M, width_deps(), direction)
end

--- Show a picker for common pane width snap points.
function M.width_picker()
    return width.picker(M, width_deps())
end

--- Toggle whether relative pane widths stay tied to total Neovim columns.
function M.toggle_sticky_relative_width(enabled)
    return width.toggle_sticky_relative(M, enabled)
end

--- Recompute sticky relative width after Neovim columns change.
function M.refresh_width()
    return width.refresh(M, width_deps())
end


-- =============================================================================
-- SETUP AND LIFECYCLE API
-- =============================================================================


--- Merge user configuration and install pane autocmds.
function M.setup(opts)
    lifecycle.setup(M, {
        focus = focus_group,
        resize = resize_group,
        shutdown = shutdown_group,
        reload = reload_group,
    }, {
        check_markdown_reload = check_markdown_reload,
        record_focus_win = record_focus_win,
        refresh_width = M.refresh_width,
        shutdown_terminals = M.shutdown_terminals,
    }, opts)
    agent_session.load_store(M)
    commands.setup(M, M.config.commands)
    global_maps.setup(M, M.config.mappings and M.config.mappings.global)
end


-- =============================================================================
-- TERMINAL ENTRY AND SELECTION HELPERS
-- =============================================================================


--- Resolve a configured preset by name, label, or default position.
local function preset_by_name(tool, preset_name)
    return entries.preset_by_name(tool, preset_name)
end

--- Build quick picker entries for Codex, Claude, and optionally IPython.
local function tool_shortcut_entries(root, opts)
    return entries.tool_shortcut_entries(M, root, opts)
end

--- Build numbered picker entries for configured terminal presets.
local function terminal_entries(root, start_index, opts)
    return entries.terminal_entries(M, root, start_index, opts)
end

--- Capture text, file, root, and snippet language for a send/ask action.
local function selection_context(opts)
    return context.selection_context(M, opts)
end


-- =============================================================================
-- TERMINAL DEPENDENCY FACTORY
-- =============================================================================


--- Build terminal module callbacks that still belong to pane/window state.
local function terminal_deps()
    return {
        ensure_win = ensure_win,
        pane_root = pane_root,
        save_markdown_view = save_markdown_view,
        selection_context = selection_context,
        setup_pane_maps = setup_pane_maps,
        update_sticky_heading = update_sticky_heading,
    }
end


-- =============================================================================
-- PANE TERMINAL API
-- =============================================================================


--- Open or focus a pane terminal, reusing an existing session when possible.
function M.open_terminal(tool_name, preset_name, opts)
    return terminal.open(M, terminal_deps(), tool_name, preset_name, opts)
end

--- Show the most recently used pane terminal, falling back to Codex.
function M.show_last_terminal(opts)
    terminal.show_last_terminal(M, terminal_deps(), opts)
end

--- Compatibility alias for show_last_terminal().
M.show_last_agent = M.show_last_terminal


-- =============================================================================
-- PANE SWITCHER API
-- =============================================================================


--- Build switcher module callbacks that still belong to pane state.
switcher_deps = function()
    return {
        numbered_select = numbered_select,
        open_terminal = M.open_terminal,
        pane_root = pane_root,
        show_last_terminal = M.show_last_terminal,
        show_markdown = M.show_markdown,
        terminal_context_for_buf = terminal_context_for_buf,
        terminal_entries = terminal_entries,
        tool_shortcut_entries = tool_shortcut_entries,
    }
end

--- Toggle between the markdown viewer and the last remembered pane terminal.
function M.toggle_markdown_terminal()
    switcher.toggle_markdown_terminal(M, switcher_deps())
end

--- Compatibility alias for toggle_markdown_terminal().
M.toggle_markdown_agent = M.toggle_markdown_terminal

--- Switch the pane using a raw internal switcher entry.
function M.switch(entry)
    return switcher.switch(M, switcher_deps(), entry)
end

--- Build a validated switch entry from a public string or table target.
---
--- Examples:
---   make_switch_entry("markdown")
---   make_switch_entry("codex")
---   make_switch_entry("x")
---   make_switch_entry({ tool = "codex", preset = "gpt55_high_fast", root = vim.fn.getcwd(), focus = true })
---
--- The returned entry is normalized for Sidepanes' current switcher internals.
--- Prefer switch_to() when you only need to switch immediately.
function M.make_switch_entry(target, opts)
    local entry, err = api_helpers.make_switch_entry(M, target, opts)

    if not entry then
        vim.notify(err, vim.log.levels.ERROR)
        return nil
    end

    return entry
end

--- Switch the pane using a stable public target shape.
---
--- Accepts strings like "markdown", "codex", "claude", "ipython", "0", "x", "c", and "i",
--- or a table with fields such as tool, preset, root, bufnr, and focus.
function M.switch_to(target, opts)
    local entry = M.make_switch_entry(target, opts)

    if not entry then
        return nil
    end

    return switcher.switch(M, switcher_deps(), entry)
end

--- Show the pane switcher picker.
function M.switch_picker()
    switcher.switch_picker(M, switcher_deps())
end


-- =============================================================================
-- TERMINAL SEND, IPYTHON, AND SHUTDOWN API
-- =============================================================================


--- Send an ask prompt, switching model first when needed.
local function send_prompt_to_terminal(ctx, entry, prompt, started)
    terminal.send_prompt(M, ctx, entry, prompt, started)
end

--- Open or focus the IPython pane terminal.
function M.open_ipython(opts)
    return terminal.open_ipython(M, terminal_deps(), opts)
end

--- Send the current line or selection to IPython.
function M.send_ipython(opts)
    terminal.send_ipython(M, terminal_deps(), opts)
end

--- Clear the running IPython terminal screen.
function M.clear_ipython(opts)
    terminal.clear_ipython(M, terminal_deps(), opts)
end

--- Restart the IPython pane terminal for the current root.
function M.restart_ipython(opts)
    return terminal.restart_ipython(M, terminal_deps(), opts)
end

--- Shut down all pane-owned terminal sessions.
function M.shutdown_terminals(opts)
    terminal.shutdown_terminals(M, opts)
end


-- =============================================================================
-- ASK PROMPT EDITOR API
-- =============================================================================


--- Build question-editor callbacks that still belong to pane/window state.
local function question_deps()
    return {
        entry_for_terminal_context = entry_for_terminal_context,
        is_coding_agent_tool = is_coding_agent_tool,
        last_coding_agent_context = last_coding_agent_context,
        numbered_select = numbered_select,
        open_terminal = M.open_terminal,
        preset_by_name = preset_by_name,
        selection_context = selection_context,
        send_prompt_to_terminal = send_prompt_to_terminal,
        set_window_options = set_window_options,
        statusline_escape = statusline_escape,
        terminal_context_for_tool = terminal_context_for_tool,
        terminal_entries = terminal_entries,
        tool_shortcut_entries = tool_shortcut_entries,
        update_sticky_heading = update_sticky_heading,
    }
end

--- Cancel and close a question editor buffer.
function M.cancel_question(bufnr)
    question.cancel(M, bufnr)
end

--- Finish a question editor, sending only after a write.
function M.finish_question(bufnr)
    question.finish(M, bufnr)
end

--- Mark a question editor as written and update its cached prompt.
function M.write_question(bufnr)
    question.write(M, bufnr)
end

--- Open the target picker from inside a question editor.
function M.change_question_target(bufnr)
    question.change_target(M, bufnr)
end

--- Ask a specific internal picker entry using a captured or fresh context.
function M.ask_with_entry(entry, opts)
    question.ask_with_entry(M, question_deps(), entry, opts)
end

--- Capture selection and ask via the target picker.
function M.ask_picker(opts)
    question.ask_picker(M, question_deps(), opts)
end

--- Ask the most recently used Codex or Claude terminal.
function M.ask_last_coding_agent(opts)
    question.ask_last_coding_agent(M, question_deps(), opts)
end

--- Ask the current/default terminal for a specific coding agent.
function M.ask_current_coding_agent(tool_name, opts)
    question.ask_current_coding_agent(M, question_deps(), tool_name, opts)
end

--- Ask a specific tool and optional preset.
function M.ask(tool_name, preset_name, opts)
    question.ask(M, question_deps(), tool_name, preset_name, opts)
end


-- =============================================================================
-- DOCUMENT PICKER API
-- =============================================================================


--- Pick a markdown document and open it in the pane.
function M.pick()
    document_picker.pick(function(path)
        M.open(path)

        if M.config.focus_on_pick and util.valid_win(M.winid) then
            local previous = vim.api.nvim_get_current_win()

            if previous ~= M.winid and util.valid_win(previous) then
                M.last_focus_win = previous
            end

            vim.api.nvim_set_current_win(M.winid)
        end
    end)
end

--- Pick a markdown heading in the current buffer or Sidepanes viewer.
function M.pick_headings()
    heading_picker.pick(M)
end


-- =============================================================================
-- MODULE BOOTSTRAP
-- =============================================================================


setup_sticky_heading_autocmds()

-- =============================================================================
-- PUBLIC FACADE
-- =============================================================================


local public = {}

local public_functions = {
    "setup",
    "open",
    "show_markdown",
    "close",
    "toggle",
    "is_open",
    "focus_toggle",
    "toggle_zoom",
    "get_width",
    "set_width",
    "adjust_width",
    "snap_width",
    "width_picker",
    "toggle_sticky_relative_width",
    "text_width",
    "toggle_wrap",
    "open_terminal",
    "show_last_terminal",
    "toggle_markdown_terminal",
    "show_last_agent",
    "toggle_markdown_agent",
    "switch_to",
    "make_switch_entry",
    "switch_picker",
    "open_ipython",
    "send_ipython",
    "clear_ipython",
    "restart_ipython",
    "shutdown_terminals",
    "ask_picker",
    "ask_last_coding_agent",
    "ask_current_coding_agent",
    "ask",
    "pick",
    "pick_headings",
}

for _, name in ipairs(public_functions) do
    public[name] = function(...)
        return M[name](...)
    end
end

--- Return a defensive copy of the normalized runtime config.
function public.get_config()
    return vim.deepcopy(M.config)
end

--- Return internal mutable state for companion modules and tests.
function public._state()
    return M
end

return public
