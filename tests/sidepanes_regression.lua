local helpers = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
helpers.append_repo_root(1)

local defaults = require("sidepanes.defaults")
local agent_session = require("sidepanes.agent_session")
local api_helpers = require("sidepanes.api")
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
local nvim_tree_integration = require("sidepanes.integrations.nvim_tree")
local presets = require("sidepanes.presets")
local terminal_module = require("sidepanes.terminal")
local util = require("sidepanes.util")
local validation = require("sidepanes.validation")
local markdown_reflow = require("sidepanes.markdown_reflow")
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

test("public facade hides mutable state and exposes config copy", function()
    reset_pane()

    local public_functions = {
        "setup",
        "open",
        "toggle",
        "close",
        "is_open",
        "focus_toggle",
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
        "zoomed",
        "config",
        "switch",
        "ask_with_entry",
        "cancel_question",
        "finish_question",
        "write_question",
        "change_question_target",
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

    for _, name in ipairs({ "switch", "ask_with_entry", "cancel_question", "finish_question", "write_question", "change_question_target" }) do
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
        agent_sessions = {
            [key] = {
                tool_name = "codex",
                root = root,
                session_id = "live-codex-session",
                pid = vim.fn.getpid(),
            },
        },
    }
    local resume = agent_session.resolve_resume(state, nil, "codex", root)

    assert(resume and resume.session_id == "live-codex-session", "remembered session was not used")
    assert(resume.pid == vim.fn.getpid(), "remembered pid was not returned")
    assert(resume.pid_running == true, "remembered live pid was not detected")
    assert(resume.source == "remembered", "remembered resume source was not reported")
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
    }
    pane.setup({
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

test("opening Claude resumes latest project session when no live job exists", function()
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
        local wrote_args = vim.wait(1000, function()
            return vim.fn.filereadable(args_file) == 1
        end, 20)

        assert(ctx and ctx.tool_name == "claude", "Claude terminal did not open")
        assert(ctx.resumed == true, "Claude terminal did not mark resumed startup")
        assert(ctx.session_id == "resume-session", "Claude terminal did not keep resume session id")
        assert(ctx.resume_source == "latest", "Claude terminal did not record resume source")
        assert(ctx.resume_badge_visible == true, "Claude terminal did not mark resume badge visible")
        assert(has_notify(messages, "Recovered/resumed a lost Claude session: session id resume-session"), "Claude recovery notification was not emitted")
        assert(wrote_args, "fake Claude did not record argv")
        assert(read_file(args_file):find("--resume\nresume%-session", 1, false), "Claude terminal did not launch with --resume session")

        local winbar = vim.api.nvim_get_option_value("winbar", { win = pane.winid })

        assert(winbar:find("%#SidepanesResumed# [RECOVERED] ", 1, true), winbar)
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

    for _, lhs in ipairs({ " 0", " x", " c", " i", "zz" }) do
        assert(has_nowait_map(pane.bufnr, lhs), lhs .. " missing on sidepanes")
    end
    assert(has_map(pane.bufnr, "ll", "x"), "ll missing on sidepanes")

    local ctx = pane.open_terminal("ipython", nil, { root = root, focus = true })

    for _, lhs in ipairs({ " 0", " x", " c", " i", "zz" }) do
        assert(has_nowait_map(ctx.bufnr, lhs), lhs .. " missing on terminal pane")
    end
    assert(has_map(ctx.bufnr, "ll", "x"), "ll missing on terminal pane")
    assert(has_nowait_map(ctx.bufnr, "\\gg", "t"), "terminal-mode primary toggle map missing on terminal pane")
    assert(has_nowait_map(ctx.bufnr, "<C-G>", "t"), "terminal-mode toggle map missing on terminal pane")
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
                gf = "mf",
                send_ipython = "ml",
                zoom = "mz",
                ask_last = "ma",
                ask_codex = "mx",
                ask_claude = "mc",
            }
        end,
        pane_root = function()
            return map_root
        end,
        show_markdown = function()
            calls.markdown = true
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
    assert(has_map(bufnr, "mf"), "custom smart-gf pane map missing")
    assert(has_map(bufnr, "ml", "x"), "custom send-IPython pane map missing")
    assert(has_map(bufnr, "mz"), "custom zoom pane map missing")
    assert(has_map(bufnr, "ma", "x"), "custom ask-last pane map missing")
    assert(has_map(bufnr, "mx", "x"), "custom ask-Codex pane map missing")
    assert(has_map(bufnr, "mc", "x"), "custom ask-Claude pane map missing")
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
    call_map(bufnr, "ml", "x")
    assert(calls.send_ipython.bufnr == bufnr and calls.send_ipython.visual == true, "custom send-IPython pane map did not pass visual opts")
    call_map(bufnr, "mz")
    assert(calls.zoom == true, "custom zoom pane map did not call zoom")
    call_map(bufnr, "ma", "x")
    assert(calls.ask_last.bufnr == bufnr and calls.ask_last.visual == true, "custom ask-last pane map did not pass visual opts")
    call_map(bufnr, "mx", "x")
    assert(calls.ask_current.tool_name == "codex", "custom ask-Codex pane map used wrong tool")
    call_map(bufnr, "mc", "x")
    assert(calls.ask_current.tool_name == "claude", "custom ask-Claude pane map used wrong tool")
    call_map(bufnr, "mw")
    assert(calls.wrap == true, "wrap toggle key no longer worked beside pane mappings")
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
    assert(#reload_autocmds == 3, "setup duplicated reload autocmds")
    assert(#shutdown_autocmds == 1, "setup duplicated shutdown autocmds")
    assert(pane.config.width == 61, "setup lost earlier config merge")
    assert(pane.config.wrap == true, "setup did not merge later config")
    assert(pane.config.tools.codex ~= nil, "setup dropped default tools")
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
        ask = function(tool_name, preset_name, opts)
            calls.ask_tool = { tool_name = tool_name, preset_name = preset_name, opts = opts }
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
        ask_codex = "SidepanesTestAskCodex",
        ask_claude = "SidepanesTestAskClaude",
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
    vim.cmd("3,5SidepanesTestAskCodex gpt55_high_fast")
    assert(calls.ask_tool.tool_name == "codex", "ask codex command used wrong tool")
    assert(calls.ask_tool.preset_name == "gpt55_high_fast", "ask codex command did not forward preset")
    assert(calls.ask_tool.opts.line1 == 3 and calls.ask_tool.opts.line2 == 5, "ask codex command did not forward range")
    vim.cmd("6,7SidepanesTestAskClaude sonnet")
    assert(calls.ask_tool.tool_name == "claude", "ask claude command used wrong tool")
    assert(calls.ask_tool.preset_name == "sonnet", "ask claude command did not forward preset")
    assert(calls.ask_tool.opts.line1 == 6 and calls.ask_tool.opts.line2 == 7, "ask claude command did not forward range")
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
        ask = function(tool_name, preset_name, opts)
            calls.ask_tool = { tool_name = tool_name, preset_name = preset_name, opts = opts }
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
    vim.cmd("3,5SidepanesRootTest ask-codex gpt55_high_fast")
    assert(calls.ask_tool.tool_name == "codex", "root ask-codex subcommand used wrong tool")
    assert(calls.ask_tool.preset_name == "gpt55_high_fast", "root ask-codex subcommand did not forward preset")
    assert(calls.ask_tool.opts.line1 == 3 and calls.ask_tool.opts.line2 == 5, "root ask-codex subcommand did not forward range")
    vim.cmd("6,7SidepanesRootTest ask-claude sonnet")
    assert(calls.ask_tool.tool_name == "claude", "root ask-claude subcommand used wrong tool")
    assert(calls.ask_tool.preset_name == "sonnet", "root ask-claude subcommand did not forward preset")
    assert(calls.ask_tool.opts.line1 == 6 and calls.ask_tool.opts.line2 == 7, "root ask-claude subcommand did not forward range")

    local subcommands = vim.fn.getcompletion("SidepanesRootTest co", "cmdline")
    local width_subcommands = vim.fn.getcompletion("SidepanesRootTest width", "cmdline")
    local tool_names = vim.fn.getcompletion("SidepanesRootTest tool c", "cmdline")
    local codex_presets = vim.fn.getcompletion("SidepanesRootTest codex g", "cmdline")
    local claude_presets = vim.fn.getcompletion("SidepanesRootTest claude s", "cmdline")

    assert(vim.tbl_contains(subcommands, "codex"), "root completion did not include codex")
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
        ask = function() end,
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
        "SidepanesAskCodex",
        "SidepanesAskClaude",
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
            focus_on_ask = false,
            shutdown_on_exit = false,
            shutdown_timeout_ms = 123,
        },
        terminal = {
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
        validation = {
            enabled = false,
        },
    })

    assert(pane.config.layout == nil, "ergonomic layout table leaked into runtime config")
    assert(pane.config.markdown == nil, "ergonomic markdown table leaked into runtime config")
    assert(pane.config.lifecycle == nil, "ergonomic lifecycle table leaked into runtime config")
    assert(pane.config.terminal == nil, "ergonomic terminal table leaked into runtime config")
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
    assert(pane.config.reload_badge.hl.bg == "#eeeeee", "markdown.reload_badge.hl did not map")
    assert(pane.config.wrap_toggle_key == "<leader>tw", "markdown.wrap_toggle_key did not map to wrap_toggle_key")
    assert(pane.config.sticky_heading == false, "markdown.sticky_heading did not map to sticky_heading")
    assert(pane.config.auto_reflow == false, "markdown.reflow.enabled did not map to auto_reflow")
    assert(pane.config.external_reflow_cmd[1] == "mdfmt", "markdown.reflow.cmd did not map to external_reflow_cmd")
    assert(pane.config.external_reflow_fallback == false, "markdown.reflow.fallback did not map to external_reflow_fallback")
    assert(pane.config.external_reflow_protect_tables == false, "markdown.reflow.protect_tables did not map to external_reflow_protect_tables")
    assert(pane.config.reflow_margin == 12, "markdown.reflow.margin did not map to reflow_margin")
    assert(pane.config.focus_on_switch == false, "lifecycle.focus_on_switch did not map to focus_on_switch")
    assert(pane.config.focus_on_ask == false, "lifecycle.focus_on_ask did not map to focus_on_ask")
    assert(pane.config.shutdown_on_exit == false, "lifecycle.shutdown_on_exit did not map to shutdown_on_exit")
    assert(pane.config.shutdown_timeout_ms == 123, "lifecycle.shutdown_timeout_ms did not map to shutdown_timeout_ms")
    assert(pane.config.agent_resume_badge_ms == 2500, "terminal.agent_resume_badge_ms did not map")
    assert(pane.config.agent_resume_badge.text == "[RECOVERED]", "terminal.agent_resume_badge.text did not map")
    assert(pane.config.agent_resume_badge.clear_on_interaction == false, "terminal.agent_resume_badge.clear_on_interaction did not map")
    assert(pane.config.agent_resume_badge.hl.bg == "#abcdef", "terminal.agent_resume_badge.hl did not map")
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
    assert(setup.lifecycle.shutdown_on_exit == defaults.config.shutdown_on_exit, "default setup lifecycle was wrong")
    assert(setup.terminal.agent_resume_badge_ms == defaults.config.agent_resume_badge_ms, "default setup resume badge timeout was wrong")
    assert(vim.deep_equal(setup.terminal.agent_resume_badge, defaults.config.agent_resume_badge), "default setup resume badge was wrong")
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
        focus_on_ask = false,
        shutdown_on_exit = false,
        shutdown_timeout_ms = 99,
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
    assert(setup.markdown.wrap_toggle_key == "<leader>xw", "to_setup lost wrap mapping")
    assert(setup.markdown.sticky_heading == false, "to_setup lost sticky heading")
    assert(setup.markdown.reflow.enabled == false, "to_setup lost reflow enabled")
    assert(setup.markdown.reflow.cmd[1] == "mdfmt", "to_setup lost reflow command")
    assert(setup.markdown.reflow.fallback == false, "to_setup lost reflow fallback")
    assert(setup.markdown.reflow.protect_tables == false, "to_setup lost table protection")
    assert(setup.markdown.reflow.margin == 5, "to_setup lost reflow margin")
    assert(setup.lifecycle.focus_on_switch == false, "to_setup lost focus_on_switch")
    assert(setup.lifecycle.focus_on_ask == false, "to_setup lost focus_on_ask")
    assert(setup.lifecycle.shutdown_on_exit == false, "to_setup lost shutdown_on_exit")
    assert(setup.lifecycle.shutdown_timeout_ms == 99, "to_setup lost shutdown timeout")
    assert(setup.terminal.agent_resume_badge_ms == 3000, "to_setup lost resume badge timeout")
    assert(setup.terminal.agent_resume_badge.text == "[RECOVERED]", "to_setup lost resume badge")
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
            hl = "WarningMsg",
        },
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
    assert(joined:find("Sidepanes config reload_badge.hl must be a table.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge_ms must be a non-negative number.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.text must be a string.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.clear_on_interaction must be a boolean.", 1, true), joined)
    assert(joined:find("Sidepanes config agent_resume_badge.hl must be a table.", 1, true), joined)
    assert(joined:find("Sidepanes tool executable not found for broken", 1, true), joined)
    assert(joined:find("Sidepanes tool has no presets configured: broken", 1, true), joined)
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
    assert(pane_context.pane_root(pane, normal_buf) == vim.fn.fnamemodify(other, ":p"), "normal buffer root was wrong")
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

local failures = {}

for _, item in ipairs(tests) do
    local ok, err = xpcall(item.fn, debug.traceback)

    reset_pane()

    if not ok then
        table.insert(failures, item.name .. "\n" .. err)
    end
end

if #failures > 0 then
    error(table.concat(failures, "\n\n"))
end

print("sidepanes regression tests passed: " .. #tests)
