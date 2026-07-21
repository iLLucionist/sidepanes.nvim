local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local sidepanes = require("sidepanes")

local root = assert(vim.env.SIDEPANES_AGENT_ROOT, "missing SIDEPANES_AGENT_ROOT")
local fake_codex = assert(vim.env.SIDEPANES_FAKE_CODEX, "missing SIDEPANES_FAKE_CODEX")
local args_file = assert(vim.env.SIDEPANES_AGENT_ARGS_FILE, "missing SIDEPANES_AGENT_ARGS_FILE")
local session_id = assert(vim.env.SIDEPANES_AGENT_SESSION_ID, "missing SIDEPANES_AGENT_SESSION_ID")

local function read_file(path)
    return table.concat(vim.fn.readfile(path), "\n")
end

local function buffer_text(bufnr)
    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

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

assert(ctx and ctx.tool_name == "codex", "second lifecycle Codex terminal did not open")
assert(ctx.resumed == true, "second lifecycle Codex terminal did not resume")
assert(ctx.session_id == session_id, "second lifecycle Codex resumed the wrong session")

local wrote_args = vim.wait(1000, function()
    return vim.fn.getfsize(args_file) > 0
end, 20)

assert(wrote_args, "fake Codex did not record second lifecycle argv")

local args = read_file(args_file)

assert(args:find("resume", 1, true), args)
assert(args:find(session_id, 1, true), args)

local restored_memory = vim.wait(1000, function()
    return buffer_text(ctx.bufnr):find("memory: remember cheap%-token") ~= nil
end, 20)

assert(restored_memory, "resumed fake Codex did not print remembered prompt")
