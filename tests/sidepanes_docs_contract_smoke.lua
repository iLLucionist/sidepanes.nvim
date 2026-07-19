--[[
sidepanes_docs_contract_smoke
Purpose: Keep user documentation aligned with Sidepanes' supported surface.
Does: Checks help and Markdown docs for commands, public API, mappings, config groups, Markdown Reflow, dependencies, and compatibility notes.
Architecture: Complements focused behavior tests with a lightweight text-contract smoke for roadmap docs requirements.
]]

local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local plugin_root = helpers.repo_root(1)

local function read(path)
    return table.concat(vim.fn.readfile(plugin_root .. "/" .. path), "\n")
end

local help = read("doc/sidepanes.txt")
local markdown = read("doc/sidepanes.md")
local readme = read("README.md")
local changelog = read("CHANGELOG.md")
local docs = table.concat({ help, markdown, readme, changelog }, "\n")

local function assert_has(text, needle, label)
    assert(text:find(needle, 1, true), "missing docs contract entry for " .. (label or needle))
end

for _, item in ipairs({
    ":Sidepanes help",
    ":Sidepanes switch",
    ":Sidepanes toggle [file]",
    ":Sidepanes open {file}",
    ":Sidepanes markdown",
    ":Sidepanes pick",
    ":Sidepanes headings",
    ":Sidepanes codex [preset]",
    ":Sidepanes claude [preset]",
    ":Sidepanes tool {tool} [preset]",
    ":Sidepanes ipython",
    ":Sidepanes ipython-restart",
    ":Sidepanes ipython-clear",
    ":Sidepanes focus",
    ":Sidepanes zoom",
    ":Sidepanes width [value]",
    ":Sidepanes width next",
    ":Sidepanes width previous",
    ":Sidepanes width prev",
    ":Sidepanes width +",
    ":Sidepanes width -",
    ":Sidepanes width pick",
    ":Sidepanes width-pick",
    ":Sidepanes ask",
    ":Sidepanes ask-codex [preset]",
    ":Sidepanes ask-claude [preset]",
    ":SidepanesToggle [file]",
    ":SidepanesPick",
    ":SidepanesHeadings",
    ":SidepanesSwitch",
    ":SidepanesTool {tool} [preset]",
    ":SidepanesCodex [preset]",
    ":SidepanesClaude [preset]",
    ":SidepanesIPython",
    ":SidepanesIPythonRestart",
    ":SidepanesIPythonClear",
    ":SidepanesFocus",
    ":SidepanesZoom",
    ":SidepanesWidth [value]",
    ":SidepanesWidthPick",
    ":SidepanesAsk",
    ":SidepanesAskCodex [preset]",
    ":SidepanesAskClaude [preset]",
}) do
    assert_has(docs, item)
end

for _, item in ipairs({
    "setup(opts)",
    "get_config()",
    "open(path)",
    "toggle(path)",
    "close()",
    "is_open()",
    "focus_toggle()",
    "toggle_zoom()",
    "show_markdown()",
    "get_width()",
    "set_width(value)",
    "adjust_width(delta)",
    "snap_width(direction)",
    "width_picker()",
    "toggle_sticky_relative_width(enabled)",
    "text_width()",
    "toggle_wrap()",
    "pick()",
    "pick_headings()",
    "switch_picker()",
    "switch_to(target, opts)",
    "make_switch_entry(target, opts)",
    "open_terminal(tool_name, preset_name, opts)",
    "show_last_terminal(opts)",
    "toggle_markdown_terminal()",
    "show_last_agent(opts)",
    "toggle_markdown_agent()",
    "open_ipython(opts)",
    "send_ipython(opts)",
    "clear_ipython(opts)",
    "restart_ipython(opts)",
    "ask(tool_name, preset_name, opts)",
    "ask_picker(opts)",
    "ask_last_coding_agent(opts)",
    "ask_current_coding_agent(tool_name, opts)",
    "shutdown_terminals(opts)",
}) do
    assert_has(docs, item)
end

for _, item in ipairs({
    "layout",
    "markdown",
    "lifecycle",
    "validation",
    "commands",
    "mappings",
    "tools",
}) do
    assert_has(markdown, item, item)
end

for _, item in ipairs({
    "toggle",
    "pick",
    "headings",
    "markdown",
    "codex",
    "claude",
    "ipython",
    "restart_ipython",
    "send_ipython",
    "clear_ipython",
    "focus",
    "zoom",
    "width_previous",
    "width_next",
    "width_picker",
    "sticky_relative_width",
    "switch",
    "ask",
    "ask_last",
    "ask_codex",
    "ask_claude",
    "toggle_agent",
    "toggle_agent_alt",
    "ipython_alt",
    "gf",
}) do
    assert_has(markdown, "`" .. item .. "`", item)
end

for _, item in ipairs({
    ":MarkdownReflow [width]",
    "sidepanes.markdown_reflow",
    "external_reflow_cmd",
    "external_reflow_fallback",
    "external_reflow_protect_tables",
    "mappings.reflow",
    "telescope.nvim",
    "Treesitter",
    "markview",
    "mdfmt",
    "codex",
    "claude",
    "ipython",
    "Compatibility",
    "Older flat runtime keys",
    ":Sidepanes width prev",
    "Release Policy",
    "CHANGELOG.md",
    "semantic versioning",
    "markdown-reflow.nvim",
}) do
    assert_has(docs, item)
end

print("sidepanes docs contract smoke passed")
