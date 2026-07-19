# sidepanes.nvim

Reusable Neovim side panes for Markdown references, coding-agent terminals,
and IPython.

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

With lazy.nvim:

```lua
{
  "iLLucionist/sidepanes.nvim",
  dependencies = {
    "nvim-telescope/telescope.nvim", -- optional pickers/headings UI
  },
  config = function()
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
          focus = "<leader>pf",
          zoom = "<leader>pz",
          width_previous = "<leader>p-",
          width_next = "<leader>p+",
          width_picker = "<leader>pw",
          sticky_relative_width = "<leader>p%",
          switch = "<leader>ps",
          send_ipython = "<leader>pl",
          ask = "<leader>pa",
        },
      },
    })

    require("sidepanes.markdown_reflow").setup({
      commands = true,
      mappings = {
        reflow = "<leader>mR",
      },
    })
  end,
}
```

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

Core loading has no required Lua dependency. Feature dependencies are optional:

- `telescope.nvim` for document and heading pickers
- Markdown Treesitter parser for heading picking and richer Markdown context
- `markview` for optional Markdown decorations
- `mdfmt` only when configured as an external Markdown formatter
- `codex`, `claude`, `ipython`, and optionally `uv` for terminal tools

Run `:checkhealth sidepanes` for the full dependency contract and setup
validation status.

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

`fast` runs the regression, setup audit, help, and health smokes. `full` also
runs real Codex/Claude CLI smoke tests when those executables are available.
