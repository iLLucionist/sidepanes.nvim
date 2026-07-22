--[[
sidepanes.ask_controller
Purpose: Preserve the legacy ask controller module path.
Does: Re-exports the pane-oriented ask controller.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.controller.
]]

return require("sidepanes.panes.ask.controller")
