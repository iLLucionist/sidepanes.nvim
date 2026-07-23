--[[
sidepanes.config
Purpose: Normalize user-facing setup options into the internal runtime config.
Does: Expands ergonomic grouped options, delegates preset generation, preserves legacy option names, and exposes canonical setup-shape helpers.
Architecture: Forms the boundary between public setup() input and the state.config table consumed by viewer, render, terminal, and switcher modules.
]]

local defaults = require("sidepanes.defaults")
local api = require("sidepanes.api")
local presets = require("sidepanes.presets")

local M = {}

--- Assign a value only when the source option was explicitly configured.
local function set_if_present(target, key, value)
    if value ~= nil then
        target[key] = value
    end
end

--- Expand nested layout options to the internal flat config keys.
local function expand_layout(opts)
    local expanded = vim.deepcopy(opts or {})
    local layout = expanded.layout or {}

    set_if_present(expanded, "width", layout.width)
    set_if_present(expanded, "zoom_text_width", layout.zoom_text_width)
    set_if_present(expanded, "sticky_relative_width", layout.sticky_relative_width)
    set_if_present(expanded, "width_snap_points", layout.width_snap_points)
    set_if_present(expanded, "width_picker_points", layout.width_picker_points)
    expanded.layout = nil

    return expanded
end

--- Expand nested markdown reflow options to the internal flat config keys.
local function expand_markdown(opts)
    local expanded = vim.deepcopy(opts or {})
    local markdown = expanded.markdown or {}
    local reflow = markdown.reflow or {}

    set_if_present(expanded, "wrap", markdown.wrap)
    set_if_present(expanded, "auto_reload", markdown.auto_reload)
    set_if_present(expanded, "reload_interval_ms", markdown.reload_interval_ms)
    set_if_present(expanded, "reload_badge_ms", markdown.reload_badge_ms)
    set_if_present(expanded, "reload_badge", markdown.reload_badge)
    set_if_present(expanded, "wrap_toggle_key", markdown.wrap_toggle_key)
    set_if_present(expanded, "sticky_heading", markdown.sticky_heading)
    set_if_present(expanded, "auto_reflow", reflow.enabled)
    set_if_present(expanded, "external_reflow_cmd", reflow.cmd)
    set_if_present(expanded, "external_reflow_fallback", reflow.fallback)
    set_if_present(expanded, "external_reflow_protect_tables", reflow.protect_tables)
    set_if_present(expanded, "reflow_margin", reflow.margin)
    expanded.markdown = nil

    return expanded
end

--- Expand nested lifecycle options to the internal flat config keys.
local function expand_lifecycle(opts)
    local expanded = vim.deepcopy(opts or {})
    local lifecycle = expanded.lifecycle or {}

    set_if_present(expanded, "focus_on_switch", lifecycle.focus_on_switch)
    set_if_present(expanded, "focus_on_pick", lifecycle.focus_on_pick)
    set_if_present(expanded, "focus_on_ask", lifecycle.focus_on_ask)
    set_if_present(expanded, "shutdown_on_exit", lifecycle.shutdown_on_exit)
    set_if_present(expanded, "shutdown_timeout_ms", lifecycle.shutdown_timeout_ms)
    expanded.lifecycle = nil

    return expanded
end

--- Expand nested terminal options to the internal flat config keys.
local function expand_terminal(opts)
    local expanded = vim.deepcopy(opts or {})
    local terminal = expanded.terminal or {}
    local resume = terminal.resume or {}

    set_if_present(expanded, "agent_resume_badge_ms", terminal.agent_resume_badge_ms)
    set_if_present(expanded, "agent_resume_badge", terminal.agent_resume_badge)
    set_if_present(expanded, "agent_auto_resume", terminal.auto_resume)
    set_if_present(expanded, "agent_auto_resume", resume.enabled)
    set_if_present(expanded, "agent_resume_infer_from_transcripts", resume.infer_from_transcripts)
    set_if_present(expanded, "agent_resume_use_claude_pid_metadata", resume.use_claude_pid_metadata)
    set_if_present(expanded, "agent_resume_mechanisms", resume.mechanisms)
    set_if_present(expanded, "agent_resume_store_path", resume.store_path)
    set_if_present(expanded, "agent_resume_store_lock_timeout_ms", resume.store_lock_timeout_ms)
    set_if_present(expanded, "agent_resume_store_lock_stale_ms", resume.store_lock_stale_ms)
    set_if_present(expanded, "agent_resume_resolver", resume.resolver)
    set_if_present(expanded, "agent_resume_failure_timeout_ms", resume.failure_timeout_ms)
    set_if_present(expanded, "agent_resume_failure_action", resume.failure_action)
    expanded.terminal = nil

    return expanded
