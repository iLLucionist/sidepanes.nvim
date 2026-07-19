--[[
sidepanes.entries
Purpose: Build normalized picker entries for configured pane tools.
Does: Resolves presets, orders tools, marks running/current terminal sessions, and creates shortcut and numbered entries.
Architecture: Shared entry factory for ask pickers and pane switchers so Codex, Claude, IPython, and custom tools present consistently.
]]

local util = require("sidepanes.util")

local M = {}

--- Resolve a configured preset by name, label, or default position.
function M.preset_by_name(tool, preset_name)
    local presets = tool.presets or {}

    if not preset_name and presets[1] then
        return presets[1]
    end

    for _, preset in ipairs(presets) do
        if preset.name == preset_name or preset.label == preset_name then
            return preset
        end
    end

    return presets[1] or { name = "default", label = "Default", args = {} }
end

--- Return configured tool names in stable picker order.
function M.ordered_tool_names(config)
    local tools = config.tools or {}
    local names = {}
    local seen = {}

    for _, name in ipairs({ "codex", "claude", "ipython" }) do
        if tools[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end

    local rest = {}

    for name in pairs(tools) do
        if not seen[name] then
            table.insert(rest, name)
        end
    end

    table.sort(rest)
    vim.list_extend(names, rest)

    return names
end

--- Return whether a terminal context is currently usable.
local function terminal_is_running(ctx)
    return ctx and util.valid_buf(ctx.bufnr) and util.is_running(ctx.job_id)
end

--- Build the quick x/c/i picker entry for a tool.
local function current_or_default_entry(state, tool_name, root, key)
    local tool = (state.config.tools or {})[tool_name]

    if not tool then
        return nil
    end

    local terminal_ctx = root and state.terminals[util.terminal_key(tool_name, root)] or nil
    local running = terminal_is_running(terminal_ctx)
    local preset = running and M.preset_by_name(tool, terminal_ctx.preset_name) or M.preset_by_name(tool)

    return {
        kind = "terminal",
        shortcut = true,
        tool_name = tool_name,
        preset_name = preset.name,
        key = key,
        label = (tool.label or tool_name) .. " current: " .. (preset.label or preset.name or "Default"),
        running = running,
        current = running,
        active = running and state.active_terminal_key == terminal_ctx.key,
    }
end

--- Build quick picker entries for Codex, Claude, and optionally IPython.
function M.tool_shortcut_entries(state, root, opts)
    opts = opts or {}

    local result = {}
    local codex = current_or_default_entry(state, "codex", root, "x")
    local claude = current_or_default_entry(state, "claude", root, "c")
    local ipython = nil

    if not opts.ask_only then
        ipython = current_or_default_entry(state, "ipython", root, "i")
    end

    if codex then
        table.insert(result, codex)
    end

    if claude then
        table.insert(result, claude)
    end

    if ipython then
        table.insert(result, ipython)
    end

    return result
end

--- Build numbered picker entries for configured terminal presets.
function M.terminal_entries(state, root, start_index, opts)
    opts = opts or {}

    local result = {}
    local index = start_index or 1

    for _, tool_name in ipairs(M.ordered_tool_names(state.config)) do
        local tool = state.config.tools[tool_name]

        if (not opts.ask_only or tool.ask ~= false) and not (opts.preset_tools_only and tool.ask == false) then
            for _, preset in ipairs(tool.presets or { { name = "default", label = "Default", args = {} } }) do
                table.insert(result, {
                    kind = "terminal",
                    tool_name = tool_name,
                    preset_name = preset.name,
                    label = (tool.label or tool_name) .. ": " .. (preset.label or preset.name or "Default"),
                    ordinal = (tool.label or tool_name) .. " " .. (preset.label or preset.name or "Default"),
                })
            end
        end
    end

    for _, entry in ipairs(result) do
        entry.index = index
        entry.key = tostring(index)

        if root then
            local key = util.terminal_key(entry.tool_name, root)
            local ctx = state.terminals[key]

            entry.terminal_key = key
            entry.session_running = terminal_is_running(ctx)
            entry.current = entry.session_running and ctx.preset_name == entry.preset_name
            entry.running = entry.current
            entry.active = entry.current and state.active_terminal_key == key
        end

        index = index + 1
    end

    return result
end

return M
