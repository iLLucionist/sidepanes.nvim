--[[
sidepanes.ask_policy
Purpose: Centralize ask-pane lifecycle predicates and action planning.
Does: Classifies command/key inputs and maps explicit ask state facts to action steps.
Architecture: Pure decision layer used by keymaps, command-line handlers, and ask-pane actions.
]]

local M = {}

M.STATES = {
    ready_empty = "ready_empty",
    draft_modified = "draft_modified",
    draft_written = "draft_written",
    sending_picker = "sending_picker",
    sending_terminal = "sending_terminal",
    send_failed = "send_failed",
    cancelled = "cancelled",
    sent = "sent",
}

M.INTENTS = {
    cancel_draft = "cancel_draft",
    append_context = "append_context",
    finish_quit = "finish_quit",
    open_picker = "open_picker",
    submit_now = "submit_now",
    change_target = "change_target",
    write_draft = "write_draft",
}

M.ACTIONS = {
    noop = "noop",
    notify_no_prompt = "notify_no_prompt",
    mark_draft_modified = "mark_draft_modified",
    notify = "notify",
    preserve_draft = "preserve_draft",
    resolve_target = "resolve_target",
    restore_previous = "restore_previous",
    write_draft = "write_draft",
    cancel_draft = "cancel_draft",
    open_before_send_picker = "open_before_send_picker",
    send_prompt = "send_prompt",
}

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalized_command(line)
    return trim(line):lower():gsub("^:", "")
end

local function normalized_rhs(rhs)
    return tostring(rhs or "")
        :lower()
        :gsub("\r", "<cr>")
        :gsub("\n", "<cr>")
        :gsub("%s+", "")
end

local function sendable_prompt(prompt)
    return prompt ~= nil and prompt ~= "" and prompt ~= "Question:"
end

function M.commandline_intent(line)
    local command = normalized_command(line)

    if command == "q" or command == "quit" then
        return M.INTENTS.finish_quit
    end

    if command == "q!" or command == "quit!" then
        return M.INTENTS.cancel_draft
    end

    if command == "wq" or command == "wq!" or command == "x" or command == "xit" or command == "exit" then
        return M.INTENTS.submit_now
    end

    return nil
end

function M.is_plain_quit_command(line)
    local command = normalized_command(line)

    return command == "q" or command == "quit"
end

function M.is_plain_quit_rhs(rhs)
    local normalized = normalized_rhs(rhs)

    return normalized == ":q<cr>"
        or normalized == ":quit<cr>"
        or normalized == "<cmd>q<cr>"
        or normalized == "<cmd>quit<cr>"
end

function M.lhs_candidates(lhs, opts)
    opts = opts or {}

    local result = {}
    local seen = {}

    local function add(value)
        if value and not seen[value] then
            seen[value] = true
            table.insert(result, value)
        end
    end

    add(lhs)

    if type(lhs) == "string" then
        add(lhs:gsub("<[Ll]eader>", opts.leader or "\\"))
        add(lhs:gsub("<[Ll]ocal[Ll]eader>", opts.localleader or "\\"))
    end

    return result
end

function M.normalize_facts(facts)
    facts = facts or {}

    local result = {
        active_target = facts.active_target,
        dirty_buffer = facts.dirty_buffer or facts.modified or false,
        live_prompt = facts.live_prompt or "",
        picker_mode = facts.picker_mode or facts.model_picker,
        previous_pane = facts.previous_pane,
        terminal_available = facts.terminal_available,
        valid_buffer = facts.valid_buffer or facts.valid_buf or false,
        written_prompt = facts.written_prompt,
    }

    result.model_picker = result.picker_mode
    result.modified = result.dirty_buffer
    result.valid_buf = result.valid_buffer

    return result
end

local function step(action, fields)
    fields = fields or {}
    fields.action = action

    return fields
end

function M.plan(intent, facts)
    facts = M.normalize_facts(facts)

    if intent == M.INTENTS.cancel_draft then
        return { step(M.ACTIONS.cancel_draft) }
    end

    if intent == M.INTENTS.write_draft then
        if not facts.valid_buffer then
            return { step(M.ACTIONS.noop) }
        end

        return { step(M.ACTIONS.write_draft) }
    end

    if intent == M.INTENTS.finish_quit then
        if not facts.valid_buffer then
            return { step(M.ACTIONS.noop) }
        end

        if facts.dirty_buffer then
            return {
                step(M.ACTIONS.mark_draft_modified),
                step(M.ACTIONS.cancel_draft),
            }
        end

        if not sendable_prompt(facts.written_prompt) then
            return { step(M.ACTIONS.cancel_draft) }
        end

        if facts.picker_mode == "before_send" then
            return { step(M.ACTIONS.open_before_send_picker, { prompt = facts.written_prompt }) }
        end

        return { step(M.ACTIONS.send_prompt, { prompt = facts.written_prompt }) }
    end

    if intent == M.INTENTS.submit_now then
        if not facts.valid_buffer then
            return { step(M.ACTIONS.notify_no_prompt) }
        end

        if not sendable_prompt(facts.live_prompt) then
            return {
                step(M.ACTIONS.write_draft),
                step(M.ACTIONS.cancel_draft),
            }
        end

        if facts.picker_mode == "before_send" then
            return {
                step(M.ACTIONS.write_draft),
                step(M.ACTIONS.open_before_send_picker, { prompt = facts.live_prompt }),
            }
        end

        return {
            step(M.ACTIONS.write_draft),
            step(M.ACTIONS.send_prompt, { prompt = facts.live_prompt }),
        }
    end

    return { step(M.ACTIONS.noop) }
end

return M
