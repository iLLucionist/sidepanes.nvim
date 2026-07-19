--[[
sidepanes.heading_picker
Purpose: Provide a Telescope picker for markdown headings in the active buffer or Sidepanes viewer.
Does: Collects markdown headings with Treesitter, previews the document, jumps to the selected heading, and restores focus after pane jumps.
Architecture: Keeps markdown navigation UI outside init.lua while receiving the Sidepanes facade as state for pane-aware targeting.
]]

local M = {}
local dependencies = require("sidepanes.dependencies")

local heading_icons = {
    [1] = "󰉫",
    [2] = "󰉬",
    [3] = "󰉭",
    [4] = "󰉮",
    [5] = "󰉯",
    [6] = "󰉰",
}

--- Return the heading level represented by a markdown Treesitter heading node.
local function heading_level(node)
    for child in node:iter_children() do
        local node_type = child:type()

        if node_type:match("^atx_h%d_marker$") then
            return tonumber(node_type:match("%d")) or 1
        elseif node_type == "setext_h1_underline" then
            return 1
        elseif node_type == "setext_h2_underline" then
            return 2
        end
    end

    return 1
end

--- Normalize raw markdown heading text for picker display.
local function clean_heading_title(text)
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+#+%s*$", "")
    text = text:gsub("%s+$", "")

    return text
end

--- Recursively collect heading entries from one Treesitter node.
local function visit(bufnr, node, headings)
    local node_type = node:type()

    if node_type == "atx_heading" or node_type == "setext_heading" then
        local content = node:field("heading_content")[1]

        if content then
            local start_row = node:range()
            local title = clean_heading_title(vim.treesitter.get_node_text(content, bufnr))

            table.insert(headings, {
                lnum = start_row + 1,
                level = heading_level(node),
                title = title,
            })
        end
    end

    for child in node:iter_children() do
        visit(bufnr, child, headings)
    end
end

--- Return sorted markdown headings for a buffer, or nil with an error message.
function M.collect(bufnr)
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")

    if not ok or not parser then
        return nil, "No markdown parser available"
    end

    local headings = {}

    for _, tree in ipairs(parser:parse()) do
        visit(bufnr, tree:root(), headings)
    end

    table.sort(headings, function(a, b)
        return a.lnum < b.lnum
    end)

    return headings
end

--- Build a Telescope display function for one heading entry.
local function entry_display(displayer, entry)
    return function()
        local indent = string.rep("  ", entry.level - 1)
        local icon = heading_icons[entry.level] or "󰉫"

        return displayer({
            { string.format("%4d", entry.lnum), "LineNr" },
            { icon, "MarkviewHeading" .. entry.level },
            indent .. entry.title,
        })
    end
end

--- Build a Telescope entry for one heading.
local function entry_maker(displayer, entry)
    return {
        value = entry,
        ordinal = string.format("%d %s", entry.lnum, entry.title),
        display = entry_display(displayer, entry),
        lnum = entry.lnum,
    }
end

--- Prepare the heading preview buffer on first preview render.
local function ensure_preview_buffer(previewer, bufnr)
    if previewer.state.bufname then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    vim.api.nvim_set_option_value("modifiable", true, { buf = previewer.state.bufnr })
    vim.api.nvim_buf_set_lines(previewer.state.bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = previewer.state.bufnr })
    vim.api.nvim_set_option_value("modifiable", false, { buf = previewer.state.bufnr })
    require("telescope.previewers.utils").highlighter(previewer.state.bufnr, "markdown")
end

--- Move the preview window to the selected heading.
local function move_preview_to_entry(previewer, entry)
    if not previewer.state.winid or not vim.api.nvim_win_is_valid(previewer.state.winid) then
        return
    end

    local line_count = vim.api.nvim_buf_line_count(previewer.state.bufnr)
    local target = math.min(entry.value.lnum, line_count)

    vim.api.nvim_set_option_value("number", true, { win = previewer.state.winid })
    vim.api.nvim_set_option_value("relativenumber", false, { win = previewer.state.winid })
    vim.api.nvim_set_option_value("cursorline", true, { win = previewer.state.winid })
    vim.api.nvim_set_option_value("wrap", false, { win = previewer.state.winid })
    vim.api.nvim_win_set_cursor(previewer.state.winid, { target, 0 })
    vim.api.nvim_win_call(previewer.state.winid, function()
        vim.cmd("normal! zz")
    end)
end

--- Jump to a selected heading and restore focus when jumping inside the pane.
local function jump_to_heading(selection, target_win, origin_win, pane_visible)
    if not selection or not vim.api.nvim_win_is_valid(target_win) then
        return
    end

    vim.api.nvim_win_call(target_win, function()
        vim.api.nvim_win_set_cursor(0, { selection.value.lnum, 0 })
        vim.cmd("normal! zz")
    end)

    if pane_visible and vim.api.nvim_win_is_valid(origin_win) then
        vim.api.nvim_set_current_win(origin_win)
    end
end

--- Show a Telescope picker for markdown headings.
function M.pick(state)
    local origin_win = vim.api.nvim_get_current_win()
    local pane_visible = state.is_open()
    local bufnr = pane_visible and state.bufnr or vim.api.nvim_get_current_buf()
    local target_win = pane_visible and state.winid or origin_win

    if dependencies.notify_missing("heading_picker", { bufnr = bufnr }) then
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local entry_display_module = require("telescope.pickers.entry_display")
    local previewers = require("telescope.previewers")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local headings, err = M.collect(bufnr)

    if not headings then
        vim.notify(err, vim.log.levels.WARN)
        return
    end

    if vim.tbl_isempty(headings) then
        vim.notify("No markdown headings found", vim.log.levels.INFO)
        return
    end

    local displayer = entry_display_module.create({
        separator = " ",
        items = {
            { width = 4 },
            { width = 2 },
            { remaining = true },
        },
    })

    pickers.new({}, {
        prompt_title = "Markdown Headings",
        finder = finders.new_table({
            results = headings,
            entry_maker = function(entry)
                return entry_maker(displayer, entry)
            end,
        }),
        previewer = previewers.new_buffer_previewer({
            title = "Markdown preview",
            get_buffer_by_name = function()
                return "markdown_headings_" .. tostring(bufnr)
            end,
            define_preview = function(self, entry)
                ensure_preview_buffer(self, bufnr)
                move_preview_to_entry(self, entry)
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr, telescope_map)
            telescope_map("i", "<C-n>", actions.move_selection_next)
            telescope_map("i", "<C-p>", actions.move_selection_previous)
            telescope_map("n", "<C-n>", actions.move_selection_next)
            telescope_map("n", "<C-p>", actions.move_selection_previous)

            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()

                actions.close(prompt_bufnr)
                jump_to_heading(selection, target_win, origin_win, pane_visible)
            end)

            return true
        end,
    }):find()
end

return M
