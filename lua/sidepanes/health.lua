--[[
sidepanes.health
Purpose: Report Sidepanes environment and configuration health through Neovim's checkhealth interface.
Does: Checks external commands, optional Lua dependencies, tool presets, configured commands, and mapping config shape.
Architecture: Reads the public sidepanes config as a diagnostic layer without owning runtime pane state.
]]

local util = require("sidepanes.util")
local dependencies = require("sidepanes.dependencies")

local M = {}

local default_commands = {
    root = "Sidepanes",
    toggle = "SidepanesToggle",
    pick = "SidepanesPick",
    headings = "SidepanesHeadings",
    switch = "SidepanesSwitch",
    tool = "SidepanesTool",
    codex = "SidepanesCodex",
    claude = "SidepanesClaude",
    ipython = "SidepanesIPython",
    ipython_restart = "SidepanesIPythonRestart",
    ipython_clear = "SidepanesIPythonClear",
    focus = "SidepanesFocus",
    zoom = "SidepanesZoom",
    width = "SidepanesWidth",
    width_picker = "SidepanesWidthPick",
    ask = "SidepanesAsk",
    ask_codex = "SidepanesAskCodex",
    ask_claude = "SidepanesAskClaude",
}

local expected_global_mappings = {
    { key = "toggle", modes = "n" },
    { key = "pick", modes = "n" },
    { key = "headings", modes = "n" },
    { key = "markdown", modes = "n" },
    { key = "codex", modes = "n" },
    { key = "claude", modes = "n" },
    { key = "ipython", modes = "n" },
    { key = "restart_ipython", modes = "n" },
    { key = "send_ipython", modes = { "n", "x" } },
    { key = "clear_ipython", modes = "n" },
    { key = "focus", modes = "n" },
    { key = "zoom", modes = "n" },
    { key = "width_previous", modes = "n" },
    { key = "width_next", modes = "n" },
    { key = "width_picker", modes = "n" },
    { key = "sticky_relative_width", modes = "n" },
    { key = "switch", modes = "n" },
    { key = "ask", modes = "x" },
    { key = "ask_last", modes = "x" },
    { key = "ask_codex", modes = "x" },
    { key = "ask_claude", modes = "x" },
}

local expected_pane_mappings = {
    { key = "markdown", modes = "n" },
    { key = "codex", modes = "n" },
    { key = "claude", modes = "n" },
    { key = "ipython", modes = "n" },
    { key = "toggle_agent", modes = "n" },
    { key = "toggle_agent_alt", modes = "n" },
    { key = "ipython_alt", modes = "n" },
    { key = "gf", modes = "n" },
    { key = "send_ipython", modes = "x" },
    { key = "zoom", modes = "n" },
    { key = "ask_last", modes = "x" },
    { key = "ask_codex", modes = "x" },
    { key = "ask_claude", modes = "x" },
}

--- Return the active health reporter table.
local function reporter()
    return vim.health
end

--- Report an info message.
local function info(message)
    reporter().info(message)
end

--- Report a successful health check.
local function ok(message)
    reporter().ok(message)
end

--- Report a warning health check.
local function warn(message, advice)
    reporter().warn(message, advice)
end

--- Report an error health check.
local function error(message, advice)
    reporter().error(message, advice)
end

--- Report a health section heading.
local function start(message)
    reporter().start(message)
end

--- Return the first command token for a string, table, or function command.
local function command_head(cmd, root, tool, preset)
    local value = cmd

    if type(value) == "function" then
        local ok_call, result = pcall(value, root or vim.fn.getcwd(), preset, tool)

        if not ok_call then
            return nil, result
        end

        value = result
    end

    if type(value) == "table" then
        return value[1]
    end

    if type(value) == "string" then
        return value
    end

    return nil
end

--- Return whether a configured executable command exists.
local function executable_available(cmd)
    return util.executable_exists(cmd)
end

--- Check that a Lua module can be loaded.
local function check_module(name, label, required)
    local ok_require = pcall(require, name)

    if ok_require then
        ok(label .. " module found")
    elseif required then
        error(label .. " module not found")
    else
        warn(label .. " module not found", "Install or load it if you use the related Sidepanes feature.")
    end
end

