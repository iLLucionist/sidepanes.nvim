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
| `:Sidepanes ask-codex [preset]` | Ask Codex directly. |
| `:Sidepanes ask-claude [preset]` | Ask Claude directly. |

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
| `:SidepanesAskCodex [preset]` | Ask Codex directly. |
| `:SidepanesAskClaude [preset]` | Ask Claude directly. |

`SidepanesAsk*` commands are range-aware, so they work with visual selections
and explicit ranges.

## Mapping Surface

Global mappings are optional. Pane-local mappings are installed inside
Sidepanes buffers.

### Global Mappings

| Config key | Typical lhs | Behavior |
| --- | --- | --- |
| `toggle` | `<leader>pp` | Toggle Sidepanes. |
| `pick` | `<leader>mP` | Pick a Markdown document. |
| `headings` | `<leader>fm` | Pick a Markdown heading. |
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
| `toggle_terminal` | `<leader>gg` | Toggle Markdown and last terminal. |
| `toggle_terminal_alt` | `<C-g>` | Faster toggle Markdown and last terminal. |
| `ipython_alt` | `<leader>gi` | Show IPython. |
| `gf` | `gf` | Smart go-to-file from the pane into the last non-pane window. |
| `send_ipython` | `ll` | Send visual selection to IPython. |
| `zoom` | `zz` | Toggle zoom. |
| `ask_last` | `aa` | Ask last coding agent from visual selection. |
| `ask_codex` | `ax` | Ask Codex from visual selection. |
| `ask_claude` | `ac` | Ask Claude from visual selection. |

Set a mapping entry to `false` to disable it.

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
    focus_on_ask = true,
    shutdown_on_exit = true,
    shutdown_timeout_ms = 300,
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
      gf = "gf",
      send_ipython = "ll",
      zoom = "zz",
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
| `markdown.wrap_toggle_key` | `wrap_toggle_key` |
| `markdown.sticky_heading` | `sticky_heading` |
| `markdown.reflow.enabled` | `auto_reflow` |
| `markdown.reflow.cmd` | `external_reflow_cmd` |
| `markdown.reflow.fallback` | `external_reflow_fallback` |
| `markdown.reflow.protect_tables` | `external_reflow_protect_tables` |
| `markdown.reflow.margin` | `reflow_margin` |
| `lifecycle.focus_on_switch` | `focus_on_switch` |
| `lifecycle.focus_on_ask` | `focus_on_ask` |
| `lifecycle.shutdown_on_exit` | `shutdown_on_exit` |
| `lifecycle.shutdown_timeout_ms` | `shutdown_timeout_ms` |
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

When `layout.sticky_relative_width` is false, relative values are resolved once
to columns. When it is true, relative values keep their ratio as Neovim columns
change. Turning sticky relative width on at runtime captures the current normal
pane width as the ratio target.

Width changes reflow and rerender Markdown only when the Markdown viewer is the
active pane. Terminal panes resize without reflowing the hidden Markdown buffer.

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

The running terminal session is one per tool. If Codex is already open and a
new Codex preset is chosen, Sidepanes sends the configured `switch_command`
before sending the prompt.

Default exit commands:

| Tool | Exit command |
| --- | --- |
| Codex | `/quit` |
| Claude | `/exit` |
| IPython | `quit()` |

## Ask Workflow

The ask workflow is designed to use Neovim editing rather than a tiny input box.

1. Select text.
2. Invoke an ask mapping or command.
3. Sidepanes opens a scratch prompt buffer containing the full outgoing prompt.
4. Edit any part of the prompt.
5. Write and quit to send.
6. Quit without writing to cancel.

The prompt includes file name, root, selected range, selected text, and detected
snippet language. For Markdown files, Sidepanes detects fenced code-block
language at the selected range, so Python in a Markdown fence is sent as
Python.

Public ask functions:

```lua
require("sidepanes").ask_picker({ visual = true })
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
helpers. They rely on Sidepanes' current runtime memory, not a durable history
model, and may show Codex, Claude, IPython, or a configured custom pane terminal.

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
