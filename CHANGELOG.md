# Changelog

All notable changes to `sidepanes.nvim` are documented here.

This project uses lightweight semantic versioning once tags begin:

- Patch releases are for fixes, docs, tests, and internal refactors.
- Minor releases are for backward-compatible features and public API additions.
- Major releases are reserved for intentional breaking changes after `v1.0.0`.

Before `v1.0.0`, the plugin may still make breaking changes in minor releases,
but they should be called out clearly in this changelog.

## Unreleased

### Changed

- Project root detection is now configurable with `project.root_markers`,
  `project.fallback`, and `project.resolver`. Sidepanes uses the detected root
  as the safety boundary for root-scoped Codex and Claude panes. On modern
  Neovim it uses `vim.fs.root()` semantics for both buffers and paths, including
  string markers, function markers, and nested equal-priority marker groups.
  Sidepanes intentionally does not clone older
  `lspconfig.util.root_pattern()` wildcard/glob semantics; users with glob,
  monorepo, generated-worktree, or tool-specific boundaries should implement
  those rules in `project.resolver`, which runs before marker lookup.
- Agent recovery can now be made stricter or disabled with
  `terminal.auto_resume`, `terminal.resume.enabled`,
  `terminal.resume.infer_from_transcripts`, and
  `terminal.resume.use_claude_pid_metadata`.
- Agent auto-resume is now documented and implemented as an evidence-based
  `tool name + detected project root` workflow. On open, Sidepanes first reuses
  a live Sidepanes-owned terminal job for that tool/root, then falls back to a
  Sidepanes-owned remembered session id, validates the remembered source
  evidence, and starts a new CLI process with `codex resume <session-id>` or
  `claude --resume <session-id>`. It resumes CLI sessions, not terminal ptys,
  and it does not adopt arbitrary latest global Codex or Claude sessions.
- Agent session capture is now configurable with
  `terminal.resume.mechanisms`, `terminal.resume.store_path`, and
  `terminal.resume.resolver`. Custom resolvers can now return evidence and are
  revalidated before Sidepanes reuses resolver-sourced records. Resolver
  callbacks receive a stable context copy, and unknown built-in mechanism names
  now produce validation warnings that point users toward
  `terminal.resume.resolver` for custom discovery. The default registry stores
  only Sidepanes-captured session ids under Neovim's state directory so Codex
  and Claude can resume after a Neovim restart without adopting unrelated
  external sessions.
- Agent resume registry contention and crash recovery are configurable with
  `terminal.resume.store_lock_timeout_ms` and
  `terminal.resume.store_lock_stale_ms`.
- Stale resume failure handling is configurable with
  `terminal.resume.failure_timeout_ms` and
  `terminal.resume.failure_action`.
- Claude recovery now captures session ids through a Sidepanes-injected
  `SessionStart` hook when available. Codex embedded-terminal recovery continues
  to use unambiguous Codex `session_meta` entries for Sidepanes-owned sessions;
  ambiguous same-root transcript candidates are ignored rather than guessed.
- Agent auto-resume is more finicky than originally expected because Codex and
  Claude expose different terminal-session metadata surfaces. Sidepanes now
  treats recovery as best-effort, project-scoped CLI session resume rather than
  terminal pty reattachment.
- The persisted agent-session registry now uses canonical project-root keys,
  atomic writes, a stale-recovering writer lock, and merge-before-save behavior
  so independent Neovim instances are less likely to clobber each other's
  remembered Sidepanes sessions.
- The pane switcher title now includes the detected project name, making the
  current root scope visible while switching between Markdown and terminal
  panes.

### Fixed

- Codex and Claude panes no longer auto-resume an arbitrary latest project
  transcript on first open. Recovery now requires a Sidepanes-owned context or
  remembered Sidepanes session id, so agent sessions created outside Sidepanes
  are not adopted just because they share a project root.
- Root-scoped Codex and Claude lookups now stay inside the requested project
  root instead of falling back to a running agent pane from another project.
- Remembered agent sessions now validate their source evidence before resume.
  Missing or mismatched hook captures, PID metadata, or transcripts are cleared
  instead of being used.
- Resolver-sourced remembered sessions are now revalidated through the custom
  resolver before reuse instead of being trusted indefinitely.