end

--- Expand nested project root options to the internal flat config keys.
local function expand_project(opts)
    local expanded = vim.deepcopy(opts or {})
    local project = expanded.project or {}

    set_if_present(expanded, "project_root_markers", project.root_markers)
    set_if_present(expanded, "project_root_fallback", project.fallback)
    set_if_present(expanded, "project_root_resolver", project.resolver)
    expanded.project = nil

    return expanded
end

--- Expand nested validation options to the internal flat config keys.
local function expand_validation(opts)
    local expanded = vim.deepcopy(opts or {})
    local validation = expanded.validation

    if type(validation) == "table" then
        set_if_present(expanded, "validate", validation.enabled)
    elseif validation ~= nil then
        set_if_present(expanded, "validate", validation)
    end

    expanded.validation = nil

    return expanded
end

--- Expand known tool shorthand while preserving custom tool config tables.
local function expand_tools(opts)
    local expanded = vim.deepcopy(opts or {})

    if not expanded.tools then
        return expanded
    end

    for tool_name, tool_opts in pairs(expanded.tools) do
        if tool_opts == false then
            expanded.tools[tool_name] = { enabled = false }
        elseif type(tool_opts) ~= "table" then
            expanded.tools[tool_name] = tool_opts
        else
            expanded.tools[tool_name] = presets.expand_tool(tool_name, tool_opts)
            expanded.tools[tool_name].enabled = nil
        end
    end

    return expanded
end

--- Remove tools explicitly disabled in the user-facing setup table.
local function remove_disabled_tools(config, opts)
    for tool_name, tool_opts in pairs((opts or {}).tools or {}) do
        if tool_opts == false or (type(tool_opts) == "table" and tool_opts.enabled == false) then
            config.tools = config.tools or {}
            config.tools[tool_name] = nil
        end
    end
end

--- Resolve setup-time width values to columns and return relative metadata.
local function resolve_setup_width(value, current_width)
    if type(value) == "number" and value >= 1 then
        return math.floor(value)
    end

    if type(value) == "string" then
        local text = value:match("^%s*(.-)%s*$")
        local numeric = tonumber(text)

        if numeric and numeric >= 1 then
            return math.floor(numeric)
        end
    end

    return api.resolve_width(value, current_width)
end

--- Normalize config width while preserving literal absolute column values.
local function normalize_width(config, base, expanded)
    local current_width = tonumber((base or {}).width) or defaults.config.width

    if config.width == nil then
        config.width = current_width

        return {
            configured = false,
            error = nil,
            relative_width = nil,
        }
    end

    local width, err, relative_width = resolve_setup_width(config.width, current_width)

    if width then
        config.width = width
    else
        config.width = current_width
    end

    return {
        configured = expanded.width ~= nil,
        error = err,
        relative_width = relative_width,
    }
end

--- Normalize renamed pane mapping keys while preserving old setup aliases.
local function normalize_mapping_aliases(config, expanded)
    local mappings = config.mappings
    local pane = type(mappings) == "table" and mappings.pane or nil
    local expanded_pane = type(expanded.mappings) == "table" and type(expanded.mappings.pane) == "table" and expanded.mappings.pane or nil

    if type(pane) ~= "table" then
        return
    end

    local function alias(preferred, legacy)
        if expanded_pane and expanded_pane[preferred] == nil and expanded_pane[legacy] ~= nil then
            pane[preferred] = expanded_pane[legacy]
        end
    end

    alias("toggle_terminal", "toggle_agent")
    alias("toggle_terminal_alt", "toggle_agent_alt")
end

