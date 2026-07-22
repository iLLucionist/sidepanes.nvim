--[[
sidepanes.ask_executor
Purpose: Preserve the legacy ask executor module path.
Does: Re-exports the pane-oriented ask executor.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.executor.
]]

return require("sidepanes.panes.ask.executor")
