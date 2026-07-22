--[[
sidepanes_audit_smoke
Purpose: Exercise the standalone Sidepanes setup surface.
Does: Verifies configured commands, forbidden legacy commands, global mappings, presets, module boundaries, and health output.
Architecture: Complements the focused regression suite with a plugin-facing smoke test that catches wiring regressions.
]]

local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local plugin_root = helpers.append_repo_root(1)

local sidepanes = require("sidepanes")
local markdown_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" }

sidepanes.setup({
    layout = {
        width = 100,
        zoom_text_width = 90,
        sticky_relative_width = false,
        width_snap_points = { 60, 70, 80, 90, 100, 110, 120, "1/3", "40%", "1/2", "60%", "2/3", "75%" },
        width_picker_points = { "1/4", "1/3", "2/5", "1/2", "60%", "2/3", "75%", 100, 120 },
    },
    markdown = {
        wrap = false,
        wrap_toggle_key = "<leader>mw",
        sticky_heading = true,
        reflow = {
            enabled = true,
            cmd = markdown_reflow_cmd,
            fallback = true,
            protect_tables = true,
            margin = 8,
        },
    },
    lifecycle = {
        focus_on_switch = true,
        focus_on_ask = true,
        shutdown_on_exit = true,
        shutdown_timeout_ms = 300,
    },
    validation = {
        enabled = true,
    },
    commands = true,
    mappings = {
        global = {
            toggle = "<leader>pp",
            pick = "<leader>mP",
            headings = "<leader>fm",
            markdown = "<leader>p0",
            codex = "<leader>px",
            claude = "<leader>pc",
            ipython = "<leader>pi",
            restart_ipython = "<leader>pR",
            send_ipython = "<leader>pl",
            clear_ipython = "<leader>pX",
            focus = "<leader>pf",
            zoom = "<leader>pz",
            width_previous = "<leader>p-",
            width_next = "<leader>p+",
            width_picker = "<leader>pw",
            sticky_relative_width = "<leader>p%",
            switch = "<leader>ps",
            ask_pane = "<leader>pa",
            ask = "<leader>pa",
            ask_last = "aa",
            ask_codex = "ax",
            ask_claude = "ac",
        },
    },
    tools = {
        codex = { cmd = "sh" },
        claude = { cmd = "sh" },
        ipython = { cmd = "sh" },
    },
})

require("sidepanes.markdown_reflow").setup({
    external_reflow_cmd = markdown_reflow_cmd,
    external_reflow_protect_tables = true,
    commands = true,
    mappings = {
        reflow = "<leader>mR",
    },
})

local function assert_command(name)
    assert(vim.api.nvim_get_commands({})[name], "missing command: " .. name)
end

local function assert_no_command(name)
    assert(not vim.api.nvim_get_commands({})[name], "unexpected command: " .. name)
end

local function assert_global_map(mode, lhs)
    local map = vim.fn.maparg(lhs, mode, false, true)

    assert(map and map.lhs and map.lhs ~= "", "missing global map " .. lhs .. " in " .. mode)
    assert(map.callback, "global map has no callback " .. lhs .. " in " .. mode)
end

local function assert_module_comment(path)
    local name = vim.fn.fnamemodify(path, ":t:r")
    local lines = vim.fn.readfile(path, "", 8)
    local header = table.concat(lines, "\n")

    assert(lines[1] == "--[[", "missing top-level block comment: " .. path)
    assert(header:find("sidepanes%." .. name), "module comment does not name module: " .. path)
    assert(header:find("Purpose:"), "module comment missing Purpose: " .. path)
    assert(header:find("Does:"), "module comment missing Does: " .. path)
    assert(header:find("Architecture:"), "module comment missing Architecture: " .. path)
end

local function capture_health(fn)
    local original = vim.health
    local reports = {}

    vim.health = {
        start = function(message)
            table.insert(reports, { level = "start", message = message })
        end,
        ok = function(message)
            table.insert(reports, { level = "ok", message = message })
        end,
        warn = function(message)
            table.insert(reports, { level = "warn", message = message })
        end,
        error = function(message)
            table.insert(reports, { level = "error", message = message })
        end,
        info = function(message)
            table.insert(reports, { level = "info", message = message })
        end,
    }

    local ok, err = pcall(fn, reports)

    vim.health = original

    if not ok then
        error(err)
    end

    return reports
end

local function has_report(reports, level, needle)
    for _, report in ipairs(reports) do
        if report.level == level and report.message:find(needle, 1, true) then
            return true
        end
    end

    return false
end

