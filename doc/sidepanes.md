# Sidepanes Reference

Sidepanes is a Neovim pane system for keeping a Markdown reference view, Codex,
Claude, and IPython in one reusable side window.

It grew from a Markdown pane, so the Markdown viewer remains the anchor. The
companion panes are terminal sessions owned by Sidepanes. Codex, Claude, and
IPython each get one session per tool, not one session per model or preset.

## Quick Start

```lua
require("sidepanes").setup({
  commands = true,
  mappings = {
    global = {
      toggle = "<leader>pp",
      markdown = "<leader>p0",
      codex = "<leader>px",
      claude = "<leader>pc",
      ipython = "<leader>pi",
      focus = "<leader>pf",
      zoom = "<leader>pz",
      width_previous = "<leader>p-",
      width_next = "<leader>p+",
      width_picker = "<leader>pw",
      sticky_relative_width = "<leader>p%",
      send_ipython = "<leader>pl",
      ask_pane = "<leader>pa",
      ask = "<leader>pa",
    },
  },
})
```

Use `:Sidepanes` to open the pane switcher. Use `:help sidepanes` for the
short Neovim help page.

## Command Surface

`commands = true` registers Sidepanes-prefixed commands. Command names can also
be configured individually with `commands = { ... }`.

### Root Command

`:Sidepanes` with no arguments opens the pane switcher.

| Command | Behavior |
| --- | --- |
| `:Sidepanes help` | Open `:help sidepanes`, falling back to a subcommand summary if helptags are missing. |
| `:Sidepanes switch` | Open the pane switcher. |
| `:Sidepanes toggle [file]` | Toggle the pane, optionally opening a Markdown file. |
| `:Sidepanes open {file}` | Open a Markdown file in the pane. |
| `:Sidepanes markdown` | Switch to the Markdown viewer. |
| `:Sidepanes pick` | Pick a Markdown document. |
| `:Sidepanes headings` | Pick a Markdown heading. |
| `:Sidepanes codex [preset]` | Open or focus Codex, optionally with a preset. |
| `:Sidepanes claude [preset]` | Open or focus Claude, optionally with a preset. |
| `:Sidepanes tool {tool} [preset]` | Open a configured tool by name. |
| `:Sidepanes ipython` | Open or focus IPython. |
| `:Sidepanes ipython-restart` | Restart IPython. |
| `:Sidepanes ipython-clear` | Clear IPython. |
| `:Sidepanes focus` | Toggle focus between the pane and previous non-pane window. |
| `:Sidepanes zoom` | Toggle pane zoom. |
| `:Sidepanes width [value]` | Report or change pane width. |
| `:Sidepanes width next` | Snap width up. |
| `:Sidepanes width previous` | Snap width down. |
| `:Sidepanes width prev` | Alias for `previous`. |
| `:Sidepanes width +` | Alias for `next`. |
| `:Sidepanes width -` | Alias for `previous`. |
| `:Sidepanes width pick` | Open the width picker. |
| `:Sidepanes width-pick` | Open the width picker. |
| `:Sidepanes ask` | Ask via the target picker. |
| `:Sidepanes ask-append` | Append the current range to the ask pane prompt. |
| `:Sidepanes ask-status` | Report active ask-pane debug status. |
| `:Sidepanes submit-question` | Submit the active ask pane prompt. |
| `:Sidepanes ask-codex [preset]` | Ask Codex directly. |
| `:Sidepanes ask-claude [preset]` | Ask Claude directly. |
| `:Sidepanes version` | Report Sidepanes version and load path. |
| `:Sidepanes mappings` | Open mapping help for the current pane. |

### Standalone Commands

| Command | Behavior |
| --- | --- |
| `:SidepanesToggle [file]` | Toggle the pane. |
| `:SidepanesPick` | Pick a Markdown document. |
| `:SidepanesHeadings` | Pick a Markdown heading. |
| `:SidepanesSwitch` | Open the pane switcher. |
| `:SidepanesTool {tool} [preset]` | Open a configured terminal tool. |
| `:SidepanesCodex [preset]` | Open or focus Codex. |
| `:SidepanesClaude [preset]` | Open or focus Claude. |
| `:SidepanesIPython` | Open or focus IPython. |
| `:SidepanesIPythonRestart` | Restart IPython. |
| `:SidepanesIPythonClear` | Clear IPython. |
| `:SidepanesFocus` | Toggle pane focus. |
| `:SidepanesZoom` | Toggle pane zoom. |
| `:SidepanesWidth [value]` | Report or change pane width. |
| `:SidepanesWidthPick` | Open the width picker. |
| `:SidepanesAsk` | Ask via the target picker. |
| `:SidepanesAskAppend` | Append the current range to the ask pane prompt. |
| `:SidepanesAskStatus` | Report active ask-pane debug status. |
| `:SidepanesSubmitQuestion` | Submit the active ask pane prompt. |
| `:SidepanesAskCodex [preset]` | Ask Codex directly. |
| `:SidepanesAskClaude [preset]` | Ask Claude directly. |
| `:SidepanesVersion` | Report Sidepanes version and load path. |
| `:SidepanesMappings` | Open mapping help for the current pane. |