- Codex transcript inference now refuses ambiguous same-root candidates instead
  of guessing which newly written transcript belongs to the Sidepanes pane.
- Resumed Codex and Claude processes that exit immediately with a non-zero code
  now clear the stale remembered session and start fresh once.

### Notes

- The current public extension point for agent auto-resume is session identity
  discovery and validation through `terminal.resume.resolver`. Resume command
  construction remains built in for Codex and Claude; alternative command
  rewriting for other CLIs would be a separate public API.

## v0.2.0 - 2026-07-21

### Changed

- Replaced pre-release README badge placeholders with live release and tag
  badges after publishing `v0.1.0`.
- Markdown panes now poll the source file with a content fingerprint to detect
  source-file changes on disk, auto-reload the pane, restore the cursor near
  the previous line, and show a configurable `[RELOADED]` winbar badge.
- Markdown auto-reload now exposes `markdown.reload_interval_ms`,
  `markdown.reload_badge_ms`, and `markdown.reload_badge` setup options for the
  polling interval, optional badge timeout, badge text, Markdown-interaction
  clearing, and badge highlight colors.
- Codex and Claude pane terminals now track OS pids and resumable session ids.
  When a pane-owned agent terminal exits or its buffer is lost, reopening the
  tool resumes the last matching project session instead of silently starting a
  blank conversation, reports the previous/new PID details when available, and
  shows a configurable `[RESUMED]` winbar badge.
- Agent recovery now exposes `terminal.agent_resume_badge_ms` and
  `terminal.agent_resume_badge` setup options for the optional badge timeout,
  badge text, interaction clearing, and badge highlight colors.

### Fixed

- Improved pane-local smart `gf` path resolution for terminal output where long
  absolute paths wrap and Neovim detects only a trailing path suffix.
- Pane-local terminal toggles are now installed in terminal-input mode as
  `nowait` mappings, so `<C-g>` and `<leader>gg` are intercepted by Sidepanes
  before they can be sent through to Codex or Claude.
- Agent session tracking now avoids adopting stale transcript fallbacks for
  freshly started or just-stopped terminals before the CLI writes new session
  metadata.
- Codex session discovery now requires `session_meta` JSONL entries and scans
  the transcript head instead of trusting any matching payload or only the first
  line.
- Resumed-terminal badge timers now clear the recovered terminal's badge even
  if another terminal becomes active before the timeout fires.
- Pane terminal shutdown now refreshes remembered Codex/Claude session metadata
  before removing stopped terminal contexts.

### Notes

- Sidepanes resumes CLI sessions, not terminal ptys. In normal Neovim terminal
  loss, the pane-owned job is gone too, so recovery starts a new CLI process
  with the tool's resume command. If a remembered PID still appears alive in an
  unusual case, Sidepanes reports it for context but still cannot reattach to
  that pty.

## v0.1.0 - 2026-07-19

### Added

- Extracted Sidepanes into a standalone plugin repository.
- Added the public `sidepanes.nvim` file tree with `lua/sidepanes/**`,
  Neovim help, Markdown reference docs, README, health checks, and tests.
- Added `tests/run_checks.sh fast|full` for standalone local verification.
- Added docs-contract smoke coverage for commands, API, mappings, config,
  Markdown Reflow, dependencies, and compatibility notes.
- Documented the release policy and compatibility stance.
- Added a short public `ROADMAP.md` and archived extraction notes in
  `docs/extraction-notes.md`.
- Added a draft `v0.1.0` GitHub release-notes file.
- Added README badges for CI, pre-release status, tag status, and license.
- Added a short README and release-notes motivation for the workflow Sidepanes
  was built around.

### Changed

- The README now presents Sidepanes as a normal GitHub-installed lazy.nvim
  plugin.
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
- Test wrappers now support explicit runtime paths for installed-plugin
  verification without relying on any consumer config repo.
- Kept `show_last_agent()` and `toggle_markdown_agent()` as compatibility
  aliases for existing callers.
- Kept `toggle_agent` and `toggle_agent_alt` as compatibility aliases for
  existing pane-local mapping configuration.

### Notes

- Markdown Reflow remains built in as `sidepanes.markdown_reflow`. It may split
  into a separate `markdown-reflow.nvim` plugin later if that becomes useful.
