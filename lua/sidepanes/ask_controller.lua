--[[
sidepanes.ask_controller
Purpose: Compose ask lifecycle handlers from policy, facts, and executor boundaries.
Does: Turns lifecycle intents into policy plans and executes them through injected handlers.
Architecture: Small controller factory; no Neovim API calls.
]]

local ask_policy = require("sidepanes.ask_policy")
local ask_executor = require("sidepanes.ask_executor")

local M = {}

function M.create(opts)
    opts = opts or {}

    local policy = opts.policy or ask_policy
    local executor = opts.executor or ask_executor
    local facts = opts.facts or function()
        return {}
    end
    local handlers = opts.handlers or {}

    local controller = {}

    function controller.plan(intent)
        return policy.plan(intent, facts())
    end

    function controller.run_intent(intent)
        return executor.run(controller.plan(intent), handlers)
    end

    function controller.finish_quit()
        return controller.run_intent(policy.INTENTS.finish_quit)
    end

    function controller.submit_now()
        return controller.run_intent(policy.INTENTS.submit_now)
    end

    function controller.cancel_draft()
        return controller.run_intent(policy.INTENTS.cancel_draft)
    end

    function controller.write_draft()
        return controller.run_intent(policy.INTENTS.write_draft)
    end

    function controller.change_target(...)
        if handlers.change_target then
            return handlers.change_target(...)
        end
    end

    function controller.append_context(...)
        if handlers.append_context then
            return handlers.append_context(...)
        end
    end

    return controller
end

return M
