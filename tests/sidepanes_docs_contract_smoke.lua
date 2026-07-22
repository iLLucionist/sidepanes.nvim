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
local release_notes = read("docs/release-notes-v0.3.0.md")
local release_notes_040 = read("docs/release-notes-v0.4.0.md")
local ask_roadmap = read("docs/ask-pane-roadmap.md")
local ci = read(".github/workflows/tests.yml")
local docs = table.concat({ help, markdown, readme, changelog, release_notes, release_notes_040, ask_roadmap, ci }, "\n")
local ask_behavior_matrix = dofile(plugin_root .. "/tests/ask_pane_behavior_matrix.lua")
local ask_mapping_zone_matrix = dofile(plugin_root .. "/tests/ask_pane_mapping_zone_matrix.lua")

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
    ":Sidepanes ask-append",
    ":Sidepanes submit-question",
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
    ":SidepanesAskAppend",
    ":SidepanesSubmitQuestion",
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
    "show_ask_pane(opts)",
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
    "append_to_ask(opts)",
    "submit_ask_pane()",
    "shutdown_terminals(opts)",
}) do
    assert_has(docs, item)
end

for _, item in ipairs({
    "layout",
    "markdown",
    "terminal",
    "lifecycle",
    "ask",
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
    "ask_pane",
    "ask",
    "ask_last",
    "ask_codex",
    "ask_claude",
    "toggle_terminal",
    "toggle_terminal_alt",
    "toggle_agent",
    "toggle_agent_alt",
    "ipython_alt",
    "headings",
    "ask_submit",
    "ask_send",
    "ask_send_alt",
    "ask_next_file",
    "ask_previous_file",
    "ask_next_selection",
    "ask_previous_selection",
    "ask_source",
    "ask_model_picker",
    "ask_model_picker_alt",
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
    "markdown.auto_reload",
    "markdown.reload_interval_ms",
    "markdown.reload_badge.min_display_ms",
    "markdown.reload_badge",
    "[RELOADED]",
    "SidepanesReloaded",
    "switching back to Markdown now restarts",
    "visible minimum-display window",
    "terminal.agent_resume_badge",
    "terminal.auto_resume",
    "terminal.resume.infer_from_transcripts",
    "terminal.resume.mechanisms",
    "terminal.resume.store_path",
    "terminal.resume.store_lock_timeout_ms",
    "terminal.resume.store_lock_stale_ms",
    "terminal.resume.resolver",
    "terminal.resume.failure_timeout_ms",
    "terminal.resume.failure_action",
    "project.root_markers",
    "project.resolver",
    "vim.fs.root()",
    "nested equal-priority marker groups",
    "lspconfig.util.root_pattern()",
    "wildcard/glob",
    "[RESUMED]",
    "SidepanesResumed",
    "SessionStart",
    "terminal_output",
    "Codex terminal-output captures",
    "codex resume <session-id>",
    "session_meta",
    "<C-c>",
    "Keyboard interrupt",
    "Sidepanes-owned",
    "tool name + detected project root",
    "terminal ptys",
    "atomic writes",
    "lock directory",
    "source evidence",
    "opts.purpose",
    "stable context copy",
    "Built-in mechanism names",
    "built-in mechanism",
    "session identity discovery",
    "does not guess",
    "stale resume id",
    "more finicky than originally anticipated",
    "resumes CLI sessions",
    "terminal-input mode",
    "lifecycle.focus_on_pick",
    "focus_on_pick",
    "CursorFG",
    ":Sidepanes width prev",
    "Release Policy",
    "CHANGELOG.md",
    "tests/run_checks.sh fast",
    "tests/run_checks.sh full",
    "nvim --version",
    "semantic versioning",
    "markdown-reflow.nvim",
    "v0.4.0",
    "ask.ui",
    "ask.auto_append",
    "ask.duplicate_policy",
    "ask.model_picker",
    "ask_pane = \"<leader>pa\"",
    "ask_pane = \"ap\"",
    "ask_submit = \"<C-CR>\"",
    "ask_model_picker = \"M\"",
    "ask_model_picker_alt = \"<Tab>\"",
    "model_picker = \"manual\"",
    "duplicate_policy = \"skip\"",
    "after_open",
    "before_send",
    "SidepanesAskAppend",
    "SidepanesSubmitQuestion",
    "append_to_ask(opts)",
    "submit_ask_pane()",
    "show_ask_pane(opts)",
    "Selection:",
    "exact duplicate file/range citations",
    "Plain normal-mode `q` is not mapped",
    "`:q` after `:w` sends",
    "`:q!` always cancels",
    "restores the previous",
    "winbar shows",
    "target/model",
    "cross-root selections",
}) do
    assert_has(docs, item)
