local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local sidepanes = require("sidepanes")
local util = require("sidepanes.util")
local pane = sidepanes._state()

local root = assert(vim.env.SIDEPANES_AGENT_ROOT, "missing SIDEPANES_AGENT_ROOT")
local fake_codex = assert(vim.env.SIDEPANES_FAKE_CODEX, "missing SIDEPANES_FAKE_CODEX")
local memory_file = assert(vim.env.SIDEPANES_AGENT_MEMORY_FILE, "missing SIDEPANES_AGENT_MEMORY_FILE")
local session_id = assert(vim.env.SIDEPANES_AGENT_SESSION_ID, "missing SIDEPANES_AGENT_SESSION_ID")

sidepanes.setup({
    tools = {
        codex = {
            label = "Codex",
            cmd = fake_codex,
            include_cd_arg = true,
            presets = { { name = "default", label = "Default", args = {} } },
        },
    },
})

local ctx = sidepanes.open_terminal("codex", nil, { root = root, focus = false })

assert(ctx and ctx.tool_name == "codex", "first lifecycle Codex terminal did not open")

local remembered = vim.wait(2500, function()
    require("sidepanes.agent_session").refresh_context(pane, ctx)
    return pane.agent_sessions[ctx.key] and pane.agent_sessions[ctx.key].session_id == session_id
end, 50)

assert(remembered, "first lifecycle Codex session was not remembered")

vim.fn.chansend(ctx.job_id, "remember cheap-token\n")

local stored = vim.wait(1000, function()
    return vim.fn.filereadable(memory_file) == 1
end, 20)

assert(stored, "fake Codex did not store the lifecycle prompt")
assert(util.is_running(ctx.job_id), "fake Codex exited before Neovim lifecycle ended")
