--[[
sidepanes.ask_session
Purpose: Preserve the legacy ask session module path.
Does: Re-exports the pane-oriented ask session helpers.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.session.
]]

return require("sidepanes.panes.ask.session")
