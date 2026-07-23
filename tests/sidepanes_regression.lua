local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local helpers = dofile(test_dir .. "/helpers.lua")
helpers.append_repo_root(1)

local ask_behavior_matrix = dofile(test_dir .. "/ask_pane_behavior_matrix.lua")
local ask_mapping_coverage = dofile(test_dir .. "/ask_pane_mapping_coverage.lua")
local ask_mapping_zone_matrix = dofile(test_dir .. "/ask_pane_mapping_zone_matrix.lua")
local defaults = require("sidepanes.defaults")
local agent_session = require("sidepanes.agent_session")
local api_helpers = require("sidepanes.api")
local ask_cmdline = require("sidepanes.ask_cmdline")
local ask_controller = require("sidepanes.ask_controller")
local ask_executor = require("sidepanes.ask_executor")
local ask_pane_module = require("sidepanes.ask_pane")
local ask_pane_entry = require("sidepanes.panes.ask")
local ask_prompt = require("sidepanes.ask_prompt")
local ask_policy = require("sidepanes.ask_policy")
local ask_route = require("sidepanes.ask_route")
local ask_session = require("sidepanes.ask_session")
local ask_status = require("sidepanes.panes.ask.status")
local ask_target_resolver = require("sidepanes.ask_target_resolver")
local commands = require("sidepanes.commands")
local config = require("sidepanes.config")
local dependencies = require("sidepanes.dependencies")
local pane_context = require("sidepanes.context")
local document_picker = require("sidepanes.document_picker")
local entries = require("sidepanes.entries")
local global_maps = require("sidepanes.global_maps")
local health = require("sidepanes.health")
local heading_picker = require("sidepanes.heading_picker")
local local_maps = require("sidepanes.maps")
local mapping_help = require("sidepanes.mapping_help")
local nvim_tree_integration = require("sidepanes.integrations.nvim_tree")
local presets = require("sidepanes.presets")
local switcher = require("sidepanes.switcher")
local terminal_module = require("sidepanes.terminal")
local util = require("sidepanes.util")
local validation = require("sidepanes.validation")
local markdown_reflow = require("sidepanes.markdown_reflow")
local sidepanes_version = require("sidepanes.version")
local winbar_module = require("sidepanes.winbar")
local sidepanes = require("sidepanes")
local pane = sidepanes._state()

local tests = {}

local function test(name, fn)
    table.insert(tests, { name = name, fn = fn })
end

local function mkdir(path)
    vim.fn.mkdir(path, "p")
end

local function write(path, lines)
    vim.fn.writefile(lines, path)
end

local function has_map(bufnr, lhs, mode)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode or "n")) do
        if map.lhs == lhs then
            return true
        end
    end

    return false
end

local function expanded_leader(lhs)
    local leader = vim.g.mapleader or "\\"

    return lhs:gsub("<leader>", leader)
end

local function has_nowait_map(bufnr, lhs, mode)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode or "n")) do
        if map.lhs == lhs and map.nowait == 1 then
            return true
        end
    end

    return false
end

local function find_map(bufnr, lhs, mode)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode or "n")) do
        if map.lhs == lhs then
            return map
        end
    end

    error("missing map: " .. lhs)
end

local function call_map(bufnr, lhs, mode)
    local map = find_map(bufnr, lhs, mode)

    assert(map.callback, lhs .. " has no callback")
    map.callback()
end

local function global_map(lhs, mode)
    local found = vim.fn.maparg(lhs, mode or "n", false, true)

    assert(found and found.lhs ~= "", "missing global map: " .. lhs)
    assert(found.callback, lhs .. " has no callback")

    return found
end

local function only_question_buf()
    local found = nil

    for bufnr in pairs(pane.question_buffers or {}) do
        assert(not found, "more than one question buffer is open")
        found = bufnr
    end

    assert(found, "no question buffer is open")

    return found
end

local function set_question(bufnr, lines)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modified", true, { buf = bufnr })
end

local function read_file(path)
    if vim.fn.filereadable(path) == 0 then
        return ""
    end

    return table.concat(vim.fn.readfile(path), "\n")
end

local function wait_for_file(path, needle)
    local ok = vim.wait(1500, function()
        return read_file(path):find(needle, 1, true) ~= nil
    end, 20)

    assert(ok, "did not find " .. needle .. " in " .. path .. ":\n" .. read_file(path))
end

local function has_state(history, state_name)
    for _, item in ipairs(history or {}) do
        if item == state_name then
            return true
        end
    end

    return false
end

local function assert_state_history_contains(history, states, label)
    for _, state_name in ipairs(states) do
        assert(
            has_state(history, state_name),
            label .. " missing state " .. state_name .. ": " .. vim.inspect(history)
        )
    end
end

local function plan_actions(plan)
    local result = {}

    for _, item in ipairs(plan or {}) do
        table.insert(result, item.action)
    end

    return result
end

local function with_options(values, fn)
    local previous = {}

    for name in pairs(values) do
        previous[name] = vim.o[name]
    end

    for name, value in pairs(values) do
        vim.o[name] = value
    end

    local ok, err = xpcall(fn, debug.traceback)

    for name, value in pairs(previous) do
        vim.o[name] = value
    end

    if not ok then
        error(err)
    end
end

local function with_home(path, fn)
    local previous = vim.env.HOME

    vim.env.HOME = path

    local ok, err = xpcall(fn, debug.traceback)

    vim.env.HOME = previous

    if not ok then
        error(err)
    end
end

local function capture_notify(fn)
    local original = vim.notify
    local messages = {}

    vim.notify = function(message, level)
        table.insert(messages, { message = message, level = level })
    end

    local ok_call, err = pcall(fn, messages)

    vim.notify = original

    if not ok_call then
        error(err)
    end

    return messages
end

local function has_notify(messages, needle)
    for _, item in ipairs(messages) do
        if item.message:find(needle, 1, true) then
            return true
        end
    end

    return false
end

local function feed_user_keys(keys)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
end

local function feed_user_command(command)
    vim.cmd.stopinsert()
    feed_user_keys(":" .. command .. "<CR>")
end

local function feed_user_insert_keys(keys)
    vim.cmd.startinsert()
    feed_user_keys(keys)
end

local function wait_until(label, condition, timeout_ms)
    assert(vim.wait(timeout_ms or 1000, condition, 10), label)
end

local function assert_pane_window(winid, bufnr, label)
    assert(vim.api.nvim_win_is_valid(winid), label .. " closed side pane")
    assert(vim.api.nvim_win_get_buf(winid) == bufnr, label .. " showed wrong side pane buffer")
end

local function capture_health(fn)
    local original = vim.health
    local reports = {}

    vim.health = {
        start = function(message)
            table.insert(reports, { level = "start", message = message })
        end,
        ok = function(message)
            table.insert(reports, { level = "ok", message = message })
        end,
        warn = function(message)
            table.insert(reports, { level = "warn", message = message })
        end,
        error = function(message)
            table.insert(reports, { level = "error", message = message })
        end,
        info = function(message)
            table.insert(reports, { level = "info", message = message })
        end,
    }

    local ok_call, err = pcall(fn, reports)

    vim.health = original

    if not ok_call then
        error(err)
    end

    return reports
end

local function has_health_report(reports, level, needle)
    for _, report in ipairs(reports) do
        if report.level == level and report.message:find(needle, 1, true) then
            return true
        end
    end

    return false
end

local function reset_pane()
    pane.shutdown_terminals({ timeout_ms = 50 })
    local ask_bufnr = pane.ask_pane and pane.ask_pane.bufnr or nil
    local cmdline_enter = vim.fn.maparg("<CR>", "c", false, true)

    if
        type(cmdline_enter) == "table"
        and (cmdline_enter.desc == "Sidepanes ask pane command-line enter" or cmdline_enter.desc == "Sidepanes pane command-line enter")
    then
        pcall(vim.keymap.del, "c", "<CR>")
    end

    pane.ask_pane = {}

    if ask_bufnr and vim.api.nvim_buf_is_valid(ask_bufnr) then
        pcall(vim.api.nvim_buf_delete, ask_bufnr, { force = true })
    end
    if pane.markdown_reload_timer then
        pcall(function()
            pane.markdown_reload_timer:stop()
        end)
        pcall(function()
            pane.markdown_reload_timer:close()
        end)
    end
    pane.close()
    pane.zoomed = false
    pane.relative_width = nil
    pane.source = nil
    pane.markdown_view = nil
    pane.markdown_file_signature = nil
    pane.markdown_reloaded = false
    pane.markdown_reload_badge_armed = false
    pane.markdown_reload_token = 0
    pane.markdown_watcher_path = nil
    pane.markdown_reload_timer = nil
    pane.active_mode = "markdown"
    pane.active_terminal_key = nil
    pane.agent_sessions = {}
    pane.agent_session_tombstones = {}
    pane.config = vim.deepcopy(defaults.config)
end

local function root_fixture(name)
    local root = helpers.tmp_path("sidepanes-" .. name)

    vim.fn.delete(root, "rf")
    mkdir(root .. "/.git")
    mkdir(root .. "/docs")
    mkdir(root .. "/src")

    return root
end

test("project root detection uses configurable markers fallback and resolver", function()
    reset_pane()

    local root = helpers.tmp_path("sidepanes-project-marker-root")
    local outside = helpers.tmp_path("sidepanes-project-marker-outside")

    vim.fn.delete(root, "rf")
    vim.fn.delete(outside, "rf")
    mkdir(root .. "/docs")
    mkdir(outside .. "/docs")
    write(root .. "/pyproject.toml", { "[project]", "name = 'sidepanes-test'" })
    write(root .. "/docs/doc.md", { "# Doc" })
    write(outside .. "/docs/doc.md", { "# Outside" })

    assert(util.project_root_for_path(root .. "/docs/doc.md", {
        project_root_markers = { "pyproject.toml" },
    }) == root, "custom project marker did not resolve root")

    if vim.fs and vim.fs.root then
        local nested = root .. "/packages/app"

        mkdir(nested .. "/src")
        write(nested .. "/package.json", { "{}" })
        write(nested .. "/src/main.lua", { "return true" })

        assert(util.project_root_for_path(nested .. "/src/main.lua", {
            project_root_markers = { { "package.json", "pyproject.toml" }, ".git" },
        }) == nested, "native nested project marker group did not resolve path root")

        assert(util.project_root_for_path(root .. "/docs/doc.md", {
            project_root_markers = function(name)
                return name == "pyproject.toml"
            end,
        }) == root, "native function project marker did not resolve path root")

        local bufnr = vim.api.nvim_create_buf(false, true)

        vim.api.nvim_buf_set_name(bufnr, nested .. "/src/main.lua")
        assert(util.project_root(bufnr, {
            project_root_markers = { { "package.json", "pyproject.toml" }, ".git" },
        }) == nested, "native nested project marker group did not resolve buffer root")
    end

    assert(util.project_root_for_path(outside .. "/docs/doc.md", {
        project_root_markers = { "pyproject.toml" },
        project_root_fallback = "buffer_dir",
    }) == vim.fn.fnamemodify(outside .. "/docs", ":p"), "buffer_dir fallback did not resolve file directory")

    assert(util.project_root_for_path(outside .. "/docs/doc.md", {
        project_root_markers = { "pyproject.toml" },
        project_root_fallback = "cwd",
    }) == vim.fn.fnamemodify(vim.fn.getcwd(), ":p"), "cwd fallback did not resolve current directory")

    assert(util.project_root_for_path(root .. "/docs/doc.md", {
        project_root_resolver = function(path, opts)
            assert(path:find("doc.md", 1, true), "resolver did not receive path")
            assert(opts.kind == "path", "resolver did not receive path kind")
            return outside
        end,
    }) == vim.fn.fnamemodify(outside, ":p"), "custom project resolver did not override root")

    local old_root = vim.fs and vim.fs.root or nil

    if vim.fs then
        vim.fs.root = nil
    end

    local ok, fallback_root = pcall(function()
        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(bufnr, root .. "/docs/doc.md")
        return util.project_root(bufnr, {
            project_root_markers = { "pyproject.toml" },
        })
    end)

    if vim.fs then
        vim.fs.root = old_root
    end

    assert(ok, fallback_root)
    assert(fallback_root == root, "vim.fs.find fallback resolved marker file instead of root")
end)

test("agent terminal keys canonicalize equivalent project roots", function()
    reset_pane()

    local root = root_fixture("agent-session-canonical-key-root")
    local link = helpers.tmp_path("sidepanes-agent-session-canonical-key-link")

    vim.fn.delete(link, "rf")

    local uv = vim.uv or vim.loop

    if not (uv and uv.fs_symlink) then
        return
    end

    local ok = pcall(uv.fs_symlink, root, link, { dir = true })

    if not ok then
        return
    end

    local key = util.terminal_key("codex", root)
    local link_key = util.terminal_key("codex", link)

    assert(key == link_key, "symlinked project root produced a different terminal key")

    local state = {
        config = {
            agent_resume_resolver = function(_, _, opts)
                return opts.remembered and opts.remembered.session_id
            end,
        },
        agent_sessions = {
            [key] = {
                key = key,
                tool_name = "codex",
                root = root,
                session_id = "canonical-session",
                source = "resolver",
            },
        },
    }
    local resume = agent_session.resolve_resume(state, nil, "codex", link)

    assert(resume and resume.session_id == "canonical-session", "canonical remembered session was not found through equivalent root")
end)

test("public facade hides mutable state and exposes config copy", function()
    reset_pane()

    local public_functions = {
        "setup",
        "open",
        "toggle",
        "close",
        "is_open",
        "focus_toggle",
        "show_ask_pane",
        "toggle_zoom",
        "get_width",
        "set_width",
        "adjust_width",
        "snap_width",
        "width_picker",
        "toggle_sticky_relative_width",
        "show_markdown",
        "switch_picker",
        "switch_to",
        "make_switch_entry",
        "pick",
        "pick_headings",
        "open_terminal",
        "show_last_terminal",
        "toggle_markdown_terminal",
        "open_ipython",
        "send_ipython",
        "clear_ipython",
        "restart_ipython",
        "ask",
        "ask_picker",
        "append_to_ask",
        "submit_ask_pane",
        "ask_last_coding_agent",
        "ask_current_coding_agent",
        "shutdown_terminals",
        "get_config",
    }
    local compatibility_functions = {
        "show_last_agent",
        "toggle_markdown_agent",
        "text_width",
        "toggle_wrap",
    }
    local hidden_fields = {
        "bufnr",
        "winid",
        "source",
        "markdown_view",
        "markdown_file_signature",
        "markdown_reloaded",
        "markdown_reload_badge_armed",
        "markdown_reload_token",
        "markdown_watcher_path",
        "markdown_reload_timer",
        "active_mode",
        "active_terminal_key",
        "last_focus_win",
        "terminals",
        "agent_sessions",
        "question_buffers",
        "ask_pane",
        "zoomed",
        "config",
        "switch",
        "ask_with_entry",
        "cancel_question",
        "finish_question",
        "write_question",
        "change_question_target",
        "cancel_ask_pane",
        "write_ask_pane",
        "finish_ask_pane",
        "change_ask_pane_target",
    }

    for _, name in ipairs(public_functions) do
        assert(type(sidepanes[name]) == "function", "missing public function: " .. name)
    end

    for _, name in ipairs(compatibility_functions) do
        assert(type(sidepanes[name]) == "function", "missing compatibility facade function: " .. name)
    end

    for _, name in ipairs(hidden_fields) do
        assert(sidepanes[name] == nil, "mutable state leaked through public facade: " .. name)
    end

    local internal = require("sidepanes.internal")

    for _, name in ipairs({
        "switch",
        "ask_with_entry",
        "cancel_question",
        "finish_question",
        "write_question",
        "change_question_target",
        "cancel_ask_pane",
        "write_ask_pane",
        "finish_ask_pane",
        "submit_ask_pane",
        "change_ask_pane_target",
    }) do
        assert(type(internal[name]) == "function", "missing internal function: " .. name)
    end

    local first = sidepanes.get_config()

    first.width = 999
    first.tools.codex.presets[1].name = "mutated"

    local second = sidepanes.get_config()

    assert(second.width == defaults.config.width, "get_config returned mutable config table")
    assert(second.tools.codex.presets[1].name == defaults.config.tools.codex.presets[1].name, "get_config returned nested mutable config")
    assert(sidepanes._state() == pane, "internal state escape hatch changed identity")
    assert(sidepanes.text_width() == pane.text_width(), "facade did not delegate text_width")
end)

test("agent session resume commands use native tool forms", function()
    local claude_cmd, claude_resumed = agent_session.resume_command("claude", { "claude", "--model", "sonnet" }, "claude-session")
    local codex_cmd, codex_resumed = agent_session.resume_command("codex", { "codex", "--cd", "/repo", "--model", "gpt-5.5" }, "codex-session")
    local sh_cmd, sh_resumed = agent_session.resume_command("claude", { "sh", "-c", "sleep 10" }, "claude-session")

    assert(claude_resumed == true, "Claude command was not marked resumed")
    assert(vim.deep_equal(claude_cmd, { "claude", "--resume", "claude-session", "--model", "sonnet" }), "Claude resume command was wrong")
    assert(codex_resumed == true, "Codex command was not marked resumed")
    assert(vim.deep_equal(codex_cmd, { "codex", "resume", "--cd", "/repo", "--model", "gpt-5.5", "codex-session" }), "Codex resume command was wrong")
    assert(sh_resumed == false, "non-Claude command was marked resumed")
    assert(vim.deep_equal(sh_cmd, { "sh", "-c", "sleep 10" }), "non-Claude command was rewritten")
end)

test("Claude hook capture records Sidepanes-owned session ids", function()
    reset_pane()

    local root = root_fixture("agent-session-claude-hook-root")
    local state = {
        config = vim.deepcopy(defaults.config),
        agent_sessions = {},
    }
    local ctx = {
        key = util.terminal_key("claude", root),
        tool_name = "claude",
        root = root,
    }

    local cmd = agent_session.prepare_command(state, ctx, { "claude", "--model", "sonnet" })

    assert(cmd[1] == "claude" and cmd[2] == "--settings", "Claude hook capture did not inject --settings")
    assert(ctx.session_capture and vim.fn.filereadable(ctx.session_capture.settings_path) == 1, "Claude hook settings file was not written")

    local settings = read_file(ctx.session_capture.settings_path)
    local hook_command = settings:match('"command"%s*:%s*"([^"]+)"')

    assert(hook_command, settings)

    vim.fn.system(hook_command, vim.json.encode({
        session_id = "claude-hook-session",
        transcript_path = "/tmp/claude-hook-session.jsonl",
        cwd = root,
        hook_event_name = "SessionStart",
    }))

    assert(agent_session.refresh_context(state, ctx) == "claude-hook-session", "Claude hook capture did not refresh context")
    assert(state.agent_sessions[ctx.key].session_id == "claude-hook-session", "Claude hook session was not remembered")
    assert(state.agent_sessions[ctx.key].source == "capture", "Claude hook session source was not recorded")
end)

test("Claude hook capture paths are unique per terminal start", function()
    reset_pane()

    local root = root_fixture("agent-session-claude-hook-unique-root")
    local state = {
        config = vim.deepcopy(defaults.config),
        agent_sessions = {},
    }
    local first = {
        key = util.terminal_key("claude", root),
        tool_name = "claude",
        root = root,
    }
    local second = {
        key = util.terminal_key("claude", root),
        tool_name = "claude",
        root = root,
    }

    agent_session.prepare_command(state, first, { "claude" })
    agent_session.prepare_command(state, second, { "claude" })

    assert(first.session_capture.path ~= second.session_capture.path, "Claude hook capture path was reused across starts")
end)

test("agent sessions discover Claude pid metadata and project fallback", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-claude")
    local root = root_fixture("agent-session-claude-root")
    local project_dir = util.normalize_project_root(root):gsub("/$", ""):gsub("/", "-")
    local state = { agent_sessions = {} }
    local key = util.terminal_key("claude", root)
    local ctx = {
        key = key,
        tool_name = "claude",
        root = root,
        pid = 4242,
    }

    vim.fn.delete(home, "rf")
    mkdir(home .. "/.claude/sessions")
    mkdir(home .. "/.claude/projects/" .. project_dir)

    with_home(home, function()
        write(home .. "/.claude/sessions/4242.json", {
            vim.json.encode({
                pid = 4242,
                sessionId = "claude-pid-session",
                cwd = root,
            }),
        })

        assert(agent_session.refresh_context(state, ctx) == "claude-pid-session", "Claude pid metadata did not refresh context")
        assert(ctx.session_id == "claude-pid-session", "Claude session id was not written to context")
        assert(state.agent_sessions[key].session_id == "claude-pid-session", "Claude session id was not remembered")

        ctx.pid = 9999
        ctx.session_id = nil
        state.agent_sessions = {}
        write(home .. "/.claude/projects/" .. project_dir .. "/fallback-session.jsonl", {
            vim.json.encode({ sessionId = "fallback-session" }),
        })

        assert(agent_session.resolve_resume_id(state, ctx, "claude", root) == "fallback-session", "Claude project fallback session was not discovered")
    end)
end)

test("agent sessions discover latest Codex session for project root", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-codex")
    local root = root_fixture("agent-session-codex-root")

    vim.fn.delete(home, "rf")
    mkdir(home .. "/.codex/sessions/2026/07/21")

    with_home(home, function()
        write(home .. "/.codex/sessions/2026/07/21/rollout-2026-07-21T10-00-00-codex-session.jsonl", {
            vim.json.encode({
                type = "event_msg",
                payload = {
                    cwd = root,
                    id = "wrong-event-id",
                    message = "metadata was not the first line",
                },
            }),
            vim.json.encode({
                type = "session_meta",
                payload = {
                    session_id = "codex-session",
                    cwd = root,
                },
            }),
        })

        assert(agent_session.latest_for_root("codex", root) == "codex-session", "Codex latest project session was not discovered")
    end)
end)

test("running agent contexts do not adopt stale transcript fallbacks", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-stale-running")
    local root = root_fixture("agent-session-stale-running-root")
    local project_dir = util.normalize_project_root(root):gsub("/$", ""):gsub("/", "-")
    local state = { agent_sessions = {} }

    vim.fn.delete(home, "rf")
    mkdir(home .. "/.claude/projects/" .. project_dir)
    write(home .. "/.claude/projects/" .. project_dir .. "/old-session.jsonl", {
        vim.json.encode({ sessionId = "old-session" }),
    })

    with_home(home, function()
        local job_id = vim.fn.jobstart({ "sh", "-c", "sleep 10" })
        local ctx = {
            key = util.terminal_key("claude", root),
            tool_name = "claude",
            root = root,
            job_id = job_id,
            initial_latest_session_id = "old-session",
        }

        assert(job_id > 0, "running context test job did not start")
        assert(agent_session.refresh_context(state, ctx) == nil, "running context adopted stale transcript fallback")
        assert(ctx.session_id == nil, "running context stored stale transcript session id")
        assert(state.agent_sessions[ctx.key] == nil, "running context remembered stale transcript")

        vim.fn.jobstop(job_id)
        vim.wait(1000, function()
            return not util.is_running(job_id)
        end, 20)

        assert(agent_session.refresh_context(state, ctx) == nil, "stopped fresh context adopted stale transcript fallback")
    end)
end)

test("running Codex context does not adopt ambiguous same-root transcripts", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-ambiguous-codex")
    local root = root_fixture("agent-session-ambiguous-codex-root")
    local state = { agent_sessions = {} }

    vim.fn.delete(home, "rf")
    mkdir(home .. "/.codex/sessions/2026/07/21")

    with_home(home, function()
        local job_id = vim.fn.jobstart({ "sh", "-c", "sleep 10" })
        local ctx = {
            key = util.terminal_key("codex", root),
            tool_name = "codex",
            root = root,
            job_id = job_id,
            started_at = os.time(),
        }

        assert(job_id > 0, "ambiguous Codex context test job did not start")

        write(home .. "/.codex/sessions/2026/07/21/first.jsonl", {
            vim.json.encode({
                type = "session_meta",
                payload = {
                    session_id = "first-ambiguous-session",
                    cwd = root,
                },
            }),
        })
        write(home .. "/.codex/sessions/2026/07/21/second.jsonl", {
            vim.json.encode({
                type = "session_meta",
                payload = {
                    session_id = "second-ambiguous-session",
                    cwd = root,
                },
            }),
        })

        assert(agent_session.refresh_context(state, ctx) == nil, "ambiguous Codex transcripts were adopted")
        assert(state.agent_sessions[ctx.key] == nil, "ambiguous Codex transcript session was remembered")

        vim.fn.jobstop(job_id)
    end)
end)

test("resume badge clearing can target a recovered terminal that is no longer active", function()
    local calls = 0
    local first = {
        resume_badge_visible = true,
        resume_badge_armed = true,
        resume_badge_token = 0,
    }
    local second = {
        resume_badge_visible = true,
        resume_badge_armed = true,
        resume_badge_token = 0,
    }
    local state = {
        active_terminal_key = "second",
        terminals = {
            first = first,
            second = second,
        },
    }

    local cleared = terminal_module.clear_resume_badge(state, {
        update_sticky_heading = function()
            calls = calls + 1
        end,
    }, first)

    assert(cleared == true, "explicit resume badge target was not cleared")
    assert(first.resume_badge_visible == false, "explicit resume badge target stayed visible")
    assert(second.resume_badge_visible == true, "active terminal badge was cleared instead of explicit target")
    assert(calls == 1, "resume badge clear did not refresh heading exactly once")
end)

test("agent sessions report remembered live process candidates", function()
    reset_pane()

    local root = root_fixture("agent-session-live-pid-root")
    local key = util.terminal_key("codex", root)
    local state = {
        config = {
            agent_resume_resolver = function(_, _, opts)
                return opts.remembered and opts.remembered.session_id
            end,
        },
        agent_sessions = {
            [key] = {
                tool_name = "codex",
                root = root,
                session_id = "live-codex-session",
                pid = vim.fn.getpid(),
                source = "resolver",
            },
        },
    }
    local resume = agent_session.resolve_resume(state, nil, "codex", root)

    assert(resume and resume.session_id == "live-codex-session", "remembered session was not used")
    assert(resume.pid == vim.fn.getpid(), "remembered pid was not returned")
    assert(resume.pid_running == true, "remembered live pid was not detected")
    assert(resume.source == "remembered", "remembered resume source was not reported")
end)

test("agent session registry saves atomically and merges independent writers", function()
    reset_pane()

    local store = helpers.tmp_path("sidepanes-agent-session-merge-store.json")
    local root_one = root_fixture("agent-session-merge-root-one")
    local root_two = root_fixture("agent-session-merge-root-two")
    local key_one = util.terminal_key("codex", root_one)
    local key_two = util.terminal_key("claude", root_two)
    local first = {
        config = {
            agent_resume_store_path = store,
        },
        agent_sessions = {
            [key_one] = {
                key = key_one,
                tool_name = "codex",
                root = root_one,
                session_id = "codex-merge-session",
                source = "resolver",
                updated_at = 100,
            },
        },
    }
    local second = {
        config = {
            agent_resume_store_path = store,
        },
        agent_sessions = {
            [key_two] = {
                key = key_two,
                tool_name = "claude",
                root = root_two,
                session_id = "claude-merge-session",
                source = "resolver",
                updated_at = 200,
            },
        },
    }

    vim.fn.delete(store)
    assert(agent_session.save_store(first), "first registry save failed")
    assert(agent_session.save_store(second), "second registry save failed")

    local loaded = {
        config = {
            agent_resume_store_path = store,
        },
        agent_sessions = {},
    }

    assert(agent_session.load_store(loaded), "merged registry did not load")
    assert(loaded.agent_sessions[key_one].session_id == "codex-merge-session", "first writer registry entry was lost")
    assert(loaded.agent_sessions[key_two].session_id == "claude-merge-session", "second writer registry entry was lost")
    assert(vim.fn.glob(store .. ".tmp.*") == "", "atomic registry save left temp files behind")
end)

test("agent session registry recovers a stale writer lock", function()
    reset_pane()

    local store = helpers.tmp_path("sidepanes-agent-session-stale-lock-store.json")
    local root = root_fixture("agent-session-stale-lock-root")
    local key = util.terminal_key("codex", root)
    local lock = store .. ".lock"
    local state = {
        config = {
            agent_resume_store_path = store,
            agent_resume_store_lock_timeout_ms = 500,
            agent_resume_store_lock_stale_ms = 1,
        },
        agent_sessions = {
            [key] = {
                key = key,
                tool_name = "codex",
                root = root,
                session_id = "stale-lock-session",
                source = "resolver",
                updated_at = 100,
            },
        },
    }

    vim.fn.delete(store, "rf")
    vim.fn.delete(lock, "rf")
    mkdir(lock)
    write(lock .. "/owner.json", {
        vim.json.encode({
            pid = 0,
            created_at_ms = 0,
        }),
    })

    assert(agent_session.save_store(state), "registry did not recover stale writer lock")
    assert(vim.fn.isdirectory(lock) == 0, "registry lock directory was left behind")
    assert(read_file(store):find("stale%-lock%-session"), "registry store was not written after stale lock recovery")
end)

test("remembered sessions require valid source evidence", function()
    reset_pane()

    local root = root_fixture("agent-session-invalid-evidence-root")
    local key = util.terminal_key("codex", root)
    local missing_transcript = helpers.tmp_path("sidepanes-agent-missing-transcript.jsonl")
    local store = helpers.tmp_path("sidepanes-agent-invalid-evidence-store.json")
    local state = {
        config = {
            agent_resume_store_path = store,
        },
        agent_sessions = {
            [key] = {
                key = key,
                tool_name = "codex",
                root = root,
                session_id = "missing-evidence-session",
                source = "transcript",
                transcript_path = missing_transcript,
                updated_at = os.time(),
            },
        },
    }

    vim.fn.delete(missing_transcript)

    assert(agent_session.resolve_resume(state, nil, "codex", root) == nil, "remembered session with missing evidence was resumed")
    assert(state.agent_sessions[key] == nil, "invalid remembered session was not cleared")
end)

test("remembered sessions reject malformed but existing evidence", function()
    reset_pane()

    local root = root_fixture("agent-session-malformed-evidence-root")
    local other_root = root_fixture("agent-session-malformed-evidence-other-root")
    local key = util.terminal_key("codex", root)
    local capture_path = helpers.tmp_path("sidepanes-agent-malformed-capture.json")
    local metadata_path = helpers.tmp_path("sidepanes-agent-malformed-metadata.json")
    local transcript_path = helpers.tmp_path("sidepanes-agent-malformed-transcript.jsonl")

    local function stale_record(extra)
        return vim.tbl_extend("force", {
            key = key,
            tool_name = "codex",
            root = root,
            session_id = "expected-session",
            source = "transcript",
            updated_at = os.time(),
        }, extra or {})
    end

    write(capture_path, {
        vim.json.encode({
            session_id = "different-session",
            cwd = root,
        }),
    })
    local capture_state = {
        agent_sessions = {
            [key] = stale_record({
                source = "capture",
                capture_path = capture_path,
            }),
        },
    }

    assert(agent_session.resolve_resume(capture_state, nil, "codex", root) == nil, "mismatched capture evidence was trusted")
    assert(capture_state.agent_sessions[key] == nil, "mismatched capture record was not cleared")

    write(metadata_path, {
        vim.json.encode({
            session_id = "expected-session",
            cwd = other_root,
        }),
    })
    local metadata_state = {
        agent_sessions = {
            [key] = stale_record({
                source = "pid_metadata",
                metadata_path = metadata_path,
            }),
        },
    }

    assert(agent_session.resolve_resume(metadata_state, nil, "codex", root) == nil, "wrong-root metadata evidence was trusted")
    assert(metadata_state.agent_sessions[key] == nil, "wrong-root metadata record was not cleared")

    write(transcript_path, {
        vim.json.encode({
            type = "session_meta",
            payload = {
                session_id = "expected-session",
                cwd = other_root,
            },
        }),
    })
    local transcript_state = {
        agent_sessions = {
            [key] = stale_record({
                source = "transcript",
                transcript_path = transcript_path,
            }),
        },
    }

    assert(agent_session.resolve_resume(transcript_state, nil, "codex", root) == nil, "wrong-root transcript evidence was trusted")
    assert(transcript_state.agent_sessions[key] == nil, "wrong-root transcript record was not cleared")
end)

test("agent auto resume can be disabled even when a session is remembered", function()
    reset_pane()

    local root = root_fixture("agent-session-auto-resume-disabled-root")
    local key = util.terminal_key("codex", root)
    local state = {
        config = {
            agent_auto_resume = false,
        },
        agent_sessions = {
            [key] = {
                tool_name = "codex",
                root = root,
                session_id = "remembered-codex-session",
            },
        },
    }

    assert(agent_session.resolve_resume(state, nil, "codex", root) == nil, "auto_resume=false still resolved a remembered session")
end)

test("agent transcript inference can be disabled while preserving Claude pid metadata", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-inference-disabled")
    local root = root_fixture("agent-session-inference-disabled-root")
    local project_dir = util.normalize_project_root(root):gsub("/$", ""):gsub("/", "-")
    local state = {
        config = {
            agent_resume_infer_from_transcripts = false,
        },
        agent_sessions = {},
    }

    vim.fn.delete(home, "rf")
    mkdir(home .. "/.claude/sessions")
    mkdir(home .. "/.claude/projects/" .. project_dir)

    with_home(home, function()
        local ctx = {
            key = util.terminal_key("claude", root),
            tool_name = "claude",
            root = root,
            pid = 4242,
        }

        write(home .. "/.claude/projects/" .. project_dir .. "/transcript-session.jsonl", {
            vim.json.encode({ sessionId = "transcript-session" }),
        })

        assert(agent_session.refresh_context(state, ctx) == nil, "transcript inference disabled still adopted transcript session")

        write(home .. "/.claude/sessions/4242.json", {
            vim.json.encode({
                pid = 4242,
                sessionId = "pid-session",
                cwd = root,
            }),
        })

        assert(agent_session.refresh_context(state, ctx) == "pid-session", "Claude PID metadata did not work with transcript inference disabled")
    end)
end)

test("agent resume supports custom resolver mechanisms", function()
    reset_pane()

    local root = root_fixture("agent-session-custom-resolver-root")
    local state = {
        config = vim.tbl_deep_extend("force", vim.deepcopy(defaults.config), {
            agent_resume_mechanisms = false,
            agent_resume_resolver = function(tool_name, ctx, opts)
                assert(tool_name == "codex", "resolver received wrong tool")
                assert(ctx.root == root, "resolver received wrong root")
                assert(opts.key == ctx.key, "resolver received wrong key")
                assert(opts.state == nil, "resolver received mutable internal state")
                ctx.root = "mutated"
                return "custom-resolver-session"
            end,
        }),
        agent_sessions = {},
    }
    local ctx = {
        key = util.terminal_key("codex", root),
        tool_name = "codex",
        root = root,
    }

    assert(agent_session.refresh_context(state, ctx) == "custom-resolver-session", "custom resolver did not provide a session id")
    assert(ctx.root == root, "custom resolver mutated internal terminal context")
    assert(state.agent_sessions[ctx.key].session_id == "custom-resolver-session", "custom resolver session was not remembered")
    assert(state.agent_sessions[ctx.key].source == "resolver", "custom resolver source was not recorded")
end)