end

for _, item in ipairs({
    "Full documentation:",
    "[doc/sidepanes.md](doc/sidepanes.md)",
    "## Tutorial",
    "## Mappings",
    "complete functionality",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "OXY2DEV/markview.nvim",
    "markdown_inline",
    "`mappings.global`",
    "`mappings.pane`",
}) do
    assert_has(readme, item, "README " .. item)
end

local function contains_value(values, needle)
    if type(values) ~= "table" then
        return false
    end

    for _, value in ipairs(values or {}) do
        if value == needle then
            return true
        end
    end

    return false
end

local function matrix_contains(field, needle)
    for _, row in ipairs(ask_behavior_matrix.rows or {}) do
        local value = row[field]

        if value == needle or (type(value) == "string" and value:find(needle, 1, true)) then
            return true
        end

        if contains_value(value, needle) then
            return true
        end
    end

    return false
end

for _, action in ipairs(ask_behavior_matrix.required_actions) do
    assert(matrix_contains("action", action) or matrix_contains("aliases", action), "ask behavior matrix missing action: " .. action)
    assert_has(ask_roadmap, action, "ask roadmap action " .. action)
end

for _, alias in ipairs(ask_behavior_matrix.required_aliases) do
    assert(matrix_contains("aliases", alias) or matrix_contains("action", alias), "ask behavior matrix missing alias: " .. alias)
    assert_has(ask_roadmap, alias, "ask roadmap alias " .. alias)
end

for _, zone in ipairs(ask_behavior_matrix.required_zones) do
    assert(matrix_contains("zone", zone), "ask behavior matrix missing zone: " .. zone)
    assert_has(ask_roadmap, zone, "ask roadmap zone " .. zone)
end

for _, state in ipairs(ask_behavior_matrix.required_states) do
    assert(matrix_contains("state", state), "ask behavior matrix missing draft state: " .. state)
    assert_has(ask_roadmap, state, "ask roadmap draft state " .. state)
end

for _, result in ipairs(ask_behavior_matrix.required_results) do
    assert(matrix_contains("results", result), "ask behavior matrix missing result: " .. result)
    assert_has(ask_roadmap, result, "ask roadmap result " .. result)
end

for _, row in ipairs(ask_behavior_matrix.rows) do
    assert(row.id and row.id ~= "", "ask behavior matrix row missing id")
    assert_has(ask_roadmap, row.id, "ask roadmap matrix row " .. row.id)
end

for _, zone in ipairs(ask_mapping_zone_matrix.required_zones) do
    assert_has(ask_roadmap, zone, "ask mapping zone " .. zone)
end

for _, mapping in ipairs(ask_mapping_zone_matrix.required_mappings) do
    assert_has(ask_roadmap, mapping, "ask mapping zone matrix mapping " .. mapping)
end

for _, command in ipairs(ask_mapping_zone_matrix.required_commands) do
    assert_has(ask_roadmap, command, "ask mapping zone matrix command " .. command)
end

for _, command in ipairs(ask_mapping_zone_matrix.planned_commands) do
    assert_has(ask_roadmap, command, "ask mapping zone matrix planned command " .. command)
    assert_has(ask_roadmap, "planned", "planned command marker for " .. command)
end

for _, row in ipairs(ask_mapping_zone_matrix.rows) do
    assert(row.id and row.id ~= "", "ask mapping zone matrix row missing id")
    assert_has(ask_roadmap, row.id, "ask roadmap mapping zone row " .. row.id)
end

print("sidepanes docs contract smoke passed")
