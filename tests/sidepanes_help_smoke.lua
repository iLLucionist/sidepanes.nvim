--[[
sidepanes_help_smoke
Purpose: Verify Neovim help integration for Sidepanes.
Does: Generates helptags for the local doc directory and opens :help sidepanes.
Architecture: Keeps help coverage independent from user config so standalone check scripts can run with -u NONE.
]]

local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local plugin_root = helpers.append_repo_root(1)

vim.cmd("helptags " .. vim.fn.fnameescape(plugin_root .. "/doc"))
vim.cmd("help sidepanes")

local lines = vim.api.nvim_buf_get_lines(0, 0, 20, false)
local report = table.concat(lines, "\n")

assert(report:find("Side panes for Markdown", 1, true), ":help sidepanes opened unexpected content:\n" .. report)

print("sidepanes help smoke passed")
