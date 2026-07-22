--[[
sidepanes.ask_target_resolver
Purpose: Resolve ask-pane target decisions from explicit session/config facts.
Does: Centralizes target ordering, picker requirements, and picker entry composition for ask workflows.
Architecture: Pure helper; callers collect Neovim/UI facts and execute the returned decision.
]]

local M = {}

local DECISIONS = {
    error = "error",
    picker = "picker",
    target = "target",
}

local REASONS = {
    active_ask_target = "active_ask_target",
    before_send_picker = "before_send_picker",
    default_ask_target = "default_ask_target",
    explicit_target_change = "explicit_target_change",
    last_coding_agent = "last_coding_agent",
    no_target = "no_target",
}

M.DECISIONS = DECISIONS
M.REASONS = REASONS

local function copy_entries(entries)
    local result = {}

    for _, entry in ipairs(type(entries) == "table" and entries or {}) do
        table.insert(result, entry)
    end

    return result
end

local function decision(kind, reason, opts)
    opts = opts or {}

    return {
        entries = opts.entries,
        entry = opts.entry,
        kind = kind,
        reason = reason,
        root = opts.root,
    }
end

function M.picker_entries(facts)
    facts = facts or {}

    local result = copy_entries(facts.target_entries or facts.default_entries)

    for _, entry in ipairs(type(facts.picker_entries) == "table" and facts.picker_entries or {}) do
        table.insert(result, entry)
    end

    return result
end

function M.resolve(facts)
    facts = facts or {}

    if facts.explicit_picker then
        return decision(DECISIONS.picker, REASONS.explicit_target_change, {
            entries = M.picker_entries(facts),
            root = facts.root,
        })
    end

    if facts.active_entry then
        return decision(DECISIONS.target, REASONS.active_ask_target, {
            entry = facts.active_entry,
            root = facts.root,
        })
    end

    if facts.last_entry then
        return decision(DECISIONS.target, REASONS.last_coding_agent, {
            entry = facts.last_entry,
            root = facts.root,
        })
    end

    local targets = facts.target_entries or facts.default_entries or {}

    if targets[1] then
        return decision(DECISIONS.target, REASONS.default_ask_target, {
            entry = targets[1],
            root = facts.root,
        })
    end

    return decision(DECISIONS.picker, REASONS.no_target, {
        entries = M.picker_entries(facts),
        root = facts.root,
    })
end

function M.before_send(facts)
    facts = facts or {}

    if facts.picker_mode == "before_send" or facts.model_picker == "before_send" then
        return decision(DECISIONS.picker, REASONS.before_send_picker, {
            entries = M.picker_entries(facts),
            root = facts.root,
        })
    end

    return M.resolve(facts)
end

function M.auto_append_blocked(facts)
    facts = facts or {}

    return facts.auto_append == false and facts.active_buf ~= nil and (facts.citation_count or 0) > 0
end

return M