`SidepanesAsk*` commands are range-aware, so they work with visual selections
and explicit ranges.

`:SidepanesAskStatus` and `:Sidepanes ask-status` notify concise ask-pane
debug status: active state, draft state, target label/root, picker mode and
shown flag, citation counts, previous pane mode, and modified/written flags.

`:SidepanesVersion`, `:Sidepanes version`, and `version()` report the Sidepanes
version and plugin load path for support and debugging.

`:SidepanesMappings`, `:Sidepanes mappings`, and `mappings_help(opts)` open a
Markdown mapping help float for the current pane.

## Mapping Surface

Global mappings are optional. Pane-local mappings are installed inside
Sidepanes buffers.

### Global Mappings

| Config key | Typical lhs | Behavior |
| --- | --- | --- |
| `toggle` | `<leader>pp` | Toggle Sidepanes. |
| `pick` | `<leader>mP` | Pick a Markdown document. |
| `headings` | `<leader>mf` | Pick a Markdown heading. |
| `markdown` | `<leader>p0` | Show Markdown viewer. |
| `codex` | `<leader>px` | Show Codex pane. |
| `claude` | `<leader>pc` | Show Claude pane. |
| `ipython` | `<leader>pi` | Show IPython pane. |
| `restart_ipython` | `<leader>pR` | Restart IPython. |
| `send_ipython` | `<leader>pl` | Send current line or visual selection to IPython. |
| `clear_ipython` | `<leader>pX` | Clear IPython. |
| `focus` | `<leader>pf` | Toggle focus between pane and last non-pane window. |
| `zoom` | `<leader>pz` | Toggle zoom. |
| `width_previous` | `<leader>p-` | Snap width down. |
| `width_next` | `<leader>p+` | Snap width up. |
| `width_picker` | `<leader>pw` | Pick width. |
| `sticky_relative_width` | `<leader>p%` | Toggle sticky relative width. |
| `switch` | `<leader>ps` | Open switcher. |
| `ask_pane` | `<leader>pa` | Show or focus the ask pane in normal mode. |
| `ask` | `<leader>pa` | Ask picker from visual selection. |
| `ask_last` | `aa` | Ask last coding agent from visual selection. |
| `ask_codex` | `ax` | Ask Codex from visual selection. |
| `ask_claude` | `ac` | Ask Claude from visual selection. |

### Pane-Local Mappings

| Config key | Default lhs | Behavior |
| --- | --- | --- |
| `markdown` | `<space>0` | Show Markdown viewer. |
| `codex` | `<space>x` | Show Codex. |
| `claude` | `<space>c` | Show Claude. |
| `ipython` | `<space>i` | Show IPython. |
| `toggle_terminal` | `<leader>gg` | Toggle Markdown and last terminal, including from terminal-input mode. |
| `toggle_terminal_alt` | `<C-g>` | Faster toggle Markdown and last terminal, including from terminal-input mode. |
| `ipython_alt` | `<leader>gi` | Show IPython. |
| `headings` | `fm` | Pick a Markdown heading from the Markdown pane. |
| `gf` | `gf` | Smart go-to-file from the pane into the last non-pane window. |
| `send_ipython` | `ll` | Send visual selection to IPython. |
| `zoom` | `zz` | Toggle zoom. |
| `ask_pane` | `ap` | Show or focus the ask pane. |
| `help` | `gh` | Open the mapping help float for the current Sidepanes pane. |
| `ask_submit` | `<C-CR>` | Submit the active ask pane prompt from normal or insert mode. |
| `ask_send` | disabled | Run the ask-pane quit lifecycle: cancel unwritten drafts and send written drafts. |
| `ask_send_alt` | disabled | Alternate ask-pane quit-lifecycle shortcut. |
| `ask_next_file` | `]f` | Jump to next ask prompt `File:` block. |
| `ask_previous_file` | `[f` | Jump to previous ask prompt `File:` block. |
| `ask_next_selection` | `]s` | Jump to next ask prompt `Selection:` block. |
| `ask_previous_selection` | `[s` | Jump to previous ask prompt `Selection:` block. |
| `ask_source` | `gf` | Open the ask citation source in the last non-pane window. |
| `ask_model_picker` | `M` | Change the ask pane target/model. |
| `ask_model_picker_alt` | `<Tab>` | Change the ask pane target/model. |
| `ask_last` | `aa` | Ask last coding agent from visual selection. |
| `ask_codex` | `ax` | Ask Codex from visual selection. |
| `ask_claude` | `ac` | Ask Claude from visual selection. |