--- Report health for the external markdown reflow command.
local function check_reflow(config)
    start("Markdown reflow")

    local cmd = command_head(config.external_reflow_cmd)

    if not cmd then
        info("No external reflow command configured; internal reflow will be used.")
        return
    end

    if executable_available(cmd) then
        ok("External reflow command found: " .. cmd)
    else
        local level = config.external_reflow_fallback == false and error or warn

        level("External reflow command not found: " .. cmd, "Install it or update markdown.reflow.cmd.")
    end

    if config.external_reflow_protect_tables then
        ok("External reflow protects markdown tables before formatting.")
    else
        warn("External reflow table protection is disabled.", "Tables may be reformatted by the external command.")
    end
end

--- Report health for optional Lua dependencies used by Sidepanes features.
local function check_dependencies()
    start("Lua dependencies")
    check_module("markview", "markview", false)
    check_module("telescope", "telescope.nvim", false)
    check_module("sidepanes.smart_gf", "built-in sidepanes.smart_gf", true)
    check_module("sidepanes.markdown_reflow", "built-in sidepanes.markdown_reflow", true)

    if dependencies.has_parser("markdown") then
        ok("Treesitter markdown parser found")
    else
        warn("Treesitter markdown parser not found", "Install it for :SidepanesHeadings and the headings mapping.")
    end
end

--- Return command names from a boolean or table command config.
local function configured_commands(config)
    if not config then
        return nil
    end

    if config == true then
        return default_commands
    end

    if type(config) == "table" then
        return vim.tbl_deep_extend("force", default_commands, config)
    end

    return nil
end

--- Report health for configured user commands.
local function check_commands(config)
    start("Commands")

    local names = configured_commands(config.commands)

    if not names then
        info("Sidepanes user commands are disabled.")
        return
    end

    local existing = vim.api.nvim_get_commands({})

    for key, name in pairs(names) do
        if name == false then
            info("Command disabled: " .. key)
        elseif type(name) ~= "string" then
            error("Invalid command name for " .. key, "Use a command name string or false.")
        elseif existing[name] then
            ok("Command registered: :" .. name)
        else
            warn("Configured command is not registered: :" .. name, "Call require('sidepanes').setup() before running :checkhealth sidepanes.")
        end
    end
end

--- Return true when a mapping value is a valid configured lhs.
local function valid_mapping_value(value)
    return value == nil or value == false or type(value) == "string"
end

--- Return true when a width-like config value has a valid primitive shape.
local function valid_width_value(value)
    return type(value) == "number" or type(value) == "string"
end

