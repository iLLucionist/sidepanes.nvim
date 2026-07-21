local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local agent_session = require("sidepanes.agent_session")
local util = require("sidepanes.util")

local store = assert(vim.env.SIDEPANES_REGISTRY_STORE, "SIDEPANES_REGISTRY_STORE is required")
local root = assert(vim.env.SIDEPANES_REGISTRY_ROOT, "SIDEPANES_REGISTRY_ROOT is required")
local tool = assert(vim.env.SIDEPANES_REGISTRY_TOOL, "SIDEPANES_REGISTRY_TOOL is required")
local session = assert(vim.env.SIDEPANES_REGISTRY_SESSION, "SIDEPANES_REGISTRY_SESSION is required")
local key = util.terminal_key(tool, root)

vim.fn.mkdir(root .. "/.git", "p")

local ok = agent_session.save_store({
    config = {
        agent_resume_store_path = store,
        agent_resume_store_lock_timeout_ms = 5000,
        agent_resume_store_lock_stale_ms = 10000,
    },
    agent_sessions = {
        [key] = {
            key = key,
            tool_name = tool,
            root = root,
            session_id = session,
            source = "resolver",
            updated_at = tonumber(vim.env.SIDEPANES_REGISTRY_UPDATED_AT) or os.time(),
        },
    },
})

assert(ok, "registry writer failed to save " .. session)