Set a mapping entry to `false` to disable it.

Press `gh` in a Sidepanes pane, run `:SidepanesMappings`, or run
`:Sidepanes mappings` to open a Markdown help float with the active mappings
for the current pane first, then global Sidepanes mappings, then relevant
commands. The winbar hint is shown as `gh help` by default. Configure it with
`help.winbar`, `help.mapping`, or `mappings.pane.help`; set the mapping to
`false` to disable both the map and hint.

## Configuration

Sidepanes accepts both the older flat runtime keys and the newer grouped setup
shape. The grouped shape is preferred because it makes intent clearer.

```lua
require("sidepanes").setup({
  layout = {
    width = 100,
    zoom_text_width = 90,
    sticky_relative_width = false,
    width_snap_points = { 60, 70, 80, 90, 100, 110, 120, "1/3", "40%", "1/2", "60%", "2/3", "75%" },
    width_picker_points = { "1/4", "1/3", "2/5", "1/2", "60%", "2/3", "75%", 100, 120 },
  },
  markdown = {
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
    wrap_toggle_key = "<leader>mw",
    sticky_heading = true,
    reflow = {
      enabled = true,
      cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
      fallback = true,
      protect_tables = true,
      margin = 8,
    },
  },
  lifecycle = {
    focus_on_switch = true,
    focus_on_pick = true,
    focus_on_ask = true,
    shutdown_on_exit = true,
    shutdown_timeout_ms = 300,
  },
  terminal = {
    auto_resume = true,
    resume = {
      enabled = true,
      infer_from_transcripts = true,
      use_claude_pid_metadata = true,
      mechanisms = {
        claude = { "hook", "pid_metadata", "transcript" },
        codex = { "terminal_output", "transcript" },
      },
      store_path = nil,
      store_lock_timeout_ms = 1000,
      store_lock_stale_ms = 10000,
      resolver = nil,
      failure_timeout_ms = 750,
      failure_action = "fresh",
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
  },
  project = {
    root_markers = { ".git" },
    fallback = "buffer_dir",
    -- Override this for wildcard, glob, monorepo, or non-file project logic.
    resolver = nil,
  },
  ask = {
    ui = "float",
    auto_append = true,
    duplicate_policy = "skip",
    model_picker = "manual",
  },
  help = {
    winbar = true,
    mapping = "gh",
    scope = "pane_first",
  },
  validation = {
    enabled = true,
  },
  commands = true,
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
      headings = "fm",
      gf = "gf",
      send_ipython = "ll",
      zoom = "zz",
      ask_pane = "ap",
      ask_submit = "<C-CR>",
      ask_send = false,
      ask_send_alt = false,
      ask_next_file = "]f",
      ask_previous_file = "[f",
      ask_next_selection = "]s",
      ask_previous_selection = "[s",
      ask_source = "gf",
      ask_model_picker = "M",
      ask_model_picker_alt = "<Tab>",
      ask_last = "aa",
      ask_codex = "ax",
      ask_claude = "ac",
    },
  },
})
```

Use this to inspect the complete grouped default shape:

```lua
vim.print(require("sidepanes.config").default_setup())
```

Grouped options normalize to runtime keys:

| Grouped option | Runtime key |
| --- | --- |
| `layout.width` | `width` |
| `layout.zoom_text_width` | `zoom_text_width` |
| `layout.sticky_relative_width` | `sticky_relative_width` |
| `layout.width_snap_points` | `width_snap_points` |
| `layout.width_picker_points` | `width_picker_points` |
| `markdown.wrap` | `wrap` |
| `markdown.auto_reload` | `auto_reload` |
| `markdown.reload_interval_ms` | `reload_interval_ms` |
| `markdown.reload_badge_ms` | `reload_badge_ms` |
| `markdown.reload_badge` | `reload_badge` |
| `markdown.wrap_toggle_key` | `wrap_toggle_key` |
| `markdown.sticky_heading` | `sticky_heading` |
| `markdown.reflow.enabled` | `auto_reflow` |
| `markdown.reflow.cmd` | `external_reflow_cmd` |
| `markdown.reflow.fallback` | `external_reflow_fallback` |
| `markdown.reflow.protect_tables` | `external_reflow_protect_tables` |
| `markdown.reflow.margin` | `reflow_margin` |
| `lifecycle.focus_on_switch` | `focus_on_switch` |
| `lifecycle.focus_on_pick` | `focus_on_pick` |
| `lifecycle.focus_on_ask` | `focus_on_ask` |
| `lifecycle.shutdown_on_exit` | `shutdown_on_exit` |
| `lifecycle.shutdown_timeout_ms` | `shutdown_timeout_ms` |
| `project.root_markers` | `project_root_markers` |
| `project.fallback` | `project_root_fallback` |
| `project.resolver` | `project_root_resolver` |
| `ask.ui` | `ask.ui` |
| `ask.auto_append` | `ask.auto_append` |
| `ask.duplicate_policy` | `ask.duplicate_policy` |
| `ask.model_picker` | `ask.model_picker` |
| `terminal.auto_resume` | `agent_auto_resume` |
| `terminal.resume.enabled` | `agent_auto_resume` |
| `terminal.resume.infer_from_transcripts` | `agent_resume_infer_from_transcripts` |
| `terminal.resume.use_claude_pid_metadata` | `agent_resume_use_claude_pid_metadata` |
| `terminal.resume.mechanisms` | `agent_resume_mechanisms` |
| `terminal.resume.store_path` | `agent_resume_store_path` |
| `terminal.resume.store_lock_timeout_ms` | `agent_resume_store_lock_timeout_ms` |
| `terminal.resume.store_lock_stale_ms` | `agent_resume_store_lock_stale_ms` |
| `terminal.resume.resolver` | `agent_resume_resolver` |
| `terminal.resume.failure_timeout_ms` | `agent_resume_failure_timeout_ms` |
| `terminal.resume.failure_action` | `agent_resume_failure_action` |
| `terminal.agent_resume_badge_ms` | `agent_resume_badge_ms` |
| `terminal.agent_resume_badge` | `agent_resume_badge` |
| `validation.enabled` | `validate` |

## Width Behavior

The pane has a normal width and a temporary zoomed width. `set_width()` changes
the normal width. `toggle_zoom()` temporarily expands the pane.

Supported width values:

| Value | Meaning |
| --- | --- |
| `100` | 100 columns. |
| `"100"` | 100 columns. |
| `"50%"` | Half of current Neovim columns. |
| `"1/2"` | Half of current Neovim columns. |
| `0.5` | Numeric ratio of current Neovim columns. |
| `"+10"` | Add 10 columns to current normal width. |
| `"-10"` | Subtract 10 columns from current normal width. |

Runtime examples:

```lua
local sidepanes = require("sidepanes")

sidepanes.set_width(100)
sidepanes.set_width("50%")
sidepanes.set_width("1/2")
sidepanes.adjust_width(10)
sidepanes.adjust_width(-10)
sidepanes.snap_width("next")
sidepanes.snap_width("previous")
sidepanes.width_picker()
sidepanes.toggle_sticky_relative_width()
```

Sidepanes' built-in numeric/letter pickers accept one-key choices without
Enter. Press `Esc`, `q`, or `<C-c>` to cancel without changing panes or width.

The Markdown document picker focuses the Sidepanes Markdown pane after a
selection by default. Configure `lifecycle.focus_on_pick = false` to keep focus
in the previous window after `pick()`, `:Sidepanes pick`, or
`:SidepanesPick`. Direct `open(path)` calls remain non-focusing.

When `layout.sticky_relative_width` is false, relative values are resolved once
to columns. When it is true, relative values keep their ratio as Neovim columns
change. Turning sticky relative width on at runtime captures the current normal
pane width as the ratio target.

Width changes reflow and rerender Markdown only when the Markdown viewer is the
active pane. Terminal panes resize without reflowing the hidden Markdown buffer.

When `markdown.auto_reload` is enabled, Sidepanes periodically compares a
content fingerprint of the active Markdown source file so same-size rewrites and
atomic saves are detected. `markdown.reload_interval_ms` controls the polling
interval. It also checks on focus, window-entry, and cursor-hold events, and
when switching back to the Markdown viewer. If the file changed on disk, the
pane reloads it, tries to return to the same or nearest matching line, and shows
a `[RELOADED]` badge in the winbar.

