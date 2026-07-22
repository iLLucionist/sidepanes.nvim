--[[
sidepanes.ask_pane
Purpose: Preserve the legacy ask-pane module path.
Does: Re-exports the pane-oriented ask entrypoint.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.
]]

return require("sidepanes.panes.ask")