--- Report health for width-related layout config.
local function check_layout(config)
    start("Layout")

    if not valid_width_value(config.width) then
        error("Invalid pane width config.", "Use columns, a percentage string, a fraction string, or a numeric ratio.")
    else
        ok("Pane width configured: " .. tostring(config.width))
    end

    for _, name in ipairs({ "width_snap_points", "width_picker_points" }) do
        local values = config[name]

        if values == nil then
            info(name .. " is not configured.")
        elseif type(values) ~= "table" then
            error("Invalid " .. name .. " config.", "Use a table of width values.")
        else
            local invalid = false

            for index, value in ipairs(values) do
                if not valid_width_value(value) then
                    error("Invalid " .. name .. " entry at index " .. index, "Use columns, a percentage string, a fraction string, or a numeric ratio.")
                    invalid = true
                end
            end

            if not invalid then
                ok(name .. " configured: " .. tostring(#values))
            end
        end
    end
end

--- Report malformed mapping entries for one mapping group.
local function check_mapping_values(group_name, mappings, specs)
    for _, spec in ipairs(specs) do
        local key = spec.key

        if not valid_mapping_value(mappings[key]) then
            error("Invalid " .. group_name .. " mapping for " .. key, "Use a lhs string, false, or nil.")
        end
    end
end

--- Return expected modes as a list.
local function mode_list(modes)
    return type(modes) == "table" and modes or { modes }
end

--- Return a display label for one or more mapping modes.
local function mode_label(modes)
    return table.concat(mode_list(modes), ", ")
end

--- Return whether a global mapping is present for all expected modes.
local function global_mapping_present(lhs, modes)
    for _, mode in ipairs(mode_list(modes)) do
        local map = vim.fn.maparg(lhs, mode, false, true)

        if not map.lhs or map.lhs == "" then
            return false
        end
    end

    return true
end

--- Report health for global and pane-local mapping configuration.
local function check_mappings(config)
    start("Mappings")

    local mappings = config.mappings or {}
    local global = mappings.global

    if global and type(global) ~= "table" then
        if global == false then
            info("Global mappings are disabled.")
        else
            error("Invalid mappings.global config.", "Use false or a table of mapping names to lhs strings.")
        end
    elseif type(global) == "table" then
        for _, spec in ipairs(expected_global_mappings) do
            local key = spec.key
            local modes = spec.modes
            local modes_text = mode_label(modes)

            if not valid_mapping_value(global[key]) then
                error("Invalid global mapping for " .. key, "Use a lhs string, false, or nil.")
            elseif type(global[key]) == "string" and global_mapping_present(global[key], modes) then
                ok("Global mapping registered (" .. modes_text .. "): " .. global[key])
            elseif type(global[key]) == "string" then
                warn("Configured global mapping is not registered (" .. modes_text .. "): " .. global[key], "Call require('sidepanes').setup() before running :checkhealth sidepanes.")
            end
        end
    else
        info("Global mappings are disabled.")
    end

    if type(mappings.pane) == "table" then
        check_mapping_values("pane", mappings.pane, expected_pane_mappings)

        for _, spec in ipairs(expected_pane_mappings) do
            local lhs = mappings.pane[spec.key]

            if type(lhs) == "string" then
                ok("Pane-local mapping configured (" .. mode_label(spec.modes) .. "): " .. lhs)
            end
        end
    else
        warn("Pane-local mapping config is missing.", "Use mappings.pane or keep the built-in defaults.")
    end
end

--- Report health for one configured terminal tool.
local function check_tool(tool_name, tool)
    if not tool or (type(tool) == "table" and tool.enabled == false) then
        warn("Tool disabled or missing: " .. tool_name)
        return
    end

    if type(tool) ~= "table" then
        error("Invalid tool config for " .. tool_name, "Use a table or false.")
        return
    end

    local label = tool.label or tool_name
    local presets = tool.presets or {}
    local preset = presets[1] or {}
    local cmd, cmd_error = command_head(tool.cmd or tool.command, vim.fn.getcwd(), tool, preset)

    if cmd_error then
        error(label .. " command function failed.", tostring(cmd_error))
    elseif executable_available(cmd) then
        ok(label .. " command found: " .. cmd)
    elseif cmd then
        error(label .. " command not found: " .. cmd, "Install it or update tools." .. tool_name .. ".cmd.")
    else
        error(label .. " command is not configured.", "Set tools." .. tool_name .. ".cmd.")
    end

    if #presets == 0 then
        error(label .. " has no presets configured.", "Configure at least one preset.")
    else
        ok(label .. " presets configured: " .. tostring(#presets))
        info(label .. " default preset: " .. (preset.label or preset.name or "unnamed"))
    end

    for index, item in ipairs(presets) do
        if type(item) ~= "table" then
            error(label .. " preset " .. index .. " is not a table.")
        elseif not item.name then
            warn(label .. " preset " .. index .. " has no name.", "Named presets are easier to invoke from commands.")
        elseif item.args ~= nil and type(item.args) ~= "table" then
            error(label .. " preset " .. item.name .. " has invalid args.", "Preset args must be a list table.")
        end
    end

    if tool.exit_command then
        ok(label .. " exit command configured.")
    else
        warn(label .. " exit command is not configured.", "Terminal shutdown may be less graceful.")
    end
end

--- Report health for all configured terminal tools.
local function check_tools(config)
    start("Terminal tools")

    local tools = config.tools or {}

    check_tool("codex", tools.codex)
    check_tool("claude", tools.claude)
    check_tool("ipython", tools.ipython)

    if executable_available("uv") then
        ok("uv found")
    else
        info("uv not found; IPython will use its fallback command when configured that way.")
    end
end

--- Return the sidepanes config to inspect for health.
local function health_config(opts)
    if opts and opts.config then
        return opts.config
    end

    return require("sidepanes").get_config()
end

--- Run Sidepanes health checks.
function M.check(opts)
    local config = health_config(opts)

    start("Sidepanes")
    ok("sidepanes.nvim loaded")
    check_layout(config)
    check_reflow(config)
    check_dependencies()
    check_tools(config)
    check_commands(config)
    check_mappings(config)
end

return M
