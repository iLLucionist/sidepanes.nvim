# Changelog

All notable changes to `sidepanes.nvim` are documented here.

This project uses lightweight semantic versioning once tags begin:

- Patch releases are for fixes, docs, tests, and internal refactors.
- Minor releases are for backward-compatible features and public API additions.
- Major releases are reserved for intentional breaking changes after `v1.0.0`.

Before `v1.0.0`, the plugin may still make breaking changes in minor releases,
but they should be called out clearly in this changelog.

## Unreleased

### Added

- Extracted Sidepanes from `illu.nvim` into a standalone plugin repository.
- Added the public `sidepanes.nvim` file tree with `lua/sidepanes/**`,
  Neovim help, Markdown reference docs, README, health checks, and tests.
- Added `tests/run_checks.sh fast|full` for standalone local verification.
- Added docs-contract smoke coverage for commands, API, mappings, config,
  Markdown Reflow, dependencies, and compatibility notes.
- Documented the release policy and compatibility stance.
- Added a short public `ROADMAP.md` and archived extraction notes in
  `docs/extraction-notes.md`.
- Added a draft `v0.1.0` GitHub release-notes file.

### Changed

- `illu.nvim` now consumes Sidepanes through lazy.nvim from GitHub instead of a
  local `lua/sidepanes/**` source tree.
- Sidepanes documentation now treats grouped setup keys as preferred while
  keeping older flat setup keys supported.
- Width aliases such as `:Sidepanes width prev`, `:Sidepanes width +`, and
  `:Sidepanes width -` are documented supported conveniences.
- Added terminal-oriented public helper names: `show_last_terminal()` and
  `toggle_markdown_terminal()`.
- Added terminal-oriented pane mapping keys: `toggle_terminal` and
  `toggle_terminal_alt`.
- Expanded the README with full documentation links, complete-functionality
  install guidance, mapping tables, and a workflow tutorial.

### Fixed

- Setup validation now recognizes `commands.width`.
- Personal `illu.nvim` tests now target the lazy-installed plugin path through
  `SIDEPANES_RUNTIME_PATH`.
- Kept `show_last_agent()` and `toggle_markdown_agent()` as compatibility
  aliases for existing callers.
- Kept `toggle_agent` and `toggle_agent_alt` as compatibility aliases for
  existing pane-local mapping configuration.

### Notes

- Markdown Reflow remains built in as `sidepanes.markdown_reflow`. It may split
  into a separate `markdown-reflow.nvim` plugin later if that becomes useful.
