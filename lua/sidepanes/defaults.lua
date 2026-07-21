--[[
sidepanes.defaults
Purpose: Define the plugin's built-in configuration.
Does: Provides pane layout defaults, reflow behavior, command/mapping toggles, lifecycle settings, and configured tool presets.
Architecture: Supplies the initial config table consumed by setup and later merged with user overrides during lifecycle setup.
]]

local M = {}

M.config = {
    width = 100,
    wrap = false,
    auto_reload = true,
    reload_interval_ms = 1000,
    reload_badge_ms = 0,
    reload_badge = {
        text = "[RELOADED]",
        clear_on_interaction = true,
        min_display_ms = 3000,
        hl = {
            fg = "CursorFG",
            bg = "WarningMsg",
            bold = true,
        },
    },
    agent_resume_badge_ms = 0,
    agent_resume_badge = {
        text = "[RESUMED]",
        clear_on_interaction = true,
        hl = {
            fg = "CursorFG",
            bg = "DiagnosticInfo",
            bold = true,
        },
    },
    agent_auto_resume = true,
    agent_resume_infer_from_transcripts = true,
    agent_resume_use_claude_pid_metadata = true,
    agent_resume_mechanisms = {
        claude = { "hook", "pid_metadata", "transcript" },
        codex = { "terminal_output", "transcript" },
    },
    agent_resume_store_path = nil,
    agent_resume_store_lock_timeout_ms = 1000,
    agent_resume_store_lock_stale_ms = 10000,
    agent_resume_resolver = nil,
    agent_resume_failure_timeout_ms = 750,
    agent_resume_failure_action = "fresh",
    project_root_markers = { ".git" },
    project_root_fallback = "buffer_dir",
    project_root_resolver = nil,
    auto_reflow = true,
    external_reflow_cmd = nil,
    external_reflow_fallback = true,
    external_reflow_protect_tables = true,
    reflow_margin = 8,
    zoom_text_width = 90,
    sticky_relative_width = false,
    width_snap_points = { 60, 70, 80, 90, 100, 110, 120, "1/3", "40%", "1/2", "60%", "2/3", "75%" },
    width_picker_points = { "1/4", "1/3", "2/5", "1/2", "60%", "2/3", "75%", 100, 120 },
    sticky_heading = true,
    wrap_toggle_key = "<leader>mw",
    focus_on_switch = true,
    focus_on_pick = true,
    focus_on_ask = true,
    shutdown_on_exit = true,
    shutdown_timeout_ms = 300,
    validate = true,
    commands = false,
    mappings = {
        global = false,
        pane = {
            markdown = "<space>0",
            codex = "<space>x",
            claude = "<space>c",
            ipython = "<space>i",
            toggle_terminal = "<leader>gg",
            toggle_terminal_alt = "<C-g>",
            ipython_alt = "<leader>gi",
            gf = "gf",
            send_ipython = "ll",
            zoom = "zz",
            ask_last = "aa",
            ask_codex = "ax",
            ask_claude = "ac",
        },
    },
    tools = {
        codex = {
            label = "Codex",
            cmd = "codex",
            include_cd_arg = true,
            send_delay_ms = 700,
            switch_command = "/model {model} {effort} {speed}",
            exit_command = "/quit\r",
            presets = {
                {
                    name = "gpt55_high_fast",
                    label = "GPT-5.5 / high / fast",
                    model = "gpt-5.5",
                    effort = "high",
                    speed = "fast",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="high"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt55_medium_fast",
                    label = "GPT-5.5 / medium / fast",
                    model = "gpt-5.5",
                    effort = "medium",
                    speed = "fast",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="medium"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt55_xhigh_fast",
                    label = "GPT-5.5 / extra high / fast",
                    model = "gpt-5.5",
                    effort = "xhigh",
                    speed = "fast",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="xhigh"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt55_high_normal",
                    label = "GPT-5.5 / high / normal",
                    model = "gpt-5.5",
                    effort = "high",
                    speed = "normal",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="high"' },
                },
                {
                    name = "gpt55_medium_normal",
                    label = "GPT-5.5 / medium / normal",
                    model = "gpt-5.5",
                    effort = "medium",
                    speed = "normal",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="medium"' },
                },
                {
                    name = "gpt55_xhigh_normal",
                    label = "GPT-5.5 / extra high / normal",
                    model = "gpt-5.5",
                    effort = "xhigh",
                    speed = "normal",
                    args = { "--model", "gpt-5.5", "-c", 'model_reasoning_effort="xhigh"' },
                },
                {
                    name = "gpt56_sol_high_fast",
                    label = "GPT-5.6 Sol / high / fast",
                    model = "gpt-5.6-sol",
                    effort = "high",
                    speed = "fast",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="high"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt56_sol_medium_fast",
                    label = "GPT-5.6 Sol / medium / fast",
                    model = "gpt-5.6-sol",
                    effort = "medium",
                    speed = "fast",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="medium"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt56_sol_xhigh_fast",
                    label = "GPT-5.6 Sol / extra high / fast",
                    model = "gpt-5.6-sol",
                    effort = "xhigh",
                    speed = "fast",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="xhigh"', "-c", 'service_tier="priority"' },
                },
                {
                    name = "gpt56_sol_high_normal",
                    label = "GPT-5.6 Sol / high / normal",
                    model = "gpt-5.6-sol",
                    effort = "high",
                    speed = "normal",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="high"' },
                },
                {
                    name = "gpt56_sol_medium_normal",
                    label = "GPT-5.6 Sol / medium / normal",
                    model = "gpt-5.6-sol",
                    effort = "medium",
                    speed = "normal",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="medium"' },
                },
                {
                    name = "gpt56_sol_xhigh_normal",
                    label = "GPT-5.6 Sol / extra high / normal",
                    model = "gpt-5.6-sol",
                    effort = "xhigh",
                    speed = "normal",
                    args = { "--model", "gpt-5.6-sol", "-c", 'model_reasoning_effort="xhigh"' },
                },
            },
        },
        claude = {
            label = "Claude",
            cmd = "claude",
            send_delay_ms = 700,
            switch_command = "/model {model} {effort}",
            exit_command = "/exit\r",
            presets = {
                {
                    name = "sonnet",
                    label = "Sonnet / normal",
                    model = "sonnet",
                    effort = "medium",
                    args = { "--model", "sonnet", "--effort", "medium" },
                },
                {
                    name = "sonnet_high",
                    label = "Sonnet / high",
                    model = "sonnet",
                    effort = "high",
                    args = { "--model", "sonnet", "--effort", "high" },
                },
                {
                    name = "opus_high",
                    label = "Opus / high",
                    model = "opus",
                    effort = "high",
                    args = { "--model", "opus", "--effort", "high" },
                },
                {
                    name = "fable_high",
                    label = "Fable / high",
                    model = "fable",
                    effort = "high",
                    args = { "--model", "fable", "--effort", "high" },
                },
                {
                    name = "default",
                    label = "Default",
                    args = {},
                },
            },
        },
        ipython = {
            label = "IPython",
            ask = false,
            --- Build the default IPython command, preferring uv-managed execution.
            cmd = function()
                if vim.fn.executable("uv") == 1 then
                    return { "uv", "run", "ipython" }
                end

                return { "ipython" }
            end,
            send_delay_ms = 500,
            exit_command = "quit()\r",
            presets = {
                {
                    name = "default",
                    label = "Default",
                    args = {},
                },
            },
        },
    },
}

return M
