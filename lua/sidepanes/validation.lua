--[[
sidepanes.validation
Purpose: Warn about malformed Sidepanes setup options and missing dependencies implied by enabled features.
Does: Checks command/mapping shapes, validates tool config basics, and reports feature-specific dependency requirements at setup time.
Architecture: Runs after config normalization in lifecycle.lua and complements health.lua with lightweight non-fatal startup diagnostics.
]]

local dependencies = require("sidepanes.dependencies")
local util = require("sidepanes.util")

local M = {}

local known_commands = {
    root = true,
    toggle = true,
    pick = true,
    headings = true,
    switch = true,
    tool = true,
    codex = true,
    claude = true,
    ipython = true,
    ipython_restart = true,
    ipython_clear = true,
    focus = true,
    zoom = true,
    width_picker = true,
    ask = true,
    ask_codex = true,
    ask_claude = true,
}

local global_mapping_features = {
    pick = "document_picker",
    headings = "heading_picker",
}

local pane_mapping_features = {}

--- Return whether a width-like value can be parsed by Sidepanes.
local function valid_width_value(value)
    return type(value) == "number" or type(value) == "string"
end

--- Append a warning diagnostic.
local function warn(diagnostics, message)
    table.insert(diagnostics, {
        level = vim.log.levels.WARN,
        message = message,
    })
end

--- Return whether a mapping or command lhs/name value is valid.
local function valid_string_or_false(value)
    return value == nil or value == false or type(value) == "string"
end

--- Return whether a feature entry is enabled in a boolean or table config.
local function enabled(config, key)
    if config == true then
        return true
    end

    if type(config) ~= "table" then
        return false
    end

    return config[key] ~= nil and config[key] ~= false
end

--- Add missing-dependency warnings for one feature when it is enabled.
local function check_feature_dependency(diagnostics, feature_name)
    local feature = dependencies.features[feature_name] or { label = feature_name }
    local missing = dependencies.missing(feature_name)

    if #missing > 0 then
        warn(diagnostics, "Sidepanes dependency missing for " .. feature.label .. ": " .. table.concat(missing, ", "))
    end
end

--- Validate configured command names and their feature dependencies.
local function validate_commands(diagnostics, commands)
    if commands == nil or commands == false then
        return
    end

    if commands ~= true and type(commands) ~= "table" then
        warn(diagnostics, "Sidepanes config commands must be true, false, or a table.")
        return
    end

    if type(commands) == "table" then
        for key, value in pairs(commands) do
            if not known_commands[key] then
                warn(diagnostics, "Unknown Sidepanes command config key: " .. tostring(key))
            elseif not valid_string_or_false(value) then
                warn(diagnostics, "Invalid Sidepanes command config for " .. key .. ": use a command name string or false.")
            end
        end
    end

    if enabled(commands, "pick") then
        check_feature_dependency(diagnostics, "document_picker")
    end

    if enabled(commands, "headings") then
        check_feature_dependency(diagnostics, "heading_picker")
    end
end

--- Validate one mapping table and its feature dependencies.
local function validate_mapping_group(diagnostics, group_name, mappings, feature_map)
    if mappings == nil or mappings == false then
        return
    end

    if type(mappings) ~= "table" then
        warn(diagnostics, "Sidepanes config mappings." .. group_name .. " must be false or a table.")
        return
    end

    for key, value in pairs(mappings) do
        if not valid_string_or_false(value) then
            warn(diagnostics, "Invalid Sidepanes " .. group_name .. " mapping for " .. key .. ": use a lhs string or false.")
        elseif type(value) == "string" and feature_map[key] then
            check_feature_dependency(diagnostics, feature_map[key])
        end
    end
end

--- Validate command/mapping config and dependency implications.
local function validate_surface(diagnostics, config)
    validate_commands(diagnostics, config.commands)

    local mappings = config.mappings or {}

    validate_mapping_group(diagnostics, "global", mappings.global, global_mapping_features)
    validate_mapping_group(diagnostics, "pane", mappings.pane, pane_mapping_features)
end

--- Validate width snapping config shape.
local function validate_layout(diagnostics, config)
    local width_lists = {
        width_snap_points = config.width_snap_points,
        width_picker_points = config.width_picker_points,
    }

    for name, values in pairs(width_lists) do
        if values ~= nil then
            if type(values) ~= "table" then
                warn(diagnostics, "Sidepanes config " .. name .. " must be a table.")
            else
                for index, value in ipairs(values) do
                    if not valid_width_value(value) then
                        warn(diagnostics, "Invalid Sidepanes " .. name .. " entry at index " .. index .. ": use a number or string.")
                    end
                end
            end

        end
    end
end

--- Return the executable head for a tool command.
local function command_head(tool)
    if not tool then
        return nil
    end

    local cmd = tool.cmd or tool.command

    if type(cmd) == "function" then
        local ok, result = pcall(cmd, vim.fn.getcwd(), (tool.presets or {})[1], tool)

        if not ok then
            return nil, result
        end

        cmd = result
    end

    if type(cmd) == "table" then
        return cmd[1]
    end

    if type(cmd) == "string" then
        return cmd
    end

    return nil
end

--- Validate terminal tool config enough to catch obvious setup mistakes.
local function validate_tools(diagnostics, config)
    for tool_name, tool in pairs(config.tools or {}) do
        if type(tool) ~= "table" then
            warn(diagnostics, "Invalid Sidepanes tool config for " .. tool_name .. ": use a table or false.")
        else
            local cmd, err = command_head(tool)

            if err then
                warn(diagnostics, "Sidepanes tool command failed for " .. tool_name .. ": " .. tostring(err))
            elseif not cmd then
                warn(diagnostics, "Sidepanes tool command missing for " .. tool_name .. ".")
            elseif not util.executable_exists(cmd) then
                warn(diagnostics, "Sidepanes tool executable not found for " .. tool_name .. ": " .. tostring(cmd))
            end

            if type(tool.presets) ~= "table" or #tool.presets == 0 then
                warn(diagnostics, "Sidepanes tool has no presets configured: " .. tool_name)
            end
        end
    end
end

--- Return setup validation diagnostics for a normalized Sidepanes config.
function M.diagnostics(config)
    local diagnostics = {}

    validate_surface(diagnostics, config or {})
    validate_layout(diagnostics, config or {})
    validate_tools(diagnostics, config or {})

    return diagnostics
end

--- Notify setup validation diagnostics unless validation is disabled.
function M.notify(config)
    if config and config.validate == false then
        return
    end

    for _, diagnostic in ipairs(M.diagnostics(config or {})) do
        vim.notify(diagnostic.message, diagnostic.level)
    end
end

return M