By default, the reload badge stays visible until key interaction inside the
Sidepanes Markdown pane after a 3000ms minimum display delay. Set
`markdown.reload_badge.min_display_ms` to change that delay, set
`markdown.reload_badge.clear_on_interaction` to false to disable interaction
clearing, or set `markdown.reload_badge_ms` to a positive millisecond value to
also hide it on a timer. When a reload happens while a terminal pane such as
Codex is visible, switching back to Markdown restarts the visible minimum
display delay so the switch gesture does not immediately clear the badge.
`markdown.reload_badge.text` changes the label.
`markdown.reload_badge.hl.fg` and `.bg` accept hex colors or Neovim highlight
group names such as `CursorFG` and `WarningMsg`; group names
resolve to their configured colors for the generated `SidepanesReloaded`
highlight group.

Recovered Codex and Claude terminals show a `[RESUMED]` badge in the winbar by
default. Set `terminal.agent_resume_badge.clear_on_interaction` to false to keep
it visible, or set `terminal.agent_resume_badge_ms` to a positive millisecond
value to hide it on a timer. `terminal.agent_resume_badge.text` changes the
label. `terminal.agent_resume_badge.hl.fg` and `.bg` accept hex colors or
Neovim highlight group names for the generated `SidepanesResumed` highlight
group.

## Tool Presets

You can write presets explicitly or generate them compactly.

```lua
tools = {
  codex = {
    models = { "gpt-5.5", "gpt-5.6-sol" },
    efforts = { "high", "medium", "xhigh" },
    speeds = { "fast", "normal" },
    default = { model = "gpt-5.5", effort = "high", speed = "fast" },
  },
}
```

That expands to `tools.codex.presets` internally. The first/default Codex
preset remains `gpt-5.5 / high / fast` with the default preset generator.

Preset tables may include:

```lua
{
  name = "gpt55_high_fast",
  label = "GPT-5.5 / high / fast",
  model = "gpt-5.5",
  effort = "high",
  speed = "fast",
  args = { "--model", "gpt-5.5" },
}
```

Running terminal sessions are tracked per tool and project root. If Codex is
already open for the current root and a new Codex preset is chosen, Sidepanes
sends the configured `switch_command` before sending the prompt. Root-scoped
agent lookups stay inside the requested project root, so a running Codex or
Claude pane from another project is not reused for the current one.

## Agent Auto-Resume

Sidepanes auto-resume is intentionally scoped and evidence-based. It never
reattaches to a lost terminal pty and it does not adopt the latest global Codex
or Claude session just because one exists. The resume key is always:

```text
tool name + detected project root
```

Project roots use Neovim's `vim.fs.root()` marker model when available. By
default, Sidepanes finds the nearest parent containing `.git`; if no marker is
found, it uses the current file's directory. Configure `project.root_markers`
with the same marker shapes Neovim accepts: strings, functions, or nested
equal-priority marker groups such as
`{ { "pyproject.toml", "package.json" }, ".git" }`. Set `project.fallback` to
`"cwd"` when markerless files should share the current working directory.

Sidepanes intentionally does not clone the older
`lspconfig.util.root_pattern()` wildcard/glob semantics. For unusual boundaries
such as `*.sln`, generated worktrees, monorepo package rules, or tool-specific
project files, provide `project.resolver = function(source, opts) return root
end`. The resolver runs before marker lookup, receives a buffer number or path
as `source` and an `opts.kind` of `"buffer"` or `"path"`, and should return the
root directory Sidepanes should use as the pane/restart/resume boundary. Return
`nil` to let Sidepanes continue with `vim.fs.root()`.

When Codex or Claude is opened, Sidepanes:

1. reuses a live Sidepanes-owned terminal job for the same tool/root when one
   still exists;
2. otherwise looks for a Sidepanes-owned remembered session id for that
   tool/root;
3. validates the remembered record against its source evidence;
4. starts a new CLI process using `codex resume <session-id>` or
   `claude --resume <session-id>`;
5. clears stale evidence and starts fresh once when a resumed CLI exits quickly
   with a non-zero status.

Built-in capture differs by agent. Claude uses a Sidepanes-injected
`SessionStart` hook by default: Sidepanes passes a temporary `--settings` file
for the pane process only, records the hook's `session_id`, `transcript_path`,
and `cwd`, and stores the matching session id in the Sidepanes registry. If hook
capture is unavailable, the default Claude mechanism list can still use
`~/.claude/sessions/<pid>.json` and, when transcript inference is enabled, a
matching project transcript.

Codex embedded-terminal capture first reads the pane terminal output for the
explicit `codex resume <session-id>` command that Codex prints on exit. Because
terminal buffers can wrap long lines, Sidepanes also scans a de-wrapped tail of
the buffer before storing that Sidepanes-observed session id as capture
evidence. If terminal-output capture is unavailable, Sidepanes can fall back to
an unambiguous `session_meta` entry that Codex writes to
`~/.codex/sessions/**` for the pane's project root. If multiple same-root
transcript candidates appear for a fresh Sidepanes context, Sidepanes does not
guess. Codex also exposes richer thread ids through the app-server/SDK surfaces,
but Sidepanes' built-in terminal integration does not switch to that separate
API surface. Users who have a stricter local Codex capture mechanism can provide
`terminal.resume.resolver`.

