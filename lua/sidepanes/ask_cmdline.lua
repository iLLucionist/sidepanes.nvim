--[[
sidepanes.ask_cmdline
Purpose: Build command-line lifecycle commands from classified ask intents.
Does: Converts command text into internal callback command strings for ask-pane
and legacy floating question-editor adapters.
Architecture: Pure command adapter; callers perform Neovim termcode expansion
and command-line mapping installation.
]]

local ask_policy = require("sidepanes.ask_policy")

local M = {}

local ASK_PANE_ACTIONS = {
    [ask_policy.INTENTS.cancel_draft] = "cancel_ask_pane",
    [ask_policy.INTENTS.finish_quit] = "finish_ask_pane",
    [ask_policy.INTENTS.submit_now] = "submit_ask_pane",
    [ask_policy.INTENTS.write_draft] = "write_ask_pane",
}

local FLOATING_QUESTION_COMMANDS = {
    q = { "finish_question" },
    ["q!"] = { "finish_question" },
    quit = { "finish_question" },
    ["quit!"] = { "finish_question" },
    wq = { "write_question", "finish_question" },
    ["wq!"] = { "write_question", "finish_question" },
    x = { "write_question", "finish_question" },
    xit = { "write_question", "finish_question" },
    exit = { "write_question", "finish_question" },
}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalized_command(line)
    return trim(line):lower():gsub("^:", "")
end

local function internal_call(name, bufnr)
    if bufnr then
        return 'require("sidepanes.internal").' .. name .. "(" .. tostring(bufnr) .. ")"
    end

    return 'require("sidepanes.internal").' .. name .. "()"
end

local function lua_command(calls)
    if not calls or #calls == 0 then
        return nil
    end

    return "<C-u>lua " .. table.concat(calls, "; ") .. "<CR>"
end

function M.markdown_return_command()
    return lua_command({ internal_call("show_markdown") })
end

function M.ask_pane_command_for_intent(intent, bufnr)
    local action = ASK_PANE_ACTIONS[intent]

    if not action then
        return nil
    end

    return lua_command({ internal_call(action, bufnr) })
end

function M.ask_pane_command_for_line(line, bufnr)
    return M.ask_pane_command_for_intent(ask_policy.commandline_intent(line), bufnr)
end

function M.floating_question_command_for_line(line, bufnr)
    local names = FLOATING_QUESTION_COMMANDS[normalized_command(line)]

    if not names then
        return nil
    end

    local calls = {}

    for _, name in ipairs(names) do
        table.insert(calls, internal_call(name, bufnr))
    end

    return lua_command(calls)
end

return M
