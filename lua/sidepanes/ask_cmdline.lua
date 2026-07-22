--[[
sidepanes.ask_cmdline
Purpose: Preserve the legacy ask command-line module path.
Does: Re-exports the pane-oriented ask command-line adapter.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.cmdline.
]]

return require("sidepanes.panes.ask.cmdline")