Remembered sessions are stored under Neovim's state directory by default. The
registry writes with an atomic rename and a lock directory, merges existing
entries before save, and recovers stale locks after
`terminal.resume.store_lock_stale_ms` so a crashed Neovim/plugin instance does
not block future saves. Reads stay lock-free because a registry reader sees
either the previous complete file or the next complete file.

Remembered sessions validate their source evidence before resume. Hook captures,
Claude PID metadata, Codex terminal-output captures, Codex/Claude transcript
paths, and custom resolver records must still match the requested tool, root,
and session id. Stale or mismatched registry entries are cleared and treated as
fresh starts.

Public tuning and extension points:

| Option | Use |
| --- | --- |
| `terminal.auto_resume` / `terminal.resume.enabled` | Turn auto-resume off entirely. |
| `terminal.resume.infer_from_transcripts` | Disable transcript inference for stricter behavior. |
| `terminal.resume.use_claude_pid_metadata` | Disable Claude PID metadata lookup. |
| `terminal.resume.mechanisms` | Enable, disable, or reorder built-in mechanism names: `"hook"`, `"pid_metadata"`, `"terminal_output"`, `"transcript"`. |
| `terminal.resume.resolver` | Provide custom session-id discovery and validation. |
| `terminal.resume.store_path` | Change or disable the persisted registry. |
| `terminal.resume.store_lock_timeout_ms` | Tune how long a registry save waits for another writer. |
| `terminal.resume.store_lock_stale_ms` | Tune crash recovery for abandoned registry locks. |
| `terminal.resume.failure_timeout_ms` | Tune the quick-failure window for stale resume ids. |
| `terminal.resume.failure_action` | Choose `"fresh"`, `"notify"`, or `"ignore"` after quick failed resume. |

Built-in mechanism names:

| Mechanism | Tool | Evidence |
| --- | --- | --- |
| `"hook"` | Claude | Pane-local `SessionStart` hook capture. |
| `"pid_metadata"` | Claude | Claude PID metadata under `~/.claude/sessions`. |
| `"terminal_output"` | Codex | The `codex resume <session-id>` command Codex prints in the pane on exit. |
| `"transcript"` | Codex/Claude | Unambiguous same-root transcript metadata. |

Custom resolvers receive `resolver(tool_name, ctx, opts)`. `ctx` is a stable
copy of the Sidepanes terminal context, with fields such as `key`, `tool_name`,
`root`, `session_id`, `pid`, `job_id`, `bufnr`, `started_at`, `resumed`, and
`resume_source`. Mutating `ctx` does not mutate Sidepanes internals. During
capture, `opts.purpose` is `"capture"` and the resolver can return a session id
string or a table such as
`{ session_id = "...", evidence = { resolver_state = ... } }`. For
resolver-sourced remembered records, Sidepanes calls the resolver again with
`opts.purpose = "validate"` and `opts.remembered` before reuse. Return the same
session id, `true`, or `{ valid = true }` to keep the record; return `false`,
`nil`, or a different id to make Sidepanes clear it and start fresh.

When a recovery candidate is launched, Claude receives
`claude --resume <session-id>` and Codex receives `codex resume <session-id>`.
Sidepanes includes the previous/new PID and session id in the notification when
available, and shows the recovered terminal badge. Sidepanes resumes CLI
sessions, not terminal ptys; when the pane-owned job is gone, recovery starts a
new CLI process with the tool's resume command. If a remembered PID still
appears alive in an unusual case, Sidepanes reports it for context but still
cannot reattach to that pty.

The current extension point is session identity discovery/validation. Resume
command construction is still built in for Codex and Claude; alternative command
rewriting for other CLIs would be a separate public API.

Default exit commands:

| Tool | Exit command |
| --- | --- |
| Codex | `/quit` |
| Claude | `/exit` |
| IPython | `quit()` |

## Ask Workflow

The ask workflow is designed to use Neovim editing rather than a tiny input box.
By default, `ask.ui = "float"` preserves the existing floating scratch prompt.
Set `ask.ui = "pane"` to use a persistent ask pane for accumulating selections
from multiple files before sending.

