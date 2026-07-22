--[[
sidepanes.ask_route
Purpose: Keep current pane-mode ask routing decisions explicit before the full resolver refactor.
Does: Selects the active/default ask target entry and decides when auto-append should focus an existing draft.
Architecture: Pure helper; target-resolution expansion belongs to the later target resolver slice.
]]

local M = {}

function M.default_entry(facts)
    facts = facts or {}

    if facts.active_entry then
        return facts.active_entry, "active_ask_target"
    end

    if facts.last_entry then
        return facts.last_entry, "last_coding_agent"
    end

    local targets = facts.target_entries or {}

    if targets[1] then
        return targets[1], "default_ask_target"
    end

    return nil, "no_target"
end

function M.auto_append_blocked(facts)
    facts = facts or {}

    return facts.auto_append == false and facts.active_buf ~= nil and (facts.citation_count or 0) > 0
end

return M
