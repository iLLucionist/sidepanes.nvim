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
    width = true,
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

local function validate_badge(diagnostics, key, badge)
    if badge ~= nil and type(badge) ~= "table" then
        warn(diagnostics, "Sidepanes config " .. key .. " must be a table.")
        return
    end

    badge = badge or {}

    if badge.text ~= nil and type(badge.text) ~= "string" then
        warn(diagnostics, "Sidepanes config " .. key .. ".text must be a string.")
    end

    if badge.clear_on_interaction ~= nil and type(badge.clear_on_interaction) ~= "boolean" then
        warn(diagnostics, "Sidepanes config " .. key .. ".clear_on_interaction must be a boolean.")
    end

    if badge.hl ~= nil and type(badge.hl) ~= "table" then
        warn(diagnostics, "Sidepanes config " .. key .. ".hl must be a table.")
    end
end

--- Validate markdown reload and badge config shape.
local function validate_markdown(diagnostics, config)
    if config.reload_interval_ms ~= nil and (type(config.reload_interval_ms) ~= "number" or config.reload_interval_ms <= 0) then
        warn(diagnostics, "Sidepanes config reload_interval_ms must be a positive number.")
    end

    if config.reload_badge_ms ~= nil and (type(config.reload_badge_ms) ~= "number" or config.reload_badge_ms < 0) then
        warn(diagnostics, "Sidepanes config reload_badge_ms must be a non-negative number.")
    end

    validate_badge(diagnostics, "reload_badge", config.reload_badge)
end

local function validate_project(diagnostics, config)
    local markers = config.project_root_markers

    if markers ~= nil and markers ~= false and type(markers) ~= "string" and type(markers) ~= "table" and type(markers) ~= "function" then
        warn(diagnostics, "Sidepanes config project_root_markers must be a string, table, function, or false.")
    end

    if config.project_root_fallback ~= nil and config.project_root_fallback ~= "buffer_dir" and config.project_root_fallback ~= "cwd" then
        warn(diagnostics, "Sidepanes config project_root_fallback must be 'buffer_dir' or 'cwd'.")
    end

    if config.project_root_resolver ~= nil and type(config.project_root_resolver) ~= "function" then
        warn(diagnostics, "Sidepanes config project_root_resolver must be a function.")
    end
end

--- Validate terminal recovery badge config shape.
local function validate_terminal(diagnostics, config)
    local known_resume_mechanisms = {
        hook = true,
        pid_metadata = true,
        transcript = true,
    }

    if config.agent_auto_resume ~= nil and type(config.agent_auto_resume) ~= "boolean" then
        warn(diagnostics, "Sidepanes config agent_auto_resume must be a boolean.")
    end

    if config.agent_resume_infer_from_transcripts ~= nil and type(config.agent_resume_infer_from_transcripts) ~= "boolean" then
        warn(diagnostics, "Sidepanes config agent_resume_infer_from_transcripts must be a boolean.")
    end

    if config.agent_resume_use_claude_pid_metadata ~= nil and type(config.agent_resume_use_claude_pid_metadata) ~= "boolean" then
        warn(diagnostics, "Sidepanes config agent_resume_use_claude_pid_metadata must be a boolean.")
    end

    if config.agent_resume_mechanisms ~= nil and config.agent_resume_mechanisms ~= false and type(config.agent_resume_mechanisms) ~= "table" then
        warn(diagnostics, "Sidepanes config agent_resume_mechanisms must be a table or false.")
    elseif type(config.agent_resume_mechanisms) == "table" then
        for tool_name, mechanisms in pairs(config.agent_resume_mechanisms) do
            if mechanisms ~= false and type(mechanisms) ~= "table" then
                warn(diagnostics, "Sidepanes config agent_resume_mechanisms." .. tostring(tool_name) .. " must be a table or false.")
            elseif type(mechanisms) == "table" then
                for index, mechanism in ipairs(mechanisms) do
                    if type(mechanism) ~= "string" then
                        warn(diagnostics, "Invalid Sidepanes agent_resume_mechanisms." .. tostring(tool_name) .. " entry at index " .. index .. ": use a string.")
                    elseif not known_resume_mechanisms[mechanism] then
                        warn(diagnostics, "Unknown Sidepanes agent_resume_mechanisms." .. tostring(tool_name) .. " entry at index " .. index .. ": " .. mechanism .. ". Use terminal.resume.resolver for custom session discovery.")
                    end
                end
            end
        end
    end

    if config.agent_resume_store_path ~= nil and config.agent_resume_store_path ~= false and type(config.agent_resume_store_path) ~= "string" then
        warn(diagnostics, "Sidepanes config agent_resume_store_path must be a string or false.")
    end

    if config.agent_resume_store_lock_timeout_ms ~= nil and (type(config.agent_resume_store_lock_timeout_ms) ~= "number" or config.agent_resume_store_lock_timeout_ms < 0) then
        warn(diagnostics, "Sidepanes config agent_resume_store_lock_timeout_ms must be a non-negative number.")
    end

    if config.agent_resume_store_lock_stale_ms ~= nil and (type(config.agent_resume_store_lock_stale_ms) ~= "number" or config.agent_resume_store_lock_stale_ms < 0) then
        warn(diagnostics, "Sidepanes config agent_resume_store_lock_stale_ms must be a non-negative number.")
    end

    if config.agent_resume_resolver ~= nil and type(config.agent_resume_resolver) ~= "function" then
        warn(diagnostics, "Sidepanes config agent_resume_resolver must be a function.")
    end

    if config.agent_resume_failure_timeout_ms ~= nil and (type(config.agent_resume_failure_timeout_ms) ~= "number" or config.agent_resume_failure_timeout_ms < 0) then
        warn(diagnostics, "Sidepanes config agent_resume_failure_timeout_ms must be a non-negative number.")
    end

    if config.agent_resume_failure_action ~= nil and config.agent_resume_failure_action ~= "fresh" and config.agent_resume_failure_action ~= "notify" and config.agent_resume_failure_action ~= "ignore" then
        warn(diagnostics, "Sidepanes config agent_resume_failure_action must be 'fresh', 'notify', or 'ignore'.")
    end

    if config.agent_resume_badge_ms ~= nil and (type(config.agent_resume_badge_ms) ~= "number" or config.agent_resume_badge_ms < 0) then
        warn(diagnostics, "Sidepanes config agent_resume_badge_ms must be a non-negative number.")
    end

    validate_badge(diagnostics, "agent_resume_badge", config.agent_resume_badge)
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
    validate_markdown(diagnostics, config or {})
    validate_project(diagnostics, config or {})
    validate_terminal(diagnostics, config or {})
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