1. Select text.
2. Invoke an ask mapping or command.
3. Sidepanes opens a scratch prompt buffer containing the full outgoing prompt.
4. In pane mode, add more selections with visual ask mappings or
   `:SidepanesAskAppend`.
5. Edit any part of the prompt.
6. Use `M` or `<Tab>` in the ask pane to change the target model when needed.
7. Press `<C-CR>`, write and quit, write then quit, or use a configured
   `mappings.pane.ask_send` / `ask_send_alt` after writing, to send.
8. Quit without writing, or quit with `:q!`, to cancel.

In non-ask Sidepanes buffers, command-line `:q` / `:quit` returns to Markdown.
This keeps personal quit mappings that expand to `:q<CR>` from closing the pane
or triggering ask-pane send shortcuts while a terminal pane is focused.

The prompt includes file name, root, selected range, selected text, and detected
snippet language. For Markdown files, Sidepanes detects fenced code-block
language at the selected range, so Python in a Markdown fence is sent as
Python.

In pane mode, repeated selections from the same file are grouped under one
`File:` block with multiple `Selection:` citations. Exact duplicate file/range
citations are skipped by default. Visual ask mappings use the default ask target
for the first capture and reuse the active draft target while appending more
context, so picker timing is controlled only by `ask.model_picker` and manual
picker mappings. Use `]f`, `[f`, `]s`, and `[s` to move through context blocks,
and `gf` to open a citation's source file at the cited line. With
`ask.model_picker = "after_open"`, the picker appears only once for the first
captured selection in an active draft.

The ask pane winbar shows the current target/model and explicit draft state:
`ready_empty`, `draft_modified`, `draft_written`, `sending_picker`,
`sending_terminal`, `send_failed`, `cancelled`, or `sent`.

When the default `ask_submit = "<C-CR>"` is used, the ask pane also maps
`<C-J>` as a submit fallback for terminals that report Ctrl+Enter that way.
In non-ask Sidepanes buffers, personal normal-mode mappings such as
`qq -> :q<CR>` or `<leader>qq -> :q<CR>` are guarded only when their RHS is a
plain quit command, so they return the pane to Markdown instead of closing it.

Public ask functions:

```lua
require("sidepanes").ask_picker({ visual = true })
require("sidepanes").append_to_ask({ visual = true })
require("sidepanes").submit_ask_pane()
require("sidepanes").ask("codex", "gpt55_high_fast", { visual = true })
require("sidepanes").ask_current_coding_agent("claude", { visual = true })
require("sidepanes").ask_last_coding_agent({ visual = true })
```

## Switching

Use `switch_to()` for programmatic switching.

```lua
local sidepanes = require("sidepanes")

sidepanes.switch_to("markdown")
sidepanes.switch_to("codex")
sidepanes.switch_to("claude")
sidepanes.switch_to("ipython")
sidepanes.switch_to("x")
sidepanes.switch_to({ tool = "codex", preset = "gpt55_high_fast", focus = true })
```

`make_switch_entry(target, opts)` validates the same target shapes and returns
the normalized internal entry. It is useful for integration code, but normal
users should prefer `switch_to()`.

`show_last_terminal(opts)` and `toggle_markdown_terminal()` are advanced workflow
helpers. They may show Codex, Claude, IPython, or a configured custom pane
terminal. For Codex and Claude, reopening after a dead pane-owned terminal uses
Sidepanes' remembered session id when available, then reports the recovered
session and shows the resume badge.

`show_last_agent(opts)` and `toggle_markdown_agent()` remain compatibility
aliases for older callers.

## Public and Private API

Stable public functions:

```lua
setup(opts)
get_config()
open(path)
toggle(path)
close()
is_open()
focus_toggle()
toggle_zoom()
show_markdown()
get_width()
set_width(value)
adjust_width(delta)
snap_width(direction)
width_picker()
toggle_sticky_relative_width(enabled)
text_width()
toggle_wrap()
pick()
pick_headings()
switch_picker()
show_ask_pane(opts)
switch_to(target, opts)
make_switch_entry(target, opts)
open_terminal(tool_name, preset_name, opts)
show_last_terminal(opts)
toggle_markdown_terminal()
open_ipython(opts)
send_ipython(opts)
clear_ipython(opts)
restart_ipython(opts)
ask(tool_name, preset_name, opts)
ask_picker(opts)
append_to_ask(opts)
ask_status(opts)
submit_ask_pane()
version()
mappings_help(opts)
ask_last_coding_agent(opts)
ask_current_coding_agent(tool_name, opts)
shutdown_terminals(opts)
```

Private or unstable:

- `require("sidepanes")._state()`
- `require("sidepanes.internal")`
- raw switcher entries
- raw `ask_with_entry` entries