--- Keep the user-facing help.mapping shortcut aligned with the installed pane-local map.
local function normalize_help_mapping(config, expanded)
    local help = type(config.help) == "table" and config.help or nil
    local expanded_help = type(expanded.help) == "table" and expanded.help or nil

    if not help or not expanded_help or expanded_help.mapping == nil then
        return
    end

    config.mappings = type(config.mappings) == "table" and config.mappings or {}
    config.mappings.pane = type(config.mappings.pane) == "table" and config.mappings.pane or {}

    local expanded_pane = type(expanded.mappings) == "table" and type(expanded.mappings.pane) == "table" and expanded.mappings.pane or nil

    if not expanded_pane or expanded_pane.help == nil then
        config.mappings.pane.help = expanded_help.mapping
    end
end

--- Return a canonical grouped setup table for an already-normalized runtime config.
function M.to_setup(runtime_config)
    local config = vim.deepcopy(runtime_config or defaults.config)

    return {
        layout = {
            width = config.width,
            zoom_text_width = config.zoom_text_width,
            sticky_relative_width = config.sticky_relative_width,
            width_snap_points = config.width_snap_points,
            width_picker_points = config.width_picker_points,
        },
        markdown = {
            wrap = config.wrap,
            auto_reload = config.auto_reload,
            reload_interval_ms = config.reload_interval_ms,
            reload_badge_ms = config.reload_badge_ms,
            reload_badge = vim.deepcopy(config.reload_badge),
            wrap_toggle_key = config.wrap_toggle_key,
            sticky_heading = config.sticky_heading,
            reflow = {
                enabled = config.auto_reflow,
                cmd = config.external_reflow_cmd,
                fallback = config.external_reflow_fallback,
                protect_tables = config.external_reflow_protect_tables,
                margin = config.reflow_margin,
            },
        },
        lifecycle = {
            focus_on_switch = config.focus_on_switch,
            focus_on_pick = config.focus_on_pick,
            focus_on_ask = config.focus_on_ask,
            shutdown_on_exit = config.shutdown_on_exit,
            shutdown_timeout_ms = config.shutdown_timeout_ms,
        },
        terminal = {
            auto_resume = config.agent_auto_resume,
            resume = {
                enabled = config.agent_auto_resume,
                infer_from_transcripts = config.agent_resume_infer_from_transcripts,
                use_claude_pid_metadata = config.agent_resume_use_claude_pid_metadata,
                mechanisms = vim.deepcopy(config.agent_resume_mechanisms),
                store_path = config.agent_resume_store_path,
                store_lock_timeout_ms = config.agent_resume_store_lock_timeout_ms,
                store_lock_stale_ms = config.agent_resume_store_lock_stale_ms,
                resolver = config.agent_resume_resolver,
                failure_timeout_ms = config.agent_resume_failure_timeout_ms,
                failure_action = config.agent_resume_failure_action,
            },
            agent_resume_badge_ms = config.agent_resume_badge_ms,
            agent_resume_badge = vim.deepcopy(config.agent_resume_badge),
        },
        project = {
            root_markers = vim.deepcopy(config.project_root_markers),
            fallback = config.project_root_fallback,
            resolver = config.project_root_resolver,
        },
        ask = vim.deepcopy(config.ask),
        help = vim.deepcopy(config.help),
        validation = {
            enabled = config.validate,
        },
        commands = config.commands,
        mappings = config.mappings,
        tools = config.tools,
    }
end

--- Expand ergonomic setup options without merging them into a base config.
function M.expand(opts)
    return expand_tools(expand_validation(expand_terminal(expand_project(expand_lifecycle(expand_markdown(expand_layout(opts or {})))))))
end

--- Merge setup options into a base config after expanding ergonomic options.
function M.normalize(base, opts)
    local expanded = M.expand(opts or {})
    local result = vim.tbl_deep_extend("force", vim.deepcopy(base or {}), expanded)
    local metadata = {
        width = normalize_width(result, base, expanded),
    }

    normalize_mapping_aliases(result, expanded)
    normalize_help_mapping(result, expanded)
    remove_disabled_tools(result, opts)

    return result, metadata
end

--- Return the plugin defaults using the canonical grouped setup shape.
function M.default_setup()
    return M.to_setup(defaults.config)
end

return M
