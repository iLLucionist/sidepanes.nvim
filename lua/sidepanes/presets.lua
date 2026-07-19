--[[
sidepanes.presets
Purpose: Generate normalized tool preset tables from compact user-facing descriptions.
Does: Expands Codex and Claude model/effort/speed options into the preset shape consumed by terminal sessions and pickers.
Architecture: Serves config.lua and advanced user configs while keeping terminal.lua focused on executing already-normalized presets.
]]

local M = {}

local effort_labels = {
    medium = "medium",
    high = "high",
    xhigh = "extra high",
}

--- Return a shallow copy of a list-like table.
local function copy_list(value)
    local result = {}

    for _, item in ipairs(value or {}) do
        table.insert(result, item)
    end

    return result
end

--- Normalize common effort aliases to the internal values used by presets.
local function normalize_effort(effort)
    if effort == "extra high" or effort == "extra_high" then
        return "xhigh"
    end

    if effort == "normal" then
        return "medium"
    end

    return effort
end

--- Return a display label for a configured model id.
local function model_label(model)
    if not model or model == "" then
        return "Default"
    end

    local without_prefix = model:gsub("^gpt%-", "")
    local label = without_prefix:gsub("%-", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest
    end)

    if model:match("^gpt%-") then
        return "GPT-" .. label
    end

    return label
end

--- Return a stable preset-name slug for a configured model id.
local function model_slug(model)
    return (model or "default"):gsub("^gpt%-", "gpt"):gsub("%.", ""):gsub("%-", "_")
end

--- Return the user-visible effort label for a preset effort.
local function effort_label(effort)
    return effort_labels[effort] or effort or "normal"
end

--- Return whether two generated preset specs describe the same target.
local function same_target(a, b)
    if type(a) == "string" then
        return a == b.name
    end

    if type(a) ~= "table" then
        return false
    end

    return (not a.model or a.model == b.model)
        and (not a.effort or normalize_effort(a.effort) == b.effort)
        and (not a.speed or a.speed == b.speed)
        and (not a.name or a.name == b.name)
end

--- Move the requested default preset to the front because existing code uses presets[1].
local function prefer_default_first(presets, default)
    if not default then
        return presets
    end

    for index, preset in ipairs(presets) do
        if same_target(default, preset) then
            table.remove(presets, index)
            table.insert(presets, 1, preset)
            return presets
        end
    end

    return presets
end

--- Return whether an explicit preset needs generated fields.
local function should_generate_preset(preset)
    return preset.args == nil and (preset.model ~= nil or preset.effort ~= nil or preset.speed ~= nil)
end

--- Return a default preset spec when the default option is table-like.
local function default_spec(opts)
    return type(opts.default) == "table" and opts.default or {}
end

--- Return configured values, falling back to the generator default when needed.
local function configured_values(primary, singular, default_value, fallback)
    if primary then
        return copy_list(primary)
    end

    if singular then
        return { singular }
    end

    if default_value then
        return { default_value }
    end

    return { fallback }
end

--- Build one normalized Codex preset.
function M.codex_preset(spec)
    spec = vim.deepcopy(spec or {})

    local model = spec.model or spec.name or "gpt-5.5"
    local effort = normalize_effort(spec.effort or "high")
    local speed = spec.speed or "fast"
    local args = vim.deepcopy(spec.args or { "--model", model, "-c", 'model_reasoning_effort="' .. effort .. '"' })

    if speed == "fast" and not spec.args then
        vim.list_extend(args, { "-c", 'service_tier="priority"' })
    end

    return vim.tbl_deep_extend("force", spec, {
        name = spec.name or table.concat({ model_slug(model), effort, speed }, "_"),
        label = spec.label or (model_label(model) .. " / " .. effort_label(effort) .. " / " .. speed),
        model = model,
        effort = effort,
        speed = speed,
        args = args,
    })
end

