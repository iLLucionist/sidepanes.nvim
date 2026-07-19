--[[
sidepanes.commands
Purpose: Register user commands that expose the sidepanes public API.
Does: Creates Sidepanes-prefixed commands for switching, asking, focusing, zooming, and controlling Codex, Claude, and IPython panes.
Architecture: Keeps command registration separate from setup while receiving the facade table as its API surface.
]]

local M = {}

local default_names = {
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

local subcommand_names = {
    "ask",
    "ask-claude",
    "ask-codex",
    "claude",
    "codex",
    "focus",
    "headings",
    "help",
    "ipython",
    "ipython-clear",
    "ipython-restart",
    "markdown",
    "open",
    "pick",
    "switch",
    "toggle",
    "tool",
    "width",
    "width-pick",
    "zoom",
}

local width_arg_names = {
    "next",
    "previous",
    "prev",
    "+",
    "-",
    "pick",
}

--- Register a user command unless its configured name is disabled.
local function command(name, callback, opts)
    if not name then
        return
    end

    opts = opts or {}
    opts.force = true
    vim.api.nvim_create_user_command(name, callback, opts)
end

--- Return all items that start with the current completion prefix.
local function matching(items, prefix)
    local result = {}

    for _, item in ipairs(items or {}) do
        if item:sub(1, #prefix) == prefix then
            table.insert(result, item)
        end
    end

    return result
end

--- Return configured terminal tool names in stable sorted order.
local function tool_names(api)
    local result = {}

    for tool_name in pairs((api.config or {}).tools or {}) do
        table.insert(result, tool_name)
    end

    table.sort(result)

    return result
end

--- Return configured preset names for one terminal tool.
local function preset_names(api, tool_name)
    local result = {}
    local tool = ((api.config or {}).tools or {})[tool_name]

    for _, preset in ipairs((tool or {}).presets or {}) do
        if preset.name then
            table.insert(result, preset.name)
        end
    end

    table.sort(result)

    return result
end

--- Return the raw argument string from a user-command completion line.
local function command_args(cmd_line)
    return (cmd_line or ""):gsub("^%s*:?", ""):gsub("^%S+%s*", "", 1)
end

--- Return completion candidates for the root Sidepanes command.
local function complete_root(api, arg_lead, cmd_line)
    local args_text = command_args(cmd_line)
    local args = vim.split(args_text, "%s+", { trimempty = true })
    local trailing_space = args_text:match("%s$") ~= nil
    local subcommand = args[1]

    if args_text == "" or (#args <= 1 and not trailing_space) then
        return matching(subcommand_names, arg_lead)
    end

    if subcommand == "toggle" or subcommand == "open" then
        return vim.fn.getcompletion(arg_lead, "file")
    end

    if subcommand == "codex" then
        return matching(preset_names(api, "codex"), arg_lead)
    end

    if subcommand == "claude" then
        return matching(preset_names(api, "claude"), arg_lead)
    end

    if subcommand == "tool" then
        if #args == 1 or (#args == 2 and not trailing_space) then
            return matching(tool_names(api), arg_lead)
        end

        return matching(preset_names(api, args[2]), arg_lead)
    end

    if subcommand == "width" then
        if #args == 1 or (#args == 2 and not trailing_space) then
            return matching(width_arg_names, arg_lead)
        end

        return {}
    end

    return {}
end

--- Return command names from a boolean or table setup value.
local function command_names(config)
    if not config then
        return nil
    end

    if config == true then
        return default_names
    end

    if type(config) ~= "table" then
        return nil
    end

    return vim.tbl_deep_extend("force", default_names, config)
end

--- Build current-buffer range options for ask commands.
local function range_opts(opts)
    return {
        bufnr = vim.api.nvim_get_current_buf(),
        line1 = opts.line1,
        line2 = opts.line2,
    }
end

--- Return command arguments after the subcommand, preserving spaces in file paths.
local function rest_args(parts)
    local rest = {}

    for index = 2, #parts do
        table.insert(rest, parts[index])
    end

    return table.concat(rest, " ")
end

--- Open Sidepanes help, falling back to a subcommand summary if helptags are unavailable.
local function show_help()
    local ok = pcall(vim.cmd.help, "sidepanes")

    if not ok then
        vim.notify("Sidepanes subcommands: " .. table.concat(subcommand_names, ", "), vim.log.levels.INFO)
    end
end

--- Set or report the configured side pane width.
local function dispatch_width(api, value)
    if not value or value == "" then
        vim.notify("Sidepanes width: " .. tostring(api.get_width()), vim.log.levels.INFO)
        return
    end

    local text = value:match("^%s*(.-)%s*$")

    if text == "next" or text == "+" then
        api.snap_width("next")
        return
    elseif text == "previous" or text == "prev" or text == "-" then
        api.snap_width("previous")
        return
    elseif text == "pick" then
        api.width_picker()
        return
    end

    if value:match("^%s*[+-]%d+%s*$") then
        api.adjust_width(value)
        return
    end

    api.set_width(value)
end

--- Dispatch the root Sidepanes command to focused subcommands.
local function dispatch_root(api, opts)
    local parts = vim.split(opts.args or "", "%s+", { trimempty = true })
    local subcommand = parts[1]

    if not subcommand then
        api.switch_picker()
        return
    end

    if subcommand == "help" then
        show_help()
    elseif subcommand == "toggle" then
        api.toggle(rest_args(parts))
    elseif subcommand == "open" then
        api.open(rest_args(parts))
    elseif subcommand == "markdown" then
        api.show_markdown()
    elseif subcommand == "pick" then
        api.pick()
    elseif subcommand == "headings" then
        api.pick_headings()
    elseif subcommand == "switch" then
        api.switch_picker()
    elseif subcommand == "tool" then
        if not parts[2] then
            api.switch_picker()
        else
            api.open_terminal(parts[2], parts[3])
        end
    elseif subcommand == "codex" then
        api.open_terminal("codex", parts[2])
    elseif subcommand == "claude" then
        api.open_terminal("claude", parts[2])
    elseif subcommand == "ipython" then
        api.open_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
            focus = true,
        })
    elseif subcommand == "ipython-restart" then
        api.restart_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
            focus = true,
        })
    elseif subcommand == "ipython-clear" then
        api.clear_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
        })
    elseif subcommand == "focus" then
        api.focus_toggle()
    elseif subcommand == "zoom" then
        api.toggle_zoom()
    elseif subcommand == "width" then
        dispatch_width(api, rest_args(parts))
    elseif subcommand == "width-pick" then
        api.width_picker()
    elseif subcommand == "ask" then
        api.ask_picker(range_opts(opts))
    elseif subcommand == "ask-codex" then
        api.ask("codex", parts[2], range_opts(opts))
    elseif subcommand == "ask-claude" then
        api.ask("claude", parts[2], range_opts(opts))
    else
        vim.notify("Unknown Sidepanes subcommand: " .. subcommand, vim.log.levels.WARN)
        show_help()
    end
