--[[
sidepanes.panes.ask.status
Purpose: Format ask-pane snapshot data for UI surfaces.
Does: Exposes status data and winbar title formatting without owning session mutation.
Architecture: Thin formatting boundary over the pure ask session snapshot helpers.
]]

local session = require("sidepanes.panes.ask.session")

local M = {}

function M.status_data(snapshot)
    return session.status_data(snapshot)
end

function M.format_title(snapshot)
    return session.format_title(snapshot)
end

return M
