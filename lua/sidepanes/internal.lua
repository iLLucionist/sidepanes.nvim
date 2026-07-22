--[[
sidepanes.internal
Purpose: Provide an explicit home for Sidepanes-owned internal callbacks.
Does: Forwards scratch-buffer lifecycle callbacks, raw switcher entry dispatch, and raw ask-entry dispatch to the private runtime state.
Architecture: Separates plugin implementation hooks from the stable `require("sidepanes")` public facade while still allowing command-string mappings to call Lua functions.
]]

local M = {}

--- Return the private Sidepanes runtime state.
local function state()
    return require("sidepanes")._state()
end

--- Switch using a raw internal switcher entry.
function M.switch(entry)
    return state().switch(entry)
end

--- Ask using a raw internal picker entry.
function M.ask_with_entry(entry, opts)
    return state().ask_with_entry(entry, opts)
end

--- Cancel and close a question editor buffer.
function M.cancel_question(bufnr)
    return state().cancel_question(bufnr)
end

--- Finish a question editor, sending only after a write.
function M.finish_question(bufnr)
    return state().finish_question(bufnr)
end

--- Mark a question editor as written and update its cached prompt.
function M.write_question(bufnr)
    return state().write_question(bufnr)
end

--- Open the target picker from inside a question editor.
function M.change_question_target(bufnr)
    return state().change_question_target(bufnr)
end

--- Cancel and restore the ask pane.
function M.cancel_ask_pane(bufnr)
    return state().cancel_ask_pane(bufnr)
end

--- Mark the ask pane prompt as written.
function M.write_ask_pane(bufnr)
    return state().write_ask_pane(bufnr)
end

--- Finish and send the ask pane prompt.
function M.finish_ask_pane(bufnr)
    return state().finish_ask_pane(bufnr)
end

--- Submit the ask pane prompt, writing it first when needed.
function M.submit_ask_pane(bufnr)
    return state().submit_ask_pane(bufnr)
end

--- Open the target picker from inside the ask pane.
function M.change_ask_pane_target(bufnr)
    return state().change_ask_pane_target(bufnr)
end

--- Return to the Markdown viewer pane.
function M.show_markdown()
    return state().show_markdown()
end

return M
