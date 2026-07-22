--[[
sidepanes.panes.ask.keymaps
Purpose: Register ask-pane-local mappings.
Does: Attaches configured target, submit, and quit-lifecycle callbacks to the ask buffer.
Architecture: Thin Neovim adapter; callbacks delegate to controller methods and
do not inspect lifecycle state.
]]

local M = {}

local function set_buffer_map(bufnr, mode, lhs, rhs, opts)
    if not lhs then
        return
    end

    opts = opts or {}
    opts.buffer = bufnr
    opts.silent = opts.silent ~= false

    vim.keymap.set(mode, lhs, rhs, opts)
end

local function set_submit_maps(bufnr, lhs, rhs)
    set_buffer_map(bufnr, { "n", "i" }, lhs, rhs, { desc = "Submit ask pane prompt" })

    if lhs == "<C-CR>" then
        set_buffer_map(bufnr, { "n", "i" }, "<C-J>", rhs, { desc = "Submit ask pane prompt" })
    end
end

function M.setup(bufnr, mappings, controller)
    mappings = mappings or {}
    controller = controller or {}

    set_buffer_map(bufnr, "n", mappings.ask_model_picker, function()
        if controller.change_target then
            controller.change_target()
        end
    end, { desc = "Change ask pane target" })

    set_buffer_map(bufnr, "n", mappings.ask_model_picker_alt, function()
        if controller.change_target then
            controller.change_target()
        end
    end, { desc = "Change ask pane target" })

    set_submit_maps(bufnr, mappings.ask_submit, function()
        if controller.submit_now then
            controller.submit_now()
        end
    end)

    set_buffer_map(bufnr, "n", mappings.ask_send, function()
        if controller.finish_quit then
            controller.finish_quit()
        end
    end, { desc = "Finish ask pane prompt" })

    set_buffer_map(bufnr, "n", mappings.ask_send_alt, function()
        if controller.finish_quit then
            controller.finish_quit()
        end
    end, { desc = "Finish ask pane prompt" })
end

return M
