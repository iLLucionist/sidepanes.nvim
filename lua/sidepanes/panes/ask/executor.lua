--[[
sidepanes.panes.ask.executor
Purpose: Execute ask action plans through explicit side-effect handlers.
Does: Maps policy action steps to injected write/cancel/send/picker/notify handlers.
Architecture: Imperative shell boundary without direct Neovim calls; tests can
run it with fake dependencies.
]]

local ask_policy = require("sidepanes.ask_policy")

local M = {}

local ACTIONS = ask_policy.ACTIONS

function M.run(plan, handlers)
    handlers = handlers or {}

    for _, item in ipairs(plan or {}) do
        if item.action == ACTIONS.noop then
            return false
        elseif item.action == ACTIONS.notify_no_prompt then
            if handlers.notify_no_prompt then
                handlers.notify_no_prompt(item)
            end
            return false
        elseif item.action == ACTIONS.mark_draft_modified then
            if handlers.mark_draft_modified then
                handlers.mark_draft_modified(item)
            end
        elseif item.action == ACTIONS.write_draft then
            if handlers.write_draft then
                handlers.write_draft(item)
            end
        elseif item.action == ACTIONS.cancel_draft then
            if handlers.cancel_draft then
                handlers.cancel_draft(item)
            end
            return true
        elseif item.action == ACTIONS.open_before_send_picker then
            if handlers.open_before_send_picker then
                handlers.open_before_send_picker(item.prompt, item)
            end
            return true
        elseif item.action == ACTIONS.send_prompt then
            if handlers.send_prompt then
                return handlers.send_prompt(item.prompt, item)
            end
            return false
        end
    end

    return true
end

return M
