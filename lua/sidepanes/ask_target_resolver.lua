--[[
sidepanes.ask_target_resolver
Purpose: Preserve the legacy ask target resolver module path.
Does: Re-exports the pane-oriented ask target resolver.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.target_resolver.
]]

return require("sidepanes.panes.ask.target_resolver")
