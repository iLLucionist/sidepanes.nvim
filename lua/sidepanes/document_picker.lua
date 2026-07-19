--[[
sidepanes.document_picker
Purpose: Provide the Telescope-based markdown document picker.
Does: Discovers markdown files with rg or glob fallback, builds picker entries, and opens the selected path through a callback.
Architecture: Keeps document discovery and Telescope wiring outside the public facade while delegating pane opening back to the facade.
]]

local util = require("sidepanes.util")
local dependencies = require("sidepanes.dependencies")

local M = {}

--- Build a Telescope entry for an rg-discovered markdown path.
function M.rg_entry(entry)
    return {
        value = util.resolve_path(entry),
        display = entry,
        ordinal = entry,
    }
end

--- Build a Telescope entry for a glob-discovered markdown path.
function M.glob_entry(entry)
    return {
        value = util.resolve_path(entry),
        display = vim.fn.fnamemodify(entry, ":."),
        ordinal = entry,
    }
end

--- Build the markdown document finder using rg when available.
function M.finder(finders)
    if vim.fn.executable("rg") == 1 then
        return finders.new_oneshot_job({
            "rg",
            "--files",
            "-g",
            "*.md",
            "-g",
            "*.markdown",
        }, {
            entry_maker = M.rg_entry,
        })
    end

    local files = vim.fn.globpath(vim.fn.getcwd(), "**/*.md", false, true)

    vim.list_extend(files, vim.fn.globpath(vim.fn.getcwd(), "**/*.markdown", false, true))

    return finders.new_table({
        results = files,
        entry_maker = M.glob_entry,
    })
end

--- Pick a markdown document and pass the selected path to a callback.
function M.pick(on_select)
    if dependencies.notify_missing("document_picker") then
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local finder = M.finder(finders)

    pickers.new({}, {
        prompt_title = "Sidepanes",
        finder = finder,
        sorter = conf.file_sorter({}),
        attach_mappings = function(prompt_bufnr)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()

                actions.close(prompt_bufnr)

                if selection and selection.value then
                    on_select(selection.value)
                end
            end)

            return true
        end,
    }):find()
end

return M