end

--- Register configured sidepanes user commands.
function M.setup(api, config)
    local names = command_names(config)

    if not names then
        return
    end

    command(names.root, function(opts)
        dispatch_root(api, opts)
    end, {
        nargs = "*",
        range = true,
        complete = function(arg_lead, cmd_line)
            return complete_root(api, arg_lead, cmd_line)
        end,
    })

    command(names.toggle, function(opts)
        api.toggle(opts.args)
    end, { nargs = "?", complete = "file" })

    command(names.pick, function()
        api.pick()
    end, {})

    command(names.headings, function()
        api.pick_headings()
    end, {})

    command(names.switch, function()
        api.switch_picker()
    end, {})

    command(names.tool, function(opts)
        local parts = vim.split(opts.args or "", "%s+", { trimempty = true })

        if not parts[1] then
            api.switch_picker()
            return
        end

        api.open_terminal(parts[1], parts[2])
    end, { nargs = "*" })

    command(names.codex, function(opts)
        local preset = opts.args ~= "" and opts.args or nil

        api.open_terminal("codex", preset)
    end, { nargs = "?" })

    command(names.claude, function(opts)
        local preset = opts.args ~= "" and opts.args or nil

        api.open_terminal("claude", preset)
    end, { nargs = "?" })

    command(names.ipython, function()
        api.open_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
            focus = true,
        })
    end, {})

    command(names.ipython_restart, function()
        api.restart_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
            focus = true,
        })
    end, {})

    command(names.ipython_clear, function()
        api.clear_ipython({
            bufnr = vim.api.nvim_get_current_buf(),
        })
    end, {})

    command(names.focus, function()
        api.focus_toggle()
    end, {})

    command(names.zoom, function()
        api.toggle_zoom()
    end, {})

    command(names.width, function(opts)
        dispatch_width(api, opts.args)
    end, { nargs = "?" })

    command(names.width_picker, function()
        api.width_picker()
    end, {})

    command(names.ask, function(opts)
        api.ask_picker(range_opts(opts))
    end, { range = true })

    command(names.ask_codex, function(opts)
        local preset = opts.args ~= "" and opts.args or nil

        api.ask("codex", preset, range_opts(opts))
    end, { nargs = "?", range = true })

    command(names.ask_claude, function(opts)
        local preset = opts.args ~= "" and opts.args or nil

        api.ask("claude", preset, range_opts(opts))
    end, { nargs = "?", range = true })
end

return M
