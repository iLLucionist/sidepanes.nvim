# sidepanes.nvim

[![Tests](https://github.com/iLLucionist/sidepanes.nvim/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/iLLucionist/sidepanes.nvim/actions/workflows/tests.yml)
[![Release](https://badgen.net/github/release/iLLucionist/sidepanes.nvim)](https://github.com/iLLucionist/sidepanes.nvim/releases)
[![Tag](https://badgen.net/github/tag/iLLucionist/sidepanes.nvim)](https://github.com/iLLucionist/sidepanes.nvim/tags)
[![License](https://badgen.net/badge/license/MIT/blue)](LICENSE)

Reusable Neovim side panes for Markdown references, coding-agent terminals, and
IPython.

Sidepanes is built for a hybrid artisan-and-agentic coding workflow: draft a
spec, let an agent produce reference implementation material, then keep that
reference beside your code while you review, revise, and refactor line by line.
It keeps Markdown reference docs, Codex, Claude, and IPython in one right-hand
pane, so you can switch between implementation files and reference material, ask
questions about selected code or prose, and send Python snippets to a live
IPython session.

Full documentation:

- [doc/sidepanes.md](doc/sidepanes.md)
- `:help sidepanes`

Sidepanes keeps one right-hand pane and switches it between:

- a Markdown viewer
- Codex
- Claude
- IPython

It preserves Markdown cursor/scroll position, reuses terminal sessions, resumes
Codex and Claude sessions after pane-owned terminal exits, sends visual
selections into agent prompt editors, sends lines or selections to IPython,
includes pane-local smart `gf`, auto-reloads Markdown files changed on disk, and
ships built-in Markdown reflow as `sidepanes.markdown_reflow`.

## Install

With lazy.nvim, this example installs the dependencies used for the intended
complete functionality: document and heading pickers, Markdown heading parsing,
optional Markdown decorations, coding-agent terminals, IPython, and Markdown
reflow.

```lua
{
  "iLLucionist/sidepanes.nvim",
  dependencies = {
    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
    },
    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
    },
    "OXY2DEV/markview.nvim",
  },
  config = function()
    require("sidepanes").setup({
      markdown = {
        auto_reload = true,
        reload_interval_ms = 1000,
        reload_badge_ms = 0,
        reload_badge = {
          text = "[RELOADED]",
          clear_on_interaction = true,
          hl = {
            fg = "CursorFG",
            bg = "WarningMsg",
            bold = true,
          },
        },
      },
      terminal = {
        auto_resume = true,
        resume = {
          enabled = true,
          infer_from_transcripts = true,
          use_claude_pid_metadata = true,
          mechanisms = {
            claude = { "hook", "pid_metadata", "transcript" },
            codex = { "transcript" },
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
      commands = true,
      mappings = {
        global = {
          toggle = "<leader>pp",
          pick = "<leader>mP",
          headings = "<leader>mf",
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

    require("sidepanes.markdown_reflow").setup({
      external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
      external_reflow_protect_tables = true,
      commands = true,
      mappings = {
        reflow = "<leader>mR",
      },
    })
  end,
}
```

For the complete workflow, install these command-line tools on your `$PATH`:

- `codex`
- `claude`
- `ipython`
- `uv`, optional but preferred for the default IPython command
- `mdfmt`, optional external Markdown formatter

Run `:checkhealth sidepanes` after setup to see exactly which optional pieces
are available in your environment.

## Tutorial

1. Imagine you are coding and want a reference Markdown document next to your
   source file. This is exactly why Sidepanes exists. Press `<leader>mP` to
   fuzzy find a Markdown document with Telescope. Once you select a file, it
   opens in a fixed panel on the right. As you scroll through the document, the
   active section stays visible in the pane winbar.

2. For long Markdown files, jump by heading instead of scrolling. Press
   `<leader>mf` to fuzzy find headings in the current Sidepanes document. Pick a
   heading and the pane moves directly there. If the Markdown file changes on
   disk, Sidepanes reloads it, returns near your previous line, and marks the
   winbar with `[RELOADED]` until you interact with the Markdown pane.

3. When a Markdown note points at a source file, put the cursor on the filename
   and press `gf` inside the pane. Sidepanes resolves the path against the
   project and opens the file in your last non-pane window, leaving the reference
   pane intact.

4. As you are coding or reading reference material, you might want to ask a
   question about it using a coding agent. Select the relevant lines and press
   `<leader>pa` from any buffer, or `aa` inside the Sidepanes panel. Sidepanes
   opens an editable prompt buffer. Notice that it automatically prefills the
   filename, line numbers, and snippet from your selection.

5. You may also want to interact with your Python code live. As with asking
   questions, select code in visual mode and press `<leader>pl` from any buffer,
   or `ll` inside the Sidepanes panel. Sidepanes sends those lines to an IPython
   session in a terminal.

6. If you want to interact directly with one of the tools, switch to it with
   `<leader>px` for Codex, `<leader>pc` for Claude, or `<leader>pi` for IPython.
   Inside the Sidepanes panel, use the faster pane-local mappings: `<space>x`
   for Codex, `<space>c` for Claude, `<space>i` for IPython, and `<space>0` for
   the Markdown viewer. Press `<leader>gg` or `<C-g>` inside the pane to toggle
   between the Markdown document and the last terminal. These toggle mappings
   are also installed in terminal-input mode, so pressing `<C-g>` while typing
   in Claude or Codex is handled by Sidepanes instead of being sent to the agent.
   If a pane-owned Codex or Claude terminal exits unexpectedly, reopening that
   tool for the same project root first checks for a live pane job, then resumes
   a Sidepanes-owned remembered session when one is available. Recovered
   terminals echo the session/PID details and show a `[RESUMED]` winbar badge.
   Sidepanes resumes CLI sessions, not terminal ptys; when the pane-owned job
   is gone, recovery starts a fresh CLI process with the resume command.

7. If the pane feels too wide or narrow, use `<leader>p-`, `<leader>p+`, or
   `<leader>pw` to adjust it. Use `<leader>p%` when you want relative widths to
   track the total Neovim window size.

## Agent Auto-Resume

Sidepanes auto-resume is intentionally scoped and evidence-based. It never
reattaches to a lost terminal pty and it no longer adopts the latest global
Codex or Claude session just because one exists. The resume key is always:

```text
tool name + detected project root
```

Project root detection uses Neovim's `vim.fs.root()` marker model when
available. It defaults to the nearest `.git` parent, falling back to the current
file's directory. Configure `project.root_markers` with the same marker shapes
Neovim accepts: strings, functions, or nested equal-priority marker groups such
as `{ { "pyproject.toml", "package.json" }, ".git" }`.

Sidepanes intentionally does not clone the older
`lspconfig.util.root_pattern()` wildcard/glob semantics. For unusual boundaries
such as `*.sln`, generated worktrees, monorepo package rules, or tool-specific
project files, use `project.resolver`. The resolver runs before marker lookup,
receives either a buffer number or path plus `opts.kind`, and should return the
root directory Sidepanes should use as the resume boundary:

```lua
require("sidepanes").setup({
  project = {
    root_markers = { { "pyproject.toml", "package.json" }, ".git" },
    fallback = "buffer_dir",
    resolver = function(source, opts)
      -- Return nil to let Sidepanes continue with vim.fs.root().
      -- Return a path to take full control for this buffer/path.
    end,
  },
})
```

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

Built-in capture differs by agent. Claude uses a temporary pane-local
`SessionStart` hook first, can fall back to Claude PID metadata, and can infer a
matching transcript when enabled. Codex uses unambiguous `session_meta` entries
from `~/.codex/sessions/**` for the pane's project root; ambiguous candidates
are ignored instead of guessed.

Remembered sessions are stored under Neovim's state directory by default. The
registry writes with an atomic rename and a lock directory, merges existing
entries before save, and recovers stale locks after
`terminal.resume.store_lock_stale_ms` so a crashed Neovim/plugin instance does
not block future saves.

Public tuning and extension points:

| Option | Use |
| --- | --- |
| `terminal.auto_resume` / `terminal.resume.enabled` | Turn auto-resume off entirely. |
| `terminal.resume.infer_from_transcripts` | Disable transcript inference for stricter behavior. |
| `terminal.resume.use_claude_pid_metadata` | Disable Claude PID metadata lookup. |
| `terminal.resume.mechanisms` | Enable, disable, or reorder built-in mechanism names: `"hook"`, `"pid_metadata"`, `"transcript"`. |
| `terminal.resume.resolver` | Provide custom session-id discovery and validation. |
| `terminal.resume.store_path` | Change or disable the persisted registry. |
| `terminal.resume.store_lock_timeout_ms` | Tune how long a registry save waits for another writer. |
| `terminal.resume.store_lock_stale_ms` | Tune crash recovery for abandoned registry locks. |
| `terminal.resume.failure_timeout_ms` | Tune the quick-failure window for stale resume ids. |
| `terminal.resume.failure_action` | Choose `"fresh"`, `"notify"`, or `"ignore"` after quick failed resume. |

Custom resolvers receive `resolver(tool_name, ctx, opts)`. `ctx` is a stable
copy of the terminal context; mutating it does not mutate Sidepanes internals.
During capture, return a session id string or a table such as
`{ session_id = "...", evidence = { resolver_state = ... } }`. Before reusing a
resolver-sourced record, Sidepanes calls the resolver again with
`opts.purpose = "validate"` and `opts.remembered`. Return the same session id,
`true`, or `{ valid = true }` to keep the record; return `false`, `nil`, or a
different id to make Sidepanes clear it and start fresh.

The current extension point is session identity discovery/validation. Resume
command construction is still built in for Codex and Claude; alternative command
rewriting for other CLIs would be a separate public API.

## Mappings

Global mappings are not enabled by default. Configure them with
`mappings.global`.

| Config key | Example lhs | Behavior |
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
| `ask` | `<leader>pa` | Ask picker from visual selection. |
| `ask_last` | `aa` | Ask last coding agent from visual selection. |
| `ask_codex` | `ax` | Ask Codex from visual selection. |
| `ask_claude` | `ac` | Ask Claude from visual selection. |

Pane-local mappings are installed inside Sidepanes buffers by default. Configure
them with `mappings.pane`.

| Config key | Default lhs | Behavior |
| --- | --- | --- |
| `markdown` | `<space>0` | Show Markdown viewer. |
| `codex` | `<space>x` | Show Codex. |
| `claude` | `<space>c` | Show Claude. |
| `ipython` | `<space>i` | Show IPython. |
| `toggle_terminal` | `<leader>gg` | Toggle Markdown and last terminal, including from terminal-input mode. |
| `toggle_terminal_alt` | `<C-g>` | Faster toggle between Markdown and last terminal, including from terminal-input mode. |
| `ipython_alt` | `<leader>gi` | Show IPython. |
| `gf` | `gf` | Smart go-to-file from the pane into the last non-pane window. |
| `send_ipython` | `ll` | Send visual selection to IPython. |
| `zoom` | `zz` | Toggle zoom. |
| `ask_last` | `aa` | Ask last coding agent from visual selection. |
| `ask_codex` | `ax` | Ask Codex from visual selection. |
| `ask_claude` | `ac` | Ask Claude from visual selection. |

Set a mapping entry to `false` to disable it.

Markdown Reflow mappings are configured separately through
`sidepanes.markdown_reflow`.

| Config key | Example lhs | Behavior |
| --- | --- | --- |
| `reflow` | `<leader>mR` | Reflow the current Markdown buffer or selection. |

## Commands

```vim
:Sidepanes
:Sidepanes help
:Sidepanes switch
:Sidepanes codex [preset]
:Sidepanes claude [preset]
:Sidepanes ipython
:Sidepanes width 100
:Sidepanes width next
:Sidepanes width previous
:Sidepanes width +
:Sidepanes width -
:Sidepanes width pick
:Sidepanes ask
:MarkdownReflow
```

Run `:help sidepanes` for the full command, mapping, config, and API reference.

## Markdown Reflow

Sidepanes uses its built-in reflow module internally, and you can also configure
it directly:

```lua
require("sidepanes.markdown_reflow").setup({
  external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
  external_reflow_protect_tables = true,
  commands = true,
  mappings = {
    reflow = "<leader>mR",
  },
})
```

If no external formatter is configured, Sidepanes falls back to its internal
paragraph reflow.

Markdown Reflow intentionally lives behind the `sidepanes.markdown_reflow`
module boundary. It may split into a separate `markdown-reflow.nvim` plugin
later if that becomes useful.

## Dependencies

Core loading has no required Lua dependency. For intended complete
functionality, install:

- `telescope.nvim` and `plenary.nvim` for document and heading pickers
- `nvim-treesitter` with Markdown parsers for heading picking and richer
  Markdown context
- `markview` for optional Markdown decorations
- `mdfmt` when using external Markdown reflow
- `codex`, `claude`, `ipython`, and optionally `uv` for terminal tools

Run `:checkhealth sidepanes` for the full dependency contract and setup
validation status. Install Markdown Treesitter parsers with your normal
Treesitter workflow, for example `:TSInstall markdown markdown_inline`.

## Release Policy

The project will use lightweight semantic versioning once tags begin. Patch
releases are for fixes, docs, tests, and internal refactors. Minor releases are
for backward-compatible features and public API additions. Major releases are
reserved for intentional breaking changes after `v1.0.0`.

Before `v1.0.0`, breaking changes may still happen in minor releases, but they
should be called out clearly in [CHANGELOG.md](CHANGELOG.md).

Grouped setup keys are preferred for new configuration. Older flat setup keys
remain supported by config normalization. Documented command aliases are
supported conveniences; the clearest forms are still `next`, `previous`, and
explicit width values.

## Project Status

See [CHANGELOG.md](CHANGELOG.md) for release history and [ROADMAP.md](ROADMAP.md)
for the short public roadmap.

## Checks

```sh
tests/run_checks.sh fast
tests/run_checks.sh full
```

`fast` runs the regression, setup audit, help, docs-contract, and health smokes.
`full` also runs real Codex/Claude CLI smoke tests when those executables are
available.
