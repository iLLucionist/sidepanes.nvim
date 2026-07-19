# sidepanes.nvim

[![Tests](https://github.com/iLLucionist/sidepanes.nvim/actions/workflows/tests.yml/badge.svg)](https://github.com/iLLucionist/sidepanes.nvim/actions/workflows/tests.yml)
[![Latest release](https://img.shields.io/github/v/release/iLLucionist/sidepanes.nvim?sort=semver&label=release)](https://github.com/iLLucionist/sidepanes.nvim/releases)
[![Latest tag](https://img.shields.io/github/v/tag/iLLucionist/sidepanes.nvim?sort=semver&label=tag)](https://github.com/iLLucionist/sidepanes.nvim/tags)
[![License](https://img.shields.io/github/license/iLLucionist/sidepanes.nvim)](LICENSE)

Reusable Neovim side panes for Markdown references, coding-agent terminals, and
IPython.

Full documentation:

- [doc/sidepanes.md](doc/sidepanes.md)
- `:help sidepanes`

Sidepanes keeps one right-hand pane and switches it between:

- a Markdown viewer
- Codex
- Claude
- IPython

It preserves Markdown cursor/scroll position, reuses terminal sessions, sends
visual selections into agent prompt editors, sends lines or selections to
IPython, includes pane-local smart `gf`, and ships built-in Markdown reflow as
`sidepanes.markdown_reflow`.

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
   heading and the pane moves directly there.

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
   between the Markdown document and the last terminal.

7. If the pane feels too wide or narrow, use `<leader>p-`, `<leader>p+`, or
   `<leader>pw` to adjust it. Use `<leader>p%` when you want relative widths to
   track the total Neovim window size.

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
| `toggle_terminal` | `<leader>gg` | Toggle Markdown and last terminal. |
| `toggle_terminal_alt` | `<C-g>` | Faster toggle between Markdown and last terminal. |
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
