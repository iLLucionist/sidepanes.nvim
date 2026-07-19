# sidepanes.nvim v0.1.0 Draft Release Notes

This is the first standalone release draft for `sidepanes.nvim`.

## Highlights

- Extracts Sidepanes from `illu.nvim` into a standalone Neovim plugin.
- Provides a reusable right-hand pane for Markdown reference docs, Codex,
  Claude, and IPython.
- Ships Neovim help through `:help sidepanes` and a longer Markdown reference in
  `doc/sidepanes.md`.
- Adds `:checkhealth sidepanes` for dependency and setup validation.
- Includes headless local checks and GitHub Actions CI.

## Included Workflows

- Fuzzy find Markdown reference documents with Telescope.
- Navigate Markdown headings from the side pane.
- Use pane-local smart `gf` to jump from reference docs to source files.
- Ask Codex or Claude about selected code or reference text through editable
  prompt buffers.
- Send Python lines or visual selections to an IPython terminal.
- Switch between Markdown, Codex, Claude, and IPython in one pane.
- Resize the pane through commands, mappings, and runtime Lua helpers.

## Compatibility

- New Lua helpers prefer terminal-oriented names:
  `show_last_terminal()` and `toggle_markdown_terminal()`.
- Existing helpers remain available as aliases:
  `show_last_agent()` and `toggle_markdown_agent()`.
- New pane-local mapping keys prefer terminal-oriented names:
  `toggle_terminal` and `toggle_terminal_alt`.
- Existing mapping keys remain available as aliases:
  `toggle_agent` and `toggle_agent_alt`.
- Older flat setup keys remain supported, while grouped setup keys are preferred
  in documentation and examples.

## Dependencies

Core loading has no required Lua dependency. Full functionality uses Telescope,
plenary.nvim, nvim-treesitter Markdown parsers, markview.nvim, and external
tools such as `codex`, `claude`, `ipython`, optional `uv`, and optional `mdfmt`.

Run `:checkhealth sidepanes` after installing to verify the local environment.

## Notes

- Markdown Reflow remains bundled as `sidepanes.markdown_reflow` for this
  release. It may split into `markdown-reflow.nvim` later.
- Platform or extension APIs for other plugins are deferred to the `v0.2.0`
  roadmap.