test("agent resume revalidates custom resolver records before reuse", function()
    reset_pane()

    local root = root_fixture("agent-session-custom-resolver-validate-root")
    local key = util.terminal_key("codex", root)
    local calls = {}
    local state = {
        config = vim.tbl_deep_extend("force", vim.deepcopy(defaults.config), {
            agent_resume_mechanisms = false,
            agent_resume_resolver = function(tool_name, ctx, opts)
                table.insert(calls, {
                    tool_name = tool_name,
                    purpose = opts.purpose,
                    remembered = opts.remembered,
                })

                if opts.purpose == "capture" then
                    return {
                        session_id = "resolver-session",
                        evidence = {
                            resolver_state = {
                                marker = "owned-by-sidepanes-test",
                            },
                        },
                    }
                elseif opts.purpose == "validate" and opts.remembered and opts.remembered.resolver_state and opts.remembered.resolver_state.marker == "owned-by-sidepanes-test" then
                    return {
                        session_id = opts.remembered.session_id,
                    }
                end

                return false
            end,
        }),
        agent_sessions = {},
    }
    local ctx = {
        key = key,
        tool_name = "codex",
        root = root,
    }

    assert(agent_session.refresh_context(state, ctx) == "resolver-session", "custom resolver did not capture a table result")
    assert(state.agent_sessions[key].resolver_state.marker == "owned-by-sidepanes-test", "custom resolver state was not stored")

    local resume = agent_session.resolve_resume(state, nil, "codex", root)

    assert(resume and resume.session_id == "resolver-session", "custom resolver record did not revalidate")
    assert(calls[#calls].purpose == "validate", "custom resolver was not called for validation")

    state.agent_sessions[key].resolver_state.marker = "tampered"

    assert(agent_session.resolve_resume(state, nil, "codex", root) == nil, "invalid custom resolver record was reused")
    assert(state.agent_sessions[key] == nil, "invalid custom resolver record was not cleared")
end)

test("agent recovery notification reports live previous pid without active wording", function()
    reset_pane()

    local bin = helpers.tmp_path("sidepanes-agent-bin-live-pid-notify")
    local root = root_fixture("agent-session-live-pid-notify-root")
    local args_file = helpers.tmp_path("sidepanes-agent-live-pid-notify-args.txt")
    local fake_codex = bin .. "/codex"
    local key = util.terminal_key("codex", root)

    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf '%s\\n' \"$@\" > " .. vim.fn.shellescape(args_file),
        "sleep 10",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    pane.agent_sessions[key] = {
        tool_name = "codex",
        root = root,
        session_id = "live-codex-session",
        pid = vim.fn.getpid(),
        source = "resolver",
    }
    pane.setup({
        terminal = {
            resume = {
                resolver = function(_, _, opts)
                    return opts.remembered and opts.remembered.session_id
                end,
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = fake_codex,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local messages = capture_notify(function()
        pane.open_terminal("codex", nil, { root = root, focus = false })
    end)
    local joined = table.concat(vim.tbl_map(function(item)
        return item.message
    end, messages), "\n")

    assert(joined:find("Recovered/resumed a lost Codex session", 1, true), joined)
    assert(joined:find("previous PID " .. tostring(vim.fn.getpid()) .. " still appears alive", 1, true), joined)
    assert(not joined:find("lost but active", 1, true), joined)
end)

test("opening Claude starts fresh when only an external latest project session exists", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-open-claude")
    local bin = helpers.tmp_path("sidepanes-agent-bin-open-claude")
    local root = root_fixture("agent-session-open-claude-root")
    local project_dir = util.normalize_project_root(root):gsub("/$", ""):gsub("/", "-")
    local args_file = helpers.tmp_path("sidepanes-agent-open-claude-args.txt")
    local fake_claude = bin .. "/claude"

    vim.fn.delete(home, "rf")
    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(home .. "/.claude/projects/" .. project_dir)
    mkdir(bin)
    write(home .. "/.claude/projects/" .. project_dir .. "/resume-session.jsonl", {
        vim.json.encode({ sessionId = "resume-session" }),
    })
    write(fake_claude, {
        "#!/bin/sh",
        "printf '%s\\n' \"$@\" > " .. vim.fn.shellescape(args_file),
        "sleep 10",
    })
    vim.fn.setfperm(fake_claude, "rwxr-xr-x")

    with_home(home, function()
        pane.setup({
            tools = {
                claude = {
                    label = "Claude",
                    cmd = fake_claude,
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
            terminal = {
                agent_resume_badge = {
                    text = "[RECOVERED]",
                },
            },
        })

        local ctx = nil
        local messages = capture_notify(function()
            ctx = pane.open_terminal("claude", nil, { root = root, focus = false })
        end)
        local wrote_args = vim.wait(2500, function()
            return vim.fn.filereadable(args_file) == 1
        end, 20)

        assert(ctx and ctx.tool_name == "claude", "Claude terminal did not open")
        assert(ctx.resumed == false, "Claude terminal resumed an external latest project session")
        assert(ctx.session_id == nil, "Claude terminal stored an external latest project session id")
        assert(ctx.resume_source == nil, "Claude terminal recorded an external latest project session source")
        assert(ctx.resume_badge_visible == false, "Claude terminal showed a resume badge for an external latest session")
        assert(not has_notify(messages, "Recovered/resumed a lost Claude session"), "Claude recovery notification was emitted for an external latest session")
        assert(wrote_args, "fake Claude did not record argv")
        assert(not read_file(args_file):find("--resume", 1, true), "Claude terminal launched with --resume for an external latest session")

        local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

        assert(not winbar:find("%#SidepanesResumed# [RECOVERED] ", 1, true), winbar)
    end)
end)

test("opening Codex resumes the same Sidepanes-owned session after terminal loss", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-codex-owned-reopen")
    local bin = helpers.tmp_path("sidepanes-agent-bin-codex-owned-reopen")
    local root = root_fixture("agent-session-codex-owned-reopen-root")
    local args_file = helpers.tmp_path("sidepanes-agent-codex-owned-reopen-args.txt")
    local fake_codex = bin .. "/codex"
    local session_id = "codex-owned-reopen-session"

    vim.fn.delete(home, "rf")
    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(home .. "/.codex/sessions/2026/07/21")
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf '%s\\n' \"$@\" >> " .. vim.fn.shellescape(args_file),
        "mkdir -p \"$HOME/.codex/sessions/2026/07/21\"",
        "printf '%s\\n' " .. vim.fn.shellescape(vim.json.encode({
            type = "session_meta",
            payload = {
                session_id = session_id,
                cwd = root,
            },
        })) .. " > \"$HOME/.codex/sessions/2026/07/21/rollout-codex-owned-reopen.jsonl\"",
        "sleep 10",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    with_home(home, function()
        pane.setup({
            tools = {
                codex = {
                    label = "Codex",
                    cmd = fake_codex,
                    include_cd_arg = true,
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
        })

        local first = pane.open_terminal("codex", nil, { root = root, focus = false })
        local remembered = vim.wait(2500, function()
            agent_session.refresh_context(pane, first)
            return pane.agent_sessions[first.key] and pane.agent_sessions[first.key].session_id == session_id
        end, 50)

        assert(remembered, "Codex session id was not captured from Sidepanes-owned startup")

        vim.fn.jobstop(first.job_id)
        vim.wait(1000, function()
            return not util.is_running(first.job_id)
        end, 20)

        vim.fn.delete(args_file)

        local second = pane.open_terminal("codex", nil, { root = root, focus = false })
        local wrote_args = vim.wait(1000, function()
            return vim.fn.filereadable(args_file) == 1
        end, 20)

        assert(second and second.resumed == true, "Codex terminal did not mark resumed reopen")
        assert(second.session_id == session_id, "Codex reopened with wrong session id")
        assert(wrote_args, "fake Codex did not record reopened argv")
        assert(read_file(args_file):find("resume", 1, true), "Codex reopened without resume subcommand")
        assert(read_file(args_file):find(session_id, 1, true), "Codex reopened without captured session id")
    end)
end)

test("opening Codex captures resume id from terminal output after exit", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-codex-output-reopen")
    local bin = helpers.tmp_path("sidepanes-agent-bin-codex-output-reopen")
    local root = root_fixture("agent-session-codex-output-reopen-root")
    local args_file = helpers.tmp_path("sidepanes-agent-codex-output-reopen-args.txt")
    local fake_codex = bin .. "/codex"
    local session_id = "019f84ba-6493-7ca3-b390-77bd025962e6"

    vim.fn.delete(home, "rf")
    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf 'run:%s\\n' \"$*\" >> " .. vim.fn.shellescape(args_file),
        "if [ \"$1\" = \"resume\" ]; then",
        "  sleep 10",
        "else",
        "  printf '%s\\n' 'To continue this session, run codex resume " .. session_id .. "'",
        "fi",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    with_home(home, function()
        pane.setup({
            tools = {
                codex = {
                    label = "Codex",
                    cmd = fake_codex,
                    include_cd_arg = true,
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
        })

        local first = pane.open_terminal("codex", nil, { root = root, focus = false })
        local remembered = vim.wait(2500, function()
            return first and not util.is_running(first.job_id) and pane.agent_sessions[first.key] and pane.agent_sessions[first.key].session_id == session_id
        end, 50)

        assert(remembered, "Codex resume id was not captured from terminal output:\n" .. table.concat(vim.api.nvim_buf_get_lines(first.bufnr, 0, -1, false), "\n"))
        assert(pane.agent_sessions[first.key].source == "terminal_output", "Codex terminal output source was not recorded")
        assert(vim.fn.filereadable(pane.agent_sessions[first.key].capture_path or "") == 1, "Codex terminal output capture file was not written")

        local loaded = {
            config = pane.config,
            agent_sessions = {},
        }

        assert(agent_session.load_store(loaded), "Codex terminal output session was not persisted")
        assert(agent_session.resolve_resume(loaded, nil, "codex", root).session_id == session_id, "persisted Codex terminal output session did not validate")

        vim.fn.delete(args_file)

        local second = pane.open_terminal("codex", nil, { root = root, focus = false })
        local wrote_args = vim.wait(1000, function()
            return vim.fn.filereadable(args_file) == 1
        end, 20)

        assert(second and second.resumed == true, "Codex terminal did not mark terminal-output reopen as resumed")
        assert(second.session_id == session_id, "Codex terminal-output reopen used the wrong session id")
        assert(wrote_args, "fake Codex did not record terminal-output reopen argv")
        assert(read_file(args_file):find("resume", 1, true), "Codex terminal-output reopen omitted resume subcommand")
        assert(read_file(args_file):find(session_id, 1, true), "Codex terminal-output reopen omitted captured session id")
    end)
end)

test("Codex terminal output capture respects resume mechanisms config", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-codex-output-disabled")
    local bin = helpers.tmp_path("sidepanes-agent-bin-codex-output-disabled")
    local root = root_fixture("agent-session-codex-output-disabled-root")
    local fake_codex = bin .. "/codex"

    vim.fn.delete(home, "rf")
    vim.fn.delete(bin, "rf")
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf '%s\\n' 'To continue this session, run codex resume disabled-output-session'",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    with_home(home, function()
        pane.setup({
            terminal = {
                resume = {
                    mechanisms = {
                        codex = { "transcript" },
                    },
                },
            },
            tools = {
                codex = {
                    label = "Codex",
                    cmd = fake_codex,
                    include_cd_arg = true,
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
        })

        local ctx = pane.open_terminal("codex", nil, { root = root, focus = false })
        local stopped = vim.wait(1000, function()
            return ctx and not util.is_running(ctx.job_id)
        end, 20)

        assert(stopped, "fake Codex did not exit")
        assert(not pane.agent_sessions[ctx.key], "Codex terminal output was captured despite disabled terminal_output mechanism")
    end)
end)

test("failed remembered Codex resume clears stale session and starts fresh", function()
    reset_pane()

    local bin = helpers.tmp_path("sidepanes-agent-bin-codex-failed-resume")
    local root = root_fixture("agent-session-codex-failed-resume-root")
    local args_file = helpers.tmp_path("sidepanes-agent-codex-failed-resume-args.txt")
    local fake_codex = bin .. "/codex"
    local key = util.terminal_key("codex", root)

    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf 'run:%s\\n' \"$*\" >> " .. vim.fn.shellescape(args_file),
        "if [ \"${1:-}\" = 'resume' ]; then exit 7; fi",
        "sleep 10",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    pane.agent_sessions[key] = {
        key = key,
        tool_name = "codex",
        root = root,
        session_id = "stale-codex-session",
        source = "resolver",
        updated_at = os.time(),
    }
    pane.setup({
        terminal = {
            resume = {
                resolver = function(_, _, opts)
                    return opts.remembered and opts.remembered.session_id
                end,
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = fake_codex,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local initial = nil
    local messages = capture_notify(function()
        initial = pane.open_terminal("codex", nil, { root = root, focus = false })
        local restarted = vim.wait(3500, function()
            local text = read_file(args_file)
            local _, runs = text:gsub("run:", "")
            local current = pane.terminals[key]

            return runs >= 2 and current and current ~= initial and util.is_running(current.job_id)
        end, 50)

        assert(restarted, "failed resume did not start a fresh Codex process:\n" .. read_file(args_file))
    end)
    local args = read_file(args_file)
    local current = pane.terminals[key]

    assert(initial and initial.resumed == true, "initial stale Codex launch did not try resume")
    assert(args:find("stale%-codex%-session"), args)
    assert(args:find("run:--cd " .. root, 1, true), args)
    assert(current and current.resumed == false, "fresh Codex retry was marked resumed")
    assert(pane.agent_sessions[key] == nil, "stale Codex session was not cleared")
    assert(has_notify(messages, "cleared stale resume id and starting fresh"), "stale resume notification was not emitted")
end)

test("failed remembered Codex resume respects timeout and action config", function()
    reset_pane()

    local bin = helpers.tmp_path("sidepanes-agent-bin-codex-failed-resume-config")
    local root = root_fixture("agent-session-codex-failed-resume-config-root")
    local args_file = helpers.tmp_path("sidepanes-agent-codex-failed-resume-config-args.txt")
    local fake_codex = bin .. "/codex"
    local key = util.terminal_key("codex", root)

    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(bin)
    write(fake_codex, {
        "#!/bin/sh",
        "printf 'run:%s\\n' \"$*\" >> " .. vim.fn.shellescape(args_file),
        "if [ \"${1:-}\" = 'resume' ]; then sleep 1; exit 7; fi",
        "sleep 10",
    })
    vim.fn.setfperm(fake_codex, "rwxr-xr-x")

    pane.agent_sessions[key] = {
        key = key,
        tool_name = "codex",
        root = root,
        session_id = "slow-stale-session",
        source = "resolver",
        updated_at = os.time(),
    }
    pane.setup({
        terminal = {
            resume = {
                resolver = function(_, _, opts)
                    return opts.remembered and opts.remembered.session_id
                end,
                failure_timeout_ms = 100,
                failure_action = "fresh",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = fake_codex,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local initial = pane.open_terminal("codex", nil, { root = root, focus = false })
    local exited = vim.wait(2500, function()
        return initial and not util.is_running(initial.job_id)
    end, 50)

    assert(exited, "slow failing resume did not exit")
    assert(read_file(args_file):find("slow%-stale%-session"), read_file(args_file))
    assert(select(2, read_file(args_file):gsub("run:", "")) == 1, "slow failing resume unexpectedly started fresh")
    assert(pane.agent_sessions[key], "slow failing resume cleared session after timeout")

    reset_pane()
    vim.fn.delete(args_file)

    pane.agent_sessions[key] = {
        key = key,
        tool_name = "codex",
        root = root,
        session_id = "notify-stale-session",
        source = "resolver",
        updated_at = os.time(),
    }
    pane.setup({
        terminal = {
            resume = {
                resolver = function(_, _, opts)
                    return opts.remembered and opts.remembered.session_id
                end,
                failure_timeout_ms = 1500,
                failure_action = "notify",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = fake_codex,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local messages = capture_notify(function()
        local notify_initial = pane.open_terminal("codex", nil, { root = root, focus = false })
        local notify_exited = vim.wait(2500, function()
            return notify_initial and not util.is_running(notify_initial.job_id)
        end, 50)

        assert(notify_exited, "notify-mode failing resume did not exit")
        vim.wait(200, function()
            return false
        end)
    end)

    assert(select(2, read_file(args_file):gsub("run:", "")) == 1, "notify failure action unexpectedly started fresh")
    assert(pane.agent_sessions[key] == nil, "notify failure action did not clear stale session")
    assert(has_notify(messages, "cleared stale resume id."), "notify failure action did not report stale session")

    reset_pane()
    vim.fn.delete(args_file)

    pane.agent_sessions[key] = {
        key = key,
        tool_name = "codex",
        root = root,
        session_id = "ignore-stale-session",
        source = "resolver",
        updated_at = os.time(),
    }
    pane.setup({
        terminal = {
            resume = {
                resolver = function(_, _, opts)
                    return opts.remembered and opts.remembered.session_id
                end,
                failure_timeout_ms = 1500,
                failure_action = "ignore",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = fake_codex,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local ignore_initial = pane.open_terminal("codex", nil, { root = root, focus = false })
    local ignore_exited = vim.wait(2500, function()
        return ignore_initial and not util.is_running(ignore_initial.job_id)
    end, 50)

    assert(ignore_exited, "ignore-mode failing resume did not exit")
    assert(select(2, read_file(args_file):gsub("run:", "")) == 1, "ignore failure action unexpectedly started fresh")
    assert(pane.agent_sessions[key].session_id == "ignore-stale-session", "ignore failure action cleared stale session")
end)

test("opening Claude resumes the same hook-captured session after terminal loss", function()
    reset_pane()

    local home = helpers.tmp_path("sidepanes-agent-home-claude-hook-reopen")
    local bin = helpers.tmp_path("sidepanes-agent-bin-claude-hook-reopen")
    local root = root_fixture("agent-session-claude-hook-reopen-root")
    local args_file = helpers.tmp_path("sidepanes-agent-claude-hook-reopen-args.txt")
    local fake_claude = bin .. "/claude"
    local session_id = "claude-hook-reopen-session"

    vim.fn.delete(home, "rf")
    vim.fn.delete(bin, "rf")
    vim.fn.delete(args_file)
    mkdir(bin)
    write(fake_claude, {
        "#!/bin/sh",
        "printf '%s\\n' \"$@\" >> " .. vim.fn.shellescape(args_file),
        "settings=''",
        "prev=''",
        "for arg in \"$@\"; do",
        "  if [ \"$prev\" = '--settings' ]; then settings=\"$arg\"; fi",
        "  prev=\"$arg\"",
        "done",
        "if [ -n \"$settings\" ]; then",
        "  command=$(sed -n 's/.*\"command\":\"\\([^\"]*\\)\".*/\\1/p' \"$settings\")",
        "  if [ -n \"$command\" ]; then",
        "    printf '%s\\n' " .. vim.fn.shellescape(vim.json.encode({
            session_id = session_id,
            transcript_path = home .. "/.claude/projects/project/" .. session_id .. ".jsonl",
            cwd = root,
            hook_event_name = "SessionStart",
        })) .. " | sh -c \"$command\"",
        "  fi",
        "fi",
        "sleep 10",
    })
    vim.fn.setfperm(fake_claude, "rwxr-xr-x")

    with_home(home, function()
        pane.setup({
            tools = {
                claude = {
                    label = "Claude",
                    cmd = fake_claude,
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
        })

        local first = pane.open_terminal("claude", nil, { root = root, focus = false })
        local remembered = vim.wait(2500, function()
            agent_session.refresh_context(pane, first)
            return pane.agent_sessions[first.key] and pane.agent_sessions[first.key].session_id == session_id
        end, 50)

        assert(remembered, "Claude session id was not captured from SessionStart hook")

        vim.fn.jobstop(first.job_id)
        vim.wait(1000, function()
            return not util.is_running(first.job_id)
        end, 20)

        vim.fn.delete(args_file)

        local second = pane.open_terminal("claude", nil, { root = root, focus = false })
        local wrote_args = vim.wait(1000, function()
            return vim.fn.filereadable(args_file) == 1
        end, 20)

        assert(second and second.resumed == true, "Claude terminal did not mark resumed reopen")
        assert(second.session_id == session_id, "Claude reopened with wrong session id")
        assert(wrote_args, "fake Claude did not record reopened argv")
        assert(read_file(args_file):find("--resume", 1, true), "Claude reopened without --resume")
        assert(read_file(args_file):find(session_id, 1, true), "Claude reopened without hook-captured session id")
    end)
end)

test("public switch entry helper normalizes strings, maps, and aliases", function()
    reset_pane()
    local switch_root = helpers.tmp_path("sidepanes-switch-entry-root")

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = {
                    { name = "default", label = "Default", args = {} },
                    { name = "review", label = "Review", args = {} },
                },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local markdown_entry = sidepanes.make_switch_entry("markdown")
    local shortcut_entry = sidepanes.make_switch_entry("x")
    local uppercase_entry = sidepanes.make_switch_entry("Codex")
    local table_entry = sidepanes.make_switch_entry({
        tool = "codex",
        preset = "Review",
        root = switch_root,
        focus = false,
    })
    local ipython_entry = sidepanes.make_switch_entry({ target = "i" })

    assert(markdown_entry.kind == "markdown", "markdown string did not normalize")
    assert(shortcut_entry.tool_name == "codex", "x alias did not normalize to codex")
    assert(uppercase_entry.tool_name == "codex", "Codex target did not normalize to codex")
    assert(table_entry.tool_name == "codex", "table tool did not normalize")
    assert(table_entry.preset_name == "review", "preset label did not normalize to preset name")
    assert(table_entry.root == switch_root, "switch entry lost root")
    assert(table_entry.focus == false, "switch entry lost focus override")
    assert(ipython_entry.tool_name == "ipython", "i alias did not normalize to ipython")

    local messages = capture_notify(function()
        assert(sidepanes.make_switch_entry({ tool = "codex", preset = "missing" }) == nil, "invalid preset returned an entry")
        assert(sidepanes.make_switch_entry("missing-tool") == nil, "invalid target returned an entry")
    end)

    assert(has_notify(messages, "Unknown Codex preset"), "invalid preset did not notify")
    assert(has_notify(messages, "Unknown pane target"), "invalid target did not notify")
end)

test("width parser accepts columns percentages fractions and deltas", function()
    local old_columns = vim.o.columns
    local old_winminwidth = vim.o.winminwidth

    vim.o.columns = 120
    vim.o.winminwidth = 1

    local columns = assert(api_helpers.resolve_width(80, 100))
    local string_columns = assert(api_helpers.resolve_width("70", 100))
    local percent, _, percent_spec = assert(api_helpers.resolve_width("50%", 100))
    local fraction, _, fraction_spec = assert(api_helpers.resolve_width("1/3", 100))
    local numeric_fraction, _, numeric_fraction_spec = assert(api_helpers.resolve_width(0.5, 100))
    local plus_delta = assert(api_helpers.resolve_width("+10", 80))
    local minus_delta = assert(api_helpers.resolve_width_delta("-5", 80))
    local numeric_delta = assert(api_helpers.resolve_width_delta(7, 80))
    local bad_width, bad_err = api_helpers.resolve_width("wide", 80)
    local snap_next, _, snap_next_spec = assert(api_helpers.resolve_width_snap(91, "next", { 80, 90, 100, "5/6" }))
    local snap_previous = assert(api_helpers.resolve_width_snap(99, "previous", { 80, 90, 100, "5/6" }))
    local bad_snap, bad_snap_err = api_helpers.resolve_width_snap(99, "sideways", { 80 })

    vim.o.columns = old_columns
    vim.o.winminwidth = old_winminwidth

    assert(columns == 80, "column width parsed incorrectly")
    assert(string_columns == 70, "string column width parsed incorrectly")
    assert(percent == 60, "percentage width parsed incorrectly")
    assert(fraction == 40, "fraction width parsed incorrectly")
    assert(numeric_fraction == 60, "numeric fraction width parsed incorrectly")
    assert(percent_spec.ratio == 0.5 and percent_spec.label == "50%", "percentage width did not return relative spec")
    assert(fraction_spec.ratio == 1 / 3 and fraction_spec.label == "1/3", "fraction width did not return relative spec")
    assert(numeric_fraction_spec.ratio == 0.5, "numeric fraction width did not return relative spec")
    assert(plus_delta == 90, "relative set width parsed incorrectly")
    assert(minus_delta == 75, "negative width delta parsed incorrectly")
    assert(numeric_delta == 87, "numeric width delta parsed incorrectly")
    assert(bad_width == nil and bad_err:find("Could not parse pane width", 1, true), "bad width did not return parse error")
    assert(snap_next == 100 and snap_next_spec and snap_next_spec.ratio == 5 / 6, "next snap did not prefer relative duplicate boundary")
    assert(snap_previous == 90, "previous snap did not find prior boundary")
    assert(bad_snap == nil and bad_snap_err:find("snap direction", 1, true), "bad snap direction did not return parse error")
end)

test("pane-local slot maps exist on markdown and terminal panes", function()
    reset_pane()

    local root = root_fixture("pane-map-test")
    write(root .. "/docs/doc.md", { "# Doc" })

    pane.setup({
        tools = {
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")

    for _, lhs in ipairs({ " 0", " x", " c", " i", "zz", "ap" }) do
        assert(has_nowait_map(pane.bufnr, lhs), lhs .. " missing on sidepanes")
    end
    assert(has_map(pane.bufnr, "ll", "x"), "ll missing on sidepanes")

    local ctx = pane.open_terminal("ipython", nil, { root = root, focus = true })

    for _, lhs in ipairs({ " 0", " x", " c", " i", "zz", "ap" }) do
        assert(has_nowait_map(ctx.bufnr, lhs), lhs .. " missing on terminal pane")
    end
    assert(has_map(ctx.bufnr, "ll", "x"), "ll missing on terminal pane")
    assert(has_nowait_map(ctx.bufnr, "\\gg", "t"), "terminal-mode primary toggle map missing on terminal pane")
    assert(has_nowait_map(ctx.bufnr, "<C-G>", "t"), "terminal-mode toggle map missing on terminal pane")
end)

-- Ask layer: keymap registration and coverage matrix tests.
test("ask mapping zone matrix matches active maps by user location", function()
    reset_pane()

    local root = root_fixture("ask-mapping-zone-matrix-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        commands = true,
        ask = {
            ui = "pane",
        },
        mappings = {
            global = {
                ask_pane = "<leader>pa",
                ask = "<leader>pa",
                ask_last = "aa",
                ask_codex = "ax",
                ask_claude = "ac",
            },
            pane = {
                ask_send = "qq",
                ask_send_alt = "<leader>qq",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "one", label = "One", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "one", label = "One", args = {} } },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")

    assert(global_map("<leader>pa", "n").callback, "project normal ask-pane map missing")
    assert(global_map("<leader>pa", "x").callback, "project visual ask map missing")
    assert(global_map("aa", "x").callback, "project visual ask-last map missing")
    assert(global_map("ax", "x").callback, "project visual ask-codex map missing")
    assert(global_map("ac", "x").callback, "project visual ask-claude map missing")
    assert(vim.fn.maparg("gh", "n", false, true).desc ~= "Show Sidepanes mapping help", "help map should not be global")

    pane.open(root .. "/docs/doc.md")

    assert(has_map(pane.bufnr, "fm"), "Markdown pane heading picker map missing")
    assert(has_nowait_map(pane.bufnr, "ap"), "Markdown pane ask-pane map missing")
    assert(has_map(pane.bufnr, "aa", "x"), "Markdown pane visual ask-last map missing")
    assert(has_map(pane.bufnr, "ax", "x"), "Markdown pane visual ask-codex map missing")
    assert(has_map(pane.bufnr, "ac", "x"), "Markdown pane visual ask-claude map missing")
    assert(has_map(pane.bufnr, "\\gg"), "Markdown pane terminal toggle map missing")
    assert(has_map(pane.bufnr, "<C-G>"), "Markdown pane terminal toggle alt map missing")
    assert(has_nowait_map(pane.bufnr, "gh"), "Markdown pane help map missing")
    assert(not has_map(pane.bufnr, "H"), "pane-local help mapping should not claim H")

    local ctx = pane.open_terminal("codex", "one", { root = root, focus = true })
    local alt_lhs = expanded_leader("<leader>qq")

    assert(has_nowait_map(ctx.bufnr, "ap"), "terminal pane ask-pane map missing")
    assert(has_map(ctx.bufnr, "\\gg"), "terminal pane normal toggle map missing")
    assert(has_map(ctx.bufnr, "<C-G>"), "terminal pane normal toggle alt map missing")
    assert(has_nowait_map(ctx.bufnr, "gh"), "terminal pane help map missing")
    assert(has_nowait_map(ctx.bufnr, "\\gg", "t"), "terminal pane terminal-mode toggle map missing")
    assert(has_nowait_map(ctx.bufnr, "<C-G>", "t"), "terminal pane terminal-mode toggle alt map missing")
    assert(not has_map(ctx.bufnr, alt_lhs), "terminal pane should not own ask-send-alt/personal quit lhs")
    assert(not has_map(ctx.bufnr, alt_lhs, "t"), "terminal-input pane should not own ask-send-alt/personal quit lhs")

    pane.show_ask_pane({ focus = true })

    local qbuf = pane.ask_pane.bufnr

    assert(has_map(qbuf, "M"), "ask pane model picker map missing")
    assert(has_map(qbuf, "<Tab>"), "ask pane model picker alt map missing")
    assert(has_nowait_map(qbuf, "gh"), "ask pane help map missing")
    assert(has_map(qbuf, "<C-CR>", "n"), "ask pane normal submit map missing")
    assert(has_map(qbuf, "<C-CR>", "i"), "ask pane insert submit map missing")
    assert(has_map(qbuf, "qq"), "ask pane send map missing")
    assert(has_map(qbuf, alt_lhs), "ask pane send alt map missing")
    assert(has_map(qbuf, "]f"), "ask pane next file map missing")
    assert(has_map(qbuf, "[f"), "ask pane previous file map missing")
    assert(has_map(qbuf, "]s"), "ask pane next selection map missing")
    assert(has_map(qbuf, "[s"), "ask pane previous selection map missing")
    assert(has_map(qbuf, "gf"), "ask pane source map missing")
    assert(has_map(qbuf, "u"), "ask pane undo map missing")

    local command_table = vim.api.nvim_get_commands({})

    assert(command_table.SidepanesAsk, "SidepanesAsk command missing")
    assert(command_table.SidepanesAskAppend, "SidepanesAskAppend command missing")
    assert(command_table.SidepanesAskStatus, "SidepanesAskStatus command missing")
    assert(command_table.SidepanesSubmitQuestion, "SidepanesSubmitQuestion command missing")
    assert(command_table.SidepanesVersion, "SidepanesVersion command missing")
    assert(command_table.SidepanesMappings, "SidepanesMappings command missing")
end)

test("ask behavior-sensitive mapping coverage table matches matrices and tests", function()
    local behavior_rows = {}
    local zone_rows = {}
    local covered_behavior_rows = {}
    local covered_zone_rows = {}
    local test_names = {}

    for _, item in ipairs(tests) do
        test_names[item.name] = true
    end

    for _, row in ipairs(ask_behavior_matrix.rows) do
        behavior_rows[row.id] = true
    end

    for _, row in ipairs(ask_mapping_zone_matrix.rows) do
        zone_rows[row.id] = true
    end

    local function assert_known_test(name, field, row)
        if name then
            assert(test_names[name], row.id .. " " .. field .. " references missing test: " .. name)
        end
    end

    for _, row in ipairs(ask_mapping_coverage.rows) do
        assert(row.id, "coverage row is missing id")
        assert(row.registration, row.id .. " missing registration coverage")
        assert(row.direct, row.id .. " missing direct policy/state coverage")
        assert(row.fed_key or row.no_fed_key_reason, row.id .. " missing fed-key coverage or no-fed-key reason")
        assert(not (row.fed_key and row.no_fed_key_reason), row.id .. " should not have both fed-key coverage and no-fed-key reason")

        assert_known_test(row.registration, "registration", row)
        assert_known_test(row.direct, "direct", row)
        assert_known_test(row.fed_key, "fed_key", row)

        if row.behavior_row then
            assert(behavior_rows[row.behavior_row], row.id .. " references unknown behavior row " .. row.behavior_row)
            covered_behavior_rows[row.behavior_row] = true
        end

        assert(row.zone_rows and #row.zone_rows > 0, row.id .. " missing zone matrix references")
        for _, zone_row in ipairs(row.zone_rows) do
            assert(zone_rows[zone_row], row.id .. " references unknown zone row " .. zone_row)
            covered_zone_rows[zone_row] = true
        end
    end

    for id in pairs(behavior_rows) do
        assert(covered_behavior_rows[id], "behavior matrix row lacks mapping coverage decision: " .. id)
    end

    for id in pairs(zone_rows) do
        assert(covered_zone_rows[id], "mapping zone row lacks coverage decision: " .. id)
    end
end)

test("pane-local mappings are configurable", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local calls = {}
    local map_root = helpers.tmp_path("sidepanes-custom-pane-map-root")

    local_maps.setup(bufnr, {
        ask_current_coding_agent = function(tool_name, opts)
            calls.ask_current = { tool_name = tool_name, opts = opts }
        end,
        ask_last_coding_agent = function(opts)
            calls.ask_last = opts
        end,
        markdown_bufnr = function()
            return bufnr
        end,
        open_terminal = function(tool_name, preset_name, opts)
            calls.open_terminal = { tool_name = tool_name, preset_name = preset_name, opts = opts }
        end,
        pane_mappings = function()
            return {
                markdown = "m0",
                codex = "mx",
                claude = "mc",
                ipython = "mi",
                toggle_terminal = "mt",
                toggle_terminal_alt = false,
                ipython_alt = false,
                headings = "mh",
                gf = "mf",
                send_ipython = "ml",
                zoom = "mz",
                ask_pane = "mp",
                ask_last = "ma",
                ask_codex = "mx",
                ask_claude = "mc",
                help = "g?",
            }
        end,
        pane_root = function()
            return map_root
        end,
        pick_headings = function()
            calls.headings = true
        end,
        show_markdown = function()
            calls.markdown = true
        end,
        show_ask_pane = function(opts)
            calls.ask_pane = opts
        end,
        show_mappings_help = function(opts)
            calls.help = opts
        end,
        send_ipython = function(opts)
            calls.send_ipython = opts
        end,
        toggle_markdown_terminal = function()
            calls.toggle_terminal = true
        end,
        toggle_zoom = function()
            calls.zoom = true
        end,
        toggle_wrap = function()
            calls.wrap = true
        end,
        wrap_toggle_key = function()
            return "mw"
        end,
    })

    assert(has_nowait_map(bufnr, "m0"), "custom markdown-viewer map missing")
    assert(has_nowait_map(bufnr, "mx"), "custom Codex pane map missing")
    assert(has_nowait_map(bufnr, "mc"), "custom Claude pane map missing")
    assert(has_nowait_map(bufnr, "mi"), "custom IPython pane map missing")
    assert(has_map(bufnr, "mt"), "custom toggle-terminal pane map missing")
    assert(has_map(bufnr, "mh"), "custom markdown headings pane map missing")
    assert(has_map(bufnr, "mf"), "custom smart-gf pane map missing")
    assert(has_map(bufnr, "ml", "x"), "custom send-IPython pane map missing")
    assert(has_map(bufnr, "mz"), "custom zoom pane map missing")
    assert(has_map(bufnr, "mp"), "custom ask-pane map missing")
    assert(has_map(bufnr, "ma", "x"), "custom ask-last pane map missing")
    assert(has_map(bufnr, "mx", "x"), "custom ask-Codex pane map missing")
    assert(has_map(bufnr, "mc", "x"), "custom ask-Claude pane map missing")
    assert(has_map(bufnr, "g?"), "custom help pane map missing")
    assert(not has_map(bufnr, "<C-G>"), "disabled toggle-terminal alternate map was installed")
    assert(not has_map(bufnr, "<C-G>", "t"), "disabled terminal-mode toggle-terminal alternate map was installed")
    assert(not has_map(bufnr, "<leader>gi"), "disabled IPython alternate map was installed")

    call_map(bufnr, "m0")
    assert(calls.markdown == true, "custom markdown-viewer map did not call show_markdown")
    call_map(bufnr, "mx")
    assert(calls.open_terminal.tool_name == "codex", "custom Codex pane map used wrong tool")
    assert(calls.open_terminal.opts.root == map_root, "custom Codex pane map lost pane root")
    call_map(bufnr, "mc")
    assert(calls.open_terminal.tool_name == "claude", "custom Claude pane map used wrong tool")
    call_map(bufnr, "mi")
    assert(calls.open_terminal.tool_name == "ipython", "custom IPython pane map used wrong tool")
    call_map(bufnr, "mt")
    assert(calls.toggle_terminal == true, "custom toggle-terminal pane map did not call toggle")
    call_map(bufnr, "mh")
    assert(calls.headings == true, "custom markdown headings pane map did not call pick_headings")
    call_map(bufnr, "ml", "x")
    assert(calls.send_ipython.bufnr == bufnr and calls.send_ipython.visual == true, "custom send-IPython pane map did not pass visual opts")
    call_map(bufnr, "mz")
    assert(calls.zoom == true, "custom zoom pane map did not call zoom")
    call_map(bufnr, "mp")
    assert(calls.ask_pane.focus == true, "custom ask-pane map did not focus ask pane")
    call_map(bufnr, "g?")
    assert(calls.help.bufnr == bufnr, "custom help pane map did not pass current pane buffer")
    call_map(bufnr, "ma", "x")
    assert(calls.ask_last.bufnr == bufnr and calls.ask_last.visual == true, "custom ask-last pane map did not pass visual opts")
    call_map(bufnr, "mx", "x")
    assert(calls.ask_current.tool_name == "codex", "custom ask-Codex pane map used wrong tool")
    call_map(bufnr, "mc", "x")
    assert(calls.ask_current.tool_name == "claude", "custom ask-Claude pane map used wrong tool")
    call_map(bufnr, "mw")
    assert(calls.wrap == true, "wrap toggle key no longer worked beside pane mappings")
end)

test("mapping help formats active mappings and pane-relative geometry", function()
    local state = {
        bufnr = 11,
        active_mode = "markdown",
        config = vim.tbl_deep_extend("force", vim.deepcopy(defaults.config), {
            mappings = {
                global = {
                    toggle = "<leader>pp",
                    ask_pane = "<leader>pa",
                },
                pane = {
                    ask_send = "qq",
                    ask_send_alt = "<leader>qq",
                    help = "g?",
                    ask_model_picker = "M",
                    ask_source = "gf",
                    ask_next_file = "]f",
                    ask_previous_file = "[f",
                    ask_submit = "<C-CR>",
                    toggle_terminal_alt = false,
                },
            },
        }),
        ask_pane = {
            bufnr = 22,
        },
    }

    local markdown_lines = table.concat(mapping_help.lines(state, { bufnr = 11 }), "\n")

    assert(markdown_lines:find("Markdown Pane Mappings", 1, true), "markdown help missed pane heading")
    assert(markdown_lines:find("`g?` (n): Show mapping help", 1, true), "markdown help missed configured help mapping")
    assert(not markdown_lines:find("<C%-g>", 1, false), "disabled pane mapping should not be listed")
    assert(markdown_lines:find("Global Sidepanes Mappings", 1, true), "mapping help missed global section")
    assert(markdown_lines:find("`<leader>pp` (n): Toggle Sidepanes", 1, true), "mapping help missed global mapping")
    assert(markdown_lines:find(":Sidepanes mappings", 1, true), "mapping help missed root mappings command")

    local pane_index = markdown_lines:find("Markdown Pane Mappings", 1, true)
    local global_index = markdown_lines:find("Global Sidepanes Mappings", 1, true)
    local command_index = markdown_lines:find("Relevant Commands", 1, true)

    assert(pane_index and global_index and pane_index < global_index, "pane mappings were not listed before global mappings")
    assert(global_index and command_index and global_index < command_index, "commands were not listed after global mappings")

    local terminal_lines = table.concat(mapping_help.lines(state, { kind = "terminal" }), "\n")

    assert(terminal_lines:find("Terminal Pane Mappings", 1, true), "terminal help missed pane heading")
    assert(terminal_lines:find("`<leader>gg` (n/t): Toggle Markdown/terminal pane", 1, true), "terminal help missed terminal toggle")
    assert(terminal_lines:find(":Sidepanes tool {tool} %[preset%]"), "terminal help missed terminal command")

    local ask_lines = table.concat(mapping_help.lines(state, { bufnr = 22 }), "\n")

    assert(ask_lines:find("Ask Pane Mappings", 1, true), "ask help missed pane heading")
    assert(ask_lines:find("`M` (n): Change ask target/model", 1, true), "ask help missed model picker")
    assert(ask_lines:find("`<Tab>` (n): Change ask target/model", 1, true), "ask help missed model picker alternate")
    assert(ask_lines:find("`gf` (n): Open citation source", 1, true), "ask help missed source mapping")
    assert(ask_lines:find("`]f` (n): Next cited file", 1, true), "ask help missed next-file mapping")
    assert(ask_lines:find("`[f` (n): Previous cited file", 1, true), "ask help missed previous-file mapping")
    assert(ask_lines:find("`qq` (n): Finish ask prompt", 1, true), "ask help missed configured ask_send mapping")
    assert(ask_lines:find("`<C-CR>` (n/i): Submit ask prompt", 1, true), "ask help missed submit mapping")

    local geometry = mapping_help.float_geometry({ row = 2, col = 100, width = 80, height = 24 }, { width = 200, height = 60 })

    assert(geometry.relative == "editor", "mapping help float should use editor-relative geometry")
    assert(geometry.width == 72, "mapping help did not size width relative to pane")
    assert(geometry.height == 20, "mapping help did not size height relative to pane")
    assert(geometry.row == 4, "mapping help did not center row over pane")
    assert(geometry.col == 104, "mapping help did not center col over pane")

    local fallback = mapping_help.float_geometry({ row = 0, col = 120, width = 20, height = 6 }, { width = 180, height = 50 })

    assert(fallback.col == 54, "small-pane fallback did not center in editor")
    assert(fallback.row == 15, "small-pane fallback did not center in editor")

    local left_geometry = mapping_help.float_geometry({ row = 10, col = 0, width = 50, height = 14 }, { width = 180, height = 50 })

    assert(left_geometry.col == 2, "left-side pane geometry did not stay attached to pane column")
    assert(left_geometry.row == 12, "left-side pane geometry did not stay attached to pane row")

    local bottom_geometry = mapping_help.float_geometry({ row = 36, col = 40, width = 60, height = 10 }, { width = 180, height = 50 })

    assert(bottom_geometry.col == 42, "bottom-style pane geometry did not stay attached to pane column")
    assert(bottom_geometry.row == 38, "bottom-style pane geometry did not stay attached to pane row")
end)

test("mapping help opens from the pane-local fed key and follows help config", function()
    reset_pane()

    local root = root_fixture("mapping-help-fed-key-test")

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "body",
    })
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
        help = {
            mapping = "g?",
        },
    })
    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("g? help", 1, true), winbar)
    assert(has_nowait_map(pane.bufnr, "g?"), "configured help mapping missing")
    assert(pane.config.mappings.pane.help == "g?", "help.mapping did not normalize to pane-local help mapping")

    feed_user_keys("g?")
    wait_until("mapping help float did not open from fed key", function()
        return vim.api.nvim_get_current_win() ~= pane.winid
    end)

    local help_bufnr = vim.api.nvim_get_current_buf()
    local help_lines = table.concat(vim.api.nvim_buf_get_lines(help_bufnr, 0, -1, false), "\n")

    assert(vim.bo[help_bufnr].filetype == "markdown", "mapping help did not open a Markdown buffer")
    assert(help_lines:find("Markdown Pane Mappings", 1, true), help_lines)
    assert(help_lines:find("`g?` (n): Show mapping help", 1, true), help_lines)

    vim.cmd.close()

    reset_pane()
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
        mappings = {
            pane = {
                help = "gH",
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("gH help", 1, true), winbar)
    assert(has_nowait_map(pane.bufnr, "gH"), "pane help mapping override was not reused")

    reset_pane()
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
        help = {
            mapping = false,
        },
    })
    pane.open(root .. "/docs/doc.md")

    winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(not winbar:find("help", 1, true), winbar)
    assert(mapping_help.winbar_hint(pane.config) == nil, "disabled help mapping still produced a winbar hint")

    reset_pane()
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
        help = {
            winbar = false,
        },
    })
    pane.open(root .. "/docs/doc.md")

    winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(not winbar:find("gh help", 1, true), winbar)
    assert(pane.config.mappings.pane.help == "gh", "help.winbar=false should not disable the mapping")
end)

test("ask pane mapping help includes target model picker from fed key", function()
    reset_pane()

    local root = root_fixture("ask-pane-mapping-help-fed-key-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })
    vim.api.nvim_set_current_win(pane.winid)

    feed_user_keys("gh")
    wait_until("ask mapping help float did not open from fed key", function()
        return vim.api.nvim_get_current_win() ~= pane.winid
    end)

    local help_bufnr = vim.api.nvim_get_current_buf()
    local help_lines = table.concat(vim.api.nvim_buf_get_lines(help_bufnr, 0, -1, false), "\n")

    assert(help_lines:find("Ask Pane Mappings", 1, true), help_lines)
    assert(help_lines:find("`M` (n): Change ask target/model", 1, true), help_lines)
    assert(help_lines:find("`<Tab>` (n): Change ask target/model", 1, true), help_lines)
end)

test("pane-local help mapping can be disabled for a fresh buffer", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    local called = false

    local_maps.setup(bufnr, {
        ask_current_coding_agent = function() end,
        ask_last_coding_agent = function() end,
        markdown_bufnr = function()
            return bufnr
        end,
        open_terminal = function() end,
        pane_mappings = function()
            return {
                help = false,
            }
        end,
        pane_root = function()
            return "/tmp"
        end,
        show_mappings_help = function()
            called = true
        end,
        show_markdown = function() end,
        show_ask_pane = function() end,
        send_ipython = function() end,
        toggle_markdown_terminal = function() end,
        toggle_zoom = function() end,
        toggle_wrap = function() end,
        wrap_toggle_key = function()
            return false
        end,
    })

    assert(not has_map(bufnr, "gh"), "disabled help mapping was installed")
    assert(called == false, "disabled help mapping callback was called")
end)

test("legacy pane-local terminal toggle mapping keys remain aliases", function()
    reset_pane()

    local normalized = config.normalize(vim.deepcopy(defaults.config), {
        mappings = {
            pane = {
                toggle_agent = "ma",
                toggle_agent_alt = false,
            },
        },
    })

    assert(normalized.mappings.pane.toggle_terminal == "ma", "legacy toggle_agent did not set toggle_terminal")
    assert(normalized.mappings.pane.toggle_terminal_alt == false, "legacy toggle_agent_alt did not disable toggle_terminal_alt")

    local bufnr = vim.api.nvim_create_buf(false, true)
    local called = false

    local_maps.setup(bufnr, {
        ask_current_coding_agent = function() end,
        ask_last_coding_agent = function() end,
        markdown_bufnr = function()
            return -1
        end,
        open_terminal = function() end,
        pane_mappings = function()
            return {
                toggle_agent = "ma",
                toggle_agent_alt = false,
            }
        end,
        pane_root = function()
            return helpers.tmp_path("sidepanes-legacy-pane-map-root")
        end,
        send_ipython = function() end,
        show_markdown = function() end,
        toggle_markdown_agent = function()
            called = true
        end,
        toggle_zoom = function() end,
        toggle_wrap = function() end,
        wrap_toggle_key = function()
            return "mw"
        end,
    })

    assert(has_map(bufnr, "ma"), "legacy toggle_agent pane map missing")
    assert(has_nowait_map(bufnr, "ma", "t"), "legacy terminal-mode toggle_agent pane map missing")
    assert(not has_map(bufnr, "<C-G>"), "legacy disabled toggle_agent_alt map was installed")
    assert(not has_map(bufnr, "<C-G>", "t"), "legacy disabled terminal-mode toggle_agent_alt map was installed")

    call_map(bufnr, "ma")
    assert(called == true, "legacy toggle_agent pane map did not call toggle")
end)

test("document picker entries preserve display and resolve absolute values", function()
    reset_pane()

    local root = root_fixture("document-picker-entry-test")
    local relative = "docs/doc.md"
    local absolute = root .. "/" .. relative

    write(absolute, { "# Doc" })

    local previous_cwd = vim.fn.getcwd()

    vim.cmd.cd(root)

    local rg_entry = document_picker.rg_entry(relative)
    local glob_entry = document_picker.glob_entry(absolute)

    vim.cmd.cd(previous_cwd)

    assert(rg_entry.value == absolute, "rg entry did not resolve absolute value")
    assert(rg_entry.display == relative, "rg entry display changed")
    assert(rg_entry.ordinal == relative, "rg entry ordinal changed")
    assert(glob_entry.value == absolute, "glob entry did not resolve absolute value")
    assert(glob_entry.display == relative, "glob entry display was not cwd-relative")
    assert(glob_entry.ordinal == absolute, "glob entry ordinal changed")
end)

test("document picker can focus selected markdown pane", function()
    reset_pane()

    local root = root_fixture("document-picker-focus-test")
    local doc = root .. "/docs/doc.md"
    local selected = nil
    local previous_modules = {
        telescope = package.loaded.telescope,
        pickers = package.loaded["telescope.pickers"],
        finders = package.loaded["telescope.finders"],
        config = package.loaded["telescope.config"],
        actions = package.loaded["telescope.actions"],
        action_state = package.loaded["telescope.actions.state"],
    }

    write(doc, { "# Doc" })

    package.loaded.telescope = {}
    package.loaded["telescope.finders"] = {
        new_oneshot_job = function()
            return {}
        end,
        new_table = function()
            return {}
        end,
    }
    package.loaded["telescope.config"] = {
        values = {
            file_sorter = function()
                return {}
            end,
        },
    }
    package.loaded["telescope.actions.state"] = {
        get_selected_entry = function()
            return { value = selected }
        end,
    }
    package.loaded["telescope.actions"] = {
        close = function() end,
        select_default = {
            replace = function(_, fn)
                package.loaded["telescope.actions"]._select_default = fn
            end,
        },
    }
    package.loaded["telescope.pickers"] = {
        new = function(_, opts)
            return {
                find = function()
                    opts.attach_mappings(1)
                    package.loaded["telescope.actions"]._select_default()
                end,
            }
        end,
    }

    local original_getcmdline
    local original_getcmdtype
    local ok, err = xpcall(function()
        local origin = vim.api.nvim_get_current_win()

        selected = doc
        pane.setup({
            lifecycle = {
                focus_on_pick = true,
            },
        })
        pane.pick()
        assert(vim.api.nvim_get_current_win() == pane.winid, "document picker did not focus selected markdown pane")
        assert(pane.last_focus_win == origin, "document picker did not remember previous focus window")

        pane.focus_toggle()
        assert(vim.api.nvim_get_current_win() == origin, "focus toggle did not return after focused pick")

        selected = doc
        pane.setup({
            lifecycle = {
                focus_on_pick = false,
            },
        })
        pane.pick()
        assert(vim.api.nvim_get_current_win() == origin, "document picker focused pane despite focus_on_pick=false")
    end, debug.traceback)

    package.loaded.telescope = previous_modules.telescope
    package.loaded["telescope.pickers"] = previous_modules.pickers
    package.loaded["telescope.finders"] = previous_modules.finders
    package.loaded["telescope.config"] = previous_modules.config
    package.loaded["telescope.actions"] = previous_modules.actions
    package.loaded["telescope.actions.state"] = previous_modules.action_state

    if not ok then
        error(err)
    end
end)

test("heading picker collects markdown headings with levels and cleaned titles", function()
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
        "# Top",
        "",
        "## Child ##",
        "",
        "Setext Child",
        "------------",
        "",
        "paragraph",
    })

    local headings, err = heading_picker.collect(bufnr)

    assert(headings, err or "heading collector failed")
    assert(#headings == 3, "heading collector returned wrong count: " .. tostring(#headings))
    assert(headings[1].lnum == 1 and headings[1].level == 1 and headings[1].title == "Top", "top heading changed")
    assert(headings[2].lnum == 3 and headings[2].level == 2 and headings[2].title == "Child", "ATX heading cleanup changed")
    assert(headings[3].lnum == 5 and headings[3].level == 2 and headings[3].title == "Setext Child", "Setext heading changed")
end)

test("nvim-tree integration filters pane and plugin windows", function()
    vim.cmd("silent! only")

    local winid = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
    assert(nvim_tree_integration.usable_window({}, winid), "normal file window was not usable")
    assert(not nvim_tree_integration.usable_window({ winid = winid }, winid), "pane window was usable")
    assert(not nvim_tree_integration.usable_window({ bufnr = bufnr }, winid), "pane buffer was usable")

    vim.api.nvim_set_option_value("filetype", "NvimTree", { buf = bufnr })
    assert(not nvim_tree_integration.usable_window({}, winid), "NvimTree window was usable")
    vim.api.nvim_set_option_value("filetype", "python", { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    assert(not nvim_tree_integration.usable_window({}, winid), "nofile window was usable")
    vim.api.nvim_set_option_value("buftype", "", { buf = bufnr })
end)

test("nvim-tree integration prefers alternate non-pane window", function()
    reset_pane()
    vim.cmd("silent! only")

    local target_win = vim.api.nvim_get_current_win()
    local target_buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_option_value("buftype", "", { buf = target_buf })
    vim.api.nvim_set_option_value("filetype", "python", { buf = target_buf })
    vim.cmd("vsplit")

    local pane_win = vim.api.nvim_get_current_win()
    local pane_buf = vim.api.nvim_create_buf(false, true)
    local old_winid = pane.winid
    local old_bufnr = pane.bufnr

    vim.api.nvim_win_set_buf(pane_win, pane_buf)
    pane.winid = pane_win
    pane.bufnr = pane_buf

    local picked = nvim_tree_integration.file_target_picker()

    pane.winid = old_winid
    pane.bufnr = old_bufnr

    assert(picked == target_win, "nvim-tree picker did not prefer alternate non-pane window")
    vim.cmd("silent! only")
end)

test("setup installs single focus and shutdown autocmds when repeated", function()
    reset_pane()

    pane.setup({
        width = 61,
    })
    pane.setup({
        wrap = true,
    })

    local focus_autocmds = vim.api.nvim_get_autocmds({ group = "SidepanesFocus" })
    local resize_autocmds = vim.api.nvim_get_autocmds({ group = "SidepanesResize" })
    local reload_autocmds = vim.api.nvim_get_autocmds({ group = "SidepanesReload" })
    local shutdown_autocmds = vim.api.nvim_get_autocmds({ group = "SidepanesShutdown" })

    assert(#focus_autocmds == 1, "setup duplicated focus autocmds")
    assert(#resize_autocmds == 1, "setup duplicated resize autocmds")
    assert(#reload_autocmds == 4, "setup duplicated reload autocmds")
    assert(#shutdown_autocmds == 1, "setup duplicated shutdown autocmds")
    assert(pane.config.width == 61, "setup lost earlier config merge")
    assert(pane.config.wrap == true, "setup did not merge later config")
    assert(pane.config.tools.codex ~= nil, "setup dropped default tools")
end)

test("version module and public API report version and load path", function()
    reset_pane()

    local root = helpers.repo_root(1)
    local fixture = sidepanes_version.info({
        source = root .. "/lua/sidepanes/version.lua",
    })

    assert(sidepanes_version.VERSION == "0.4.0-dev", "version constant was wrong")
    assert(fixture.version == "0.4.0-dev", "version info used wrong version")
    assert(fixture.load_path == root, "version info did not trim module path")
    assert(
        sidepanes_version.info({ source = "@/tmp/other/lua/sidepanes/version.lua" }).load_path == "/tmp/other",
        "version info did not handle @-prefixed module source"
    )
    assert(
        sidepanes_version.info({ source = "/tmp/not-sidepanes.lua" }).load_path == "/tmp/not-sidepanes.lua",
        "version info should keep unrecognized source paths"
    )

    local public_info = pane.version()

    assert(public_info.version == "0.4.0-dev", "public version API used wrong version")
    assert(public_info.load_path == root, "public version API reported wrong load path")

    local messages = capture_notify(function()
        local notified = pane.version({ notify = true })

        assert(notified.version == "0.4.0-dev", "notifying version API returned wrong version")
    end)

    assert(#messages == 1, "version API notify did not emit one message")
    assert(messages[1].level == vim.log.levels.INFO, "version API notify used wrong log level")
    assert(messages[1].message:find("Sidepanes version: 0.4.0-dev", 1, true), "version notify missed version")
    assert(messages[1].message:find("Load path: " .. root, 1, true), "version notify missed load path")
end)

test("command registration invokes facade callbacks", function()
    local calls = {}
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "1", "2", "3", "4", "5", "6", "7" })

    commands.setup({
        toggle = function(path)
            calls.toggle = path
        end,
        pick = function()
            calls.pick = true
        end,
        pick_headings = function()
            calls.headings = true
        end,
        switch_picker = function()
            calls.switch = true
        end,
        open_terminal = function(tool_name, preset_name)
            calls.open_terminal = { tool_name = tool_name, preset_name = preset_name }
        end,
        open_ipython = function(opts)
            calls.open_ipython = opts
        end,
        restart_ipython = function(opts)
            calls.restart_ipython = opts
        end,
        clear_ipython = function(opts)
            calls.clear_ipython = opts
        end,
        focus_toggle = function()
            calls.focus = true
        end,
        toggle_zoom = function()
            calls.zoom = true
        end,
        get_width = function()
            calls.get_width = true
            return 91
        end,
        set_width = function(value)
            calls.set_width = value
        end,
        adjust_width = function(value)
            calls.adjust_width = value
        end,
        snap_width = function(direction)
            calls.snap_width = direction
        end,
        width_picker = function()
            calls.width_picker = true
        end,
        ask_picker = function(opts)
            calls.ask = opts
        end,
        append_to_ask = function(opts)
            calls.ask_append = opts
        end,
        ask_status = function()
            calls.ask_status = true
        end,
        submit_ask_pane = function()
            calls.submit_question = true
        end,
        ask = function(tool_name, preset_name, opts)
            calls.ask_tool = { tool_name = tool_name, preset_name = preset_name, opts = opts }
        end,
        version = function(opts)
            calls.version = opts
        end,
        mappings_help = function(opts)
            calls.mappings_help = opts or {}
        end,
    }, {
        toggle = "SidepanesTestToggle",
        pick = "SidepanesTestPick",
        headings = "SidepanesTestHeadings",
        switch = "SidepanesTestSwitch",
        tool = "SidepanesTestTool",
        codex = "SidepanesTestCodex",
        claude = "SidepanesTestClaude",
        ipython = "SidepanesTestIPython",
        ipython_restart = "SidepanesTestIPythonRestart",
        ipython_clear = "SidepanesTestIPythonClear",
        focus = "SidepanesTestFocus",
        zoom = "SidepanesTestZoom",
        width = "SidepanesTestWidth",
        width_picker = "SidepanesTestWidthPick",
        ask = "SidepanesTestAsk",
        ask_append = "SidepanesTestAskAppend",
        ask_status = "SidepanesTestAskStatus",
        submit_question = "SidepanesTestSubmitQuestion",
        ask_codex = "SidepanesTestAskCodex",
        ask_claude = "SidepanesTestAskClaude",
        version = "SidepanesTestVersion",
        mappings = "SidepanesTestMappings",
    })

    vim.cmd("SidepanesTestToggle docs/demo.md")
    assert(calls.toggle == "docs/demo.md", "toggle command did not forward optional path")
    vim.cmd("SidepanesTestPick")
    assert(calls.pick == true, "pick command did not call pick")
    vim.cmd("SidepanesTestHeadings")
    assert(calls.headings == true, "headings command did not call pick_headings")
    vim.cmd("SidepanesTestSwitch")
    assert(calls.switch == true, "switch command did not call switch picker")
    vim.cmd("SidepanesTestTool codex review")
    assert(calls.open_terminal.tool_name == "codex", "tool command did not forward tool")
    assert(calls.open_terminal.preset_name == "review", "tool command did not forward preset")
    vim.cmd("SidepanesTestCodex gpt55_high_fast")
    assert(calls.open_terminal.tool_name == "codex", "codex command did not open codex")
    assert(calls.open_terminal.preset_name == "gpt55_high_fast", "codex command did not forward preset")
    vim.cmd("SidepanesTestClaude sonnet")
    assert(calls.open_terminal.tool_name == "claude", "claude command did not open claude")
    assert(calls.open_terminal.preset_name == "sonnet", "claude command did not forward preset")
    vim.cmd("SidepanesTestIPython")
    assert(calls.open_ipython.bufnr == bufnr and calls.open_ipython.focus == true, "ipython command did not use current buffer")
    vim.cmd("SidepanesTestIPythonRestart")
    assert(calls.restart_ipython.bufnr == bufnr and calls.restart_ipython.focus == true, "ipython restart command did not use current buffer")
    vim.cmd("SidepanesTestIPythonClear")
    assert(calls.clear_ipython.bufnr == bufnr, "ipython clear command did not use current buffer")
    vim.cmd("SidepanesTestFocus")
    assert(calls.focus == true, "focus command did not call focus toggle")
    vim.cmd("SidepanesTestZoom")
    assert(calls.zoom == true, "zoom command did not call zoom toggle")
    vim.cmd("SidepanesTestWidth 45%")
    assert(calls.set_width == "45%", "width command did not forward absolute width")
    vim.cmd("SidepanesTestWidth +5")
    assert(calls.adjust_width == "+5", "width command did not forward relative width")
    vim.cmd("SidepanesTestWidth next")
    assert(calls.snap_width == "next", "width command did not snap next")
    vim.cmd("SidepanesTestWidth prev")
    assert(calls.snap_width == "previous", "width command did not snap previous")
    vim.cmd("SidepanesTestWidth pick")
    assert(calls.width_picker == true, "width command did not open picker alias")
    capture_notify(function()
        vim.cmd("SidepanesTestWidth")
    end)
    assert(calls.get_width == true, "width command without args did not report width")
    vim.cmd("SidepanesTestWidthPick")
    assert(calls.width_picker == true, "width picker command did not call picker")
    vim.cmd("2,4SidepanesTestAsk")
    assert(calls.ask.bufnr == bufnr and calls.ask.line1 == 2 and calls.ask.line2 == 4, "ask command did not forward range")
    vim.cmd("2,5SidepanesTestAskAppend")
    assert(calls.ask_append.bufnr == bufnr and calls.ask_append.line1 == 2 and calls.ask_append.line2 == 5, "ask append command did not forward range")
    vim.cmd("SidepanesTestAskStatus")
    assert(calls.ask_status == true, "ask status command did not report status")
    vim.cmd("SidepanesTestSubmitQuestion")
    assert(calls.submit_question == true, "submit question command did not submit ask pane")
    vim.cmd("3,5SidepanesTestAskCodex gpt55_high_fast")
    assert(calls.ask_tool.tool_name == "codex", "ask codex command used wrong tool")
    assert(calls.ask_tool.preset_name == "gpt55_high_fast", "ask codex command did not forward preset")
    assert(calls.ask_tool.opts.line1 == 3 and calls.ask_tool.opts.line2 == 5, "ask codex command did not forward range")
    vim.cmd("6,7SidepanesTestAskClaude sonnet")
    assert(calls.ask_tool.tool_name == "claude", "ask claude command used wrong tool")
    assert(calls.ask_tool.preset_name == "sonnet", "ask claude command did not forward preset")
    assert(calls.ask_tool.opts.line1 == 6 and calls.ask_tool.opts.line2 == 7, "ask claude command did not forward range")
    vim.cmd("SidepanesTestVersion")
    assert(calls.version and calls.version.notify == true, "version command did not report version")
    vim.cmd("SidepanesTestMappings")
    assert(calls.mappings_help, "mappings command did not open mapping help")
end)

test("root command dispatches subcommands and completes choices", function()
    local calls = {}
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "1", "2", "3", "4", "5", "6", "7" })

    commands.setup({
        toggle = function(path)
            calls.toggle = path
        end,
        open = function(path)
            calls.open = path
        end,
        show_markdown = function()
            calls.markdown = true
        end,
        pick = function()
            calls.pick = true
        end,
        pick_headings = function()
            calls.headings = true
        end,
        switch_picker = function()
            calls.switch = true
        end,
        open_terminal = function(tool_name, preset_name)
            calls.open_terminal = { tool_name = tool_name, preset_name = preset_name }
        end,
        open_ipython = function(opts)
            calls.open_ipython = opts
        end,
        restart_ipython = function(opts)
            calls.restart_ipython = opts
        end,
        clear_ipython = function(opts)
            calls.clear_ipython = opts
        end,
        focus_toggle = function()
            calls.focus = true
        end,
        toggle_zoom = function()
            calls.zoom = true
        end,
        get_width = function()
            calls.get_width = true
            return 88
        end,
        set_width = function(value)
            calls.set_width = value
        end,
        adjust_width = function(value)
            calls.adjust_width = value
        end,
        snap_width = function(direction)
            calls.snap_width = direction
        end,
        width_picker = function()
            calls.width_picker = true
        end,
        ask_picker = function(opts)
            calls.ask = opts
        end,
        append_to_ask = function(opts)
            calls.ask_append = opts
        end,
        ask_status = function()
            calls.ask_status = true
        end,
        submit_ask_pane = function()
            calls.submit_question = true
        end,
        ask = function(tool_name, preset_name, opts)
            calls.ask_tool = { tool_name = tool_name, preset_name = preset_name, opts = opts }
        end,
        version = function(opts)
            calls.version = opts
        end,
        mappings_help = function(opts)
            calls.mappings_help = opts or {}
        end,
        config = {
            tools = {
                codex = {
                    presets = {
                        { name = "gpt55_high_fast" },
                    },
                },
                claude = {
                    presets = {
                        { name = "sonnet" },
                    },
                },
                ipython = {
                    presets = {
                        { name = "default" },
                    },
                },
            },
        },
    }, {
        root = "SidepanesRootTest",
    })

    vim.cmd("SidepanesRootTest")
    assert(calls.switch == true, "root command without subcommand did not open switcher")
    calls.switch = false
    vim.cmd("SidepanesRootTest help")
    assert(vim.bo.buftype == "help", "root help subcommand did not open help")
    assert(vim.api.nvim_buf_get_name(0):find("sidepanes.txt", 1, true), "root help subcommand opened wrong help file")
    vim.cmd("helpclose")
    vim.cmd("SidepanesRootTest markdown")
    assert(calls.markdown == true, "root markdown subcommand did not show markdown")
    vim.cmd("SidepanesRootTest toggle docs/root.md")
    assert(calls.toggle == "docs/root.md", "root toggle subcommand did not forward path")
    vim.cmd("SidepanesRootTest open docs/open.md")
    assert(calls.open == "docs/open.md", "root open subcommand did not forward path")
    vim.cmd("SidepanesRootTest pick")
    assert(calls.pick == true, "root pick subcommand did not call pick")
    vim.cmd("SidepanesRootTest headings")
    assert(calls.headings == true, "root headings subcommand did not call pick_headings")
    vim.cmd("SidepanesRootTest switch")
    assert(calls.switch == true, "root switch subcommand did not call switch picker")
    vim.cmd("SidepanesRootTest tool codex gpt55_high_fast")
    assert(calls.open_terminal.tool_name == "codex", "root tool subcommand did not forward tool")
    assert(calls.open_terminal.preset_name == "gpt55_high_fast", "root tool subcommand did not forward preset")
    vim.cmd("SidepanesRootTest codex gpt55_high_fast")
    assert(calls.open_terminal.tool_name == "codex", "root codex subcommand used wrong tool")
    assert(calls.open_terminal.preset_name == "gpt55_high_fast", "root codex subcommand did not forward preset")
    vim.cmd("SidepanesRootTest claude sonnet")
    assert(calls.open_terminal.tool_name == "claude", "root claude subcommand used wrong tool")
    assert(calls.open_terminal.preset_name == "sonnet", "root claude subcommand did not forward preset")
    vim.cmd("SidepanesRootTest ipython")
    assert(calls.open_ipython.bufnr == bufnr and calls.open_ipython.focus == true, "root ipython subcommand did not use current buffer")
    vim.cmd("SidepanesRootTest ipython-restart")
    assert(calls.restart_ipython.bufnr == bufnr and calls.restart_ipython.focus == true, "root ipython-restart subcommand did not use current buffer")
    vim.cmd("SidepanesRootTest ipython-clear")
    assert(calls.clear_ipython.bufnr == bufnr, "root ipython-clear subcommand did not use current buffer")
    vim.cmd("SidepanesRootTest focus")
    assert(calls.focus == true, "root focus subcommand did not call focus toggle")
    vim.cmd("SidepanesRootTest zoom")
    assert(calls.zoom == true, "root zoom subcommand did not call zoom toggle")
    vim.cmd("SidepanesRootTest width 1/2")
    assert(calls.set_width == "1/2", "root width subcommand did not forward absolute width")
    vim.cmd("SidepanesRootTest width -4")
    assert(calls.adjust_width == "-4", "root width subcommand did not forward relative width")
    vim.cmd("SidepanesRootTest width next")
    assert(calls.snap_width == "next", "root width subcommand did not snap next")
    vim.cmd("SidepanesRootTest width previous")
    assert(calls.snap_width == "previous", "root width subcommand did not snap previous")
    vim.cmd("SidepanesRootTest width +")
    assert(calls.snap_width == "next", "root width plus alias did not snap next")
    vim.cmd("SidepanesRootTest width -")
    assert(calls.snap_width == "previous", "root width minus alias did not snap previous")
    vim.cmd("SidepanesRootTest width pick")
    assert(calls.width_picker == true, "root width pick alias did not call picker")
    capture_notify(function()
        vim.cmd("SidepanesRootTest width")
    end)
    assert(calls.get_width == true, "root width subcommand without args did not report width")
    vim.cmd("SidepanesRootTest width-pick")
    assert(calls.width_picker == true, "root width-pick subcommand did not call picker")
    vim.cmd("2,4SidepanesRootTest ask")
    assert(calls.ask.bufnr == bufnr and calls.ask.line1 == 2 and calls.ask.line2 == 4, "root ask subcommand did not forward range")
    vim.cmd("3,6SidepanesRootTest ask-append")
    assert(calls.ask_append.bufnr == bufnr and calls.ask_append.line1 == 3 and calls.ask_append.line2 == 6, "root ask-append subcommand did not forward range")
    vim.cmd("SidepanesRootTest ask-status")
    assert(calls.ask_status == true, "root ask-status subcommand did not call ask status")
    vim.cmd("SidepanesRootTest submit-question")
    assert(calls.submit_question == true, "root submit-question subcommand did not submit ask pane")
    vim.cmd("3,5SidepanesRootTest ask-codex gpt55_high_fast")
    assert(calls.ask_tool.tool_name == "codex", "root ask-codex subcommand used wrong tool")
    assert(calls.ask_tool.preset_name == "gpt55_high_fast", "root ask-codex subcommand did not forward preset")
    assert(calls.ask_tool.opts.line1 == 3 and calls.ask_tool.opts.line2 == 5, "root ask-codex subcommand did not forward range")
    vim.cmd("6,7SidepanesRootTest ask-claude sonnet")
    assert(calls.ask_tool.tool_name == "claude", "root ask-claude subcommand used wrong tool")
    assert(calls.ask_tool.preset_name == "sonnet", "root ask-claude subcommand did not forward preset")
    assert(calls.ask_tool.opts.line1 == 6 and calls.ask_tool.opts.line2 == 7, "root ask-claude subcommand did not forward range")
    vim.cmd("SidepanesRootTest version")
    assert(calls.version and calls.version.notify == true, "root version subcommand did not report version")
    vim.cmd("SidepanesRootTest mappings")
    assert(calls.mappings_help, "root mappings subcommand did not open mapping help")

    local subcommands = vim.fn.getcompletion("SidepanesRootTest co", "cmdline")
    local ask_subcommands = vim.fn.getcompletion("SidepanesRootTest ask", "cmdline")
    local submit_subcommands = vim.fn.getcompletion("SidepanesRootTest submit", "cmdline")
    local version_subcommands = vim.fn.getcompletion("SidepanesRootTest v", "cmdline")
    local mappings_subcommands = vim.fn.getcompletion("SidepanesRootTest m", "cmdline")
    local width_subcommands = vim.fn.getcompletion("SidepanesRootTest width", "cmdline")
    local tool_names = vim.fn.getcompletion("SidepanesRootTest tool c", "cmdline")
    local codex_presets = vim.fn.getcompletion("SidepanesRootTest codex g", "cmdline")
    local claude_presets = vim.fn.getcompletion("SidepanesRootTest claude s", "cmdline")

    assert(vim.tbl_contains(subcommands, "codex"), "root completion did not include codex")
    assert(vim.tbl_contains(ask_subcommands, "ask-append"), "root completion did not include ask-append")
    assert(vim.tbl_contains(ask_subcommands, "ask-status"), "root completion did not include ask-status")
    assert(vim.tbl_contains(submit_subcommands, "submit-question"), "root completion did not include submit-question")
    assert(vim.tbl_contains(version_subcommands, "version"), "root completion did not include version")
    assert(vim.tbl_contains(mappings_subcommands, "mappings"), "root completion did not include mappings")
    assert(vim.tbl_contains(width_subcommands, "width-pick"), "root completion did not include width-pick")
    assert(vim.tbl_contains(width_subcommands, "width"), "root completion did not include width")
    local width_args = vim.fn.getcompletion("SidepanesRootTest width n", "cmdline")
    assert(vim.tbl_contains(width_args, "next"), "root width completion did not include next")
    assert(vim.tbl_contains(tool_names, "codex"), "root tool completion did not include codex")
    assert(vim.tbl_contains(codex_presets, "gpt55_high_fast"), "root codex completion did not include preset")
    assert(vim.tbl_contains(claude_presets, "sonnet"), "root claude completion did not include preset")
end)

test("default command names use Sidepanes prefix", function()
    local api = {
        toggle = function() end,
        pick = function() end,
        pick_headings = function() end,
        switch_picker = function() end,
        open_terminal = function() end,
        open_ipython = function() end,
        restart_ipython = function() end,
        clear_ipython = function() end,
        focus_toggle = function() end,
        toggle_zoom = function() end,
        get_width = function() end,
        set_width = function() end,
        adjust_width = function() end,
        width_picker = function() end,
        ask_picker = function() end,
        append_to_ask = function() end,
        ask_status = function() end,
        ask = function() end,
        version = function() end,
        mappings_help = function() end,
    }

    commands.setup(api, true)

    local command_table = vim.api.nvim_get_commands({})
    local expected = {
        "Sidepanes",
        "SidepanesToggle",
        "SidepanesPick",
        "SidepanesHeadings",
        "SidepanesSwitch",
        "SidepanesTool",
        "SidepanesCodex",
        "SidepanesClaude",
        "SidepanesIPython",
        "SidepanesIPythonRestart",
        "SidepanesIPythonClear",
        "SidepanesFocus",
        "SidepanesZoom",
        "SidepanesWidth",
        "SidepanesWidthPick",
        "SidepanesAsk",
        "SidepanesAskAppend",
        "SidepanesAskStatus",
        "SidepanesSubmitQuestion",
        "SidepanesAskCodex",
        "SidepanesAskClaude",
        "SidepanesVersion",
        "SidepanesMappings",
    }
    local forbidden = {
        "PaneSwitch",
        "PaneTool",
        "PaneCodex",
        "PaneClaude",
        "PaneIPython",
        "PaneIPythonRestart",
        "PaneIPythonClear",
        "PaneFocus",
        "PaneZoom",
        "PaneWidth",
        "PaneAsk",
        "PaneAskAppend",
        "PaneAskCodex",
        "PaneAskClaude",
    }

    for _, name in ipairs(expected) do
        assert(command_table[name], "default command missing: " .. name)
    end

    for _, name in ipairs(forbidden) do
        assert(not command_table[name], "generic Pane command should not be registered: " .. name)
    end
end)

test("global map registration invokes facade callbacks", function()
    local calls = {}
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    global_maps.setup({
        toggle = function()
            calls.toggle = true
        end,
        pick = function()
            calls.pick = true
        end,
        pick_headings = function()
            calls.headings = true
        end,
        show_markdown = function()
            calls.markdown = true
        end,
        open_terminal = function(tool_name, preset_name, opts)
            calls.open_terminal = { tool_name = tool_name, preset_name = preset_name, opts = opts }
        end,
        open_ipython = function(opts)
            calls.open_ipython = opts
        end,
        restart_ipython = function(opts)
            calls.restart_ipython = opts
        end,
        send_ipython = function(opts)
            calls.send_ipython = opts
        end,
        clear_ipython = function(opts)
            calls.clear_ipython = opts
        end,
        focus_toggle = function()
            calls.focus = true
        end,
        toggle_zoom = function()
            calls.zoom = true
        end,
        snap_width = function(direction)
            calls.snap_width = direction
        end,
        width_picker = function()
            calls.width_picker = true
        end,
        toggle_sticky_relative_width = function()
            calls.sticky_relative_width = true
        end,
        switch_picker = function()
            calls.switch = true
        end,
        show_ask_pane = function(opts)
            calls.ask_pane = opts
        end,
        ask_picker = function(opts)
            calls.ask = opts
        end,
        ask_last_coding_agent = function(opts)
            calls.ask_last = opts
        end,
        ask_current_coding_agent = function(tool_name, opts)
            calls.ask_current = { tool_name = tool_name, opts = opts }
        end,
    }, {
        toggle = "<leader>zt",
        pick = "<leader>zk",
        headings = "<leader>zh",
        markdown = "<leader>z0",
        codex = "<leader>zx",
        claude = "<leader>zc",
        ipython = "<leader>zi",
        restart_ipython = "<leader>zR",
        send_ipython = "<leader>zl",
        clear_ipython = "<leader>zX",
        focus = "<leader>zf",
        zoom = "<leader>zz",
        width_previous = "<leader>z-",
        width_next = "<leader>z+",
        width_picker = "<leader>zw",
        sticky_relative_width = "<leader>z%",
        switch = "<leader>zs",
        ask_pane = "<leader>za",
        ask = "<leader>za",
        ask_last = "zA",
        ask_codex = "zX",
        ask_claude = "zC",
    })

    global_map("<leader>zt").callback()
    assert(calls.toggle == true, "toggle map did not call toggle")
    global_map("<leader>zk").callback()
    assert(calls.pick == true, "pick map did not call pick")
    global_map("<leader>zh").callback()
    assert(calls.headings == true, "headings map did not call pick_headings")
    global_map("<leader>z0").callback()
    assert(calls.markdown == true, "markdown map did not call show_markdown")
    global_map("<leader>zx").callback()
    assert(calls.open_terminal.tool_name == "codex" and calls.open_terminal.opts.bufnr == bufnr, "codex map did not open codex for current buffer")
    global_map("<leader>zc").callback()
    assert(calls.open_terminal.tool_name == "claude" and calls.open_terminal.opts.focus == true, "claude map did not focus terminal")
    global_map("<leader>zi").callback()
    assert(calls.open_ipython.bufnr == bufnr and calls.open_ipython.focus == true, "ipython map did not use current buffer")
    global_map("<leader>zR").callback()
    assert(calls.restart_ipython.bufnr == bufnr and calls.restart_ipython.focus == true, "ipython restart map did not use current buffer")
    global_map("<leader>zl").callback()
    assert(calls.send_ipython.bufnr == bufnr and calls.send_ipython.line1 == 1 and calls.send_ipython.line2 == 1, "normal send map did not send current line")
    global_map("<leader>zl", "x").callback()
    assert(calls.send_ipython.bufnr == bufnr and calls.send_ipython.visual == true, "visual send map did not send visual selection")
    global_map("<leader>zX").callback()
    assert(calls.clear_ipython.bufnr == bufnr, "clear map did not use current buffer")
    global_map("<leader>zf").callback()
    assert(calls.focus == true, "focus map did not call focus toggle")
    global_map("<leader>zz").callback()
    assert(calls.zoom == true, "zoom map did not call zoom toggle")
    global_map("<leader>z-").callback()
    assert(calls.snap_width == "previous", "previous width map did not snap down")
    global_map("<leader>z+").callback()
    assert(calls.snap_width == "next", "next width map did not snap up")
    global_map("<leader>zw").callback()
    assert(calls.width_picker == true, "width picker map did not call picker")
    global_map("<leader>z%").callback()
    assert(calls.sticky_relative_width == true, "sticky relative width map did not call toggle")
    global_map("<leader>zs").callback()
    assert(calls.switch == true, "switch map did not call switch picker")
    global_map("<leader>za").callback()
    assert(calls.ask_pane.focus == true, "normal ask-pane map did not focus ask pane")
    global_map("<leader>za", "x").callback()
    assert(calls.ask.bufnr == bufnr and calls.ask.visual == true, "ask map did not use visual opts")
    global_map("zA", "x").callback()
    assert(calls.ask_last.bufnr == bufnr and calls.ask_last.visual == true, "ask-last map did not use visual opts")
    global_map("zX", "x").callback()
    assert(calls.ask_current.tool_name == "codex", "ask-codex map used wrong tool")
    global_map("zC", "x").callback()
    assert(calls.ask_current.tool_name == "claude", "ask-claude map used wrong tool")
end)

test("codex preset generator matches the default preset table", function()
    local tool = presets.codex({
        models = { "gpt-5.5", "gpt-5.6-sol" },
        efforts = { "high", "medium", "xhigh" },
        speeds = { "fast", "normal" },
        default = { model = "gpt-5.5", effort = "high", speed = "fast" },
    })

    assert(vim.deep_equal(tool.presets, defaults.config.tools.codex.presets), "generated Codex presets changed default shape")
end)

test("config normalizes ergonomic markdown and tool setup", function()
    reset_pane()

    pane.setup({
        layout = {
            width = 88,
            zoom_text_width = 77,
            sticky_relative_width = true,
            width_snap_points = { 72, "50%" },
            width_picker_points = { "1/3", 88 },
        },
        markdown = {
            wrap = true,
            auto_reload = false,
            reload_interval_ms = 250,
            reload_badge_ms = 1500,
            reload_badge = {
                text = "[FRESH]",
                clear_on_interaction = false,
                min_display_ms = 1250,
                hl = {
                    fg = "#111111",
                    bg = "#eeeeee",
                    bold = false,
                },
            },
            wrap_toggle_key = "<leader>tw",
            sticky_heading = false,
            reflow = {
                enabled = false,
                cmd = { "mdfmt", "--stdin", "--width", "{width}" },
                fallback = false,
                protect_tables = false,
                margin = 12,
            },
        },
        tools = {
            codex = {
                cmd = { "sh", "-c", "sleep 10" },
                models = { "gpt-5.5", "gpt-5.6-sol" },
                efforts = { "high", "medium" },
                speeds = { "fast", "normal" },
                default = { model = "gpt-5.6-sol", effort = "medium", speed = "normal" },
            },
            claude = false,
        },
        lifecycle = {
            focus_on_switch = false,
            focus_on_pick = false,
            focus_on_ask = false,
            shutdown_on_exit = false,
            shutdown_timeout_ms = 123,
        },
        terminal = {
            auto_resume = false,
            resume = {
                infer_from_transcripts = false,
                use_claude_pid_metadata = false,
                mechanisms = {
                    claude = { "hook" },
                    codex = false,
                },
                store_path = helpers.tmp_path("sidepanes-agent-config-store.json"),
                store_lock_timeout_ms = 222,
                store_lock_stale_ms = 333,
                resolver = function()
                    return "configured-session"
                end,
                failure_timeout_ms = 444,
                failure_action = "notify",
            },
            agent_resume_badge_ms = 2500,
            agent_resume_badge = {
                text = "[RECOVERED]",
                clear_on_interaction = false,
                hl = {
                    fg = "#101010",
                    bg = "#abcdef",
                    bold = false,
                },
            },
        },
        project = {
            root_markers = { ".git", "pyproject.toml" },
            fallback = "cwd",
            resolver = function()
                return root_fixture("setup-project-resolver-root")
            end,
        },
        ask = {
            ui = "pane",
            auto_append = false,
            duplicate_policy = "allow",
            model_picker = "before_send",
        },
        validation = {
            enabled = false,
        },
    })

    assert(pane.config.layout == nil, "ergonomic layout table leaked into runtime config")
    assert(pane.config.markdown == nil, "ergonomic markdown table leaked into runtime config")
    assert(pane.config.lifecycle == nil, "ergonomic lifecycle table leaked into runtime config")
    assert(pane.config.terminal == nil, "ergonomic terminal table leaked into runtime config")
    assert(pane.config.project == nil, "ergonomic project table leaked into runtime config")
    assert(pane.config.validation == nil, "ergonomic validation table leaked into runtime config")
    assert(pane.config.width == 88, "layout.width did not map to width")
    assert(pane.config.zoom_text_width == 77, "layout.zoom_text_width did not map to zoom_text_width")
    assert(pane.config.sticky_relative_width == true, "layout.sticky_relative_width did not map to sticky_relative_width")
    assert(pane.config.width_snap_points[2] == "50%", "layout.width_snap_points did not map to width_snap_points")
    assert(pane.config.width_picker_points[1] == "1/3", "layout.width_picker_points did not map to width_picker_points")
    assert(pane.config.wrap == true, "markdown.wrap did not map to wrap")
    assert(pane.config.auto_reload == false, "markdown.auto_reload did not map to auto_reload")
    assert(pane.config.reload_interval_ms == 250, "markdown.reload_interval_ms did not map to reload_interval_ms")
    assert(pane.config.reload_badge_ms == 1500, "markdown.reload_badge_ms did not map to reload_badge_ms")
    assert(pane.config.reload_badge.text == "[FRESH]", "markdown.reload_badge.text did not map to reload_badge.text")
    assert(pane.config.reload_badge.clear_on_interaction == false, "markdown.reload_badge.clear_on_interaction did not map")
    assert(pane.config.reload_badge.min_display_ms == 1250, "markdown.reload_badge.min_display_ms did not map")
    assert(pane.config.reload_badge.hl.bg == "#eeeeee", "markdown.reload_badge.hl did not map")
    assert(pane.config.wrap_toggle_key == "<leader>tw", "markdown.wrap_toggle_key did not map to wrap_toggle_key")
    assert(pane.config.sticky_heading == false, "markdown.sticky_heading did not map to sticky_heading")
    assert(pane.config.auto_reflow == false, "markdown.reflow.enabled did not map to auto_reflow")
    assert(pane.config.external_reflow_cmd[1] == "mdfmt", "markdown.reflow.cmd did not map to external_reflow_cmd")
    assert(pane.config.external_reflow_fallback == false, "markdown.reflow.fallback did not map to external_reflow_fallback")
    assert(pane.config.external_reflow_protect_tables == false, "markdown.reflow.protect_tables did not map to external_reflow_protect_tables")
    assert(pane.config.reflow_margin == 12, "markdown.reflow.margin did not map to reflow_margin")
    assert(pane.config.focus_on_switch == false, "lifecycle.focus_on_switch did not map to focus_on_switch")
    assert(pane.config.focus_on_pick == false, "lifecycle.focus_on_pick did not map to focus_on_pick")
    assert(pane.config.focus_on_ask == false, "lifecycle.focus_on_ask did not map to focus_on_ask")
    assert(pane.config.shutdown_on_exit == false, "lifecycle.shutdown_on_exit did not map to shutdown_on_exit")
    assert(pane.config.shutdown_timeout_ms == 123, "lifecycle.shutdown_timeout_ms did not map to shutdown_timeout_ms")
    assert(pane.config.agent_resume_badge_ms == 2500, "terminal.agent_resume_badge_ms did not map")
    assert(pane.config.agent_resume_badge.text == "[RECOVERED]", "terminal.agent_resume_badge.text did not map")
    assert(pane.config.agent_resume_badge.clear_on_interaction == false, "terminal.agent_resume_badge.clear_on_interaction did not map")
    assert(pane.config.agent_resume_badge.hl.bg == "#abcdef", "terminal.agent_resume_badge.hl did not map")
    assert(pane.config.agent_auto_resume == false, "terminal.auto_resume did not map")
    assert(pane.config.agent_resume_infer_from_transcripts == false, "terminal.resume.infer_from_transcripts did not map")
    assert(pane.config.agent_resume_use_claude_pid_metadata == false, "terminal.resume.use_claude_pid_metadata did not map")
    assert(pane.config.agent_resume_mechanisms.claude[1] == "hook", "terminal.resume.mechanisms did not map")
    assert(pane.config.agent_resume_mechanisms.codex == false, "terminal.resume.mechanisms false tool did not map")
    assert(pane.config.agent_resume_store_path:find("sidepanes%-agent%-config%-store%.json"), "terminal.resume.store_path did not map")
    assert(pane.config.agent_resume_store_lock_timeout_ms == 222, "terminal.resume.store_lock_timeout_ms did not map")
    assert(pane.config.agent_resume_store_lock_stale_ms == 333, "terminal.resume.store_lock_stale_ms did not map")
    assert(type(pane.config.agent_resume_resolver) == "function", "terminal.resume.resolver did not map")
    assert(pane.config.agent_resume_failure_timeout_ms == 444, "terminal.resume.failure_timeout_ms did not map")
    assert(pane.config.agent_resume_failure_action == "notify", "terminal.resume.failure_action did not map")
    assert(pane.config.project_root_markers[2] == "pyproject.toml", "project.root_markers did not map")
    assert(pane.config.project_root_fallback == "cwd", "project.fallback did not map")
    assert(type(pane.config.project_root_resolver) == "function", "project.resolver did not map")
    assert(pane.config.ask.ui == "pane", "ask.ui did not map")
    assert(pane.config.ask.auto_append == false, "ask.auto_append did not map")
    assert(pane.config.ask.duplicate_policy == "allow", "ask.duplicate_policy did not map")
    assert(pane.config.ask.model_picker == "before_send", "ask.model_picker did not map")
    assert(pane.config.mappings.pane.headings == "fm", "pane heading picker mapping default was lost")
    assert(pane.config.mappings.pane.ask_submit == "<C-CR>", "ask submit mapping default was lost")
    assert(pane.config.mappings.pane.ask_send == false, "ask send mapping default was lost")
    assert(pane.config.mappings.pane.ask_send_alt == false, "ask send alt mapping default was lost")
    assert(pane.config.mappings.pane.ask_model_picker == "M", "ask model picker mapping default was lost")
    assert(pane.config.mappings.pane.ask_model_picker_alt == "<Tab>", "ask model picker alt mapping default was lost")
    assert(pane.config.validate == false, "validation.enabled did not map to validate")
    assert(pane.config.tools.claude == nil, "disabled tool was still present")
    assert(pane.config.tools.codex.cmd[1] == "sh", "generated tool lost explicit command override")
    assert(pane.config.tools.codex.presets[1].name == "gpt56_sol_medium_normal", "default generated preset was not first")
    assert(pane.config.tools.codex.presets[1].model == "gpt-5.6-sol", "generated preset model was wrong")
    assert(pane.config.tools.codex.presets[1].effort == "medium", "generated preset effort was wrong")
    assert(pane.config.tools.codex.presets[1].speed == "normal", "generated preset speed was wrong")
end)

test("setup width accepts columns percentages fractions and numeric ratios", function()
    reset_pane()

    with_options({ columns = 160, winminwidth = 1 }, function()
        pane.setup({
            layout = {
                width = "50%",
                sticky_relative_width = false,
            },
        })

        assert(pane.config.width == 80, "setup percentage width did not resolve to columns")
        assert(pane.relative_width == nil, "nonsticky setup width stored a relative width")

        pane.setup({
            layout = {
                width = "1/4",
                sticky_relative_width = true,
            },
        })

        assert(pane.config.width == 40, "setup fraction width did not resolve to columns")
        assert(pane.relative_width and pane.relative_width.ratio == 0.25, "sticky setup fraction did not store relative width")

        pane.setup({
            layout = {
                width = 0.5,
                sticky_relative_width = true,
            },
        })

        assert(pane.config.width == 80, "setup numeric ratio width did not resolve to columns")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "sticky setup numeric ratio did not store relative width")
    end)
end)

test("canonical default setup normalizes to runtime defaults", function()
    local setup = config.default_setup()
    local normalized = config.normalize(vim.deepcopy(defaults.config), setup)

    assert(setup.width == nil, "default setup exposed flat width")
    assert(setup.external_reflow_cmd == nil, "default setup exposed flat reflow command")
    assert(setup.validate == nil, "default setup exposed flat validation key")
    assert(setup.layout.width == defaults.config.width, "default setup layout width was wrong")
    assert(setup.layout.zoom_text_width == defaults.config.zoom_text_width, "default setup zoom width was wrong")
    assert(setup.layout.sticky_relative_width == defaults.config.sticky_relative_width, "default setup sticky relative width was wrong")
    assert(vim.deep_equal(setup.layout.width_snap_points, defaults.config.width_snap_points), "default setup width snap points were wrong")
    assert(vim.deep_equal(setup.layout.width_picker_points, defaults.config.width_picker_points), "default setup width picker points were wrong")
    assert(setup.markdown.wrap == defaults.config.wrap, "default setup markdown wrap was wrong")
    assert(setup.markdown.auto_reload == defaults.config.auto_reload, "default setup auto reload was wrong")
    assert(setup.markdown.reload_interval_ms == defaults.config.reload_interval_ms, "default setup reload interval was wrong")
    assert(setup.markdown.reload_badge_ms == defaults.config.reload_badge_ms, "default setup reload badge timeout was wrong")
    assert(vim.deep_equal(setup.markdown.reload_badge, defaults.config.reload_badge), "default setup reload badge was wrong")
    assert(setup.markdown.reflow.enabled == defaults.config.auto_reflow, "default setup reflow enabled was wrong")
    assert(setup.lifecycle.focus_on_pick == defaults.config.focus_on_pick, "default setup focus-on-pick was wrong")
    assert(setup.lifecycle.shutdown_on_exit == defaults.config.shutdown_on_exit, "default setup lifecycle was wrong")
    assert(setup.project.root_markers[1] == ".git", "default setup project root marker was wrong")
    assert(setup.project.fallback == defaults.config.project_root_fallback, "default setup project fallback was wrong")
    assert(setup.terminal.auto_resume == defaults.config.agent_auto_resume, "default setup auto resume was wrong")
    assert(setup.terminal.resume.infer_from_transcripts == defaults.config.agent_resume_infer_from_transcripts, "default setup transcript inference was wrong")
    assert(setup.terminal.resume.use_claude_pid_metadata == defaults.config.agent_resume_use_claude_pid_metadata, "default setup Claude PID metadata was wrong")
    assert(vim.deep_equal(setup.terminal.resume.mechanisms, defaults.config.agent_resume_mechanisms), "default setup resume mechanisms were wrong")
    assert(setup.terminal.resume.store_lock_timeout_ms == defaults.config.agent_resume_store_lock_timeout_ms, "default setup store lock timeout was wrong")
    assert(setup.terminal.resume.store_lock_stale_ms == defaults.config.agent_resume_store_lock_stale_ms, "default setup stale lock timeout was wrong")
    assert(setup.terminal.resume.failure_timeout_ms == defaults.config.agent_resume_failure_timeout_ms, "default setup resume failure timeout was wrong")
    assert(setup.terminal.resume.failure_action == defaults.config.agent_resume_failure_action, "default setup resume failure action was wrong")
    assert(setup.terminal.agent_resume_badge_ms == defaults.config.agent_resume_badge_ms, "default setup resume badge timeout was wrong")
    assert(vim.deep_equal(setup.terminal.agent_resume_badge, defaults.config.agent_resume_badge), "default setup resume badge was wrong")
    assert(vim.deep_equal(setup.ask, defaults.config.ask), "default setup ask config was wrong")
    assert(setup.ask.ui == "float", "default setup ask ui was not float")
    assert(vim.deep_equal(setup.help, defaults.config.help), "default setup help config was wrong")
    assert(setup.validation.enabled == defaults.config.validate, "default setup validation was wrong")
    assert(vim.deep_equal(normalized, defaults.config), "canonical default setup did not round-trip to runtime defaults")
end)

test("runtime config converts to canonical setup shape", function()
    local runtime = vim.tbl_deep_extend("force", vim.deepcopy(defaults.config), {
        width = 72,
        zoom_text_width = 66,
        sticky_relative_width = true,
        width_snap_points = { 64, "1/2" },
        width_picker_points = { "1/4", 72 },
        wrap = true,
        auto_reload = false,
        reload_interval_ms = 500,
        reload_badge_ms = 2000,
        reload_badge = {
            text = "[SYNCED]",
            clear_on_interaction = true,
            min_display_ms = 1750,
            hl = {
                fg = "CursorFG",
                bg = "WarningMsg",
                bold = true,
            },
        },
        wrap_toggle_key = "<leader>xw",
        sticky_heading = false,
        auto_reflow = false,
        external_reflow_cmd = { "mdfmt", "--stdin" },
        external_reflow_fallback = false,
        external_reflow_protect_tables = false,
        reflow_margin = 5,
        focus_on_switch = false,
        focus_on_pick = false,
        focus_on_ask = false,
        shutdown_on_exit = false,
        shutdown_timeout_ms = 99,
        agent_auto_resume = false,
        agent_resume_infer_from_transcripts = false,
        agent_resume_use_claude_pid_metadata = false,
        agent_resume_mechanisms = {
            claude = { "hook" },
            codex = { "transcript" },
        },
        agent_resume_store_path = "/tmp/sidepanes-agent-store.json",
        agent_resume_store_lock_timeout_ms = 1200,
        agent_resume_store_lock_stale_ms = 9000,
        agent_resume_resolver = function()
            return "runtime-session"
        end,
        agent_resume_failure_timeout_ms = 800,
        agent_resume_failure_action = "notify",
        agent_resume_badge_ms = 3000,
        agent_resume_badge = {
            text = "[RECOVERED]",
            clear_on_interaction = true,
            hl = {
                fg = "CursorFG",
                bg = "DiagnosticInfo",
                bold = true,
            },
        },
        project_root_markers = { ".git", "package.json" },
        project_root_fallback = "cwd",
        project_root_resolver = function()
            return "/tmp/sidepanes-project-root"
        end,
        ask = {
            ui = "pane",
            auto_append = false,
            duplicate_policy = "allow",
            model_picker = "after_open",
        },
        help = {
            winbar = false,
            mapping = "g?",
            scope = "pane_first",
        },
        validate = false,
    })
    local setup = config.to_setup(runtime)
    local normalized = config.normalize(vim.deepcopy(defaults.config), setup)

    assert(setup.layout.width == 72, "to_setup lost width")
    assert(setup.layout.zoom_text_width == 66, "to_setup lost zoom text width")
    assert(setup.layout.sticky_relative_width == true, "to_setup lost sticky relative width")
    assert(setup.layout.width_snap_points[2] == "1/2", "to_setup lost width snap points")
    assert(setup.layout.width_picker_points[2] == 72, "to_setup lost width picker points")
    assert(setup.markdown.wrap == true, "to_setup lost markdown wrap")
    assert(setup.markdown.auto_reload == false, "to_setup lost markdown auto reload")
    assert(setup.markdown.reload_interval_ms == 500, "to_setup lost markdown reload interval")
    assert(setup.markdown.reload_badge_ms == 2000, "to_setup lost markdown reload badge timeout")
    assert(setup.markdown.reload_badge.text == "[SYNCED]", "to_setup lost markdown reload badge")
    assert(setup.markdown.reload_badge.min_display_ms == 1750, "to_setup lost markdown reload badge minimum display")
    assert(setup.markdown.wrap_toggle_key == "<leader>xw", "to_setup lost wrap mapping")
    assert(setup.markdown.sticky_heading == false, "to_setup lost sticky heading")
    assert(setup.markdown.reflow.enabled == false, "to_setup lost reflow enabled")
    assert(setup.markdown.reflow.cmd[1] == "mdfmt", "to_setup lost reflow command")
    assert(setup.markdown.reflow.fallback == false, "to_setup lost reflow fallback")
    assert(setup.markdown.reflow.protect_tables == false, "to_setup lost table protection")
    assert(setup.markdown.reflow.margin == 5, "to_setup lost reflow margin")
    assert(setup.lifecycle.focus_on_switch == false, "to_setup lost focus_on_switch")
    assert(setup.lifecycle.focus_on_pick == false, "to_setup lost focus_on_pick")
    assert(setup.lifecycle.focus_on_ask == false, "to_setup lost focus_on_ask")
    assert(setup.lifecycle.shutdown_on_exit == false, "to_setup lost shutdown_on_exit")
    assert(setup.lifecycle.shutdown_timeout_ms == 99, "to_setup lost shutdown timeout")
    assert(setup.terminal.auto_resume == false, "to_setup lost auto resume")
    assert(setup.terminal.resume.infer_from_transcripts == false, "to_setup lost transcript inference")
    assert(setup.terminal.resume.use_claude_pid_metadata == false, "to_setup lost Claude PID metadata")
    assert(setup.terminal.resume.mechanisms.claude[1] == "hook", "to_setup lost resume mechanisms")
    assert(setup.terminal.resume.store_path == "/tmp/sidepanes-agent-store.json", "to_setup lost resume store path")
    assert(setup.terminal.resume.store_lock_timeout_ms == 1200, "to_setup lost resume store lock timeout")
    assert(setup.terminal.resume.store_lock_stale_ms == 9000, "to_setup lost resume stale lock timeout")
    assert(type(setup.terminal.resume.resolver) == "function", "to_setup lost resume resolver")
    assert(setup.terminal.resume.failure_timeout_ms == 800, "to_setup lost resume failure timeout")
    assert(setup.terminal.resume.failure_action == "notify", "to_setup lost resume failure action")
    assert(setup.terminal.agent_resume_badge_ms == 3000, "to_setup lost resume badge timeout")
    assert(setup.terminal.agent_resume_badge.text == "[RECOVERED]", "to_setup lost resume badge")
    assert(setup.project.root_markers[2] == "package.json", "to_setup lost project root markers")
    assert(setup.project.fallback == "cwd", "to_setup lost project fallback")
    assert(type(setup.project.resolver) == "function", "to_setup lost project resolver")
    assert(setup.ask.ui == "pane", "to_setup lost ask ui")
    assert(setup.ask.auto_append == false, "to_setup lost ask auto_append")
    assert(setup.ask.duplicate_policy == "allow", "to_setup lost ask duplicate policy")
    assert(setup.ask.model_picker == "after_open", "to_setup lost ask model picker")
    assert(setup.help.winbar == false, "to_setup lost help winbar flag")
    assert(setup.help.mapping == "g?", "to_setup lost help mapping")
    assert(setup.help.scope == "pane_first", "to_setup lost help scope")
    assert(setup.validation.enabled == false, "to_setup lost validation flag")
    assert(vim.deep_equal(normalized, runtime), "canonical setup did not round-trip custom runtime config")
end)

test("config expansion leaves legacy presets intact", function()
    local legacy = {
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = {
                    { name = "custom", label = "Custom", args = { "--custom" } },
                },
            },
        },
    }
    local normalized = config.normalize(vim.deepcopy(defaults.config), legacy)

    assert(normalized.tools.codex.presets[1].name == "custom", "legacy preset name changed")
    assert(normalized.tools.codex.presets[1].label == "Custom", "legacy preset label changed")
    assert(normalized.tools.codex.presets[1].args[1] == "--custom", "legacy preset args changed")
    assert(normalized.tools.codex.presets[1].model == nil, "legacy preset gained generated model")
    assert(normalized.tools.codex.presets[1].effort == nil, "legacy preset gained generated effort")
    assert(normalized.tools.codex.presets[1].speed == nil, "legacy preset gained generated speed")
    assert(normalized.tools.codex.presets[2] == nil, "legacy preset list did not replace defaults")
end)

test("preset generators derive presets from default-only ergonomic config", function()
    local normalized = config.normalize(vim.deepcopy(defaults.config), {
        tools = {
            codex = {
                default = { model = "gpt-5.6-sol", effort = "high", speed = "fast" },
            },
            claude = {
                default = { model = "opus", effort = "high" },
            },
        },
    })

    local codex_preset = normalized.tools.codex.presets[1]
    local claude_preset = normalized.tools.claude.presets[1]
    local cmd = util.command_list(normalized.tools.codex, codex_preset, "/tmp/project")

    assert(#normalized.tools.codex.presets == 1, "default-only Codex config generated extra presets")
    assert(codex_preset.name == "gpt56_sol_high_fast", "default-only Codex preset name was wrong")
    assert(codex_preset.label == "GPT-5.6 Sol / high / fast", "default-only Codex preset label was wrong")
    assert(cmd[1] == "codex", "generated Codex command did not use default cmd")
    assert(cmd[2] == "--cd" and cmd[3] == "/tmp/project", "generated Codex command lost --cd root")
    assert(vim.tbl_contains(cmd, "gpt-5.6-sol"), "generated Codex command lost model")
    assert(vim.tbl_contains(cmd, 'model_reasoning_effort="high"'), "generated Codex command lost effort")
    assert(vim.tbl_contains(cmd, 'service_tier="priority"'), "generated Codex fast command lost priority tier")
    assert(#normalized.tools.claude.presets == 1, "default-only Claude config generated extra presets")
    assert(claude_preset.name == "opus_high", "default-only Claude preset name was wrong")
    assert(claude_preset.label == "Opus / high", "default-only Claude preset label was wrong")
end)

test("preset generators fill missing ergonomic dimensions", function()
    local normalized = config.normalize(vim.deepcopy(defaults.config), {
        tools = {
            codex = {
                model = "gpt-5.6-sol",
            },
            claude = {
                model = "opus",
            },
        },
    })

    local codex_preset = normalized.tools.codex.presets[1]
    local claude_preset = normalized.tools.claude.presets[1]

    assert(#normalized.tools.codex.presets == 1, "model-only Codex config generated wrong preset count")
    assert(codex_preset.name == "gpt56_sol_high_fast", "model-only Codex preset name was wrong")
    assert(codex_preset.label == "GPT-5.6 Sol / high / fast", "model-only Codex preset label was wrong")
    assert(codex_preset.effort == "high", "model-only Codex preset did not default effort")
    assert(codex_preset.speed == "fast", "model-only Codex preset did not default speed")
    assert(vim.tbl_contains(codex_preset.args, 'service_tier="priority"'), "fast Codex preset lost priority tier")
    assert(#normalized.tools.claude.presets == 1, "model-only Claude config generated wrong preset count")
    assert(claude_preset.name == "opus", "model-only Claude preset name was wrong")
    assert(claude_preset.label == "Opus / normal", "model-only Claude preset label was wrong")
    assert(claude_preset.effort == "medium", "model-only Claude preset did not default effort")
end)

test("preset generators use default models for effort-only config", function()
    local normalized = config.normalize(vim.deepcopy(defaults.config), {
        tools = {
            codex = {
                effort = "medium",
                speed = "fast",
            },
            claude = {
                effort = "high",
            },
        },
    })

    local codex_preset = normalized.tools.codex.presets[1]
    local claude_preset = normalized.tools.claude.presets[1]

    assert(codex_preset.model == "gpt-5.5", "effort-only Codex config did not default model")
    assert(codex_preset.name == "gpt55_medium_fast", "effort-only Codex preset name was wrong")
    assert(claude_preset.model == "sonnet", "effort-only Claude config did not default model")
    assert(claude_preset.name == "sonnet_high", "effort-only Claude preset name was wrong")
end)

test("empty preset helpers match plugin default choices", function()
    local codex = presets.codex({})
    local claude = presets.claude({})
    local codex_preset = codex.presets[1]
    local claude_preset = claude.presets[1]

    assert(codex_preset.name == "gpt55_high_fast", "empty Codex helper did not use default preset")
    assert(codex_preset.label == "GPT-5.5 / high / fast", "empty Codex helper label was wrong")
    assert(codex_preset.model == "gpt-5.5", "empty Codex helper model was wrong")
    assert(codex_preset.speed == "fast", "empty Codex helper speed was wrong")
    assert(claude_preset.name == "sonnet", "empty Claude helper did not use default preset")
    assert(claude_preset.label == "Sonnet / normal", "empty Claude helper label was wrong")
    assert(claude_preset.model == "sonnet", "empty Claude helper model was wrong")
    assert(claude_preset.effort == "medium", "empty Claude helper effort was wrong")
end)

test("health check reports configured commands, mappings, and tools", function()
    reset_pane()

    local reports = capture_health(function()
        health.check({
            config = {
                external_reflow_cmd = { "sh", "-c", "cat" },
                external_reflow_fallback = true,
                external_reflow_protect_tables = true,
                commands = false,
                mappings = {
                    global = false,
                    pane = {
                        markdown = "<space>0",
                    },
                },
                tools = {
                    codex = {
                        label = "Codex",
                        cmd = "sh",
                        exit_command = "/quit\r",
                        presets = {
                            { name = "default", label = "Default", args = {} },
                        },
                    },
                    claude = {
                        label = "Claude",
                        cmd = "sh",
                        exit_command = "/exit\r",
                        presets = {
                            { name = "default", label = "Default", args = {} },
                        },
                    },
                    ipython = {
                        label = "IPython",
                        cmd = "sh",
                        exit_command = "quit()\r",
                        presets = {
                            { name = "default", label = "Default", args = {} },
                        },
                    },
                },
            },
        })
    end)

    assert(has_health_report(reports, "ok", "sidepanes.nvim loaded"), "health did not report plugin loaded")
    assert(has_health_report(reports, "info", "Version: 0.4.0-dev"), "health did not report version")
    assert(has_health_report(reports, "info", "Load path: " .. helpers.repo_root(1)), "health did not report load path")
    assert(has_health_report(reports, "ok", "External reflow command found: sh"), "health did not find reflow command")
    assert(has_health_report(reports, "ok", "Codex command found: sh"), "health did not find Codex command")
    assert(has_health_report(reports, "ok", "Claude command found: sh"), "health did not find Claude command")
    assert(has_health_report(reports, "ok", "IPython command found: sh"), "health did not find IPython command")
    assert(has_health_report(reports, "ok", "Treesitter markdown parser found"), "health did not check markdown parser")
    assert(has_health_report(reports, "info", "Sidepanes user commands are disabled."), "health did not report disabled commands")
    assert(has_health_report(reports, "info", "Global mappings are disabled."), "health did not report disabled global mappings")
    assert(has_health_report(reports, "ok", "Pane-local mapping configured (n): <space>0"), "health did not report pane mapping mode")
end)

test("health check reports malformed config", function()
    local reports = capture_health(function()
        health.check({
            config = {
                width = 80,
                width_snap_points = { 80, true },
                width_picker_points = { "1/2", false },
                external_reflow_cmd = { "definitely_missing_sidepanes_reflow_cmd" },
                external_reflow_fallback = false,
                external_reflow_protect_tables = false,
                commands = {
                    toggle = true,
                },
                mappings = {
                    global = {
                        toggle = true,
                    },
                    pane = {
                        markdown = true,
                    },
                },
                tools = {
                    codex = {
                        label = "Codex",
                        cmd = "definitely_missing_sidepanes_codex_cmd",
                        presets = {},
                    },
                    claude = false,
                    ipython = {
                        label = "IPython",
                        cmd = function()
                            error("broken command")
                        end,
                        presets = {
                            { name = "bad", args = "--bad" },
                        },
                    },
                },
            },
        })
    end)

    assert(has_health_report(reports, "error", "External reflow command not found"), "health did not report missing reflow command")
    assert(has_health_report(reports, "error", "Invalid width_snap_points entry at index 2"), "health did not report invalid width snap point")
    assert(has_health_report(reports, "error", "Invalid width_picker_points entry at index 2"), "health did not report invalid width picker point")
    assert(has_health_report(reports, "warn", "External reflow table protection is disabled."), "health did not report table protection warning")
    assert(has_health_report(reports, "error", "Invalid command name for toggle"), "health did not report invalid command name")
    assert(has_health_report(reports, "error", "Invalid global mapping for toggle"), "health did not report invalid global mapping")
    assert(has_health_report(reports, "error", "Invalid pane mapping for markdown"), "health did not report invalid pane mapping")
    assert(has_health_report(reports, "error", "Codex command not found"), "health did not report missing Codex command")
    assert(has_health_report(reports, "error", "Codex has no presets configured."), "health did not report missing Codex presets")
    assert(has_health_report(reports, "warn", "Tool disabled or missing: claude"), "health did not report disabled Claude")
    assert(has_health_report(reports, "error", "IPython command function failed."), "health did not report failing IPython command function")
    assert(has_health_report(reports, "error", "IPython preset bad has invalid args."), "health did not report invalid preset args")
end)

test("setup validation reports malformed config and implied dependency gaps", function()
    local original_missing = dependencies.missing

    dependencies.missing = function(feature_name)
        if feature_name == "heading_picker" then
            return { "Treesitter markdown parser" }
        elseif feature_name == "document_picker" then
            return { "telescope.nvim" }
        end

        return {}
    end

    local diagnostics = validation.diagnostics({
        commands = {
            root = "Sidepanes",
            pick = "SidepanesPick",
            headings = "SidepanesHeadings",
            width = "SidepanesWidth",
            bogus = "Nope",
            zoom = true,
        },
        mappings = {
            global = {
                pick = "<leader>p",
                headings = "<leader>h",
                zoom = true,
            },
            pane = {
                gf = "gf",
                markdown = true,
            },
        },
        width_snap_points = { 80, true },
        width_picker_points = { "1/2", false },
        reload_interval_ms = 0,
        reload_badge_ms = -1,
        reload_badge = {
            text = true,
            clear_on_interaction = "yes",
            min_display_ms = "soon",
            hl = "WarningMsg",
        },
        project_root_markers = 42,
        project_root_fallback = "never",
        project_root_resolver = "rooter",
        ask = {
            ui = "popup",
            auto_append = "yes",
            duplicate_policy = "confirm",
            model_picker = "always",
            mystery = true,
        },
        help = {
            winbar = "yes",
            mapping = true,
            scope = "global",
            mystery = true,
        },
        agent_auto_resume = "yes",
        agent_resume_infer_from_transcripts = "no",
        agent_resume_use_claude_pid_metadata = "maybe",
        agent_resume_mechanisms = {
            codex = { "transcript", false, "custom" },
            claude = "hook",
        },
        agent_resume_store_path = 42,
        agent_resume_store_lock_timeout_ms = -1,
        agent_resume_store_lock_stale_ms = "old",
        agent_resume_resolver = "resolver",
        agent_resume_failure_timeout_ms = -2,
        agent_resume_failure_action = "restart",
        agent_resume_badge_ms = -1,
        agent_resume_badge = {
            text = true,
            clear_on_interaction = "yes",
            hl = "DiagnosticInfo",
        },
        tools = {
            broken = {
                cmd = "definitely_missing_sidepanes_validation_cmd",
                presets = {},
            },
        },
    })

    dependencies.missing = original_missing

    local messages = vim.tbl_map(function(item)
        return item.message
    end, diagnostics)
    local joined = table.concat(messages, "\n")

    assert(joined:find("Unknown Sidepanes command config key: bogus", 1, true), joined)
    assert(not joined:find("Unknown Sidepanes command config key: width", 1, true), joined)
    assert(joined:find("Invalid Sidepanes command config for zoom", 1, true), joined)
    assert(joined:find("Invalid Sidepanes global mapping for zoom", 1, true), joined)
    assert(joined:find("Invalid Sidepanes pane mapping for markdown", 1, true), joined)
    assert(joined:find("Sidepanes dependency missing for document picker: telescope.nvim", 1, true), joined)
    assert(joined:find("Sidepanes dependency missing for markdown headings: Treesitter markdown parser", 1, true), joined)
    assert(joined:find("Invalid Sidepanes width_snap_points entry at index 2", 1, true), joined)
    assert(joined:find("Invalid Sidepanes width_picker_points entry at index 2", 1, true), joined)
    assert(joined:find("Sidepanes config reload_interval_ms must be a positive number.", 1, true), joined)
    assert(joined:find("Sidepanes config reload_badge_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config reload_badge.text must be a string.", 1, true), joined)
    assert(joined:find("Sidepanes config reload_badge.clear_on_interaction must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config reload_badge.min_display_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config reload_badge.hl must be a table.", 1, true), joined)
    assert(joined:find("Sidepanes config project_root_markers must be a string, table, function, or false.", 1, true), joined)
    assert(joined:find("Sidepanes config project_root_fallback must be 'buffer_dir' or 'cwd'.", 1, true), joined)
    assert(joined:find("Sidepanes config project_root_resolver must be a function.", 1, true), joined)
    assert(joined:find("Unknown Sidepanes ask config key: mystery", 1, true), joined)
    assert(joined:find("Sidepanes config ask.ui must be 'float' or 'pane'.", 1, true), joined)
    assert(joined:find("Sidepanes config ask.auto_append must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config ask.duplicate_policy must be 'skip' or 'allow'.", 1, true), joined)
    assert(joined:find("Sidepanes config ask.model_picker must be 'manual', 'after_open', or 'before_send'.", 1, true), joined)
    assert(joined:find("Unknown Sidepanes help config key: mystery", 1, true), joined)
    assert(joined:find("Sidepanes config help.winbar must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config help.mapping must be a lhs string or false.", 1, true), joined)
    assert(joined:find("Sidepanes config help.scope must be 'pane_first'.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_auto_resume must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_infer_from_transcripts must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_use_claude_pid_metadata must be a boolean.", 1, true), joined)
    assert(joined:find("Invalid Sidepanes agent_resume_mechanisms.codex entry at index 2", 1, true), joined)
    assert(joined:find("Unknown Sidepanes agent_resume_mechanisms.codex entry at index 3: custom. Use terminal.resume.resolver for custom session discovery.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_mechanisms.claude must be a table or false.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_store_path must be a string or false.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_store_lock_timeout_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_store_lock_stale_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_resolver must be a function.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_failure_timeout_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_failure_action must be 'fresh', 'notify', or 'ignore'.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.text must be a string.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.clear_on_interaction must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.hl must be a table.", 1, true), joined)
    assert(joined:find("Sidepanes tool executable not found for broken", 1, true), joined)
    assert(joined:find("Sidepanes tool has no presets configured: broken", 1, true), joined)
end)

test("setup validation accepts native project marker groups and warns on invalid entries", function()
    local valid = validation.diagnostics({
        project_root_markers = {
            { "pyproject.toml", "package.json" },
            function()
                return false
            end,
            ".git",
        },
    })

    assert(#valid == 0, "native project marker groups produced diagnostics: " .. vim.inspect(valid))

    local invalid = validation.diagnostics({
        project_root_markers = {
            "pyproject.toml",
            { false },
        },
    })
    local joined = table.concat(vim.tbl_map(function(item)
        return item.message
    end, invalid), "\n")

    assert(joined:find("Sidepanes config project_root_markers entries must be strings, functions, or nested marker tables.", 1, true), joined)
end)

test("setup validation accepts ask config and rejects malformed ask tables", function()
    local valid = validation.diagnostics({
        ask = {
            ui = "pane",
            auto_append = true,
            duplicate_policy = "skip",
            model_picker = "manual",
        },
    })

    assert(#valid == 0, "valid ask config produced diagnostics: " .. vim.inspect(valid))

    local invalid = validation.diagnostics({
        ask = true,
    })
    local joined = table.concat(vim.tbl_map(function(item)
        return item.message
    end, invalid), "\n")

    assert(joined:find("Sidepanes config ask must be a table.", 1, true), joined)
end)

test("setup validation accepts help config and rejects malformed help tables", function()
    local valid = validation.diagnostics({
        help = {
            winbar = true,
            mapping = "g?",
            scope = "pane_first",
        },
    })

    assert(#valid == 0, "valid help config produced diagnostics: " .. vim.inspect(valid))

    local invalid = validation.diagnostics({
        help = true,
    })
    local joined = table.concat(vim.tbl_map(function(item)
        return item.message
    end, invalid), "\n")

    assert(joined:find("Sidepanes config help must be a table.", 1, true), joined)
end)

test("setup validation can be disabled", function()
    local messages = capture_notify(function()
        validation.notify({
            validate = false,
            commands = {
                zoom = true,
            },
            tools = {
                broken = {
                    cmd = "definitely_missing_sidepanes_validation_cmd",
                    presets = {},
                },
            },
        })
    end)

    assert(#messages == 0, "validation emitted notifications despite validate=false")
end)

test("pane setup emits validation warnings", function()
    reset_pane()

    local original_missing = dependencies.missing

    dependencies.missing = function(feature_name)
        if feature_name == "document_picker" then
            return { "telescope.nvim" }
        end

        return {}
    end

    local messages = capture_notify(function()
        pane.setup({
            commands = {
                pick = "SidepanesPick",
            },
            tools = {
                codex = false,
                claude = false,
                ipython = false,
            },
        })
    end)

    dependencies.missing = original_missing

    assert(has_notify(messages, "Sidepanes dependency missing for document picker: telescope.nvim"), "setup did not emit dependency validation warning")
end)

test("runtime dependency guards stop feature commands gracefully", function()
    local original_notify_missing = dependencies.notify_missing
    local calls = {}

    dependencies.notify_missing = function(feature_name)
        table.insert(calls, feature_name)
        return true
    end

    document_picker.pick(function()
        error("document picker callback should not run when dependency is missing")
    end)
    heading_picker.pick({
        is_open = function()
            return false
        end,
    })

    dependencies.notify_missing = original_notify_missing

    assert(vim.tbl_contains(calls, "document_picker"), "document picker did not check dependencies")
    assert(vim.tbl_contains(calls, "heading_picker"), "heading picker did not check dependencies")
end)

test("runtime dependency warning names missing parser", function()
    local original_missing = dependencies.missing

    dependencies.missing = function(feature_name)
        if feature_name == "heading_picker" then
            return { "Treesitter markdown parser" }
        end

        return {}
    end

    local messages = capture_notify(function()
        assert(dependencies.notify_missing("heading_picker") == true, "heading dependency guard did not stop")
    end)

    dependencies.missing = original_missing

    assert(has_notify(messages, "Sidepanes dependency missing for markdown headings: Treesitter markdown parser"), "missing parser warning was not clear")
end)

test("context identifies pane buffers and resolves pane roots", function()
    reset_pane()

    local root = root_fixture("context-root-test")
    local other = root_fixture("context-other-root-test")

    write(root .. "/docs/doc.md", { "# Doc", "", "body" })
    write(other .. "/src/normal.py", { "print('normal')" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    local normal_buf = vim.fn.bufadd(other .. "/src/normal.py")

    vim.fn.bufload(normal_buf)

    local ctx = pane.open_terminal("codex", nil, { root = root, focus = false })

    assert(pane_context.is_pane_buf(pane, pane.bufnr), "sidepanes buffer was not identified")
    assert(pane_context.is_pane_buf(pane, ctx.bufnr), "terminal pane buffer was not identified")
    assert(not pane_context.is_pane_buf(pane, normal_buf), "normal buffer was identified as pane buffer")
    assert(pane_context.pane_root(pane, pane.bufnr) == root, "sidepanes root did not use source")
    assert(pane_context.pane_root(pane, ctx.bufnr) == root, "terminal pane root did not use terminal context")
    assert(pane_context.pane_root(pane, normal_buf) == other, "normal buffer root was wrong")
end)

test("context selection metadata uses markdown source and terminal identity", function()
    reset_pane()

    local root = root_fixture("context-selection-test")

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "```python",
        "value = 42",
        "```",
    })
    pane.setup({})
    pane.open(root .. "/docs/doc.md")

    local markdown_context = pane_context.selection_context(pane, {
        bufnr = pane.bufnr,
        line1 = 4,
        line2 = 4,
    })

    assert(markdown_context.file == "docs/doc.md", markdown_context.file)
    assert(markdown_context.root == root, markdown_context.root)
    assert(markdown_context.snippet_filetype == "python", markdown_context.snippet_filetype)

    local terminal_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(terminal_buf, 0, -1, false, { "Traceback line" })

    pane.terminals.fake = {
        bufnr = terminal_buf,
        root = root,
        tool_label = "Codex",
        preset_label = "Default",
    }

    local terminal_context = pane_context.selection_context(pane, {
        bufnr = terminal_buf,
        line1 = 1,
        line2 = 1,
    })

    assert(terminal_context.file == "Terminal: Codex / Default", terminal_context.file)
    assert(terminal_context.root == root, terminal_context.root)
    assert(terminal_context.text == "Traceback line", terminal_context.text)
end)

test("pane-local slot maps switch between markdown, agents, and IPython", function()
    reset_pane()

    local root = root_fixture("pane-slot-switch-test")
    write(root .. "/docs/doc.md", { "# Doc" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()

    call_map(pane.bufnr, " x")
    assert(pane.active_mode == "codex", "space-x did not switch to Codex")

    local codex_buf = vim.api.nvim_win_get_buf(pane.winid)

    call_map(codex_buf, " c")
    assert(pane.active_mode == "claude", "space-c did not switch to Claude")

    local claude_buf = vim.api.nvim_win_get_buf(pane.winid)

    call_map(claude_buf, " i")
    assert(pane.active_mode == "ipython", "space-i did not switch to IPython")

    local ipython_buf = vim.api.nvim_win_get_buf(pane.winid)

    call_map(ipython_buf, " 0")
    assert(pane.active_mode == "markdown", "space-0 did not switch to markdown")
    assert(vim.api.nvim_win_get_buf(pane.winid) == pane.bufnr, "space-0 did not restore markdown buffer")
end)

test("pane switch accepts string and terminal entry targets", function()
    reset_pane()

    local root = root_fixture("switch-target-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = {
                    { name = "default", label = "Default", args = {} },
                    { name = "review", label = "Review", args = {} },
                },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    pane.switch("codex")
    assert(pane.active_mode == "codex", "string switch did not open Codex")

    pane.switch({
        kind = "terminal",
        tool_name = "codex",
        preset_name = "review",
    })

    local ctx = pane.terminals[next(pane.terminals)]

    assert(ctx and ctx.tool_name == "codex", "terminal entry switch did not keep Codex")
    assert(ctx.requested_preset and ctx.requested_preset.name == "review", "terminal entry switch did not request preset")
end)

test("public switch_to accepts strings, maps, roots, and aliases", function()
    reset_pane()

    local root = root_fixture("public-switch-to-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = {
                    { name = "default", label = "Default", args = {} },
                    { name = "review", label = "Review", args = {} },
                },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    local codex_ctx = sidepanes.switch_to({
        tool = "codex",
        preset = "review",
        root = root,
        focus = true,
    })

    assert(codex_ctx and codex_ctx.tool_name == "codex", "switch_to table did not open Codex")
    assert(codex_ctx.requested_preset and codex_ctx.requested_preset.name == "review", "switch_to table did not request preset")
    assert(pane.active_mode == "codex", "switch_to table did not set active Codex mode")
    assert(vim.api.nvim_get_current_win() == pane.winid, "switch_to focus override did not focus pane")

    sidepanes.switch_to("0")
    assert(pane.active_mode == "markdown", "switch_to 0 did not restore markdown")

    local ipython_ctx = sidepanes.switch_to("i", { root = root, focus = false })

    assert(ipython_ctx and ipython_ctx.tool_name == "ipython", "switch_to i did not open IPython")
    assert(pane.active_mode == "ipython", "switch_to i did not set active IPython mode")
end)

test("pane switch picker selects markdown and shortcut entries without enter", function()
    reset_pane()

    local root = root_fixture("switch-picker-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    pane._test_next_choice = "x"
    pane.switch_picker()
    assert(pane.active_mode == "codex", "picker x did not switch to Codex")

    pane._test_next_choice = "0"
    pane.switch_picker()
    assert(pane.active_mode == "markdown", "picker 0 did not switch to Markdown")
    assert(vim.api.nvim_win_get_buf(pane.winid) == pane.bufnr, "picker 0 did not restore markdown buffer")
end)

test("pane switch picker treats Ctrl-C as cancel", function()
    reset_pane()

    local root = root_fixture("switch-picker-cancel-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    local before_mode = pane.active_mode
    pane._test_getcharstr = function()
        error("Keyboard interrupt")
    end

    local ok, err = pcall(function()
        pane.switch_picker()
    end)

    pane._test_getcharstr = nil

    assert(ok, "switch picker Ctrl-C raised: " .. tostring(err))
    assert(pane.active_mode == before_mode, "switch picker Ctrl-C changed active mode")
end)

test("pane switch picker title includes current project name", function()
    reset_pane()

    local root = root_fixture("switch-picker-project-title")
    local prompts = {}

    write(root .. "/docs/doc.md", { "# Doc" })

    switcher.switch_picker({}, {
        numbered_select = function(prompt, entries, callback)
            table.insert(prompts, prompt)
            callback(entries[1])
        end,
        open_terminal = function() end,
        pane_root = function()
            return root
        end,
        show_markdown = function() end,
        terminal_context_for_buf = function()
            return nil
        end,
        terminal_entries = function()
            return {}
        end,
        tool_shortcut_entries = function()
            return {}
        end,
    })

    local expected = "Switch pane in " .. vim.fn.fnamemodify(root:gsub("/$", ""), ":t")

    assert(prompts[1] == expected, "switch picker title did not include project name: " .. tostring(prompts[1]))
end)

test("show last terminal falls back to Codex when no terminal was remembered", function()
    reset_pane()

    local root = root_fixture("last-terminal-fallback-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")

    pane.show_last_terminal({ root = root, focus = true })

    assert(pane.active_mode == "codex", "show_last_terminal did not fall back to Codex")
    assert(vim.api.nvim_get_current_win() == pane.winid, "show_last_terminal focus option did not focus pane")
end)

test("agent context lookups stay within the requested project root", function()
    reset_pane()

    local first_root = root_fixture("agent-context-first-root")
    local second_root = root_fixture("agent-context-second-root")

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    local first = pane.open_terminal("codex", nil, { root = first_root, focus = false })
    local second = pane.open_terminal("codex", nil, { root = second_root, focus = false })

    assert(first and second and first ~= second, "test did not create two running Codex panes")
    assert(pane.last_tool_terminal_keys.codex == second.key, "second Codex pane was not remembered as latest")

    local first_lookup = terminal_module.context_for_tool(pane, "codex", first_root)
    local first_agent = terminal_module.last_coding_agent_context(pane, first_root)
    local unscoped = terminal_module.context_for_tool(pane, "codex")

    assert(first_lookup == first, "root-scoped Codex lookup returned a different project context")
    assert(first_agent == first, "root-scoped last agent lookup returned a different project context")
    assert(unscoped == second, "unscoped Codex lookup did not keep latest-agent behavior")
end)

test("toggle markdown terminal flips between markdown and last remembered terminal", function()
    reset_pane()

    local root = root_fixture("toggle-terminal-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")
    pane.open_terminal("codex", nil, { root = root, focus = true })
    pane.open_terminal("ipython", nil, { root = root, focus = true })
    pane.show_markdown()

    pane.toggle_markdown_terminal()
    assert(pane.active_mode == "ipython", "toggle did not return to last remembered terminal")

    pane.toggle_markdown_terminal()
    assert(pane.active_mode == "markdown", "toggle did not return to markdown")
end)

test("old terminal helper names remain compatibility aliases", function()
    assert(type(sidepanes.show_last_agent) == "function", "show_last_agent is not callable")
    assert(type(sidepanes.toggle_markdown_agent) == "function", "toggle_markdown_agent is not callable")
    assert(pane.show_last_agent == pane.show_last_terminal, "show_last_agent is not an internal alias")
    assert(pane.toggle_markdown_agent == pane.toggle_markdown_terminal, "toggle_markdown_agent is not an internal alias")
end)

-- Ask layer: policy predicate and action-plan tests.
test("ask action policy classifies command lines plain quit mappings and lifecycle plans", function()
    local intents = ask_policy.INTENTS
    local actions = ask_policy.ACTIONS

    assert(ask_policy.commandline_intent("q") == intents.finish_quit, "q did not map to finish_quit")
    assert(ask_policy.commandline_intent(":quit") == intents.finish_quit, "quit did not map to finish_quit")
    assert(ask_policy.commandline_intent("q!") == intents.cancel_draft, "q! did not map to cancel_draft")
    assert(ask_policy.commandline_intent(":quit!") == intents.cancel_draft, "quit! did not map to cancel_draft")
    assert(ask_policy.commandline_intent("w") == intents.write_draft, "w did not map to write_draft")
    assert(ask_policy.commandline_intent("wq") == intents.submit_now, "wq did not map to submit_now")
    assert(ask_policy.commandline_intent("wq!") == intents.submit_now, "wq! did not map to submit_now")
    assert(ask_policy.commandline_intent("x") == intents.submit_now, "x did not map to submit_now")
    assert(ask_policy.commandline_intent("xit") == intents.submit_now, "xit did not map to submit_now")
    assert(ask_policy.commandline_intent("exit") == intents.submit_now, "exit did not map to submit_now")
    assert(ask_policy.commandline_intent("write") == nil, "write should not map to lifecycle intent")
    assert(intents.append_context == "append_context", "append context intent missing")
    assert(intents.change_target == "change_target", "change target intent missing")
    assert(intents.open_picker == "open_picker", "open picker intent missing")

    assert(actions.resolve_target == "resolve_target", "resolve target action missing")
    assert(actions.preserve_draft == "preserve_draft", "preserve draft action missing")
    assert(actions.restore_previous == "restore_previous", "restore previous action missing")

    assert(ask_policy.is_plain_quit_command(":q"), ":q was not recognized as plain quit")
    assert(ask_policy.is_plain_quit_command("quit"), "quit was not recognized as plain quit")
    assert(not ask_policy.is_plain_quit_command("q!"), "q! should not be a plain quit")

    assert(ask_policy.is_plain_quit_rhs(":q<CR>"), ":q<CR> was not recognized as plain quit RHS")
    assert(ask_policy.is_plain_quit_rhs(":quit\r"), ":quit carriage return was not recognized as plain quit RHS")
    assert(ask_policy.is_plain_quit_rhs("<cmd>q<cr>"), "<cmd>q<cr> was not recognized as plain quit RHS")
    assert(ask_policy.is_plain_quit_rhs("<cmd>quit<CR>"), "<cmd>quit<CR> was not recognized as plain quit RHS")
    assert(not ask_policy.is_plain_quit_rhs(":q!<CR>"), ":q!<CR> should not be plain quit RHS")
    assert(not ask_policy.is_plain_quit_rhs(":write<CR>"), ":write<CR> should not be plain quit RHS")

    assert(
        vim.deep_equal(ask_policy.lhs_candidates("<leader>qq", { leader = " " }), { "<leader>qq", " qq" }),
        "leader lhs candidates were wrong"
    )

    local facts = ask_policy.normalize_facts({
        active_target = "codex",
        dirty_buffer = true,
        live_prompt = "live",
        picker_mode = "before_send",
        previous_pane = "markdown",
        terminal_available = true,
        valid_buffer = true,
        written_prompt = "written",
    })

    assert(facts.valid_buffer == true and facts.valid_buf == true, "valid buffer facts were wrong")
    assert(facts.dirty_buffer == true and facts.modified == true, "dirty buffer facts were wrong")
    assert(facts.picker_mode == "before_send" and facts.model_picker == "before_send", "picker facts were wrong")
    assert(facts.active_target == "codex", "active target fact was lost")
    assert(facts.previous_pane == "markdown", "previous pane fact was lost")
    assert(facts.terminal_available == true, "terminal availability fact was lost")

    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.finish_quit, { valid_buf = false })), { actions.noop }),
        "finish invalid buffer plan was wrong"
    )
    assert(
        vim.deep_equal(
            plan_actions(ask_policy.plan(intents.finish_quit, { valid_buffer = true, dirty_buffer = true })),
            { actions.mark_draft_modified, actions.cancel_draft }
        ),
        "finish modified plan was wrong"
    )
    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.finish_quit, { valid_buf = true, written_prompt = "Question:" })), { actions.cancel_draft }),
        "finish empty written prompt plan was wrong"
    )
    assert(
        vim.deep_equal(
            plan_actions(ask_policy.plan(intents.finish_quit, { valid_buffer = true, written_prompt = "send", picker_mode = "before_send" })),
            { actions.open_before_send_picker }
        ),
        "finish before-send plan was wrong"
    )
    assert(
        vim.deep_equal(
            plan_actions(ask_policy.plan(intents.finish_quit, { valid_buf = true, written_prompt = "send", model_picker = "manual" })),
            { actions.send_prompt }
        ),
        "finish send plan was wrong"
    )
    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.submit_now, { valid_buf = false })), { actions.notify_no_prompt }),
        "submit invalid buffer plan was wrong"
    )
    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.submit_now, { valid_buf = true, live_prompt = "Question:" })), { actions.write_draft, actions.cancel_draft }),
        "submit empty prompt plan was wrong"
    )
    assert(
        vim.deep_equal(
            plan_actions(ask_policy.plan(intents.submit_now, { valid_buffer = true, live_prompt = "send", picker_mode = "before_send" })),
            { actions.write_draft, actions.open_before_send_picker }
        ),
        "submit before-send plan was wrong"
    )
    assert(
        vim.deep_equal(
            plan_actions(ask_policy.plan(intents.submit_now, { valid_buf = true, live_prompt = "send", model_picker = "manual" })),
            { actions.write_draft, actions.send_prompt }
        ),
        "submit send plan was wrong"
    )
    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.cancel_draft, { valid_buf = true })), { actions.cancel_draft }),
        "cancel draft plan was wrong"
    )
    assert(
        vim.deep_equal(plan_actions(ask_policy.plan(intents.write_draft, { valid_buf = true })), { actions.write_draft }),
        "write draft plan was wrong"
    )
end)

test("ask functional core modules do not call Neovim APIs directly", function()
    for _, module in ipairs({
        "sidepanes.ask_policy",
        "sidepanes.ask_cmdline",
        "sidepanes.panes.ask.cmdline",
        "sidepanes.ask_controller",
        "sidepanes.panes.ask.controller",
        "sidepanes.ask_executor",
        "sidepanes.panes.ask.executor",
        "sidepanes.ask_route",
        "sidepanes.ask_session",
        "sidepanes.panes.ask.session",
        "sidepanes.panes.ask.status",
        "sidepanes.ask_target_resolver",
        "sidepanes.panes.ask.target_resolver",
    }) do
        local path = vim.fn.getcwd() .. "/lua/" .. module:gsub("%.", "/") .. ".lua"
        local source = table.concat(vim.fn.readfile(path), "\n")

        assert(not source:find("vim%.", 1, false), module .. " contains a direct vim.* call")
    end
end)

test("ask pane module split keeps new namespace and old shims loadable", function()
    local pairs_to_check = {
        { "sidepanes.ask_pane", "sidepanes.panes.ask" },
        { "sidepanes.ask_cmdline", "sidepanes.panes.ask.cmdline" },
        { "sidepanes.ask_controller", "sidepanes.panes.ask.controller" },
        { "sidepanes.ask_executor", "sidepanes.panes.ask.executor" },
        { "sidepanes.ask_keymaps", "sidepanes.panes.ask.keymaps" },
        { "sidepanes.ask_session", "sidepanes.panes.ask.session" },
        { "sidepanes.ask_target_resolver", "sidepanes.panes.ask.target_resolver" },
    }

    for _, pair in ipairs(pairs_to_check) do
        local old_module = require(pair[1])
        local new_module = require(pair[2])

        assert(old_module == new_module, pair[1] .. " did not shim to " .. pair[2])
    end

    assert(ask_pane_module == ask_pane_entry, "test ask pane require path did not match new namespace")
    assert(type(require("sidepanes.panes.ask.navigation").jump_header) == "function", "ask navigation jump_header missing")
    assert(type(require("sidepanes.panes.ask.navigation").source_jump) == "function", "ask navigation source_jump missing")
    assert(type(ask_status.status_data) == "function", "ask status data formatter missing")
    assert(type(ask_status.debug_data) == "function", "ask status debug data formatter missing")
    assert(type(ask_status.debug_lines) == "function", "ask status debug line formatter missing")
    assert(type(ask_status.format_title) == "function", "ask status title formatter missing")
end)

test("ask target resolver centralizes pane-mode target decisions", function()
    local active = { label = "Active" }
    local last = { label = "Last" }
    local default = { label = "Default" }
    local extra = { label = "Extra" }
    local decision = ask_target_resolver.resolve({
        active_entry = active,
        last_entry = last,
        target_entries = { default },
        root = "/project",
    })

    assert(decision.kind == "target", "active ask target decision did not return target kind")
    assert(decision.entry == active, "active ask target was not preferred")
    assert(decision.reason == "active_ask_target", "active ask target reason was wrong")
    assert(decision.root == "/project", "resolver did not preserve root")

    decision = ask_target_resolver.resolve({
        last_entry = last,
        target_entries = { default },
    })
    assert(decision.entry == last and decision.reason == "last_coding_agent", "last coding agent was not preferred")

    decision = ask_target_resolver.resolve({
        target_entries = { default },
    })
    assert(decision.entry == default and decision.reason == "default_ask_target", "default ask target was not preferred")

    decision = ask_target_resolver.resolve({
        explicit_picker = true,
        picker_entries = { extra },
        target_entries = { default },
    })
    assert(decision.kind == "picker", "explicit target change should open picker")
    assert(decision.reason == "explicit_target_change", "explicit picker reason was wrong")
    assert(decision.entries[1] == default and decision.entries[2] == extra, "picker entries did not preserve target then extra order")
    assert(ask_target_resolver.REASONS.explicit_target == "explicit_target", "explicit target reason missing")

    decision = ask_target_resolver.resolve({})
    assert(decision.kind == "picker" and decision.reason == "no_target", "missing target route was wrong")

    decision = ask_target_resolver.before_send({
        active_entry = active,
        picker_entries = { extra },
        picker_mode = "before_send",
        target_entries = { default },
    })
    assert(decision.kind == "picker", "before_send should request picker even with an active target")
    assert(decision.reason == "before_send_picker", "before_send picker reason was wrong")
    assert(decision.entries[1] == default and decision.entries[2] == extra, "before_send picker entries were wrong")

    local entry, reason = ask_route.default_entry({
        active_entry = active,
        last_entry = last,
        target_entries = { default },
    })

    assert(entry == active and reason == "active_ask_target", "compat ask route did not delegate to resolver")

    assert(
        ask_route.auto_append_blocked({ auto_append = false, active_buf = 10, citation_count = 1 }),
        "auto_append=false with existing citations should focus the current draft"
    )
    assert(
        not ask_route.auto_append_blocked({ auto_append = false, active_buf = 10, citation_count = 0 }),
        "empty draft should still allow first append"
    )
    assert(
        not ask_route.auto_append_blocked({ auto_append = true, active_buf = 10, citation_count = 1 }),
        "auto_append=true should allow append"
    )
end)

-- Ask layer: snapshot and selector tests.
test("ask session snapshot exposes serializable state facts and labels", function()
    local raw = {
        bufnr = 12,
        citations = {
            { file = "src/one.lua", path = "/project/src/one.lua" },
            { file = "src/one.lua", path = "/project/src/one.lua" },
            { file = "src/two.lua", path = "/project/src/two.lua" },
        },
        draft_state = "draft_written",
        entry = {
            label = "Codex: Default",
            root = "/project",
        },
        model_picker_shown = true,
        previous = {
            active_mode = "codex",
            active_terminal_key = "codex:default:/project",
        },
        root = "/project",
        target_reason = "active_ask_target",
        written_prompt = "Question:\nhello",
    }

    local snapshot = ask_session.snapshot(raw, {
        ask_config = { model_picker = "after_open" },
        buffer = {
            live_prompt = "Question:\nhello live",
            modified = true,
            valid = true,
        },
        window = {
            active = true,
            valid = true,
        },
    })

    assert(snapshot.active == true, "snapshot did not mark valid ask session active")
    assert(snapshot.valid_buffer == true, "snapshot lost valid buffer fact")
    assert(snapshot.valid_window == true, "snapshot lost valid window fact")
    assert(snapshot.active_window == true, "snapshot lost active window fact")
    assert(snapshot.dirty_buffer == true, "snapshot lost modified buffer fact")
    assert(snapshot.live_prompt == "Question:\nhello live", "snapshot lost live prompt")
    assert(snapshot.written_prompt == "Question:\nhello", "snapshot lost written prompt")
    assert(snapshot.draft_state == "draft_written", "snapshot lost current draft state")
    assert(snapshot.target_reason == "active_ask_target", "snapshot target reason was wrong")
    assert(snapshot.target_label == "Codex: Default", "snapshot target label was wrong")
    assert(snapshot.target_root == "/project", "snapshot target root was wrong")
    assert(snapshot.picker_mode == "after_open", "snapshot picker mode was wrong")
    assert(snapshot.picker_shown == true, "snapshot picker shown fact was wrong")
    assert(snapshot.previous_pane_mode == "codex", "snapshot previous pane mode was wrong")
    assert(snapshot.citation_count == 3, "snapshot citation count was wrong")
    assert(snapshot.file_count == 2, "snapshot file count was wrong")

    local facts = ask_session.lifecycle_facts(snapshot)

    assert(facts.valid_buffer == true, "lifecycle facts lost valid buffer")
    assert(facts.dirty_buffer == true, "lifecycle facts lost dirty buffer")
    assert(facts.live_prompt == "Question:\nhello live", "lifecycle facts lost live prompt")
    assert(facts.written_prompt == "Question:\nhello", "lifecycle facts lost written prompt")
    assert(facts.picker_mode == "after_open", "lifecycle facts lost picker mode")
    assert(facts.active_target == "Codex: Default", "lifecycle facts lost active target")
    assert(facts.target_reason == "active_ask_target", "lifecycle facts lost target reason")
    assert(facts.previous_pane == "codex", "lifecycle facts lost previous pane")

    local status = ask_session.status_data(snapshot)

    assert(status.active == true, "status data lost active state")
    assert(status.draft_state == "draft_written", "status data lost draft state")
    assert(status.modified == true, "status data lost modified flag")
    assert(status.written == true, "status data lost written flag")
    assert(status.target_reason == "active_ask_target", "status data lost target reason")
    assert(status.target_label == "Codex: Default", "status data lost target label")
    assert(status.target_root == "/project", "status data lost target root")
    assert(status.picker_mode == "after_open", "status data lost picker mode")
    assert(status.picker_shown == true, "status data lost picker shown")
    assert(status.previous_pane_mode == "codex", "status data lost previous pane mode")
    assert(status.citation_count == 3 and status.file_count == 2, "status data lost citation counts")
    assert(ask_session.format_title(snapshot) == "Ask: Codex: Default - draft_written", "formatted title was wrong")
    assert(ask_status.format_title(snapshot) == ask_session.format_title(snapshot), "status module title disagreed with session formatter")
    assert(vim.deep_equal(ask_status.status_data(snapshot), status), "status module data disagreed with session formatter")

    local debug = ask_status.debug_data(snapshot)

    assert(debug.active == true, "debug status lost active state")
    assert(debug.target_label == "Codex: Default", "debug status lost target label")
    assert(debug.target_root == "/project", "debug status lost target root")
    assert(debug.picker_mode == "after_open", "debug status lost picker mode")
    assert(debug.picker_shown == true, "debug status lost picker shown state")
    assert(debug.after_open_shown == true, "debug status lost after_open shown state")
    assert(debug.draft_state == "draft_written", "debug status lost draft state")
    assert(debug.previous_pane_mode == "codex", "debug status lost previous pane mode")
    assert(debug.modified == true, "debug status lost modified flag")
    assert(debug.written == true, "debug status lost written flag")
    assert(debug.citation_count == 3 and debug.file_count == 2, "debug status lost citation counts")

    local lines = ask_status.debug_lines(snapshot)

    assert(lines[1] == "Ask pane: active", "debug lines active state was wrong")
    assert(lines[2] == "Draft state: draft_written", "debug lines draft state was wrong")
    assert(lines[3] == "Ask target: Codex: Default", "debug lines target was wrong")
    assert(lines[4] == "Target root: /project", "debug lines root was wrong")
    assert(lines[5] == "Picker mode: after_open", "debug lines picker mode was wrong")
    assert(lines[6] == "Picker shown: yes", "debug lines picker shown state was wrong")
    assert(lines[7] == "After-open picker shown: yes", "debug lines after_open shown state was wrong")
    assert(lines[8] == "Citations: 3 (2 files)", "debug lines citation counts were wrong")
    assert(lines[9] == "Previous pane: codex", "debug lines previous pane was wrong")
    assert(lines[10] == "Modified: yes", "debug lines modified flag was wrong")
    assert(lines[11] == "Written: yes", "debug lines written flag was wrong")
end)

test("ask session snapshot covers empty invalid target and picker cases", function()
    for _, state_name in ipairs({
        "ready_empty",
        "draft_modified",
        "draft_written",
        "sending_picker",
        "sending_terminal",
        "send_failed",
        "cancelled",
        "sent",
    }) do
        local snapshot = ask_session.snapshot({ bufnr = 2, draft_state = state_name }, {
            buffer = { valid = true },
        })

        assert(snapshot.draft_state == state_name, "snapshot lost state " .. state_name)
    end

    local ready = ask_session.snapshot({ bufnr = 3, ready = true }, {
        ask_config = { model_picker = "manual" },
        buffer = {
            live_prompt = "Question:",
            modified = false,
            valid = true,
        },
        window = { valid = false },
    })

    assert(ready.active == true, "ready snapshot should be active with a valid buffer")
    assert(ready.draft_state == "ready_empty", "ready snapshot should default to ready_empty")
    assert(ready.target_label == "No target", "missing target should use No target label")
    assert(ready.target_root == nil, "missing target root should stay nil")
    assert(ready.picker_mode == "manual", "manual picker mode was lost")
    assert(ready.picker_shown == false, "picker shown should default false")
    assert(ready.previous_pane_mode == nil, "missing previous pane should stay nil")
    assert(ready.citation_count == 0 and ready.file_count == 0, "empty citations should count as zero")
    assert(ready.valid_window == false, "invalid window fact was lost")

    local invalid = ask_session.snapshot({
        bufnr = 4,
        citations = { { file = "src/old.lua" } },
        draft_state = "send_failed",
        entry = { preset_label = "Fallback Preset", root = "/fallback" },
        previous = { active_terminal_key = "claude:default:/fallback" },
    }, {
        ask_config = { model_picker = "before_send" },
        buffer = {
            live_prompt = "stale",
            modified = true,
            valid = false,
        },
        window = { valid = false },
    })

    assert(invalid.active == false, "invalid buffer snapshot should be inactive")
    assert(invalid.draft_state == nil, "inactive snapshot should not expose a current draft state")
    assert(invalid.dirty_buffer == true, "invalid snapshot should still carry explicit dirty fact")
    assert(invalid.target_label == "Fallback Preset", "target label fallback was wrong")
    assert(invalid.target_root == "/fallback", "target root fallback was wrong")
    assert(invalid.picker_mode == "before_send", "before_send picker mode was lost")
    assert(invalid.previous_pane_mode == "claude:default:/fallback", "terminal previous fallback was wrong")
    assert(invalid.citation_count == 1 and invalid.file_count == 1, "invalid snapshot counts were wrong")
    assert(ask_session.format_title(invalid) == "Ask: Fallback Preset - inactive", "inactive title was wrong")

    local inactive_debug = ask_status.debug_data(invalid)

    assert(inactive_debug.target_label == "Fallback Preset", "inactive debug target label was wrong")
    assert(inactive_debug.target_root == "/fallback", "inactive debug target root was wrong")
    assert(inactive_debug.picker_mode == "before_send", "inactive debug picker mode was wrong")
    assert(inactive_debug.after_open_shown == false, "inactive debug after_open state should be false")
    assert(inactive_debug.draft_state == "inactive", "inactive debug draft state was wrong")
    assert(inactive_debug.previous_pane_mode == "claude:default:/fallback", "inactive debug previous pane was wrong")
    assert(inactive_debug.modified == true, "inactive debug modified flag was wrong")
    assert(inactive_debug.written == false, "inactive debug written flag was wrong")

    local empty_debug = ask_status.debug_data({})

    assert(empty_debug.target_label == "No target", "empty debug target label was wrong")
    assert(empty_debug.target_root == "", "empty debug target root was wrong")
    assert(empty_debug.picker_mode == "manual", "empty debug picker mode should default to manual")
    assert(empty_debug.after_open_shown == false, "empty debug after_open state should be false")
    assert(empty_debug.draft_state == "inactive", "empty debug draft state was wrong")
    assert(empty_debug.active == false, "empty debug active flag was wrong")
    assert(empty_debug.previous_pane_mode == "", "empty debug previous pane should default to empty")
    assert(empty_debug.modified == false, "empty debug modified flag should default false")
    assert(empty_debug.written == false, "empty debug written flag should default false")
    assert(empty_debug.citation_count == 0 and empty_debug.file_count == 0, "empty debug counts were wrong")
end)

test("ask session records lifecycle history at the session boundary", function()
    local state = {}
    local raw = {}

    ask_session.record_state(state, raw, "ready_empty")
    ask_session.record_state(state, raw, "draft_modified")

    assert(raw.draft_state == "draft_modified", "record_state did not update raw draft state")
    assert(state.ask_pane_last_state == "draft_modified", "record_state did not update last state")
    assert(vim.deep_equal(state.ask_pane_state_history, { "ready_empty", "draft_modified" }), "record_state history was wrong")
end)

test("ask session refreshes draft state after undo through adapter facts", function()
    local state = {
        ask_pane_state_history = {},
    }
    local lines = { "Question:", "written draft" }
    local modified = false
    local raw = {
        bufnr = 12,
        written_prompt = "Question:\nwritten draft",
    }
    local adapter = {
        get_lines = function(bufnr, start, stop, strict)
            assert(bufnr == 12 and start == 0 and stop == -1 and strict == false, "refresh read wrong buffer lines")
            return lines
        end,
        get_option = function(name, opts)
            assert(name == "modified" and opts.buf == 12, "refresh read wrong option")
            return modified
        end,
        trim = util.trim,
        valid_buf = function(bufnr)
            return bufnr == 12
        end,
    }

    assert(ask_session.refresh_after_undo(state, raw, adapter) == true, "refresh did not handle written prompt")
    assert(raw.draft_state == "draft_written", "refresh did not restore written state")
    assert(state.ask_pane_last_state == "draft_written", "refresh did not update last state")

    modified = true

    assert(ask_session.refresh_after_undo(state, raw, adapter) == true, "refresh did not handle modified prompt")
    assert(raw.draft_state == "draft_modified", "refresh did not mark modified prompt")
    assert(raw.written_prompt == nil, "refresh did not clear stale written prompt after modified undo")
end)

test("ask session owns buffer setup reset snapshot and previous capture through adapters", function()
    local valid_bufs = {}
    local created_bufs = {}
    local options = {}
    local deleted = {}
    local scheduled = false
    local mapset_args = nil
    local del_keymap_args = nil
    local state = {
        active_mode = "markdown",
        bufnr = 9,
        config = {
            ask = {
                model_picker = "manual",
            },
        },
        winid = 42,
    }
    local adapter = {
        cmdline_enter_desc = "session-test-enter",
        cmd_map = function()
            return { desc = "session-test-enter" }
        end,
        create_augroup = function(name, opts)
            assert(name == "SidepanesAskPane101", "augroup name was wrong")
            assert(opts.clear == true, "augroup opts were wrong")
            return 202
        end,
        create_buf = function(listed, scratch)
            assert(listed == false and scratch == true, "buffer creation opts were wrong")
            table.insert(created_bufs, 101)
            valid_bufs[101] = true
            return 101
        end,
        current_win = function()
            return 42
        end,
        delete_buf = function(bufnr, opts)
            table.insert(deleted, { bufnr = bufnr, force = opts.force })
            valid_bufs[bufnr] = false
        end,
        del_keymap = function(mode, lhs)
            del_keymap_args = { mode = mode, lhs = lhs }
        end,
        get_lines = function(bufnr)
            assert(bufnr == 101, "snapshot read wrong buffer")
            return { "Question:", "  hello  " }
        end,
        get_option = function(name)
            return options[name]
        end,
        mapset = function(mode, abbr, map)
            mapset_args = { mode = mode, abbr = abbr, map = map }
        end,
        schedule = function(callback)
            scheduled = true
            callback()
        end,
        set_buf_name = function(bufnr, name)
            assert(bufnr == 101 and name == "Pane Question", "buffer name was wrong")
        end,
        set_lines = function(bufnr, start, stop, strict, lines)
            assert(bufnr == 101 and start == 0 and stop == -1 and strict == false, "initial line range was wrong")
            assert(vim.deep_equal(lines, { "Question:", "" }), "initial ask buffer lines were wrong")
        end,
        set_option = function(name, value)
            options[name] = value
        end,
        trim = util.trim,
        valid_buf = function(bufnr)
            return valid_bufs[bufnr] == true
        end,
        valid_win = function(winid)
            return winid == 42
        end,
        win_buf = function(winid)
            assert(winid == 42, "snapshot checked wrong window")
            return 101
        end,
    }

    ask_session.capture_previous(state)
    assert(state.ask_pane.previous.active_mode == "markdown", "previous markdown mode was not captured")
    assert(state.ask_pane.previous.bufnr == 9, "previous markdown buffer was not captured")

    local bufnr = ask_session.ensure_buffer(state, adapter)

    assert(bufnr == 101, "ensure_buffer returned wrong buffer")
    assert(#created_bufs == 1, "ensure_buffer did not create exactly one buffer")
    assert(state.ask_pane.augroup == 202, "ensure_buffer did not store augroup")
    assert(state.ask_pane.draft_state == "ready_empty", "ensure_buffer did not set ready state")
    assert(vim.deep_equal(state.ask_pane.citations, {}), "ensure_buffer did not initialize citations")
    assert(options.buftype == "acwrite", "ensure_buffer did not set buftype")
    assert(options.bufhidden == "hide", "ensure_buffer did not set bufhidden")
    assert(options.swapfile == false, "ensure_buffer did not disable swapfile")
    assert(options.filetype == "markdown", "ensure_buffer did not set filetype")
    assert(options.modified == false, "ensure_buffer did not clear modified")
    assert(vim.deep_equal(state.ask_pane_state_history, { "ready_empty" }), "ensure_buffer did not reset state history")
    assert(ask_session.ensure_buffer(state, adapter) == 101, "ensure_buffer did not reuse valid buffer")
    assert(#created_bufs == 1, "ensure_buffer recreated a valid buffer")

    options.modified = true
    local snapshot = ask_session.runtime_snapshot(state, state.ask_pane, adapter)

    assert(snapshot.active == true, "runtime snapshot did not mark active ask buffer")
    assert(snapshot.active_window == true, "runtime snapshot did not mark active window")
    assert(snapshot.live_prompt == "Question:\n  hello", "runtime snapshot did not trim prompt")
    assert(snapshot.dirty_buffer == true, "runtime snapshot did not report modified buffer")
    assert(snapshot.picker_mode == "manual", "runtime snapshot did not include ask config")

    state.ask_pane.cmdline_enter_setup = true
    state.ask_pane.previous_cmdline_enter = { rhs = "old" }
    ask_session.reset(state, { defer_delete = true }, adapter)

    assert(scheduled == true, "deferred reset did not schedule delete")
    assert(vim.deep_equal(deleted, { { bufnr = 101, force = true } }), "reset did not delete ask buffer")
    assert(mapset_args.mode == "c" and mapset_args.abbr == false, "reset did not restore previous command-line map")
    assert(mapset_args.map.rhs == "old", "reset restored wrong command-line map")
    assert(vim.deep_equal(state.ask_pane, {}), "reset did not clear ask session")

    state.ask_pane = {
        bufnr = 102,
        cmdline_enter_setup = true,
        previous_cmdline_enter = {},
    }
    valid_bufs[102] = true
    ask_session.reset(state, nil, adapter)

    assert(del_keymap_args.mode == "c" and del_keymap_args.lhs == "<CR>", "reset did not delete command-line map without previous map")
    assert(deleted[#deleted].bufnr == 102, "non-deferred reset did not delete the current buffer")
end)

test("ask pane keeps session state compatibility helpers while exposing snapshots", function()
    local state = {
        config = {
            ask = {
                model_picker = "manual",
            },
        },
    }
    local ask = ask_pane_module.session(state)

    assert(type(ask) == "table", "ask pane session helper did not return a table")
    assert(type(ask.citations) == "table", "ask pane session helper did not initialize citations")
    assert(ask_pane_module.DRAFT_STATES.ready_empty == "ready_empty", "ask pane draft state constants compatibility changed")
    assert(type(ask_pane_module.snapshot) == "function", "ask pane snapshot helper missing")
    assert(type(ask_pane_module.lifecycle_facts) == "function", "ask pane lifecycle facts helper missing")

    local snapshot = ask_pane_module.snapshot(state)

    assert(snapshot.active == false, "empty compatibility snapshot should be inactive")
    assert(snapshot.target_label == "No target", "empty compatibility snapshot target label was wrong")
end)

test("ask status API and commands report active draft facts", function()
    reset_pane()

    local root = root_fixture("ask-status-api-test")

    write(root .. "/src/one.lua", { "one()" })
    write(root .. "/src/two.lua", { "two()" })
    pane.setup({
        commands = true,
        ask = {
            ui = "pane",
            model_picker = "manual",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "exit 0" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    local inactive = pane.ask_status({ notify = false })

    assert(inactive.active == false, "inactive status should report inactive")
    assert(inactive.draft_state == "inactive", "inactive status should use inactive draft state")
    assert(inactive.citation_count == 0 and inactive.file_count == 0, "inactive status counts should be zero")
    assert(vim.tbl_contains(inactive.lines, "Ask pane: inactive"), "inactive status lines missed active state")

    local messages = capture_notify(function()
        vim.cmd("SidepanesAskStatus")
    end)

    assert(#messages == 1, "standalone ask status command did not notify once")
    assert(messages[1].level == vim.log.levels.INFO, "standalone ask status command used wrong log level")
    assert(messages[1].message:find("Ask pane: inactive", 1, true), "standalone ask status command missed inactive state")

    pane.show_ask_pane({ focus = true })

    local ready = pane.ask_status({ notify = false })

    assert(ready.active == true, "ready status should report active")
    assert(ready.draft_state == "ready_empty", "ready status should report ready_empty")
    assert(ready.citation_count == 0 and ready.file_count == 0, "ready status should report no citations")
    assert(ready.modified == false and ready.written == false, "ready status should not be modified or written")

    vim.cmd.edit(root .. "/src/one.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })
    vim.cmd.edit(root .. "/src/two.lua")
    pane.append_to_ask({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local collected = pane.ask_status({ notify = false })

    assert(collected.active == true, "collected status should report active")
    assert(collected.draft_state == "draft_modified", "collected status should report modified draft")
    assert(collected.target_label == "Codex: One", "collected status target label was wrong")
    assert(collected.target_root == root, "collected status target root was wrong")
    assert(collected.picker_mode == "manual", "collected status picker mode was wrong")
    assert(collected.picker_shown == false, "manual collected status should not report picker shown")
    assert(collected.citation_count == 2 and collected.file_count == 2, "collected status counts were wrong")
    assert(collected.previous_pane_mode == "markdown", "collected status previous pane was wrong")
    assert(collected.modified == true and collected.written == false, "collected status flags were wrong before write")

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "status check" })
    pane.write_ask_pane(qbuf)

    local written = pane.ask_status({ notify = false })

    assert(written.draft_state == "draft_written", "written status should report draft_written")
    assert(written.modified == false, "written status should not be modified")
    assert(written.written == true, "written status should report written")
    assert(vim.tbl_contains(written.lines, "Written: yes"), "written status lines missed written flag")

    messages = capture_notify(function()
        vim.cmd("Sidepanes ask-status")
    end)

    assert(#messages == 1, "root ask-status subcommand did not notify once")
    assert(messages[1].message:find("Citations: 2 (2 files)", 1, true), "root ask-status missed citation counts")
    assert(messages[1].message:find("Written: yes", 1, true), "root ask-status missed written flag")

    pane.cancel_ask_pane(qbuf)

    local cancelled = pane.ask_status({ notify = false })

    assert(cancelled.active == false, "cancelled status should report inactive")
    assert(cancelled.draft_state == "inactive", "cancelled status should report inactive draft state")
    assert(cancelled.citation_count == 0 and cancelled.file_count == 0, "cancelled status counts should reset")
end)

-- Ask layer: command-line adapter tests.
test("ask command-line adapter builds ask pane and floating compatibility commands", function()
    assert(
        ask_cmdline.markdown_return_command() == '<C-u>lua require("sidepanes.internal").show_markdown()<CR>',
        "markdown return command changed"
    )

    assert(
        ask_cmdline.ask_pane_command_for_line("q!", 12) == '<C-u>lua require("sidepanes.internal").cancel_ask_pane(12)<CR>',
        "ask pane q! command was wrong"
    )
    assert(
        ask_cmdline.ask_pane_command_for_line("q", 12) == '<C-u>lua require("sidepanes.internal").finish_ask_pane(12)<CR>',
        "ask pane q command was wrong"
    )
    assert(
        ask_cmdline.ask_pane_command_for_line("w", 12) == '<C-u>lua require("sidepanes.internal").write_ask_pane(12)<CR>',
        "ask pane w command was wrong"
    )
    assert(
        ask_cmdline.ask_pane_command_for_line("wq", 12) == '<C-u>lua require("sidepanes.internal").submit_ask_pane(12)<CR>',
        "ask pane wq command was wrong"
    )
    assert(ask_cmdline.ask_pane_command_for_line("write", 12) == nil, "ask pane write command should pass through")

    assert(
        ask_cmdline.floating_question_command_for_line("q!", 34) == '<C-u>lua require("sidepanes.internal").finish_question(34)<CR>',
        "floating question q! compatibility command changed"
    )
    assert(
        ask_cmdline.floating_question_command_for_line("wq", 34)
            == '<C-u>lua require("sidepanes.internal").write_question(34); require("sidepanes.internal").finish_question(34)<CR>',
        "floating question wq compatibility command changed"
    )
end)

-- Ask layer: executor tests with fake dependencies.
test("ask lifecycle executor runs policy actions through fake handlers", function()
    local calls = {}
    local actions = ask_policy.ACTIONS
    local result = ask_executor.run({
        { action = actions.mark_draft_modified },
        { action = actions.write_draft },
        { action = actions.send_prompt, prompt = "hello" },
    }, {
        mark_draft_modified = function()
            table.insert(calls, "mark")
        end,
        write_draft = function()
            table.insert(calls, "write")
        end,
        send_prompt = function(prompt)
            table.insert(calls, "send:" .. prompt)
            return true
        end,
    })

    assert(result == true, "executor did not return send result")
    assert(vim.deep_equal(calls, { "mark", "write", "send:hello" }), "executor calls were wrong: " .. vim.inspect(calls))

    calls = {}
    result = ask_executor.run({
        { action = actions.open_before_send_picker, prompt = "pick" },
        { action = actions.send_prompt, prompt = "should not run" },
    }, {
        open_before_send_picker = function(prompt)
            table.insert(calls, "picker:" .. prompt)
        end,
        send_prompt = function(prompt)
            table.insert(calls, "send:" .. prompt)
            return true
        end,
    })

    assert(result == true, "open picker should stop as handled")
    assert(vim.deep_equal(calls, { "picker:pick" }), "picker plan did not stop before send: " .. vim.inspect(calls))

    calls = {}
    result = ask_executor.run({
        { action = actions.notify_no_prompt },
        { action = actions.cancel_draft },
    }, {
        notify_no_prompt = function()
            table.insert(calls, "notify")
        end,
        cancel_draft = function()
            table.insert(calls, "cancel")
        end,
    })

    assert(result == false, "notify_no_prompt should stop as unhandled")
    assert(vim.deep_equal(calls, { "notify" }), "notify plan did not stop: " .. vim.inspect(calls))
end)

test("ask controller composes facts policy and executor handlers", function()
    local calls = {}
    local controller = ask_controller.create({
        facts = function()
            return {
                valid_buf = true,
                live_prompt = "send through controller",
                model_picker = "manual",
            }
        end,
        handlers = {
            write_draft = function()
                table.insert(calls, "write")
            end,
            send_prompt = function(prompt)
                table.insert(calls, "send:" .. prompt)
                return true
            end,
            change_target = function(target)
                table.insert(calls, "target:" .. target)
            end,
            append_context = function(context)
                table.insert(calls, "append:" .. context)
            end,
        },
    })

    assert(controller.submit_now() == true, "controller submit did not return executor result")
    controller.change_target("codex")
    controller.append_context("selection")

    assert(
        vim.deep_equal(calls, { "write", "send:send through controller", "target:codex", "append:selection" }),
        "controller calls were wrong: " .. vim.inspect(calls)
    )
end)

test("ask pane opens reusable ready scratch buffer in the side split", function()
    reset_pane()

    pane.setup({ wrap = true })

    local bufnr, winid = pane.show_ask_pane({ focus = true })

    assert(vim.api.nvim_buf_is_valid(bufnr), "ask pane buffer was not created")
    assert(vim.api.nvim_win_is_valid(winid), "ask pane window was not created")
    assert(pane.active_mode == "ask", "ask pane did not become active mode")
    assert(vim.api.nvim_win_get_buf(winid) == bufnr, "ask pane window did not show ask buffer")
    assert(vim.api.nvim_get_current_win() == winid, "ask pane did not focus when requested")
    assert(vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "acwrite", "ask buffer buftype was wrong")
    assert(vim.api.nvim_get_option_value("bufhidden", { buf = bufnr }) == "hide", "ask buffer hidden behavior was wrong")
    assert(vim.api.nvim_get_option_value("filetype", { buf = bufnr }) == "markdown", "ask buffer filetype was wrong")
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), { "Question:", "" }), "ask buffer did not start ready")
    assert(vim.api.nvim_get_option_value("number", { win = winid }) == true, "ask pane did not enable line numbers")
    assert(vim.api.nvim_get_option_value("wrap", { win = winid }) == true, "ask pane did not use markdown-like wrap")
    assert(vim.api.nvim_get_option_value("conceallevel", { win = winid }) == 0, "ask pane should not conceal editable markdown")

    local winbar = vim.api.nvim_get_option_value("winbar", { win = winid })

    assert(winbar:find("Ask: No target %- ready_empty"), winbar)
    assert(pane.ask_pane.draft_state == "ready_empty", "ask pane did not record ready_empty state")
    assert_state_history_contains(pane.ask_pane_state_history, { "ready_empty" }, "open ask pane")

    local snapshot = ask_pane_module.snapshot(pane)

    assert(snapshot.active == true, "runtime ask snapshot did not mark ready pane active")
    assert(snapshot.active_window == true, "runtime ask snapshot did not mark pane window active")
    assert(snapshot.draft_state == "ready_empty", "runtime ask snapshot lost ready_empty")
    assert(snapshot.target_label == "No target", "runtime ask snapshot target label was wrong")
    assert(snapshot.live_prompt == "Question:", "runtime ask snapshot live prompt was wrong")
    assert(snapshot.citation_count == 0 and snapshot.file_count == 0, "runtime ask snapshot counts were wrong")

    local facts = ask_pane_module.lifecycle_facts(pane)

    assert(facts.valid_buffer == true, "runtime lifecycle facts lost valid buffer")
    assert(facts.live_prompt == "Question:", "runtime lifecycle facts lost ready prompt")
    assert(facts.dirty_buffer == false, "runtime lifecycle facts should not mark ready prompt dirty")

    local again = pane.show_ask_pane({ focus = true })

    assert(again == bufnr, "ask pane did not reuse existing buffer")
end)

test("ask pane focus mapping preserves modified drafts and clears unmodified drafts with undo", function()
    reset_pane()

    local root = root_fixture("ask-pane-focus-clear-undo-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        mappings = {
            global = {
                ask_pane = "<leader>pa",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr
    local original = vim.api.nvim_buf_get_lines(qbuf, 0, -1, false)

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "keep this draft" })
    vim.api.nvim_set_option_value("modified", true, { buf = qbuf })
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys("<leader>pa")

    assert(pane.ask_pane.bufnr == qbuf, "modified ask focus mapping changed the ask buffer")
    assert(
        table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n"):find("keep this draft", 1, true),
        "modified ask focus mapping cleared the draft"
    )
    assert(#(pane.ask_pane.citations or {}) == 1, "modified ask focus mapping cleared citation state")

    pane.write_ask_pane(qbuf)
    assert(vim.api.nvim_get_option_value("modified", { buf = qbuf }) == false, "write did not make the draft unmodified")

    feed_user_keys("<leader>pa")

    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), { "Question:", "" }), "unmodified ask focus mapping did not clear to a fresh question")
    assert(vim.api.nvim_get_option_value("modified", { buf = qbuf }) == false, "fresh ask question should not remain modified")
    assert(#(pane.ask_pane.citations or {}) == 0, "fresh ask question did not clear citation state")
    assert(pane.ask_pane.draft_state == "ready_empty", "fresh ask question did not reset visible state")

    feed_user_keys("u")
    wait_until("undo did not restore cleared ask draft", function()
        return table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n"):find("keep this draft", 1, true) ~= nil
    end)

    assert(not vim.deep_equal(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), original), "undo restored the pre-edit prompt instead of the edited prompt")
    assert(#(pane.ask_pane.citations or {}) == 1, "undo did not restore citation state")
    assert(pane.ask_pane.draft_state == "draft_modified", "undo did not restore a modified draft state")
end)

test("ask pane captures previous markdown and terminal pane state", function()
    reset_pane()

    local root = root_fixture("ask-pane-previous-state-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")
    pane.show_markdown()
    pane.show_ask_pane({ focus = true })

    assert(pane.ask_pane.previous.active_mode == "markdown", "ask pane did not remember markdown mode")
    assert(pane.ask_pane.previous.bufnr == pane.bufnr, "ask pane did not remember markdown buffer")

    pane.open_terminal("codex", nil, { root = root, focus = true })

    local terminal_key = pane.active_terminal_key

    pane.show_ask_pane({ focus = true })

    assert(pane.ask_pane.previous.active_mode == "codex", "ask pane did not remember terminal mode")
    assert(pane.ask_pane.previous.active_terminal_key == terminal_key, "ask pane did not remember terminal key")
end)

test("ask pane winbar formats the session snapshot instead of deriving fallback state", function()
    reset_pane()

    pane.setup({
        ask = {
            ui = "pane",
        },
    })

    pane.show_ask_pane({ focus = true })

    local qbuf = pane.ask_pane.bufnr

    pane.ask_pane.draft_state = nil
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "modified without explicit state" })
    vim.api.nvim_set_option_value("modified", true, { buf = qbuf })
    winbar_module.update(pane)

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("Ask: No target %- ready_empty"), winbar)
    assert(not winbar:find("draft_modified", 1, true), "winbar inferred draft_modified instead of formatting snapshot: " .. winbar)
end)

test("public IPython send captures current line through terminal deps", function()
    reset_pane()

    local root = root_fixture("ipython-send-test")
    local out = helpers.tmp_path("sidepanes-ipython-send.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", {
        "value = 41 + 1",
        "print(value)",
    })

    pane.setup({
        tools = {
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    pane.send_ipython({
        bufnr = vim.api.nvim_get_current_buf(),
        line1 = 1,
        line2 = 1,
    })

    wait_for_file(out, "value = 41 + 1")
end)

test("visual IPython send exits visual mode after capture", function()
    reset_pane()

    local root = root_fixture("ipython-visual-exit-test")
    local out = helpers.tmp_path("sidepanes-ipython-visual-exit.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", {
        "first = 1",
        "second = 2",
        "third = 3",
    })

    pane.setup({
        tools = {
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("normal! Vj")

    local visual_mode = vim.fn.mode(1)

    assert(visual_mode:match("[vV\22]"), "test did not enter visual mode")

    pane.send_ipython({
        bufnr = vim.api.nvim_get_current_buf(),
        visual = true,
        visual_mode = visual_mode,
    })

    wait_for_file(out, "first = 1")
    wait_for_file(out, "second = 2")

    local exited = vim.wait(500, function()
        return not vim.fn.mode(1):match("[vV\22]")
    end, 20)

    assert(exited, "visual mode remained active after send")
end)

test("ask prompt helper preserves current prompt shape without visible metadata", function()
    local prompt = ask_prompt.prompt_template({
        root = "/tmp/project",
        file = "src/main.lua",
        path = "/tmp/project/src/main.lua",
        start_lnum = 4,
        end_lnum = 6,
        text = "local value = 42",
        filetype = "lua",
        snippet_filetype = "lua",
    })

    assert(prompt:find("^Question:\n\n\nFile:\nsrc/main%.lua\n\nSelection:\nlines 4%-6\n\n```lua\nlocal value = 42\n```$"), prompt)
    assert(not prompt:find("Target:", 1, true), "prompt exposed target metadata")
    assert(not prompt:find("Model:", 1, true), "prompt exposed model metadata")
end)

test("ask prompt helper appends new file blocks and skips duplicate ranges", function()
    local first = {
        root = "/tmp/project",
        file = "src/one.lua",
        path = "/tmp/project/src/one.lua",
        start_lnum = 10,
        end_lnum = 12,
        text = "first()",
        snippet_filetype = "lua",
    }
    local second = {
        root = "/tmp/project",
        file = "src/two.lua",
        path = "/tmp/project/src/two.lua",
        start_lnum = 3,
        end_lnum = 4,
        text = "second()",
        snippet_filetype = "lua",
    }
    local lines = vim.split(ask_prompt.prompt_template(first), "\n", { plain = true })
    local duplicate_result, duplicate_meta = ask_prompt.add_citation(lines, first, { duplicate_policy = "skip" })

    assert(duplicate_meta.added == false, "duplicate citation was added")
    assert(duplicate_meta.reason == "duplicate", "duplicate citation reason was wrong")
    assert(vim.deep_equal(duplicate_result, lines), "duplicate citation mutated prompt lines")

    local updated, meta = ask_prompt.add_citation(lines, second)
    local prompt = table.concat(updated, "\n")

    assert(meta.added == true and meta.reason == "new_file", "new file citation did not report new_file")
    assert(prompt:find("File:\nsrc/one%.lua", 1, false), prompt)
    assert(prompt:find("File:\nsrc/two%.lua", 1, false), prompt)
    assert(prompt:find("lines 3%-4", 1, false), prompt)
end)

test("ask prompt helper inserts same-file citations by line when machine-shaped", function()
    local first = {
        root = "/tmp/project",
        file = "src/one.lua",
        path = "/tmp/project/src/one.lua",
        start_lnum = 30,
        end_lnum = 35,
        text = "later()",
        snippet_filetype = "lua",
    }
    local earlier = vim.tbl_extend("force", first, {
        start_lnum = 5,
        end_lnum = 8,
        text = "earlier()",
    })
    local lines = vim.split(ask_prompt.prompt_template(first), "\n", { plain = true })
    local updated, meta = ask_prompt.add_citation(lines, earlier)
    local prompt = table.concat(updated, "\n")
    local earlier_at = prompt:find("lines 5%-8", 1, false)
    local later_at = prompt:find("lines 30%-35", 1, false)

    assert(meta.reason == "same_file_ordered", "same-file insertion did not report ordered")
    assert(earlier_at and later_at and earlier_at < later_at, prompt)
    assert(select(2, prompt:gsub("File:\nsrc/one%.lua", "")) == 1, "same-file citation created another file block")
end)

test("ask prompt helper appends same-file citations when block was manually edited", function()
    local first = {
        root = "/tmp/project",
        file = "src/one.lua",
        path = "/tmp/project/src/one.lua",
        start_lnum = 30,
        end_lnum = 35,
        text = "later()",
        snippet_filetype = "lua",
    }
    local earlier = vim.tbl_extend("force", first, {
        start_lnum = 5,
        end_lnum = 8,
        text = "earlier()",
    })
    local lines = vim.split(ask_prompt.prompt_template(first), "\n", { plain = true })

    for index, line in ipairs(lines) do
        if line == "lines 30-35" then
            lines[index] = "manually described range"
            break
        end
    end

    local updated, meta = ask_prompt.add_citation(lines, earlier)
    local prompt = table.concat(updated, "\n")
    local manual_at = prompt:find("manually described range", 1, true)
    local earlier_at = prompt:find("lines 5%-8", 1, false)

    assert(meta.reason == "same_file_appended", "edited block did not force append fallback")
    assert(manual_at and earlier_at and manual_at < earlier_at, prompt)
end)

test("ask prompt helper labels cross-root citations without changing same-root paths", function()
    local same_root = ask_prompt.format_file_block({
        root = "/tmp/project",
        file = "src/one.lua",
        path = "/tmp/project/src/one.lua",
        start_lnum = 1,
        end_lnum = 1,
        text = "same()",
        snippet_filetype = "lua",
    }, {
        target_root = "/tmp/project",
    })
    local cross_root = ask_prompt.format_file_block({
        root = "/tmp/other",
        file = "src/two.lua",
        path = "/tmp/other/src/two.lua",
        start_lnum = 2,
        end_lnum = 2,
        text = "other()",
        snippet_filetype = "lua",
    }, {
        target_root = "/tmp/project",
    })

    assert(same_root:find("File:\nsrc/one%.lua\n", 1, false), same_root)
    assert(cross_root:find("File:\nsrc/two%.lua %(root: /tmp/other%)\n", 1, false), cross_root)
end)

test("visual-line ask captures all selected lines", function()
    reset_pane()

    local captured = nil
    local original_set_lines = vim.api.nvim_buf_set_lines

    vim.api.nvim_buf_set_lines = function(bufnr, start, stop, strict, lines)
        if lines and lines[1] == "Question:" then
            captured = table.concat(lines, "\n")
        end

        return original_set_lines(bufnr, start, stop, strict, lines)
    end

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "before",
        "from pipio.core.ir import Value, Binding, ErrorSpec",
        "assert Value(1).value==1 and Binding(\"a\", 1).name==\"a\"",
        "after",
    })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = 0 })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.cmd("normal! Vj")

    pane.ask("codex", nil, {
        bufnr = vim.api.nvim_get_current_buf(),
        visual = true,
        visual_mode = vim.fn.mode(1),
    })

    vim.api.nvim_buf_set_lines = original_set_lines

    assert(captured, "question buffer was not created")
    assert(captured:find("lines 2%-3"), captured)
    assert(captured:find("from pipio%.core%.ir import Value, Binding, ErrorSpec"), captured)
    assert(captured:find("assert Value%(1%)%.value==1 and Binding"), captured)
end)

-- Ask layer: fed-key user paths and end-to-end pane-mode smoke.
test("pane-mode ask creates ask pane prompt and appends same-file selections", function()
    reset_pane()

    local root = root_fixture("ask-pane-append-same-file-test")

    write(root .. "/src/origin.lua", {
        "local later = 2",
        "local middle = 3",
        "local first = 1",
    })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    local origin_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = origin_buf, line1 = 3, line2 = 3 })
    pane.ask("codex", nil, { bufnr = origin_buf, line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr
    local prompt = table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n")
    local first_at = prompt:find("lines 1%-1", 1, false)
    local later_at = prompt:find("lines 3%-3", 1, false)

    assert(pane.active_mode == "ask", "pane ask did not switch to ask mode")
    assert(pane.ask_pane.entry.tool_name == "codex", "pane ask did not store target entry")
    assert(first_at and later_at and first_at < later_at, prompt)
    assert(select(2, prompt:gsub("File:\nsrc/origin%.lua", "")) == 1, "same-file append created duplicate file block")
end)

test("pane-mode first selection preserves question typed in ready ask pane", function()
    reset_pane()

    local root = root_fixture("ask-pane-preserve-ready-question-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.show_ask_pane({ focus = true })

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "Please explain this before editing.", "Keep the answer short." })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local prompt = table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n")

    assert(prompt:find("Please explain this before editing%.", 1, false), prompt)
    assert(prompt:find("Keep the answer short%.", 1, false), prompt)
    assert(prompt:find("File:\nsrc/origin%.lua", 1, false), prompt)
end)

test("pane-mode ask appends different files and skips exact duplicates", function()
    reset_pane()

    local root = root_fixture("ask-pane-append-different-file-test")

    write(root .. "/src/one.lua", { "one()" })
    write(root .. "/src/two.lua", { "two()" })
    pane.setup({
        ask = {
            ui = "pane",
            duplicate_policy = "skip",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/one.lua")
    local one_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = one_buf, line1 = 1, line2 = 1 })

    local messages = capture_notify(function()
        pane.ask("codex", nil, { bufnr = one_buf, line1 = 1, line2 = 1 })
    end)

    vim.cmd.edit(root .. "/src/two.lua")
    pane.append_to_ask({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local prompt = table.concat(vim.api.nvim_buf_get_lines(pane.ask_pane.bufnr, 0, -1, false), "\n")

    assert(has_notify(messages, "Duplicate ask citation skipped"), "duplicate ask citation did not notify")
    assert(select(2, prompt:gsub("File:\nsrc/one%.lua", "")) == 1, "duplicate citation added another first file block")
    assert(prompt:find("File:\nsrc/two%.lua", 1, false), prompt)
end)

test("pane-mode visual ask mappings reuse active ask target without reopening picker", function()
    reset_pane()

    local root = root_fixture("ask-pane-visual-reuse-target-test")

    write(root .. "/src/origin.lua", {
        "first()",
        "second()",
    })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    local origin_buf = vim.api.nvim_get_current_buf()

    pane._test_next_choice = "2"
    pane.ask_picker({ bufnr = origin_buf, line1 = 1, line2 = 1 })

    pane._test_next_choice = "2"
    pane.ask_picker({ bufnr = origin_buf, line1 = 2, line2 = 2 })

    local prompt = table.concat(vim.api.nvim_buf_get_lines(pane.ask_pane.bufnr, 0, -1, false), "\n")

    assert(pane.ask_pane.entry.preset_name == "one", "visual ask picker reopened instead of reusing active ask target")
    assert(pane.ask_pane.target_reason == "active_ask_target", "later visual append did not reuse active target through resolver")
    assert(prompt:find("lines 1%-1", 1, false), prompt)
    assert(prompt:find("lines 2%-2", 1, false), prompt)

    pane._test_next_choice = "2"
    pane.ask_last_coding_agent({ bufnr = origin_buf, line1 = 2, line2 = 2 })

    assert(pane.ask_pane.entry.preset_name == "one", "ask-last reopened picker instead of reusing active ask target")
end)

test("pane-mode ask-last first capture uses default target without picker", function()
    reset_pane()

    local root = root_fixture("ask-pane-ask-last-default-target-test")

    write(root .. "/src/origin.lua", {
        "first()",
        "second()",
    })
    pane.setup({
        ask = {
            ui = "pane",
            model_picker = "before_send",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane._test_next_choice = "2"
    pane.ask_last_coding_agent({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local prompt = table.concat(vim.api.nvim_buf_get_lines(pane.ask_pane.bufnr, 0, -1, false), "\n")

    assert(pane.ask_pane.entry.preset_name == "one", "ask-last first capture opened picker instead of using default target")
    assert(pane.ask_pane.target_reason == "default_ask_target", "ask-last first capture did not record default target reason")
    assert(prompt:find("lines 1%-1", 1, false), prompt)
end)

test("pane-mode ask target resolver ignores last coding-agent context from another root", function()
    reset_pane()

    local first_root = root_fixture("ask-pane-target-cross-root-first")
    local second_root = root_fixture("ask-pane-target-cross-root-second")

    write(first_root .. "/src/origin.lua", { "first()" })
    write(second_root .. "/src/origin.lua", { "second()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    pane.open_terminal("codex", "two", { root = first_root, focus = true })
    vim.cmd.edit(second_root .. "/src/origin.lua")
    pane.ask_last_coding_agent({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    assert(pane.ask_pane.root == second_root, "ask target resolver used the previous root")
    assert(pane.ask_pane.entry.preset_name == "one", "cross-root ask reused the previous root preset")
    assert(pane.ask_pane.target_reason == "default_ask_target", "cross-root ask did not fall back through default target")
end)

test("pane-mode ask target resolver leaves missing targets to the picker path", function()
    reset_pane()

    local root = root_fixture("ask-pane-target-missing-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = false,
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask_picker({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    assert(not pane.ask_pane.bufnr, "missing ask target unexpectedly created an ask pane")
end)

test("pane-mode explicit ask target replaces stale resolver reason", function()
    reset_pane()

    local root = root_fixture("ask-pane-explicit-target-reason-test")

    write(root .. "/src/origin.lua", {
        "first()",
        "second()",
    })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    local origin_buf = vim.api.nvim_get_current_buf()

    pane.ask_picker({ bufnr = origin_buf, line1 = 1, line2 = 1 })
    pane.ask("claude", nil, { bufnr = origin_buf, line1 = 2, line2 = 2 })

    local snapshot = ask_pane_module.snapshot(pane)

    assert(pane.ask_pane.entry.tool_name == "claude", "explicit ask did not replace target")
    assert(pane.ask_pane.target_reason == "explicit_target", "explicit ask kept stale target reason")
    assert(snapshot.target_reason == "explicit_target", "explicit ask snapshot kept stale target reason")
end)

test("pane-mode duplicate detection respects edited ask draft text", function()
    reset_pane()

    local root = root_fixture("ask-pane-edited-duplicate-test")

    write(root .. "/src/one.lua", { "one()" })
    pane.setup({
        ask = {
            ui = "pane",
            duplicate_policy = "skip",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/one.lua")
    local one_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = one_buf, line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 2, -1, false, {})

    local messages = capture_notify(function()
        pane.ask("codex", nil, { bufnr = one_buf, line1 = 1, line2 = 1 })
    end)
    local prompt = table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n")

    assert(not has_notify(messages, "Duplicate ask citation skipped"), "stale citation registry skipped an edited-out citation")
    assert(prompt:find("File:\nsrc/one%.lua", 1, false), prompt)
    assert(prompt:find("lines 1%-1", 1, false), prompt)
end)

test("pane-mode explicit append works when auto append is disabled", function()
    reset_pane()

    local root = root_fixture("ask-pane-explicit-append-test")

    write(root .. "/src/origin.lua", {
        "first()",
        "second()",
    })
    pane.setup({
        ask = {
            ui = "pane",
            auto_append = false,
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    local origin_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = origin_buf, line1 = 1, line2 = 1 })
    pane.ask("codex", nil, { bufnr = origin_buf, line1 = 2, line2 = 2 })

    local after_auto = table.concat(vim.api.nvim_buf_get_lines(pane.ask_pane.bufnr, 0, -1, false), "\n")

    assert(not after_auto:find("lines 2%-2", 1, false), "disabled auto append still mutated prompt")

    pane.append_to_ask({ bufnr = origin_buf, line1 = 2, line2 = 2 })

    local after_explicit = table.concat(vim.api.nvim_buf_get_lines(pane.ask_pane.bufnr, 0, -1, false), "\n")

    assert(after_explicit:find("lines 2%-2", 1, false), "explicit append did not mutate prompt")

    local snapshot = ask_pane_module.snapshot(pane)

    assert(snapshot.draft_state == "draft_modified", "append snapshot did not report draft_modified")
    assert(snapshot.citation_count == 2, "append snapshot citation count was wrong")
    assert(snapshot.file_count == 1, "append snapshot file count was wrong")
end)

test("pane-mode ask write then quit sends accumulated prompt", function()
    reset_pane()

    local root = root_fixture("ask-pane-send-test")
    local out = helpers.tmp_path("sidepanes-ask-pane-send.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "send accumulated prompt" })
    pane.write_ask_pane(qbuf)
    assert(pane.ask_pane.draft_state == "draft_written", "ask write did not record draft_written")
    pane.finish_ask_pane(qbuf)

    wait_for_file(out, "send accumulated prompt")
    wait_for_file(out, "selected()")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "accumulated prompt send"
    )
    assert(pane.ask_pane_last_state == "sent", "ask send did not leave sent as last state")
    assert(pane.active_mode == "codex", "ask pane send did not focus target terminal")
    assert(not pane.ask_pane.bufnr, "ask pane state was not cleared after send")
    assert(ask_pane_module.snapshot(pane).active == false, "sent ask snapshot should be inactive after state clear")
    assert(
        vim.fn.maparg("<CR>", "c", false, true).desc ~= "Sidepanes ask pane command-line enter",
        "ask pane send leaked command-line enter mapping"
    )
end)

test("pane-mode ask preserves prompt when target terminal fails to open", function()
    reset_pane()

    local root = root_fixture("ask-pane-send-open-failure-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sidepanes-missing-executable-for-test" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "do not lose this draft" })

    local messages = capture_notify(function()
        pane.submit_ask_pane(qbuf)
    end)

    local prompt = table.concat(vim.api.nvim_buf_get_lines(qbuf, 0, -1, false), "\n")

    assert(has_notify(messages, "Pane tool executable not found"), "terminal-open failure did not notify")
    assert(has_notify(messages, "Ask prompt was not sent; target terminal did not open"), "ask pane did not warn about preserved draft")
    assert(pane.ask_pane.bufnr == qbuf, "failed send cleared ask pane state")
    assert(pane.ask_pane.draft_state == "send_failed", "failed send did not record send_failed")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "send_failed" },
        "failed terminal send"
    )
    assert(vim.api.nvim_buf_is_valid(qbuf), "failed send deleted ask buffer")
    assert(prompt:find("do not lose this draft", 1, true), prompt)
    assert(pane.active_mode == "ask", "failed send should leave ask pane active")

    local snapshot = ask_pane_module.snapshot(pane)
    local status = ask_session.status_data(snapshot)
    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(snapshot.active == true, "failed send snapshot should stay active")
    assert(snapshot.draft_state == "send_failed", "failed send snapshot lost send_failed")
    assert(status.draft_state == "send_failed", "failed send status data lost send_failed")
    assert(winbar:find("send_failed", 1, true), winbar)

    messages = capture_notify(function()
        vim.api.nvim_set_current_win(pane.winid)
        feed_user_command("q")
    end)

    assert(has_notify(messages, "Ask prompt was not sent; target terminal did not open"), "fed :q failed-send retry did not warn")
    assert(pane.ask_pane.bufnr == qbuf, "fed :q failed-send retry cleared ask pane state")
    assert(pane.ask_pane.draft_state == "send_failed", "fed :q failed-send retry did not preserve send_failed")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "send_failed", "sending_terminal" },
        "fed :q failed-send retry"
    )
end)

test("pane-mode ask cancel restores previous markdown and terminal modes", function()
    reset_pane()

    local root = root_fixture("ask-pane-cancel-restore-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")
    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })
    pane.cancel_ask_pane(pane.ask_pane.bufnr)

    assert(pane.active_mode == "markdown", "ask pane cancel did not restore markdown mode")
    assert(vim.api.nvim_win_get_buf(pane.winid) == pane.bufnr, "ask pane cancel did not restore markdown buffer")
    assert(ask_pane_module.snapshot(pane).active == false, "cancel snapshot should be inactive after state clear")

    pane.open_terminal("codex", nil, { root = root, focus = true })

    local terminal_key = pane.active_terminal_key

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })
    pane.cancel_ask_pane(pane.ask_pane.bufnr)

    assert(pane.active_mode == "codex", "ask pane cancel did not restore terminal mode")
    assert(pane.active_terminal_key == terminal_key, "ask pane cancel did not restore terminal key")
end)

test("pane-mode ask cancel restores claude ipython and custom terminal modes", function()
    reset_pane()

    local root = root_fixture("ask-pane-cancel-all-terminals-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            shell = {
                label = "Shell",
                ask = true,
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    local origin_buf = vim.api.nvim_get_current_buf()

    local function assert_restore(tool_name, ask_tool)
        pane.open_terminal(tool_name, nil, { root = root, focus = true })

        local terminal_key = pane.active_terminal_key

        pane.ask(ask_tool or "codex", nil, { bufnr = origin_buf, line1 = 1, line2 = 1 })

        vim.api.nvim_buf_set_lines(pane.ask_pane.bufnr, 1, 1, false, { "modified before cancel" })
        assert(vim.api.nvim_get_option_value("modified", { buf = pane.ask_pane.bufnr }), "ask buffer was not modified before cancel")

        pane.cancel_ask_pane(pane.ask_pane.bufnr)

        assert(pane.active_mode == tool_name, "ask pane cancel did not restore " .. tool_name .. " mode")
        assert(pane.active_terminal_key == terminal_key, "ask pane cancel did not restore " .. tool_name .. " terminal key")
    end

    assert_restore("claude")
    assert_restore("ipython")
    assert_restore("shell", "shell")
end)

test("ask pane command-line mapping cancels q and sends wq through internal callbacks", function()
    reset_pane()

    pane.setup({
        ask = {
            ui = "pane",
        },
    })
    pane.show_ask_pane({ focus = true })

    local qbuf = pane.ask_pane.bufnr
    local enter_map = vim.fn.maparg("<CR>", "c", false, true)
    original_getcmdline = vim.fn.getcmdline
    original_getcmdtype = vim.fn.getcmdtype

    assert(enter_map.callback, "ask pane command-line enter map has no callback")
    assert(enter_map.desc == "Sidepanes ask pane command-line enter", "ask pane command-line enter map had wrong desc")

    vim.fn.getcmdtype = function()
        return ":"
    end

    local function mapped(command)
        vim.fn.getcmdline = function()
            return command
        end

        return enter_map.callback()
    end

    local quit = mapped("q!")
    local finish_quit = mapped("q")
    local quit_long = mapped("quit")
    local quit_bang = mapped("quit!")
    local write_and_quit = mapped("wq")
    local write_and_quit_bang = mapped("wq!")
    local exit = mapped("exit")
    local xit = mapped("xit")
    local x = mapped("x")

    vim.fn.getcmdline = original_getcmdline
    vim.fn.getcmdtype = original_getcmdtype

    assert(quit:find('require%("sidepanes%.internal"%)%.cancel_ask_pane', 1, false), quit)
    assert(finish_quit:find('require%("sidepanes%.internal"%)%.finish_ask_pane', 1, false), finish_quit)
    assert(quit_long:find('require%("sidepanes%.internal"%)%.finish_ask_pane', 1, false), quit_long)
    assert(quit_bang:find('require%("sidepanes%.internal"%)%.cancel_ask_pane', 1, false), quit_bang)
    assert(write_and_quit:find('require%("sidepanes%.internal"%)%.submit_ask_pane', 1, false), write_and_quit)
    assert(write_and_quit_bang:find('require%("sidepanes%.internal"%)%.submit_ask_pane', 1, false), write_and_quit_bang)
    assert(exit:find('require%("sidepanes%.internal"%)%.submit_ask_pane', 1, false), exit)
    assert(xit:find('require%("sidepanes%.internal"%)%.submit_ask_pane', 1, false), xit)
    assert(x:find('require%("sidepanes%.internal"%)%.submit_ask_pane', 1, false), x)
    assert(not has_map(qbuf, "q"), "plain normal q should not cancel ask pane")
end)

test("ask pane fed command-line lifecycle covers q w and wq user paths", function()
    reset_pane()

    local root = root_fixture("ask-pane-fed-commandline-test")
    local out = helpers.tmp_path("sidepanes-ask-pane-fed-commandline.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")

    local source_win = vim.api.nvim_get_current_win()

    pane.open(root .. "/docs/doc.md")

    local winid = pane.winid

    local function open_ask_from_source()
        vim.api.nvim_set_current_win(source_win)
        vim.cmd.edit(root .. "/src/origin.lua")
        pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

        return pane.ask_pane.bufnr
    end

    pane.show_ask_pane({ focus = true })

    local ready_buf = pane.ask_pane.bufnr

    vim.api.nvim_set_current_win(winid)
    feed_user_command("q")
    wait_until("fed :q did not cancel ready ask pane", function()
        return pane.active_mode == "markdown" and not vim.api.nvim_buf_is_valid(ready_buf)
    end)
    assert_pane_window(winid, pane.bufnr, "fed :q ready")
    assert_state_history_contains(pane.ask_pane_state_history, { "ready_empty", "cancelled" }, "fed :q ready")

    pane.show_ask_pane({ focus = true })

    local ready_write_buf = pane.ask_pane.bufnr

    vim.api.nvim_set_current_win(winid)
    feed_user_command("w")
    wait_until("fed :w did not keep ready ask pane active", function()
        return pane.active_mode == "ask" and pane.ask_pane.bufnr == ready_write_buf
    end)
    assert(vim.api.nvim_buf_is_valid(ready_write_buf), "fed :w deleted ready ask buffer")
    assert(pane.ask_pane.draft_state == "draft_written", "fed :w ready did not record draft_written")
    assert(pane.ask_pane.written_prompt == "Question:", "fed :w ready cached unexpected prompt")
    assert(not vim.api.nvim_get_option_value("modified", { buf = ready_write_buf }), "fed :w ready left buffer modified")
    assert(read_file(out) == "", "fed :w ready sent a prompt")
    pane.cancel_ask_pane(ready_write_buf)

    local write_buf = open_ask_from_source()

    vim.api.nvim_buf_set_lines(write_buf, 1, 1, false, { "write modified prompt only" })
    vim.api.nvim_set_option_value("modified", true, { buf = write_buf })
    vim.api.nvim_set_current_win(winid)
    assert(vim.api.nvim_win_get_buf(winid) == write_buf, "fed :w modified setup did not focus ask buffer")
    assert(vim.api.nvim_get_option_value("buftype", { buf = write_buf }) == "acwrite", "fed :w modified setup lost acwrite buffer type")
    assert(
        vim.fn.maparg("<CR>", "c", false, true).desc == "Sidepanes ask pane command-line enter",
        "fed :w modified setup lost ask command-line enter map"
    )
    feed_user_command("w")
    wait_until("fed :w did not keep modified ask pane active", function()
        return pane.active_mode == "ask" and pane.ask_pane.bufnr == write_buf
    end)
    assert(pane.ask_pane.draft_state == "draft_written", "fed :w modified did not record draft_written")
    assert(pane.ask_pane.written_prompt:find("write modified prompt only", 1, true), pane.ask_pane.written_prompt)
    assert(not vim.api.nvim_get_option_value("modified", { buf = write_buf }), "fed :w modified left buffer modified")
    assert(not read_file(out):find("write modified prompt only", 1, true), "fed :w modified sent a prompt")
    pane.cancel_ask_pane(write_buf)

    local modified_buf = open_ask_from_source()

    vim.api.nvim_buf_set_lines(modified_buf, 1, 1, false, { "cancel modified prompt with q" })
    vim.api.nvim_set_option_value("modified", true, { buf = modified_buf })
    vim.api.nvim_set_current_win(winid)
    feed_user_command("q")
    wait_until("fed :q did not cancel modified ask pane", function()
        return pane.active_mode == "markdown" and not vim.api.nvim_buf_is_valid(modified_buf)
    end)
    assert(not read_file(out):find("cancel modified prompt with q", 1, true), "fed :q sent modified prompt")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "cancelled" },
        "fed :q modified"
    )

    local written_buf = open_ask_from_source()

    vim.api.nvim_buf_set_lines(written_buf, 1, 1, false, { "send written prompt with q" })
    pane.write_ask_pane(written_buf)
    assert(pane.ask_pane.draft_state == "draft_written", "fed :q written setup lost draft_written state")
    vim.api.nvim_set_current_win(winid)
    feed_user_command("q")
    wait_for_file(out, "send written prompt with q")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "fed :q written"
    )
    assert(pane.ask_pane_last_state == "sent", "fed :q written did not record sent")
    assert(pane.active_mode == "codex", "fed :q written did not switch to target terminal")

    local submit_buf = open_ask_from_source()

    vim.api.nvim_buf_set_lines(submit_buf, 1, 1, false, { "send modified prompt with wq" })
    vim.api.nvim_set_option_value("modified", true, { buf = submit_buf })
    vim.api.nvim_set_current_win(winid)
    feed_user_command("wq")
    wait_for_file(out, "send modified prompt with wq")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "fed :wq modified"
    )
    assert(pane.ask_pane_last_state == "sent", "fed :wq did not record sent")
    assert(pane.active_mode == "codex", "fed :wq did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "fed :wq did not clear ask state")
end)

test("ask pane empty ready draft writes then submit cancels without sending", function()
    reset_pane()

    local root = root_fixture("ask-pane-ready-submit-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        ask = {
            ui = "pane",
        },
    })

    pane.open(root .. "/docs/doc.md")
    pane.show_ask_pane({ focus = true })

    local winid = pane.winid
    local qbuf = pane.ask_pane.bufnr

    pane.write_ask_pane(qbuf)

    assert(vim.api.nvim_buf_is_valid(qbuf), "ready write deleted ask buffer")
    assert(pane.active_mode == "ask", "ready write left ask pane")
    assert(pane.ask_pane.written_prompt == "Question:", "ready write cached unexpected prompt")
    assert(pane.ask_pane.draft_state == "draft_written", "ready write did not record draft_written")
    assert(not vim.api.nvim_get_option_value("modified", { buf = qbuf }), "ready write left buffer modified")

    local snapshot = ask_pane_module.snapshot(pane)
    local facts = ask_pane_module.lifecycle_facts(pane)

    assert(snapshot.draft_state == "draft_written", "runtime snapshot lost draft_written after write")
    assert(snapshot.written_prompt == "Question:", "runtime snapshot lost written prompt after write")
    assert(snapshot.dirty_buffer == false, "runtime snapshot marked written prompt dirty")
    assert(facts.written_prompt == "Question:", "runtime lifecycle facts lost written prompt")
    assert(facts.dirty_buffer == false, "runtime lifecycle facts marked written prompt dirty")

    pane.submit_ask_pane(qbuf)

    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_written", "cancelled" },
        "empty ready submit"
    )
    assert(pane.ask_pane_last_state == "cancelled", "empty ready submit did not record cancelled")
    assert(pane.active_mode == "markdown", "ready submit did not restore markdown")
    assert(vim.api.nvim_win_is_valid(winid), "ready submit closed side pane")
    assert(vim.api.nvim_win_get_buf(winid) == pane.bufnr, "ready submit did not restore markdown buffer")
    assert(vim.wait(1000, function()
        return not vim.api.nvim_buf_is_valid(qbuf)
    end), "ready submit did not clear ask buffer")
    assert(ask_pane_module.snapshot(pane).active == false, "cancelled ready submit snapshot should be inactive after clear")
end)

test("submit question command without active ask draft warns and keeps state", function()
    reset_pane()

    pane.setup({
        ask = {
            ui = "pane",
        },
    })

    local current_buf = vim.api.nvim_get_current_buf()
    local messages = capture_notify(function()
        vim.cmd("SidepanesSubmitQuestion")
    end)

    assert(has_notify(messages, "No ask pane prompt to submit"), "submit command without draft did not warn")
    assert(vim.api.nvim_get_current_buf() == current_buf, "submit command without draft changed current buffer")
    assert(not pane.ask_pane or not pane.ask_pane.bufnr, "submit command without draft created ask state")
end)

test("direct ask pane command-line fallback cancels without missing pane deps", function()
    reset_pane()

    local root = root_fixture("ask-pane-direct-fallback-cancel-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        ask = {
            ui = "pane",
        },
    })

    pane.open(root .. "/docs/doc.md")
    pane.show_ask_pane({ focus = true })

    local winid = pane.winid
    local qbuf = pane.ask_pane.bufnr

    pane.ask_pane.last_cmdline = "q"
    vim.api.nvim_exec_autocmds("CmdlineLeave", {})

    assert(vim.wait(1000, function()
        return pane.active_mode == "markdown"
    end), "direct ask pane fallback :q did not restore markdown")
    assert(vim.api.nvim_win_is_valid(winid), "direct ask pane fallback :q closed the side pane")
    assert(vim.api.nvim_win_get_buf(winid) == pane.bufnr, "direct ask pane fallback :q did not restore markdown buffer")
    assert(vim.wait(1000, function()
        return not vim.api.nvim_buf_is_valid(qbuf)
    end), "direct ask pane fallback :q did not clear ask buffer")
    assert_state_history_contains(pane.ask_pane_state_history, { "ready_empty", "cancelled" }, "direct ask pane :q fallback")
    assert(pane.ask_pane_last_state == "cancelled", "direct ask pane fallback :q did not record cancelled")
end)

test("ask pane typed q bang cancels without closing the side pane", function()
    reset_pane()

    local root = root_fixture("ask-pane-typed-quit-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        ask = {
            ui = "pane",
        },
    })

    pane.open(root .. "/docs/doc.md")
    pane.show_ask_pane({ focus = true })

    local winid = pane.winid
    local qbuf = pane.ask_pane.bufnr

    vim.cmd("stopinsert")
    feed_user_keys("<Esc>")
    vim.api.nvim_set_current_win(winid)
    assert(vim.wait(1000, function()
        return vim.api.nvim_get_mode().mode == "n"
    end), "typed :q! test did not reach normal mode")
    feed_user_command("q!")

    assert(vim.wait(1000, function()
        return pane.active_mode == "markdown"
    end), "typed :q! did not cancel ask pane")
    assert(vim.api.nvim_win_is_valid(winid), "typed :q! closed the side pane")
    assert(vim.api.nvim_win_get_buf(winid) == pane.bufnr, "typed :q! did not restore markdown buffer")
    assert(vim.wait(1000, function()
        return not vim.api.nvim_buf_is_valid(qbuf)
    end), "typed :q! did not clear ask buffer")
    assert_state_history_contains(pane.ask_pane_state_history, { "ready_empty", "cancelled" }, "typed :q!")
    assert(pane.ask_pane_last_state == "cancelled", "typed :q! did not record cancelled")
    assert(
        vim.fn.maparg("<CR>", "c", false, true).desc ~= "Sidepanes ask pane command-line enter",
        "ask pane cancel leaked command-line enter mapping"
    )
end)

test("ask pane target picker mapping updates target and winbar", function()
    reset_pane()

    local root = root_fixture("ask-pane-target-picker-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
            model_picker = "manual",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    pane._test_next_choice = "2"
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys("M")

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })
    local snapshot = ask_pane_module.snapshot(pane)
    local status = ask_session.status_data(snapshot)
    local debug = ask_status.debug_data(snapshot)

    assert(pane.ask_pane.entry.preset_name == "two", "ask pane target picker did not update preset")
    assert(pane.ask_pane.target_reason == "explicit_target_change", "manual target picker did not record explicit target-change reason")
    assert(snapshot.target_label == "Codex: Two", "target picker snapshot label was wrong")
    assert(snapshot.target_reason == "explicit_target_change", "target picker snapshot reason was wrong")
    assert(status.target_label == "Codex: Two", "target picker status label was wrong")
    assert(status.target_reason == "explicit_target_change", "target picker status reason was wrong")
    assert(debug.target_label == "Codex: Two", "target picker debug status label was wrong")
    assert(debug.target_root == root, "target picker debug status root was wrong")
    assert(debug.picker_mode == "manual", "target picker debug status picker mode was wrong")
    assert(debug.after_open_shown == false, "manual target picker should not report after_open shown")
    assert(debug.draft_state == "draft_modified", "target picker debug status draft state was wrong")
    assert(debug.citation_count == 1 and debug.file_count == 1, "target picker debug status counts were wrong")
    assert(winbar:find("Codex: Two", 1, true), winbar)
    assert(not winbar:find("Citations:", 1, true), "winbar should not become a dense status dump: " .. winbar)
end)

test("ask pane target picker mapping is configurable", function()
    reset_pane()

    local root = root_fixture("ask-pane-configurable-picker-map-test")

    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        mappings = {
            pane = {
                ask_model_picker = "K",
                ask_model_picker_alt = false,
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    assert(has_map(qbuf, "K"), "custom ask model picker mapping missing")
    assert(not has_map(qbuf, "<Tab>"), "disabled ask model picker alt mapping was installed")

    pane._test_next_choice = "2"
    call_map(qbuf, "K")

    assert(pane.ask_pane.entry.preset_name == "two", "custom ask model picker mapping did not update target")
end)

test("ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts", function()
    reset_pane()

    local root = root_fixture("ask-pane-send-map-test")
    local out = helpers.tmp_path("sidepanes-ask-pane-send-map.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        mappings = {
            pane = {
                ask_send = "qq",
                ask_send_alt = "<leader>qq",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    local function open_ask()
        vim.cmd.edit(root .. "/src/origin.lua")
        pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

        return pane.ask_pane.bufnr
    end

    local qbuf = open_ask()

    assert(has_map(qbuf, "qq"), "custom ask send mapping missing")
    local alt_lhs = expanded_leader("<leader>qq")

    assert(has_map(qbuf, alt_lhs), "custom ask send alt mapping missing")
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "cancel from qq" })

    local messages = capture_notify(function()
        vim.api.nvim_set_current_win(pane.winid)
        feed_user_keys("qq")
    end)

    assert(not has_notify(messages, "Write the ask prompt before sending"), "unwritten ask send mapping warned instead of quitting")
    assert(read_file(out) == "", "unwritten ask send mapping sent prompt")
    assert(not pane.ask_pane.bufnr, "unwritten ask send mapping did not cancel ask state")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "cancelled" },
        "unwritten qq"
    )
    assert(pane.ask_pane_last_state == "cancelled", "unwritten qq did not record cancelled")

    qbuf = open_ask()
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "send from qq" })

    pane.write_ask_pane(qbuf)
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys("qq")
    wait_for_file(out, "send from qq")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "written qq"
    )
    assert(pane.ask_pane_last_state == "sent", "written qq did not record sent")
    assert(pane.active_mode == "codex", "ask send mapping did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "ask send mapping did not clear ask state")

    qbuf = open_ask()

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "cancel from leader qq" })
    messages = capture_notify(function()
        vim.api.nvim_set_current_win(pane.winid)
        feed_user_keys(alt_lhs)
    end)

    assert(not has_notify(messages, "Write the ask prompt before sending"), "unwritten ask send alt mapping warned instead of quitting")
    assert(not read_file(out):find("cancel from leader qq", 1, true), "unwritten ask send alt mapping sent prompt")
    assert(not pane.ask_pane.bufnr, "unwritten ask send alt mapping did not cancel ask state")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "cancelled" },
        "unwritten leader qq"
    )
    assert(pane.ask_pane_last_state == "cancelled", "unwritten leader qq did not record cancelled")

    qbuf = open_ask()
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "send from leader qq" })

    pane.write_ask_pane(qbuf)
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys(alt_lhs)
    wait_for_file(out, "send from leader qq")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "written leader qq"
    )
    assert(pane.ask_pane_last_state == "sent", "written leader qq did not record sent")
    assert(pane.active_mode == "codex", "ask send alt mapping did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "ask send alt mapping did not clear ask state")
end)

test("personal quit mapping in terminal pane follows q command path with plain quit guard", function()
    reset_pane()

    local root = root_fixture("personal-quit-command-terminal-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.lua", { "selected()" })
    vim.keymap.set("n", "<leader>qq", ":q<CR>", { silent = true, desc = "Personal quit mapping" })

    pane.setup({
        ask = {
            ui = "pane",
        },
        mappings = {
            pane = {
                ask_send_alt = "<leader>qq",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    local ok, err = xpcall(function()
        pane.open(root .. "/docs/doc.md")

        local winid = pane.winid
        local ctx = pane.open_terminal("codex", "one", { root = root, focus = true })
        local alt_lhs = expanded_leader("<leader>qq")

        assert(has_map(ctx.bufnr, alt_lhs), "terminal pane did not guard personal ask_send_alt/global quit lhs")
        assert(not has_map(ctx.bufnr, alt_lhs, "t"), "terminal-input pane should not own personal ask_send_alt/global quit lhs")

        local function assert_quit_command_path(command, label)
            local messages = capture_notify(function()
                feed_user_command(command)
            end)

            assert(not has_notify(messages, "Write the ask prompt before sending"), label .. " command-line quit called ask send")
            wait_until(label .. " command-line quit did not return to markdown", function()
                return vim.api.nvim_win_is_valid(winid)
                    and pane.active_mode == "markdown"
                    and vim.api.nvim_win_get_buf(winid) == pane.bufnr
            end)
        end

        vim.api.nvim_set_current_win(winid)
        assert_quit_command_path("q", "terminal without active ask draft")

        ctx = pane.open_terminal("codex", "one", { root = root, focus = true })
        vim.cmd.edit(root .. "/src/origin.lua")
        pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })
        ctx = pane.open_terminal("codex", "one", { root = root, focus = true })

        assert(has_map(ctx.bufnr, alt_lhs), "terminal pane did not guard personal ask_send_alt/global quit lhs while ask draft is active")
        assert(not has_map(ctx.bufnr, alt_lhs, "t"), "terminal-input pane should not own personal ask_send_alt/global quit lhs while ask draft is active")

        vim.api.nvim_set_current_win(winid)
        assert_quit_command_path("q", "terminal with active ask draft")

        vim.api.nvim_set_current_win(winid)
        assert_quit_command_path("quit", "Markdown pane with active ask draft")

    end, debug.traceback)

    pcall(vim.keymap.del, "n", "<leader>qq")

    if not ok then
        error(err)
    end
end)

test("personal normal quit mappings do not close markdown or terminal side panes", function()
    reset_pane()

    local root = root_fixture("personal-normal-quit-map-pane-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.lua", { "selected()" })
    vim.keymap.set("n", "qq", ":q<CR>", { silent = true, desc = "Personal quit mapping" })
    vim.keymap.set("n", "<leader>qq", ":q<CR>", { silent = true, desc = "Personal leader quit mapping" })

    pane.setup({
        ask = {
            ui = "pane",
        },
        mappings = {
            pane = {
                ask_send = "qq",
                ask_send_alt = "<leader>qq",
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    local ok, err = xpcall(function()
        pane.open(root .. "/docs/doc.md")

        local winid = pane.winid
        local markdown_bufnr = pane.bufnr
        local alt_lhs = expanded_leader("<leader>qq")

        assert(has_map(markdown_bufnr, "qq"), "Markdown pane did not guard personal qq quit mapping")
        assert(has_map(markdown_bufnr, alt_lhs), "Markdown pane did not guard personal leader quit mapping")

        vim.api.nvim_set_current_win(winid)
        feed_user_keys("qq")

        assert(vim.wait(500, function()
            return vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == markdown_bufnr
        end, 10), "personal qq closed the Markdown side pane")

        pane.open_terminal("codex", "one", { root = root, focus = true })

        local ctx = pane.terminals[util.terminal_key("codex", root)]

        assert(ctx and vim.api.nvim_buf_is_valid(ctx.bufnr), "Codex pane did not open")
        assert(has_map(ctx.bufnr, "qq"), "terminal pane did not guard personal qq quit mapping")
        assert(has_map(ctx.bufnr, alt_lhs), "terminal pane did not guard personal leader quit mapping")

        vim.cmd.stopinsert()
        vim.api.nvim_set_current_win(winid)
        feed_user_keys(alt_lhs)

        assert(vim.wait(500, function()
            return vim.api.nvim_win_is_valid(winid) and pane.active_mode == "markdown" and vim.api.nvim_win_get_buf(winid) == pane.bufnr
        end, 10), "personal leader quit mapping closed the terminal side pane")
    end, debug.traceback)

    pcall(vim.keymap.del, "n", "qq")
    pcall(vim.keymap.del, "n", "<leader>qq")

    if not ok then
        error(err)
    end
end)

test("ask pane submit mapping sends modified prompt from normal and insert modes", function()
    reset_pane()

    local root = root_fixture("ask-pane-submit-map-test")
    local out = helpers.tmp_path("sidepanes-ask-pane-submit-map.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    assert(has_map(qbuf, "<C-CR>", "n"), "ask submit normal mapping missing")
    assert(has_map(qbuf, "<C-CR>", "i"), "ask submit insert mapping missing")
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "submit from ctrl enter" })
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys("<C-CR>")

    wait_for_file(out, "submit from ctrl enter")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "normal ctrl-enter submit"
    )
    assert(pane.ask_pane_last_state == "sent", "normal ctrl-enter submit did not record sent")
    assert(pane.active_mode == "codex", "ask submit mapping did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "ask submit mapping did not clear ask state")

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    qbuf = pane.ask_pane.bufnr
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "submit from insert ctrl enter" })
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_insert_keys("<C-CR>")

    wait_for_file(out, "submit from insert ctrl enter")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "insert ctrl-enter submit"
    )
    assert(pane.ask_pane_last_state == "sent", "insert ctrl-enter submit did not record sent")
    assert(pane.active_mode == "codex", "ask submit insert mapping did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "ask submit insert mapping did not clear ask state")

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    qbuf = pane.ask_pane.bufnr
    assert(has_map(qbuf, "<C-J>", "n"), "ask submit normal Ctrl+Enter fallback mapping missing")
    assert(has_map(qbuf, "<C-J>", "i"), "ask submit insert Ctrl+Enter fallback mapping missing")
    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "submit from ctrl enter fallback" })
    vim.api.nvim_set_current_win(pane.winid)
    feed_user_keys("<C-J>")

    wait_for_file(out, "submit from ctrl enter fallback")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_terminal", "sent" },
        "ctrl-enter fallback submit"
    )
    assert(pane.ask_pane_last_state == "sent", "ctrl-enter fallback submit did not record sent")
    assert(pane.active_mode == "codex", "ask submit fallback mapping did not switch to target terminal")
    assert(not pane.ask_pane.bufnr, "ask submit fallback mapping did not clear ask state")
end)

test("ask pane automatic model picker modes update target", function()
    reset_pane()

    local root = root_fixture("ask-pane-model-picker-mode-test")
    local out = helpers.tmp_path("sidepanes-ask-pane-model-picker.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.lua", { "selected()" })
    pane.setup({
        ask = {
            ui = "pane",
            model_picker = "after_open",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane._test_next_choice = "2"
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    assert(pane.ask_pane.entry.preset_name == "two", "after_open model picker did not update target")

    local after_open_snapshot = ask_pane_module.snapshot(pane)
    local after_open_debug = ask_status.debug_data(after_open_snapshot)

    assert(after_open_snapshot.picker_mode == "after_open", "after_open snapshot picker mode was wrong")
    assert(after_open_snapshot.picker_shown == true, "after_open snapshot did not report picker shown")
    assert(after_open_snapshot.target_label == "Codex: Two", "after_open snapshot target label was wrong")
    assert(after_open_debug.target_label == "Codex: Two", "after_open debug status target label was wrong")
    assert(after_open_debug.target_root == root, "after_open debug status target root was wrong")
    assert(after_open_debug.picker_mode == "after_open", "after_open debug status picker mode was wrong")
    assert(after_open_debug.after_open_shown == true, "after_open debug status did not report picker shown")
    assert(after_open_debug.draft_state == "draft_modified", "after_open debug status draft state was wrong")
    assert(after_open_debug.citation_count == 1 and after_open_debug.file_count == 1, "after_open debug status counts were wrong")

    pane._test_next_choice = "1"
    pane.show_markdown()
    pane.show_ask_pane({ focus = true })
    assert(pane.ask_pane.entry.preset_name == "two", "after_open picker reran when refocusing an active draft")

    pane.cancel_ask_pane(pane.ask_pane.bufnr)
    pane.setup({
        ask = {
            ui = "pane",
            model_picker = "before_send",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
            claude = false,
            ipython = false,
        },
    })

    vim.cmd.edit(root .. "/src/origin.lua")
    pane.ask("codex", "one", { bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    vim.api.nvim_buf_set_lines(qbuf, 1, 1, false, { "send with changed model" })
    pane.write_ask_pane(qbuf)

    local before_send_debug = ask_status.debug_data(ask_pane_module.snapshot(pane))

    assert(before_send_debug.target_label == "Codex: One", "before_send debug status target label before send was wrong")
    assert(before_send_debug.target_root == root, "before_send debug status target root before send was wrong")
    assert(before_send_debug.picker_mode == "before_send", "before_send debug status picker mode before send was wrong")
    assert(before_send_debug.after_open_shown == false, "before_send debug status should not report after_open shown")
    assert(before_send_debug.draft_state == "draft_written", "before_send debug status draft state before send was wrong")
    assert(before_send_debug.citation_count == 1 and before_send_debug.file_count == 1, "before_send debug status counts before send were wrong")

    pane._test_next_choice = "2"
    pane.finish_ask_pane(qbuf)

    local terminal_ctx = pane.terminals[util.terminal_key("codex", root)]

    wait_for_file(out, "send with changed model")
    assert_state_history_contains(
        pane.ask_pane_state_history,
        { "ready_empty", "draft_modified", "draft_written", "sending_picker", "sending_terminal", "sent" },
        "before-send picker"
    )
    assert(pane.ask_pane_last_state == "sent", "before-send picker did not record sent")
    assert(terminal_ctx.preset_name == "two", "before_send model picker did not send to selected preset")
    assert(terminal_ctx.root == root, "before_send model picker sent with wrong root")
end)

test("ask pane navigation mappings move between context headers and source jump opens citation", function()
    reset_pane()

    local root = root_fixture("ask-pane-navigation-test")

    write(root .. "/src/one.lua", {
        "one_a()",
        "one_b()",
    })
    write(root .. "/src/two.lua", {
        "two_a()",
        "two_b()",
    })
    pane.setup({
        ask = {
            ui = "pane",
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/one.lua")
    local source_win = vim.api.nvim_get_current_win()
    local one_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = one_buf, line1 = 2, line2 = 2 })
    vim.cmd.edit(root .. "/src/two.lua")
    pane.append_to_ask({ bufnr = vim.api.nvim_get_current_buf(), line1 = 1, line2 = 1 })

    local qbuf = pane.ask_pane.bufnr

    assert(has_map(qbuf, "]f"), "ask next file mapping missing")
    assert(has_map(qbuf, "[f"), "ask previous file mapping missing")
    assert(has_map(qbuf, "]s"), "ask next selection mapping missing")
    assert(has_map(qbuf, "[s"), "ask previous selection mapping missing")
    assert(has_map(qbuf, "gf"), "ask source jump mapping missing")

    vim.api.nvim_set_current_win(pane.winid)
    vim.api.nvim_win_set_cursor(pane.winid, { 1, 0 })
    call_map(qbuf, "]s")

    local first_selection_line = vim.api.nvim_win_get_cursor(pane.winid)[1]

    assert(vim.api.nvim_buf_get_lines(qbuf, first_selection_line - 1, first_selection_line, false)[1] == "Selection:", "next selection did not land on selection header")

    call_map(qbuf, "]f")

    local second_file_line = vim.api.nvim_win_get_cursor(pane.winid)[1]

    assert(vim.api.nvim_buf_get_lines(qbuf, second_file_line - 1, second_file_line, false)[1] == "File:", "next file did not land on file header")

    call_map(qbuf, "[f")

    local first_file_line = vim.api.nvim_win_get_cursor(pane.winid)[1]

    assert(first_file_line < second_file_line, "previous file did not move backward")

    vim.api.nvim_win_set_cursor(pane.winid, { first_file_line, 0 })
    call_map(qbuf, "gf")

    assert(vim.api.nvim_get_current_win() == source_win, "ask file source jump did not return to source window")
    assert(vim.api.nvim_buf_get_name(0) == root .. "/src/one.lua", "ask file source jump opened wrong file")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "ask file source jump opened wrong line")

    vim.api.nvim_set_current_win(pane.winid)
    vim.api.nvim_win_set_cursor(pane.winid, { first_selection_line, 0 })
    call_map(qbuf, "gf")

    assert(vim.api.nvim_get_current_win() == source_win, "ask source jump did not return to source window")
    assert(vim.api.nvim_buf_get_name(0) == root .. "/src/one.lua", "ask source jump opened wrong file")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "ask source jump opened wrong line")
end)

test("question quit cancels unwritten changes and restores origin", function()
    reset_pane()

    local root = root_fixture("question-cancel-test")
    local out = helpers.tmp_path("sidepanes-question-cancel.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()
    local origin_buf = vim.api.nvim_get_current_buf()

    pane.ask("codex", nil, { bufnr = origin_buf })

    local qbuf = only_question_buf()

    set_question(qbuf, { "Question:", "this should not send" })
    pane.finish_question(qbuf)

    assert(next(pane.question_buffers) == nil, "question buffer was not cleared")
    assert(next(pane.terminals) == nil, "cancelled question started a terminal")
    assert(vim.api.nvim_get_current_win() == origin_win, "cancel did not restore origin window")
    assert(vim.api.nvim_get_current_buf() == origin_buf, "cancel did not restore origin buffer")
    assert(read_file(out) == "", "cancelled question wrote to terminal")
end)

test("question write then quit sends prompt and focuses terminal", function()
    reset_pane()

    local root = root_fixture("question-send-test")
    local out = helpers.tmp_path("sidepanes-question-send.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf() })

    local qbuf = only_question_buf()
    local internal = require("sidepanes.internal")

    set_question(qbuf, { "Question:", "send this exact prompt" })
    internal.write_question(qbuf)
    internal.finish_question(qbuf)

    wait_for_file(out, "send this exact prompt")
    assert(next(pane.question_buffers) == nil, "sent question buffer was not cleared")
    assert(vim.api.nvim_get_current_win() == pane.winid, "send did not focus the pane terminal")
    assert(pane.active_mode == "codex", "send did not activate Codex")
end)

test("question command-line mapping calls internal lifecycle callbacks", function()
    reset_pane()

    local root = root_fixture("question-commandline-internal-test")

    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf() })

    local qbuf = only_question_buf()
    local enter_map = find_map(qbuf, "<CR>", "c")
    local original_getcmdline = vim.fn.getcmdline

    assert(enter_map.callback, "question command-line enter map has no callback")

    vim.fn.getcmdline = function()
        return "wq"
    end

    local write_and_quit = enter_map.callback()

    vim.fn.getcmdline = function()
        return "q"
    end

    local quit = enter_map.callback()

    vim.fn.getcmdline = original_getcmdline

    assert(write_and_quit:find('require%("sidepanes%.internal"%)%.write_question', 1, false), write_and_quit)
    assert(write_and_quit:find('require%("sidepanes%.internal"%)%.finish_question', 1, false), write_and_quit)
    assert(quit:find('require%("sidepanes%.internal"%)%.finish_question', 1, false), quit)
    assert(not write_and_quit:find('require%("sidepanes"%)%.write_question', 1, false), write_and_quit)
    assert(not quit:find('require%("sidepanes"%)%.finish_question', 1, false), quit)

    pane.finish_question(qbuf)
end)

test("question write without quit does not send", function()
    reset_pane()

    local root = root_fixture("question-write-only-test")
    local out = helpers.tmp_path("sidepanes-question-write-only.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")
    pane.ask("codex", nil, { bufnr = vim.api.nvim_get_current_buf() })

    local qbuf = only_question_buf()

    set_question(qbuf, { "Question:", "draft but do not send" })
    pane.write_question(qbuf)
    vim.wait(150, function()
        return false
    end, 20)

    assert(read_file(out) == "", "write-only question sent to terminal")
    assert(pane.question_buffers[qbuf] ~= nil, "write-only question closed the editor")

    pane.finish_question(qbuf)
    wait_for_file(out, "draft but do not send")
end)

test("asking with a new preset reuses the same agent session and sends a model switch", function()
    reset_pane()

    local root = root_fixture("model-switch-test")
    local out = helpers.tmp_path("sidepanes-model-switch.txt")

    pcall(vim.fn.delete, out)
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                send_delay_ms = 0,
                switch_command = "SWITCH {name}",
                presets = {
                    { name = "one", label = "One", args = {} },
                    { name = "two", label = "Two", args = {} },
                },
            },
        },
    })

    local ctx = pane.open_terminal("codex", "one", { root = root, focus = false })
    local original_buf = ctx.bufnr
    local original_job = ctx.job_id

    vim.cmd.edit(root .. "/src/origin.py")
    pane.ask("codex", "two", { bufnr = vim.api.nvim_get_current_buf() })

    local qbuf = only_question_buf()

    set_question(qbuf, { "Question:", "reuse this session" })
    pane.write_question(qbuf)
    pane.finish_question(qbuf)

    wait_for_file(out, "SWITCH two")
    wait_for_file(out, "reuse this session")

    local updated = pane.terminals[ctx.key]

    assert(updated.bufnr == original_buf, "Codex buffer was replaced")
    assert(updated.job_id == original_job, "Codex job was replaced")
    assert(updated.preset_name == "two", "Codex preset was not updated")

    local current = {}

    for _, entry in ipairs(entries.terminal_entries(pane, root, 1, { ask_only = true })) do
        if entry.tool_name == "codex" and entry.current then
            table.insert(current, entry)
        end
    end

    assert(#current == 1, "model picker marked multiple Codex presets current")
    assert(current[1].preset_name == "two", "model picker current preset did not follow switch")
end)

test("smart gf from sidepanes opens in last non-pane window", function()
    reset_pane()

    local root = root_fixture("smart-gf-markdown-test")
    write(root .. "/docs/doc.md", { "# Doc", "", "See ir.py" })
    write(root .. "/src/ir.py", { "print('target')" })
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({ focus_on_switch = true })
    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()

    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()
    assert(vim.api.nvim_get_current_win() == pane.winid, "pane did not focus")

    vim.api.nvim_win_set_cursor(pane.winid, { 3, 5 })
    require("sidepanes.smart_gf").open()

    assert(vim.api.nvim_get_current_win() == origin_win, "gf did not return to origin window")
    assert(vim.api.nvim_buf_get_name(0) == root .. "/src/ir.py", "gf opened wrong buffer")
    assert(vim.api.nvim_win_get_buf(pane.winid) == pane.bufnr, "pane buffer was replaced")
end)

test("open without path uses current markdown buffer", function()
    reset_pane()

    local root = root_fixture("viewer-default-current-test")
    local doc = root .. "/docs/current.md"

    write(doc, { "# Current", "", "body" })
    vim.cmd.edit(doc)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = 0 })

    local origin_win = vim.api.nvim_get_current_win()

    pane.open()

    assert(pane.source == doc, "pane did not use current markdown file")
    assert(vim.api.nvim_get_current_win() == origin_win, "open stole focus")
    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Current", "pane loaded wrong markdown")
end)

test("unreadable markdown path does not mutate viewer state", function()
    reset_pane()

    local root = root_fixture("viewer-unreadable-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Original", "", "keep me" })
    pane.setup({ auto_reflow = false })
    pane.open(doc)

    local source = pane.source
    local lines = vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false)

    pane.open(root .. "/docs/missing.md")

    assert(pane.source == source, "missing file changed pane source")
    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false), lines), "missing file changed pane buffer")
end)

test("opening a different markdown file resets cursor to top", function()
    reset_pane()

    local root = root_fixture("viewer-different-file-test")
    local first = root .. "/docs/first.md"
    local second = root .. "/docs/second.md"
    local first_lines = {}
    local second_lines = {}

    for index = 1, 40 do
        table.insert(first_lines, "First " .. index)
        table.insert(second_lines, "Second " .. index)
    end

    write(first, first_lines)
    write(second, second_lines)
    pane.setup({ auto_reflow = false })
    pane.open(first)
    pane.focus_toggle()
    vim.api.nvim_win_set_cursor(pane.winid, { 30, 0 })
    pane.open(second)

    assert(pane.source == second, "second file did not become source")
    assert(vim.api.nvim_win_get_cursor(pane.winid)[1] == 1, "different file did not reset cursor")
    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "Second 1", "second file did not load")
end)

test("markdown auto reload detects filesystem changes and restores approximate cursor", function()
    reset_pane()

    local root = root_fixture("viewer-auto-reload-test")
    local doc = root .. "/docs/doc.md"
    local original = {}

    for index = 1, 60 do
        original[index] = "Line " .. index
    end

    original[30] = "Anchor detail version one"
    write(doc, original)
    pane.setup({
        auto_reflow = false,
        markdown = {
            auto_reload = true,
            reload_badge = {
                min_display_ms = 100,
            },
        },
    })
    pane.open(doc)
    pane.focus_toggle()
    vim.api.nvim_win_set_cursor(pane.winid, { 30, 0 })
    assert(pane.markdown_watcher_path == doc, "auto reload did not track the source path")
    assert(pane.markdown_reload_timer ~= nil, "auto reload did not start polling timer")

    local changed = {
        "# Inserted",
        "",
        "new intro",
        "",
        "another new line",
    }

    for index, line in ipairs(original) do
        changed[#changed + 1] = index == 30 and "Anchor detail version two" or line
    end

    write(doc, changed)
    local reloaded = vim.wait(1500, function()
        return vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Inserted"
    end, 20)

    assert(reloaded, "auto reload did not refresh buffer contents")

    local cursor = vim.api.nvim_win_get_cursor(pane.winid)
    local current_line = vim.api.nvim_buf_get_lines(pane.bufnr, cursor[1] - 1, cursor[1], false)[1]
    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(current_line == "Anchor detail version two", "auto reload did not restore fuzzy cursor line: " .. tostring(current_line))
    assert(winbar:find("%#SidepanesReloaded# [RELOADED] ", 1, true), winbar)
    assert(pane.markdown_reloaded == true, "reload badge state was not set")

    assert(vim.wait(500, function()
        return pane.markdown_reload_badge_armed == true
    end, 10), "reload badge was not armed for interaction clearing")

    local other_buf = vim.api.nvim_create_buf(false, true)
    local other_win = vim.api.nvim_get_current_win()

    vim.cmd("botright new")
    other_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(other_win, other_buf)
    vim.cmd("doautocmd CursorMoved")
    assert(pane.markdown_reloaded == true, "non-markdown interaction cleared reload badge")

    vim.api.nvim_set_current_win(pane.winid)
    vim.cmd("doautocmd CursorMoved")
    assert(pane.markdown_reloaded == true, "synthetic markdown cursor event cleared reload badge")

    vim.api.nvim_feedkeys("j", "xt", false)
    assert(vim.wait(500, function()
        return pane.markdown_reloaded == false
    end, 10), "markdown key interaction did not clear reload badge")
    assert(not vim.api.nvim_get_option_value("winbar", { win = pane.winid }):find("[RELOADED]", 1, true), "cleared reload badge stayed in winbar")

    if vim.api.nvim_win_is_valid(other_win) then
        vim.api.nvim_win_close(other_win, true)
    end
end)

test("markdown auto reload detects external atomic file replacement and updates winbar", function()
    reset_pane()

    local root = root_fixture("viewer-auto-reload-external-test")
    local doc = root .. "/docs/doc.md"

    write(doc, {
        "# Original",
        "",
        "before external save",
    })
    pane.setup({
        auto_reflow = false,
        markdown = {
            auto_reload = true,
        },
    })
    pane.open(doc)
    pane.focus_toggle()

    local tmp = doc .. ".tmp"
    local job = vim.fn.jobstart({
        "sh",
        "-c",
        "sleep 0.1; printf '%s\n%s\n%s\n' '# External' '' 'after external save' > " .. vim.fn.shellescape(tmp) .. "; mv " .. vim.fn.shellescape(tmp) .. " " .. vim.fn.shellescape(doc),
    })

    assert(job > 0, "external writer job did not start")

    local reloaded = vim.wait(2000, function()
        return vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# External"
    end, 20)

    assert(reloaded, "external atomic save did not reload markdown pane")

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 2, 3, false)[1] == "after external save", "external save body did not reload")
    assert(winbar:find("%#SidepanesReloaded# [RELOADED] ", 1, true), winbar)
end)

test("markdown reload badge ignores interaction until minimum display delay", function()
    reset_pane()

    local root = root_fixture("viewer-reload-badge-delay-test")
    local doc = root .. "/docs/doc.md"

    write(doc, {
        "# Original",
        "",
        "old body",
        "extra line",
    })
    pane.setup({
        auto_reflow = false,
        markdown = {
            auto_reload = true,
            reload_badge = {
                min_display_ms = 250,
            },
        },
    })
    pane.open(doc)
    pane.focus_toggle()

    write(doc, {
        "# Changed",
        "",
        "new body",
        "extra line",
    })
    vim.cmd("doautocmd CursorHold")

    assert(pane.markdown_reloaded == true, "reload badge state was not set")
    assert(pane.markdown_reload_badge_armed == false, "reload badge armed before minimum display delay")

    vim.api.nvim_feedkeys("j", "xt", false)
    assert(vim.wait(100, function()
        return pane.markdown_reloaded == false
    end, 10) == false, "interaction cleared reload badge before minimum display delay")

    assert(vim.wait(500, function()
        return pane.markdown_reload_badge_armed == true
    end, 10), "reload badge did not arm after minimum display delay")

    vim.api.nvim_feedkeys("j", "xt", false)
    assert(vim.wait(500, function()
        return pane.markdown_reloaded == false
    end, 10), "interaction did not clear reload badge after minimum display delay")
end)

test("markdown auto reload detects same-size external content replacement", function()
    reset_pane()

    local root = root_fixture("viewer-auto-reload-same-size-test")
    local doc = root .. "/docs/doc.md"

    write(doc, {
        "# Original",
        "",
        "alpha",
    })
    pane.setup({
        auto_reflow = false,
        markdown = {
            auto_reload = true,
        },
    })
    pane.open(doc)

    local job = vim.fn.jobstart({
        "sh",
        "-c",
        "sleep 0.1; printf '%s\n%s\n%s\n' '# Original' '' 'bravo' > " .. vim.fn.shellescape(doc),
    })

    assert(job > 0, "same-size external writer job did not start")

    local reloaded = vim.wait(2000, function()
        return vim.api.nvim_buf_get_lines(pane.bufnr, 2, 3, false)[1] == "bravo"
    end, 20)

    assert(reloaded, "same-size external content replacement did not reload markdown pane")
    assert(vim.api.nvim_get_option_value("winbar", { win = pane.winid }):find("%#SidepanesReloaded# [RELOADED] ", 1, true), "same-size reload did not update winbar")
end)

test("disabled markdown auto reload leaves pane buffer unchanged", function()
    reset_pane()

    local root = root_fixture("viewer-auto-reload-disabled-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Original", "", "old body" })
    pane.setup({
        auto_reflow = false,
        markdown = {
            auto_reload = false,
        },
    })
    pane.open(doc)
    assert(pane.markdown_watcher_path == nil, "disabled auto reload tracked a source path")
    assert(pane.markdown_reload_timer == nil, "disabled auto reload started polling timer")
    write(doc, { "# Changed", "", "new body" })
    pane.markdown_file_signature = "stale-signature"
    vim.cmd("doautocmd CursorHold")

    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Original", "disabled auto reload changed buffer")
    assert(pane.markdown_reloaded == false, "disabled auto reload set reload badge")
end)

test("show markdown from terminal restores markdown cursor view", function()
    reset_pane()

    local root = root_fixture("viewer-show-markdown-test")
    local doc = root .. "/docs/doc.md"
    local lines = {}

    for index = 1, 70 do
        table.insert(lines, "Line " .. index)
    end

    write(doc, lines)
    pane.setup({
        auto_reflow = false,
        focus_on_switch = true,
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(doc)
    pane.focus_toggle()
    vim.api.nvim_win_set_cursor(pane.winid, { 45, 0 })
    vim.api.nvim_win_call(pane.winid, function()
        vim.cmd("normal! zt")
    end)

    pane.open_terminal("codex", nil, { root = root, focus = true })
    pane.show_markdown()

    assert(pane.active_mode == "markdown", "show_markdown did not activate markdown")
    assert(vim.api.nvim_win_get_buf(pane.winid) == pane.bufnr, "show_markdown did not restore markdown buffer")
    assert(vim.api.nvim_win_get_cursor(pane.winid)[1] == 45, "show_markdown did not restore cursor")
end)

test("show markdown from terminal reloads changed markdown source", function()
    reset_pane()

    local root = root_fixture("viewer-show-markdown-reload-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Original", "", "old body" })
    pane.setup({
        auto_reflow = false,
        focus_on_switch = true,
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(doc)
    pane.open_terminal("codex", nil, { root = root, focus = true })
    write(doc, { "# Changed", "", "Reloaded from Codex" })
    pane.show_markdown()

    assert(pane.active_mode == "markdown", "show_markdown did not activate markdown")
    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Changed", "show_markdown did not reload changed markdown source")
    assert(vim.api.nvim_get_option_value("winbar", { win = pane.winid }):find("%#SidepanesReloaded# [RELOADED] ", 1, true), "show_markdown reload did not update winbar")
end)

test("show markdown from codex keeps previously reloaded badge visible", function()
    reset_pane()

    local root = root_fixture("viewer-show-markdown-hidden-reload-badge-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Original", "", "old body" })
    pane.setup({
        auto_reflow = false,
        focus_on_switch = true,
        markdown = {
            auto_reload = true,
            reload_badge = {
                min_display_ms = 250,
            },
        },
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(doc)
    pane.open_terminal("codex", nil, { root = root, focus = true })
    write(doc, { "# Changed", "", "Reloaded while Codex was visible" })
    vim.cmd("doautocmd CursorHold")

    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Changed", "hidden markdown reload did not update buffer")
    assert(pane.markdown_reloaded == true, "hidden markdown reload did not set badge state")
    assert(vim.wait(500, function()
        return pane.markdown_reload_badge_armed == true
    end, 10), "hidden markdown reload badge did not arm before switching back")

    pane.show_markdown()

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(pane.active_mode == "markdown", "show_markdown did not activate markdown")
    assert(winbar:find("%#SidepanesReloaded# [RELOADED] ", 1, true), winbar)
    assert(pane.markdown_reload_badge_armed == false, "show_markdown did not restart visible reload badge delay")

    assert(vim.wait(500, function()
        return pane.markdown_reload_badge_armed == true
    end, 10), "visible reload badge did not arm after switching back")
    assert(pane.markdown_reloaded == true, "switch-back reload badge did not remain visible through minimum display delay")
end)

test("toggle closes pane and reopens last markdown source", function()
    reset_pane()

    local root = root_fixture("viewer-toggle-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Toggle", "", "body" })
    pane.open(doc)

    local source = pane.source

    assert(pane.is_open(), "pane was not opened")
    pane.toggle()
    assert(not pane.is_open(), "toggle did not close open pane")
    pane.toggle()
    assert(pane.is_open(), "toggle did not reopen pane")
    assert(pane.source == source, "toggle did not reopen last source")
end)

test("focus toggle moves between normal window and pane", function()
    reset_pane()

    local root = root_fixture("focus-toggle-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({})
    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()

    pane.open(root .. "/docs/doc.md")
    assert(vim.api.nvim_get_current_win() == origin_win, "open stole focus")

    pane.focus_toggle()
    assert(vim.api.nvim_get_current_win() == pane.winid, "focus_toggle did not focus pane")

    pane.focus_toggle()
    assert(vim.api.nvim_get_current_win() == origin_win, "focus_toggle did not return to origin window")
end)

test("focus toggle reloads changed markdown pane on return", function()
    reset_pane()

    local root = root_fixture("focus-toggle-reload-test")
    local doc = root .. "/docs/doc.md"

    write(doc, { "# Original", "", "old body" })
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({ auto_reflow = false })
    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()

    pane.open(doc)
    pane.focus_toggle()
    assert(vim.api.nvim_get_current_win() == pane.winid, "focus_toggle did not focus pane")
    pane.focus_toggle()
    assert(vim.api.nvim_get_current_win() == origin_win, "focus_toggle did not return to origin window")

    write(doc, { "# Changed", "", "new body" })
    pane.focus_toggle()

    assert(vim.api.nvim_get_current_win() == pane.winid, "focus_toggle did not return to pane")
    assert(vim.api.nvim_buf_get_lines(pane.bufnr, 0, 1, false)[1] == "# Changed", "focus_toggle did not reload changed markdown source")
    assert(vim.api.nvim_get_option_value("winbar", { win = pane.winid }):find("%#SidepanesReloaded# [RELOADED] ", 1, true), "focus_toggle reload did not update winbar")
end)

test("closing and reopening sidepanes restores cursor view", function()
    reset_pane()

    local root = root_fixture("close-reopen-view-test")
    local doc = {}

    for index = 1, 80 do
        table.insert(doc, "Line " .. index)
    end

    write(root .. "/docs/doc.md", doc)
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({ auto_reflow = false })
    vim.cmd.edit(root .. "/src/origin.py")
    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()

    vim.api.nvim_win_set_cursor(pane.winid, { 40, 0 })
    vim.api.nvim_win_call(pane.winid, function()
        vim.cmd("normal! zt")
    end)

    pane.close()
    assert(not pane.is_open(), "pane did not close")

    pane.open(root .. "/docs/doc.md")
    assert(vim.api.nvim_win_get_cursor(pane.winid)[1] == 40, "markdown cursor view was not restored")
end)

test("closing pane preserves running terminal session", function()
    reset_pane()

    local root = root_fixture("close-terminal-preserve-test")

    write(root .. "/docs/doc.md", { "# Doc" })

    pane.setup({
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")

    local ctx = pane.open_terminal("codex", nil, { root = root, focus = true })
    local bufnr = ctx.bufnr
    local job_id = ctx.job_id

    pane.close()
    assert(not pane.is_open(), "pane did not close")
    assert(vim.api.nvim_buf_is_valid(bufnr), "terminal buffer was deleted on close")

    local reopened = pane.open_terminal("codex", nil, { root = root, focus = true })

    assert(reopened.bufnr == bufnr, "terminal buffer was not reused")
    assert(reopened.job_id == job_id, "terminal job was not reused")
end)

test("markdown and terminal pane window options are mode-specific", function()
    reset_pane()

    local root = root_fixture("window-options-test")

    write(root .. "/docs/doc.md", { "# Doc" })

    pane.setup({
        wrap = true,
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open(root .. "/docs/doc.md")

    assert(vim.api.nvim_get_option_value("number", { win = pane.winid }) == true, "sidepanes number option was off")
    assert(vim.api.nvim_get_option_value("wrap", { win = pane.winid }) == true, "sidepanes wrap option was off")
    assert(vim.api.nvim_get_option_value("conceallevel", { win = pane.winid }) == 3, "sidepanes conceallevel was wrong")

    pane.open_terminal("codex", nil, { root = root, focus = true })

    assert(vim.api.nvim_get_option_value("number", { win = pane.winid }) == false, "terminal pane number option was on")
    assert(vim.api.nvim_get_option_value("wrap", { win = pane.winid }) == false, "terminal pane wrap option was on")
    assert(vim.api.nvim_get_option_value("conceallevel", { win = pane.winid }) == 0, "terminal pane conceallevel was wrong")
end)

test("zoom focuses pane and caps markdown text width", function()
    reset_pane()

    local root = root_fixture("zoom-focus-test")

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "This is a paragraph that exists so zoom reflow has content to work with in the pane.",
    })
    write(root .. "/src/origin.py", { "print('origin')" })

    pane.setup({
        width = 40,
        zoom_text_width = 90,
        reflow_margin = 8,
    })

    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()

    pane.open(root .. "/docs/doc.md")
    assert(vim.api.nvim_get_current_win() == origin_win, "pane open stole focus before zoom")

    pane.toggle_zoom()

    assert(vim.api.nvim_get_current_win() == pane.winid, "zoom did not focus pane")
    assert(pane.text_width() <= 90, "zoom text width exceeded cap")
end)

test("public width api resizes pane and reflows only markdown", function()
    reset_pane()

    local root = root_fixture("pane-width-api-test")

    with_options({ columns = 140, winminwidth = 1 }, function()
        write(root .. "/docs/doc.md", {
            "# Doc",
            "",
            "This paragraph should fit as a single line when the pane starts wide but should wrap into multiple shorter lines after the public width API narrows the pane.",
        })

        pane.setup({
            width = 100,
            reflow_margin = 4,
            auto_reflow = true,
            external_reflow_cmd = false,
            tools = {
                ipython = {
                    label = "IPython",
                    ask = false,
                    cmd = { "sh", "-c", "sleep 10" },
                    presets = { { name = "default", label = "Default", args = {} } },
                },
            },
        })
        pane.open(root .. "/docs/doc.md")

        local initial_line_count = vim.api.nvim_buf_line_count(pane.bufnr)
        local width = sidepanes.set_width("50%")

        assert(width == 70, "percentage width did not resolve against screen columns")
        assert(sidepanes.get_width() == 70, "get_width did not return configured width")
        assert(vim.api.nvim_win_get_width(pane.winid) == 70, "set_width did not resize open pane")

        sidepanes.adjust_width("-30")

        assert(sidepanes.get_width() == 40, "adjust_width did not update configured width")
        assert(vim.api.nvim_win_get_width(pane.winid) == 40, "adjust_width did not resize open pane")
        assert(vim.api.nvim_buf_line_count(pane.bufnr) > initial_line_count, "narrowing Sidepanes viewer did not reflow")

        local markdown_lines_after_reflow = vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false)

        pane.open_terminal("ipython", nil, { root = root, focus = true })
        sidepanes.set_width("1/2")

        assert(pane.active_mode == "ipython", "width change left terminal mode")
        assert(vim.api.nvim_win_get_width(pane.winid) == 70, "fraction width did not resize terminal pane")
        assert(vim.deep_equal(vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false), markdown_lines_after_reflow), "terminal width change reflowed markdown buffer")
    end)
end)

test("sticky relative width tracks Neovim columns after relative widths", function()
    reset_pane()

    local root = root_fixture("sticky-relative-width-test")

    with_options({ columns = 140, winminwidth = 1 }, function()
        write(root .. "/docs/doc.md", {
            "# Doc",
            "",
            "This paragraph is present so sticky relative width can reflow markdown after the total editor width changes.",
        })

        pane.setup({
            width = 80,
            sticky_relative_width = true,
            reflow_margin = 4,
            auto_reflow = true,
            external_reflow_cmd = false,
        })
        pane.open(root .. "/docs/doc.md")

        sidepanes.set_width("50%")

        assert(sidepanes.get_width() == 70, "sticky percentage width did not resolve initially")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "sticky percentage did not store relative width")

        vim.o.columns = 180
        pane.refresh_width()

        assert(sidepanes.get_width() == 90, "sticky percentage width did not track resized columns")
        assert(vim.api.nvim_win_get_width(pane.winid) == 90, "sticky percentage did not resize open pane")

        sidepanes.set_width(100)

        assert(pane.relative_width == nil, "absolute width did not clear sticky relative width")

        vim.o.columns = 200
        pane.refresh_width()

        assert(sidepanes.get_width() == 100, "absolute width changed after resize despite cleared sticky relative width")

        sidepanes.set_width("1/2")
        vim.o.columns = 160
        vim.api.nvim_exec_autocmds("VimResized", {})

        assert(sidepanes.get_width() == 80, "VimResized did not refresh sticky relative width")
    end)
end)

test("sticky relative width toggle captures and releases current width ratio", function()
    reset_pane()

    with_options({ columns = 200, winminwidth = 1 }, function()
        pane.setup({
            width = 100,
            sticky_relative_width = false,
        })

        capture_notify(function()
            sidepanes.toggle_sticky_relative_width()
        end)

        assert(pane.config.sticky_relative_width == true, "sticky relative width config did not enable")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "sticky toggle did not capture current width ratio")

        vim.o.columns = 160
        pane.refresh_width()

        assert(sidepanes.get_width() == 80, "sticky toggle did not keep current width ratio after resize")

        capture_notify(function()
            sidepanes.toggle_sticky_relative_width()
        end)

        assert(pane.config.sticky_relative_width == false, "sticky relative width config did not disable")
        assert(pane.relative_width == nil, "sticky relative width toggle did not clear relative target")

        vim.o.columns = 220
        pane.refresh_width()

        assert(sidepanes.get_width() == 80, "disabled sticky relative width still changed after resize")
    end)
end)

test("width snap api moves to configured boundaries and cooperates with sticky relative width", function()
    reset_pane()

    with_options({ columns = 200, winminwidth = 1 }, function()
        pane.setup({
            width = 95,
            sticky_relative_width = true,
            width_snap_points = { 80, 100, "1/2", "2/3" },
        })

        local snap_messages = capture_notify(function()
            sidepanes.snap_width("next")
        end)

        assert(sidepanes.get_width() == 100, "next snap did not move to the next boundary")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "snap did not preserve relative duplicate while sticky")
        assert(has_notify(snap_messages, "Sidepanes width: 1/2 (100 cols); previous 80 (80 cols); next 2/3"), "snap message did not include landed and neighboring boundaries")

        vim.o.columns = 160
        pane.refresh_width()

        assert(sidepanes.get_width() == 80, "sticky snap did not track resized columns")

        capture_notify(function()
            sidepanes.snap_width("previous")
        end)

        assert(sidepanes.get_width() == 80, "no-op previous snap changed the smallest boundary")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "no-op snap cleared sticky relative target")

        capture_notify(function()
            sidepanes.snap_width("next")
        end)

        assert(sidepanes.get_width() == 100, "next snap did not move to the absolute boundary")
        assert(pane.relative_width == nil, "absolute snap did not clear relative target")

        capture_notify(function()
            sidepanes.snap_width("previous")
        end)

        assert(sidepanes.get_width() == 80, "previous snap did not return to the prior boundary")
    end)
end)

test("width picker selects common configured width points", function()
    reset_pane()

    with_options({ columns = 200, winminwidth = 1 }, function()
        pane.setup({
            width = 80,
            sticky_relative_width = true,
            width_snap_points = { 80, 100, 120 },
            width_picker_points = { "1/4", "1/2", 120 },
        })

        pane._test_next_choice = "2"

        local messages = capture_notify(function()
            sidepanes.width_picker()
        end)

        assert(sidepanes.get_width() == 100, "width picker did not apply selected common point")
        assert(pane.relative_width and pane.relative_width.ratio == 0.5, "width picker did not preserve relative target when sticky")
        assert(has_notify(messages, "Sidepanes width: 1/2 (100 cols); previous 80 (80 cols); next 120"), "width picker did not notify selected and neighboring points")
    end)
end)

test("width picker falls back to snap points when picker points are not configured", function()
    reset_pane()

    with_options({ columns = 200, winminwidth = 1 }, function()
        pane.setup({
            width = 80,
            sticky_relative_width = false,
            width_snap_points = { 80, "1/2", 120 },
            width_picker_points = nil,
        })

        pane.config.width_picker_points = nil
        pane._test_next_choice = "2"

        capture_notify(function()
            sidepanes.width_picker()
        end)

        assert(sidepanes.get_width() == 100, "width picker did not fall back to snap points")
        assert(pane.relative_width == nil, "nonsticky fallback picker stored relative width")
    end)
end)

test("relative width inputs stay absolute when sticky relative width is disabled", function()
    reset_pane()

    local root = root_fixture("nonsticky-relative-width-test")

    with_options({ columns = 140 }, function()
        write(root .. "/docs/doc.md", { "# Doc" })

        pane.setup({
            width = 80,
            sticky_relative_width = false,
        })
        pane.open(root .. "/docs/doc.md")
        sidepanes.set_width("50%")

        assert(sidepanes.get_width() == 70, "nonsticky percentage width did not resolve initially")
        assert(pane.relative_width == nil, "nonsticky percentage stored relative width")

        vim.o.columns = 180
        pane.refresh_width()

        assert(sidepanes.get_width() == 70, "nonsticky percentage width changed after resize")
    end)
end)

test("external mdfmt reflow preserves markdown tables", function()
    if vim.fn.executable("mdfmt") ~= 1 then
        return
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    local table_block = {
        "| Name | Value |",
        "| ---- | ----- |",
        "| alpha | one two three |",
        "| beta | four five six |",
    }
    local lines = {
        "# Doc",
        "",
        "This paragraph is intentionally long enough that mdfmt should wrap it when a narrow width is requested for the external reflow test.",
        "",
        table_block[1],
        table_block[2],
        table_block[3],
        table_block[4],
    }

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    markdown_reflow.reflow_buffer(bufnr, {
        width = 48,
        notify = false,
        external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
        external_reflow_protect_tables = true,
        external_reflow_fallback = false,
    })

    local output = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local found = {}

    for _, line in ipairs(output) do
        if line:find("^|") then
            table.insert(found, line)
        end
    end

    assert(vim.deep_equal(found, table_block), table.concat(output, "\n"))
end)

test("markdown reflow setup registers command and mapping", function()
    markdown_reflow.setup({
        external_reflow_cmd = false,
        commands = {
            reflow = "MarkdownReflowRegression",
        },
        mappings = {
            reflow = "<leader>ZR",
        },
    })

    local command_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_current_buf(command_buf)
    vim.api.nvim_buf_set_lines(command_buf, 0, -1, false, {
        "This paragraph is deliberately long enough to wrap when the MarkdownReflowRegression command uses a narrow width.",
    })
    vim.cmd("MarkdownReflowRegression 34")
    assert(vim.api.nvim_buf_line_count(command_buf) > 1, "MarkdownReflow command did not reflow current buffer")

    local mapping_buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_current_buf(mapping_buf)
    vim.api.nvim_set_option_value("textwidth", 34, { buf = mapping_buf })
    vim.api.nvim_buf_set_lines(mapping_buf, 0, -1, false, {
        "This paragraph is deliberately long enough to wrap when the configured Markdown reflow mapping is invoked.",
    })

    local map = global_map("<leader>ZR")

    map.callback()
    assert(vim.api.nvim_buf_line_count(mapping_buf) > 1, "MarkdownReflow mapping did not reflow current buffer")
end)

test("toggle wrap updates markdown window wrap options", function()
    reset_pane()

    local root = root_fixture("render-toggle-wrap-test")

    write(root .. "/docs/doc.md", { "# Doc", "", "body" })
    pane.setup({ wrap = false })
    pane.open(root .. "/docs/doc.md")

    assert(vim.api.nvim_get_option_value("wrap", { win = pane.winid }) == false, "wrap started enabled")

    pane.toggle_wrap()

    assert(vim.api.nvim_get_option_value("wrap", { win = pane.winid }) == true, "wrap was not enabled")
    assert(vim.api.nvim_get_option_value("linebreak", { win = pane.winid }) == true, "linebreak was not enabled")
    assert(vim.api.nvim_get_option_value("breakindent", { win = pane.winid }) == true, "breakindent was not enabled")

    pane.toggle_wrap()

    assert(vim.api.nvim_get_option_value("wrap", { win = pane.winid }) == false, "wrap was not disabled")
    assert(vim.api.nvim_get_option_value("linebreak", { win = pane.winid }) == false, "linebreak was not disabled")
    assert(vim.api.nvim_get_option_value("breakindent", { win = pane.winid }) == false, "breakindent was not disabled")
end)

test("markdown winbar shows current heading and zoom state", function()
    reset_pane()

    local root = root_fixture("winbar-markdown-test")

    write(root .. "/docs/doc.md", {
        "# Top",
        "",
        "body",
        "## Details",
        "",
        "more body",
    })
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
    })
    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()
    vim.api.nvim_win_set_cursor(pane.winid, { 4, 0 })
    vim.api.nvim_win_call(pane.winid, function()
        vim.cmd("normal! zt")
    end)

    vim.cmd("doautocmd CursorMoved")

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("Markdown: ## Details", 1, true), winbar)

    pane.toggle_zoom()

    winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("[zoom]", 1, true), winbar)
end)

test("markdown reload badge text and highlight are configurable", function()
    reset_pane()

    local root = root_fixture("winbar-reload-badge-config-test")

    write(root .. "/docs/doc.md", {
        "# Top",
        "",
        "body",
    })
    pane.setup({
        auto_reflow = false,
        sticky_heading = true,
        markdown = {
            reload_badge = {
                text = "[SYNCED]",
                hl = {
                    fg = "#111111",
                    bg = "#eeeeee",
                    bold = false,
                },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")
    pane.focus_toggle()

    pane.markdown_reloaded = true
    pane.markdown_reload_badge_armed = false
    vim.cmd("doautocmd WinResized")

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })
    local hl = vim.api.nvim_get_hl(0, { name = "SidepanesReloaded", link = false })

    assert(winbar:find("%#SidepanesReloaded# [SYNCED] ", 1, true), winbar)
    assert(hl.fg == 0x111111, "reload badge fg was not configurable")
    assert(hl.bg == 0xeeeeee, "reload badge bg was not configurable")
    assert(hl.bold ~= true, "reload badge bold was not configurable")
end)

test("terminal winbar shows tool preset and root", function()
    reset_pane()

    local root = root_fixture("winbar-terminal-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        sticky_heading = true,
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })
    pane.open(root .. "/docs/doc.md")
    pane.open_terminal("codex", nil, { root = root, focus = true })

    local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

    assert(winbar:find("Codex: Default - " .. vim.fn.fnamemodify(root, ":t"), 1, true), winbar)
end)

test("disabled sticky heading clears pane winbar", function()
    reset_pane()

    local root = root_fixture("winbar-disabled-test")

    write(root .. "/docs/doc.md", { "# Doc" })
    pane.setup({
        sticky_heading = false,
    })
    pane.open(root .. "/docs/doc.md")

    assert(vim.api.nvim_get_option_value("winbar", { win = pane.winid }) == "", "winbar was not cleared")
end)

test("pane reflow preserves readonly modifiable and modified flags", function()
    reset_pane()

    local root = root_fixture("render-buffer-state-test")

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "This paragraph is intentionally long enough that it can be considered for reflow while testing pane buffer option restoration.",
    })
    pane.setup({
        width = 46,
        auto_reflow = true,
    })
    pane.open(root .. "/docs/doc.md")

    assert(vim.api.nvim_get_option_value("readonly", { buf = pane.bufnr }) == true, "pane buffer readonly was not restored")
    assert(vim.api.nvim_get_option_value("modifiable", { buf = pane.bufnr }) == false, "pane buffer modifiable was not restored")
    assert(vim.api.nvim_get_option_value("modified", { buf = pane.bufnr }) == false, "pane buffer was left modified")
end)

test("pane external reflow command is used", function()
    reset_pane()

    local root = root_fixture("render-external-used-test")

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "original paragraph that should be replaced by the external formatter",
    })
    pane.setup({
        external_reflow_cmd = { "sh", "-c", "printf '%s\\n' '# External' '' 'external body'" },
        external_reflow_fallback = false,
    })
    pane.open(root .. "/docs/doc.md")

    local output = table.concat(vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false), "\n")

    assert(output:find("# External", 1, true), output)
    assert(output:find("external body", 1, true), output)
    assert(not output:find("original paragraph", 1, true), output)
