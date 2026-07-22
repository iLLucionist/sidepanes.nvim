--[[
sidepanes.ask_route
Purpose: Keep ask routing predicates available while target decisions live in the resolver.
Does: Preserves compatibility for ask route helpers used by pane-mode ask workflows.
Architecture: Pure compatibility wrapper; target resolution belongs to ask_target_resolver.
]]

local ask_target_resolver = require("sidepanes.panes.ask.target_resolver")

local M = {}

function M.default_entry(facts)
    local decision = ask_target_resolver.resolve(facts)

    return decision.entry, decision.reason
end

function M.auto_append_blocked(facts)
    return ask_target_resolver.auto_append_blocked(facts)
end

return M
