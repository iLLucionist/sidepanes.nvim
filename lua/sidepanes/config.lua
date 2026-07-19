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
    set_if_present(expanded, "focus_on_ask", lifecycle.focus_on_ask)
    set_if_present(expanded, "shutdown_on_exit", lifecycle.shutdown_on_exit)
    set_if_present(expanded, "shutdown_timeout_ms", lifecycle.shutdown_timeout_ms)
    expanded.lifecycle = nil

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
            focus_on_ask = config.focus_on_ask,
            shutdown_on_exit = config.shutdown_on_exit,
            shutdown_timeout_ms = config.shutdown_timeout_ms,
        },
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
    return expand_tools(expand_validation(expand_lifecycle(expand_markdown(expand_layout(opts or {})))))
end

--- Merge setup options into a base config after expanding ergonomic options.
function M.normalize(base, opts)
    local expanded = M.expand(opts or {})
    local result = vim.tbl_deep_extend("force", vim.deepcopy(base or {}), expanded)
    local metadata = {
        width = normalize_width(result, base, expanded),
    }

    remove_disabled_tools(result, opts)

    return result, metadata
end

--- Return the plugin defaults using the canonical grouped setup shape.
function M.default_setup()
    return M.to_setup(defaults.config)
end

return M