--- Build normalized Codex presets from explicit presets or model/effort/speed matrices.
function M.codex_presets(opts)
    opts = opts or {}

    if opts.presets then
        local result = {}

        for _, preset in ipairs(opts.presets) do
            table.insert(result, should_generate_preset(preset) and M.codex_preset(preset) or vim.deepcopy(preset))
        end

        return prefer_default_first(result, opts.default)
    end

    local default = default_spec(opts)
    local models = configured_values(opts.models, opts.model, default.model, "gpt-5.5")
    local efforts = configured_values(opts.efforts, opts.effort, default.effort, "high")
    local speeds = configured_values(opts.speeds, opts.speed, default.speed, "fast")
    local result = {}

    for _, model in ipairs(models) do
        for _, speed in ipairs(speeds) do
            for _, effort in ipairs(efforts) do
                table.insert(result, M.codex_preset({
                    model = model,
                    effort = effort,
                    speed = speed,
                }))
            end
        end
    end

    return prefer_default_first(result, opts.default)
end

--- Build a complete Codex tool config with generated presets.
function M.codex(opts)
    opts = vim.deepcopy(opts or {})
    local presets = M.codex_presets(opts)

    opts.models = nil
    opts.model = nil
    opts.efforts = nil
    opts.effort = nil
    opts.speeds = nil
    opts.speed = nil
    opts.default = nil

    return vim.tbl_deep_extend("force", {
        label = "Codex",
        cmd = "codex",
        include_cd_arg = true,
        send_delay_ms = 700,
        switch_command = "/model {model} {effort} {speed}",
    }, opts, {
        presets = presets,
    })
end

--- Build one normalized Claude preset.
function M.claude_preset(spec)
    spec = vim.deepcopy(spec or {})

    if not spec.model then
        return vim.tbl_deep_extend("force", {
            name = "default",
            label = "Default",
            args = {},
        }, spec)
    end

    local effort = normalize_effort(spec.effort or "medium")
    local label_effort = spec.effort == "normal" and "normal" or effort_label(effort)

    return vim.tbl_deep_extend("force", spec, {
        name = spec.name or (spec.model .. (effort == "medium" and "" or "_" .. effort)),
        label = spec.label or (model_label(spec.model) .. " / " .. label_effort),
        model = spec.model,
        effort = effort,
        args = spec.args or { "--model", spec.model, "--effort", effort },
    })
end

--- Build normalized Claude presets from explicit presets or model/effort matrices.
function M.claude_presets(opts)
    opts = opts or {}

    if opts.presets then
        local result = {}

        for _, preset in ipairs(opts.presets) do
            table.insert(result, should_generate_preset(preset) and M.claude_preset(preset) or vim.deepcopy(preset))
        end

        return prefer_default_first(result, opts.default)
    end

    local default = default_spec(opts)
    local models = configured_values(opts.models, opts.model, default.model, "sonnet")
    local efforts = configured_values(opts.efforts, opts.effort, default.effort, "normal")
    local result = {}

    for _, model in ipairs(models) do
        for _, effort in ipairs(efforts) do
            table.insert(result, M.claude_preset({
                model = model,
                effort = effort,
            }))
        end
    end

    return prefer_default_first(result, opts.default)
end

--- Build a complete Claude tool config with generated presets.
function M.claude(opts)
    opts = vim.deepcopy(opts or {})
    local presets = M.claude_presets(opts)

    opts.models = nil
    opts.model = nil
    opts.efforts = nil
    opts.effort = nil
    opts.default = nil

    return vim.tbl_deep_extend("force", {
        label = "Claude",
        cmd = "claude",
        send_delay_ms = 700,
        switch_command = "/model {model} {effort}",
    }, opts, {
        presets = presets,
    })
end

--- Expand known tool ergonomics while leaving custom tools untouched.
function M.expand_tool(tool_name, opts)
    if tool_name == "codex" and (opts.presets or opts.models or opts.model or opts.efforts or opts.effort or opts.speeds or opts.speed or opts.default) then
        return M.codex(opts)
    end

    if tool_name == "claude" and (opts.presets or opts.models or opts.model or opts.efforts or opts.effort or opts.default) then
        return M.claude(opts)
    end

    return vim.deepcopy(opts or {})
end

return M