end)

test("pane external reflow without fallback leaves loaded markdown untouched", function()
    reset_pane()

    local root = root_fixture("render-external-no-fallback-test")
    local lines = {
        "# Doc",
        "",
        "this text should survive a failed external formatter when fallback is disabled",
    }

    write(root .. "/docs/doc.md", lines)
    pane.setup({
        external_reflow_cmd = { "sh", "-c", "exit 7" },
        external_reflow_fallback = false,
    })
    pane.open(root .. "/docs/doc.md")

    assert(vim.deep_equal(vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false), lines), "failed external reflow mutated markdown")
end)

test("pane mdfmt reflow preserves markdown tables", function()
    if vim.fn.executable("mdfmt") ~= 1 then
        return
    end

    reset_pane()

    local root = root_fixture("render-pane-table-test")
    local table_block = {
        "| Name | Value |",
        "| ---- | ----- |",
        "| alpha | one two three |",
        "| beta | four five six |",
    }

    write(root .. "/docs/doc.md", {
        "# Doc",
        "",
        "This paragraph is intentionally long enough that mdfmt should wrap it when the pane opens with a narrow configured width.",
        "",
        table_block[1],
        table_block[2],
        table_block[3],
        table_block[4],
    })
    pane.setup({
        width = 48,
        external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
        external_reflow_protect_tables = true,
        external_reflow_fallback = false,
    })
    pane.open(root .. "/docs/doc.md")

    local output = vim.api.nvim_buf_get_lines(pane.bufnr, 0, -1, false)
    local found = {}

    for _, line in ipairs(output) do
        if line:find("^|") then
            table.insert(found, line)
        end
    end

    assert(vim.deep_equal(found, table_block), table.concat(output, "\n"))
end)

