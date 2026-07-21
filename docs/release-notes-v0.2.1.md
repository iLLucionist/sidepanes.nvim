# sidepanes.nvim v0.2.1 Release Notes

Draft notes for the next patch release.

## Agent Auto-Resume Hardening

This release tightens Codex and Claude auto-resume after terminal loss. The
behavior is more finicky than originally anticipated because Codex and Claude
expose different terminal-session metadata surfaces. Sidepanes now treats
recovery as best-effort, project-scoped CLI session resume rather than terminal
pty reattachment.

Mental model:

- Auto-resume is keyed by `tool name + detected project root`.
- Opening Codex or Claude first reuses a live Sidepanes-owned terminal job for
  that tool/root.
- If the live job is gone, Sidepanes looks for a Sidepanes-owned remembered
  session id, validates its evidence, and starts a new CLI with
  `codex resume <session-id>` or `claude --resume <session-id>`.
- Sidepanes does not adopt arbitrary latest global Codex or Claude sessions.
- If a resumed CLI exits quickly with a non-zero status, Sidepanes treats the id
  as stale and starts fresh once by default.

Changes:

- Codex and Claude no longer adopt arbitrary latest project transcripts on first
  open.
- Remembered sessions are scoped by canonical project root.
- Codex now captures the explicit `codex resume <session-id>` command printed in
  the terminal on exit, including when Neovim wraps the long line.
- Project root detection uses Neovim `vim.fs.root()` semantics for buffers and
  paths, including string markers, function markers, and nested equal-priority
  marker groups.
- Wildcard/glob project boundaries are handled through `project.resolver`
  instead of a Sidepanes clone of `lspconfig.util.root_pattern()`. Use this for
  monorepos, generated worktrees, `*.sln`-style roots, or tool-specific project
  rules.
- The Sidepanes agent-session registry uses atomic writes, a stale-recovering
  writer lock, and merge-before-save behavior.
- Remembered sessions validate hook, PID metadata, terminal-output capture, or
  transcript evidence before resume.
- Custom resolver records are revalidated before reuse, and resolver callbacks
  receive a stable context copy rather than mutable Sidepanes internals.
- Ambiguous same-root Codex transcript candidates are ignored instead of guessed.
- Quickly failing resumed CLIs clear the stale resume id and start fresh once by
  default.
- The pane switcher title now shows the detected project name, so the current
  root scope is visible while choosing a pane.

Configuration:

- `terminal.auto_resume = false` or `terminal.resume.enabled = false` disables
  automatic resume.
- `terminal.resume.infer_from_transcripts = false` disables transcript-based
  inference.
- `terminal.resume.mechanisms` and `terminal.resume.resolver` let users replace
  the built-in mechanisms with a stricter local strategy. Mechanism entries are
  built-in names; use `terminal.resume.resolver` for custom session discovery.
- `terminal.resume.store_lock_timeout_ms` and
  `terminal.resume.store_lock_stale_ms` tune shared-registry contention and
  crash recovery.
- `terminal.resume.failure_timeout_ms` and `terminal.resume.failure_action`
  tune what happens when a stale resume id fails after launch.
- `project.root_markers`, `project.fallback`, and `project.resolver` control
  the root Sidepanes uses as the pane/restart/resume boundary. The resolver runs
  before marker lookup and can return `nil` to continue with `vim.fs.root()`.

Extension boundary:

- `terminal.resume.resolver` is the public hook for custom session identity
  discovery and validation. It can return a session id string or
  `{ session_id = "...", evidence = { resolver_state = ... } }`, and Sidepanes
  calls it again with `opts.purpose = "validate"` before reusing resolver-owned
  records.
- Resume command construction remains built in for Codex and Claude. A custom
  command-rewriting API for other CLIs would be a future feature.