Those exist for companion modules and command-string callbacks. They are not
the user-facing contract.

## Markdown Reflow

Markdown reflow is built in as `sidepanes.markdown_reflow`. Sidepanes uses it
internally, and users can configure it directly for standalone buffer reflow.

```lua
require("sidepanes.markdown_reflow").setup({
  external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
  external_reflow_fallback = true,
  external_reflow_protect_tables = true,
  commands = true,
  mappings = {
    reflow = "<leader>mR",
  },
})
```

| Setup key | Behavior |
| --- | --- |
| `external_reflow_cmd` | External formatter command as a string, argv table, or function. `{width}` is replaced with the target width. |
| `external_reflow_fallback` | Fall back to internal paragraph reflow when the external formatter fails. |
| `external_reflow_protect_tables` | Mask Markdown tables before external formatting and restore them afterward. |
| `commands` | `true`, `false`, or `{ reflow = "CommandName" }`. |
| `mappings.reflow` | Optional normal-mode mapping for `reflow_buffer(0)`. |

When `commands = true`, the module registers:

```vim
:MarkdownReflow [width]
```

If no external formatter is configured, the internal reflow implementation is
used. If an external formatter fails and fallback is disabled, the command
reports an error and leaves the buffer unchanged.

## Dependencies and Health

Run:

```vim
:checkhealth sidepanes
```

Health checks report configured commands, mapping lhs values with their
expected modes, tool presets, external commands, optional dependencies, and
malformed config.

Sidepanes has no required Lua dependency for loading the core module. Optional
dependencies are tied to features:

| Dependency | Required for | Missing behavior | Validation | Health |
| --- | --- | --- | --- | --- |
| `telescope.nvim` | Document and heading pickers. | Picker commands notify and do not open. | Warns when related command or mapping is enabled. | Warns as optional Lua dependency. |
| Markdown Treesitter parser | Heading picker and Markdown code-fence context. | Heading picker notifies; ask context falls back where possible. | Warns when heading picker command or mapping is enabled. | Warns when parser cannot be created. |
| `markview` | Optional Markdown pane decorations. | Markdown still opens without decorations. | No warning; rendering is opportunistic. | Warns as optional Lua dependency. |
| `mdfmt` | External Markdown reflow when configured. | Falls back to internal reflow when fallback is enabled; otherwise errors. | No warning from setup validation. | Ok/warn/error depending on command availability and fallback. |
| `codex` | Codex terminal tool. | Opening Codex fails through terminal job startup. | Warns when configured executable is missing. | Errors when configured command is missing. |
| `claude` | Claude terminal tool. | Opening Claude fails through terminal job startup. | Warns when configured executable is missing. | Errors when configured command is missing. |
| `ipython` / `uv` | IPython terminal tool. | Opening IPython fails if no configured command can start. | Warns when configured executable is missing. | Errors for missing `ipython`; reports `uv` as informational fallback support. |

Pane-local `gf` is built in as `sidepanes.smart_gf`.

Markdown reflow is built in as `sidepanes.markdown_reflow`. Sidepanes itself
requires that module path so the reflow implementation has a clear boundary if
it is extracted later.

Setup validation is enabled by default and warns for malformed config or
missing dependencies implied by enabled features.

```lua
require("sidepanes").setup({
  validation = { enabled = false },
})
```

## Compatibility

Grouped setup keys are preferred for new configuration. Older flat runtime keys
remain supported by config normalization.

The pane-local mapping keys `toggle_agent` and `toggle_agent_alt` remain
supported as compatibility aliases for `toggle_terminal` and
`toggle_terminal_alt`. New configuration should use the terminal-named keys.

Documented command aliases such as `:Sidepanes width prev`,
`:Sidepanes width +`, `:Sidepanes width -`, and the matching
`:SidepanesWidth` aliases are supported conveniences. The clearest forms remain
`next`, `previous`, and explicit width values.

Older advanced helper names remain available as compatibility aliases:

```lua
require("sidepanes").show_last_agent()
require("sidepanes").toggle_markdown_agent()
```

New code should prefer `show_last_terminal()` and `toggle_markdown_terminal()`.

## Refactor and Test Standard

Before refactoring Sidepanes behavior, run:

```sh
tests/run_checks.sh full
```

That runs:

- focused regression tests
- standalone setup audit smoke
- docs-contract smoke
- `:checkhealth sidepanes` smoke
- real Codex/Claude CLI smoke

The goal is practical confidence: enough focused coverage to catch realistic
regressions in pane switching, ask flow, terminal reuse, IPython sending,
Markdown rendering, width handling, command registration, and mappings.