test("smart gf from IPython pane opens traceback file and line outside pane", function()
    reset_pane()

    local root = root_fixture("smart-gf-terminal-test")
    write(root .. "/src/target.py", { "one", "two", "three" })
    write(root .. "/src/origin.py", { "origin" })

    pane.setup({
        tools = {
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "printf 'File " .. root .. "/src/target.py:2\\n'; sleep 10" },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    vim.cmd.edit(root .. "/src/origin.py")

    local origin_win = vim.api.nvim_get_current_win()
    local ctx = pane.open_terminal("ipython", nil, { root = root, focus = true })

    vim.wait(1000, function()
        return table.concat(vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false), "\n"):find("target.py", 1, true) ~= nil
    end, 20)

    local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
    local target_line = nil

    for index, line in ipairs(lines) do
        if line:find("target.py", 1, true) then
            target_line = index
            break
        end
    end

    assert(target_line, table.concat(lines, "\n"))

    vim.api.nvim_win_set_cursor(pane.winid, { target_line, 8 })
    require("sidepanes.smart_gf").open()

    assert(vim.api.nvim_get_current_win() == origin_win, "gf did not switch to origin window")
    assert(vim.api.nvim_buf_get_name(0) == root .. "/src/target.py", "opened wrong file")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 2, "did not jump to traceback line")
    assert(vim.api.nvim_win_get_buf(pane.winid) == ctx.bufnr, "pane terminal buffer was replaced")
end)

