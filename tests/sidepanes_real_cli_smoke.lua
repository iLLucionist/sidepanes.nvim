local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local defaults = require("sidepanes.defaults")
local sidepanes = require("sidepanes")
local pane = sidepanes._state()
local util = require("sidepanes.util")

local root = "/private/tmp/sidepanes-real-cli-smoke"

vim.fn.mkdir(root .. "/.git", "p")
vim.fn.writefile({ "# Real CLI smoke" }, root .. "/doc.md")

local function reset()
    pane.shutdown_terminals({ timeout_ms = 800 })
    pane.close()
    pane.zoomed = false
    pane.config = vim.deepcopy(defaults.config)
end

local function buffer_text(bufnr)
    if not util.valid_buf(bufnr) then
        return "<invalid buffer>"
    end

    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function smoke(tool_name)
    local tool = defaults.config.tools[tool_name]

    if not tool or vim.fn.executable(type(tool.cmd) == "string" and tool.cmd or tool_name) ~= 1 then
        print("skip " .. tool_name .. ": executable not found")
        return
    end

    reset()
    pane.setup({ shutdown_timeout_ms = 800 })
    pane.open(root .. "/doc.md")

    local ctx = pane.open_terminal(tool_name, nil, { root = root, focus = true })

    assert(ctx, tool_name .. " did not create a terminal context")

    local started = vim.wait(5000, function()
        return util.is_running(ctx.job_id) or buffer_text(ctx.bufnr) ~= ""
    end, 50)

    assert(started, tool_name .. " produced no terminal state")
    assert(util.is_running(ctx.job_id), tool_name .. " exited early:\n" .. buffer_text(ctx.bufnr))

    pane.shutdown_terminals({ timeout_ms = 1200 })

    local stopped = vim.wait(3000, function()
        return not util.is_running(ctx.job_id)
    end, 50)

    assert(stopped, tool_name .. " did not stop after configured exit command:\n" .. buffer_text(ctx.bufnr))
    print("smoked " .. tool_name)
end

local failures = {}

for _, tool_name in ipairs({ "codex", "claude" }) do
    local ok, err = xpcall(function()
        smoke(tool_name)
    end, debug.traceback)

    reset()

    if not ok then
        table.insert(failures, tool_name .. "\n" .. err)
    end
end

if #failures > 0 then
    error(table.concat(failures, "\n\n"))
end

print("sidepanes real CLI smoke passed")
