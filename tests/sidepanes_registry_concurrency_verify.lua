local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local util = require("sidepanes.util")

local store = assert(vim.env.SIDEPANES_REGISTRY_STORE, "SIDEPANES_REGISTRY_STORE is required")
local root_one = assert(vim.env.SIDEPANES_REGISTRY_ROOT_ONE, "SIDEPANES_REGISTRY_ROOT_ONE is required")
local root_two = assert(vim.env.SIDEPANES_REGISTRY_ROOT_TWO, "SIDEPANES_REGISTRY_ROOT_TWO is required")
local session_one = assert(vim.env.SIDEPANES_REGISTRY_SESSION_ONE, "SIDEPANES_REGISTRY_SESSION_ONE is required")
local session_two = assert(vim.env.SIDEPANES_REGISTRY_SESSION_TWO, "SIDEPANES_REGISTRY_SESSION_TWO is required")

local decoded = vim.json.decode(table.concat(vim.fn.readfile(store), "\n"))
local sessions = decoded.sessions or decoded
local key_one = util.terminal_key("codex", root_one)
local key_two = util.terminal_key("claude", root_two)

assert(sessions[key_one], "codex registry entry missing after concurrent writes")
assert(sessions[key_two], "claude registry entry missing after concurrent writes")
assert(sessions[key_one].session_id == session_one, "codex registry entry changed during concurrent writes")
assert(sessions[key_two].session_id == session_two, "claude registry entry changed during concurrent writes")
assert(vim.fn.isdirectory(store .. ".lock") == 0, "registry lock was left behind after concurrent writes")
assert(vim.fn.glob(store .. ".tmp.*") == "", "registry temp file was left behind after concurrent writes")