test("shutdown sends configured exit commands", function()
    reset_pane()

    local root = root_fixture("shutdown-test")
    local out = helpers.tmp_path("sidepanes-pane-exit-commands.txt")

    pcall(vim.fn.delete, out)

    pane.setup({
        shutdown_timeout_ms = 200,
        tools = {
            codex = {
                label = "Codex",
                cmd = { "sh", "-c", "tee -a " .. out },
                include_cd_arg = false,
                presets = { { name = "default", label = "Default", args = {} } },
            },
            claude = {
                label = "Claude",
                cmd = { "sh", "-c", "tee -a " .. out },
                presets = { { name = "default", label = "Default", args = {} } },
            },
            ipython = {
                label = "IPython",
                ask = false,
                cmd = { "sh", "-c", "tee -a " .. out },
                presets = { { name = "default", label = "Default", args = {} } },
            },
        },
    })

    pane.open_terminal("codex", nil, { root = root, focus = false })
    pane.open_terminal("claude", nil, { root = root, focus = false })
    pane.open_terminal("ipython", nil, { root = root, focus = false })
    pane.shutdown_terminals({ timeout_ms = 200 })

    local sent = table.concat(vim.fn.readfile(out), "\n")

    assert(sent:find("/quit", 1, true), sent)
    assert(sent:find("/exit", 1, true), sent)
    assert(sent:find("quit()", 1, true), sent)
end)

local function selected_test(name)
    local filter = vim.env.SIDEPANES_TEST_FILTER

    if not filter or filter == "" then
        return true
    end

    for token in filter:gmatch("[^,]+") do
        token = vim.trim(token)
        if token ~= "" and name:find(token, 1, true) then
            return true
        end
    end

    return false
end

local failures = {}
local selected_count = 0

for _, item in ipairs(tests) do
    if not selected_test(item.name) then
        goto continue
    end

    selected_count = selected_count + 1

    local ok, err = xpcall(item.fn, debug.traceback)

    reset_pane()

    if not ok then
        table.insert(failures, item.name .. "\n" .. err)
    end

    ::continue::
end

if #failures > 0 then
    error(table.concat(failures, "\n\n"))
end

print("sidepanes regression tests passed: " .. selected_count)