local expected_commands = {
    "Sidepanes",
    "SidepanesToggle",
    "SidepanesPick",
    "SidepanesHeadings",
    "SidepanesSwitch",
    "SidepanesTool",
    "SidepanesCodex",
    "SidepanesClaude",
    "SidepanesIPython",
    "SidepanesIPythonRestart",
    "SidepanesIPythonClear",
    "SidepanesFocus",
    "SidepanesZoom",
    "SidepanesWidth",
    "SidepanesWidthPick",
    "SidepanesAsk",
    "SidepanesAskAppend",
    "SidepanesAskStatus",
    "SidepanesSubmitQuestion",
    "SidepanesAskCodex",
    "SidepanesAskClaude",
    "MarkdownReflow",
}

local forbidden_commands = {
    "PaneSwitch",
    "PaneTool",
    "PaneCodex",
    "PaneClaude",
    "PaneIPython",
    "PaneIPythonRestart",
    "PaneIPythonClear",
    "PaneFocus",
    "PaneZoom",
    "PaneAsk",
    "PaneAskAppend",
    "PaneAskCodex",
    "PaneAskClaude",
}

local expected_maps = {
    { "n", "<leader>fm" },
    { "n", "<leader>mR" },
    { "n", "<leader>pp" },
    { "n", "<leader>mP" },
    { "n", "<leader>p0" },
    { "n", "<leader>px" },
    { "n", "<leader>pc" },
    { "n", "<leader>pi" },
    { "n", "<leader>pR" },
    { "n", "<leader>pl" },
    { "x", "<leader>pl" },
    { "n", "<leader>pX" },
    { "n", "<leader>pf" },
    { "n", "<leader>pz" },
    { "n", "<leader>p-" },
    { "n", "<leader>p+" },
    { "n", "<leader>pw" },
    { "n", "<leader>p%" },
    { "n", "<leader>ps" },
    { "n", "<leader>pa" },
    { "x", "<leader>pa" },
    { "x", "aa" },
    { "x", "ax" },
    { "x", "ac" },
}

for _, name in ipairs(expected_commands) do
    assert_command(name)
end

for _, name in ipairs(forbidden_commands) do
    assert_no_command(name)
end

for _, item in ipairs(expected_maps) do
    assert_global_map(item[1], item[2])
end

for _, path in ipairs(vim.fn.globpath(plugin_root .. "/lua/sidepanes", "*.lua", false, true)) do
    assert_module_comment(path)

    local source = table.concat(vim.fn.readfile(path), "\n")

    assert(
        not source:find('require%("markdown_reflow"%)'),
        "sidepanes runtime module should not require legacy markdown_reflow shim: " .. path
    )
end

local pane_config = sidepanes.get_config()

assert(pane_config.width == 100, "configured pane width changed")
assert(pane_config.zoom_text_width == 90, "configured zoom text width changed")
assert(pane_config.sticky_relative_width == false, "configured sticky relative width changed")
assert(pane_config.width_snap_points[1] == 60 and pane_config.width_snap_points[#pane_config.width_snap_points] == "75%", "configured width snap points changed")
assert(pane_config.width_picker_points[1] == "1/4" and pane_config.width_picker_points[#pane_config.width_picker_points] == 120, "configured width picker points changed")
assert(pane_config.external_reflow_cmd[1] == "mdfmt", "configured external reflow command changed")
assert(#pane_config.tools.codex.presets == 12, "configured Codex preset count changed")
assert(pane_config.tools.codex.presets[1].name == "gpt55_high_fast", "configured Codex default changed")
assert(#pane_config.tools.claude.presets == 5, "configured Claude preset count changed")
assert(pane_config.tools.claude.presets[1].name == "sonnet", "configured Claude default changed")
assert(pane_config.tools.ipython.exit_command == "quit()\r", "configured IPython exit command changed")
assert(pane_config.ask.ui == "float", "configured ask UI default changed")

local reports = capture_health(function()
    require("sidepanes.health").check({ config = pane_config })
end)

for _, report in ipairs(reports) do
    assert(report.level ~= "error", "health error: " .. report.message)
end

assert(has_report(reports, "ok", "sidepanes.nvim loaded"), "health did not report sidepanes loaded")
assert(
    has_report(reports, "ok", "built-in sidepanes.markdown_reflow module found"),
    "health did not report built-in markdown_reflow module"
)
assert(has_report(reports, "ok", "Codex presets configured: 12"), "health did not report Codex presets")
assert(has_report(reports, "ok", "Command registered: :SidepanesSwitch"), "health did not report SidepanesSwitch")
assert(has_report(reports, "ok", "Global mapping registered (n): <leader>pp"), "health did not report normal global mapping mode")
assert(has_report(reports, "ok", "Global mapping registered (x): aa"), "health did not report visual global mapping mode")
assert(has_report(reports, "ok", "Global mapping registered (n, x): <leader>pl"), "health did not report multi-mode global mapping")
assert(has_report(reports, "ok", "Pane-local mapping configured (x): aa"), "health did not report pane-local mapping mode")

print("sidepanes audit smoke passed")
