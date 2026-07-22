--[[
sidepanes.panes.ask.status
Purpose: Format ask-pane snapshot data for UI surfaces.
Does: Exposes status data and winbar title formatting without owning session mutation.
Architecture: Thin formatting boundary over the pure ask session snapshot helpers.
]]

local session = require("sidepanes.panes.ask.session")

local M = {}

local function bool_label(value)
    return value and "yes" or "no"
end

function M.status_data(snapshot)
    return session.status_data(snapshot)
end

function M.debug_data(snapshot)
    local status = M.status_data(snapshot)
    local picker_mode = status.picker_mode or "manual"

    return {
        active = status.active == true,
        after_open_shown = picker_mode == "after_open" and status.picker_shown == true,
        citation_count = status.citation_count or 0,
        draft_state = status.draft_state or "inactive",
        file_count = status.file_count or 0,
        modified = status.modified == true,
        picker_mode = picker_mode,
        picker_shown = status.picker_shown == true,
        previous_pane_mode = status.previous_pane_mode or "",
        target_label = status.target_label or "No target",
        target_root = status.target_root or "",
        written = status.written == true,
    }
end

function M.debug_lines(snapshot)
    local data = M.debug_data(snapshot)

    return {
        "Ask pane: " .. (data.active and "active" or "inactive"),
        "Draft state: " .. data.draft_state,
        "Ask target: " .. data.target_label,
        "Target root: " .. data.target_root,
        "Picker mode: " .. data.picker_mode,
        "Picker shown: " .. bool_label(data.picker_shown),
        "After-open picker shown: " .. bool_label(data.after_open_shown),
        ("Citations: %d (%d files)"):format(data.citation_count, data.file_count),
        "Previous pane: " .. data.previous_pane_mode,
        "Modified: " .. bool_label(data.modified),
        "Written: " .. bool_label(data.written),
    }
end

function M.format_title(snapshot)
    return session.format_title(snapshot)
end

return M
