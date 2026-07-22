--[[
sidepanes.ask_keymaps
Purpose: Preserve the legacy ask keymaps module path.
Does: Re-exports the pane-oriented ask keymap adapter.
Architecture: Compatibility shim; implementation lives in sidepanes.panes.ask.keymaps.
]]

return require("sidepanes.panes.ask.keymaps")
