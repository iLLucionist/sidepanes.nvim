--[[
sidepanes_checkhealth_smoke
Purpose: Exercise the real :checkhealth sidepanes command path.
Does: Runs Neovim's health command, inspects the generated report buffer, and fails on Sidepanes warnings or errors.
Architecture: Complements sidepanes_audit_smoke.lua by testing Neovim's command-facing health integration instead of calling the health module directly.
]]

local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

require("sidepanes").setup({
    commands = true,
    mappings = {
        global = {
            toggle = "<leader>pp",
            pick = "<leader>mP",
            headings = "<leader>fm",
            markdown = "<leader>p0",
            codex = "<leader>px",
            claude = "<leader>pc",
            ipython = "<leader>pi",
            restart_ipython = "<leader>pR",
            send_ipython = "<leader>pl",
            clear_ipython = "<leader>pX",
            focus = "<leader>pf",
            zoom = "<leader>pz",
            width_previous = "<leader>p-",
            width_next = "<leader>p+",
            width_picker = "<leader>pw",
            sticky_relative_width = "<leader>p%",
            switch = "<leader>ps",
            ask = "<leader>pa",
            ask_last = "aa",
            ask_codex = "ax",
            ask_claude = "ac",
        },
    },
    tools = {
        codex = { cmd = "sh" },
        claude = { cmd = "sh" },
        ipython = { cmd = "sh" },
    },
})

require("sidepanes.markdown_reflow").setup({
    commands = true,
    mappings = {
        reflow = "<leader>mR",
    },
})

vim.cmd("checkhealth sidepanes")

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local report = table.concat(lines, "\n")

assert(report:find("sidepanes.nvim loaded", 1, true), "health report did not load sidepanes:\n" .. report)
assert(
    report:find("built-in sidepanes.markdown_reflow module found", 1, true),
    "health report did not include built-in markdown_reflow module:\n" .. report
)
assert(report:find("Codex presets configured: 12", 1, true), "health report did not include Codex presets:\n" .. report)
assert(report:find("Command registered: :Sidepanes", 1, true), "health report did not include root command:\n" .. report)
assert(report:find("Global mapping registered (n, x): <leader>pl", 1, true), "health report did not include global mapping modes:\n" .. report)
assert(report:find("Pane-local mapping configured (x): aa", 1, true), "health report did not include pane-local mapping modes:\n" .. report)

for _, pattern in ipairs({ "ERROR", "❌" }) do
    assert(not report:find(pattern, 1, true), "health report contained " .. pattern .. ":\n" .. report)
end

print("sidepanes checkhealth smoke passed")
