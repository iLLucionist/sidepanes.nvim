# sidepanes.nvim v0.2.1 Release Notes

Draft notes for the next patch release.

## Agent Auto-Resume Hardening

This release tightens Codex and Claude auto-resume after terminal loss. The
behavior is more finicky than originally anticipated because Codex and Claude
expose different terminal-session metadata surfaces. Sidepanes now treats
recovery as best-effort, project-scoped CLI session resume rather than terminal
pty reattachment.

Changes:

- Codex and Claude no longer adopt arbitrary latest project transcripts on first
  open.
- Remembered sessions are scoped by canonical project root.
- The Sidepanes agent-session registry uses atomic writes and merge-before-save
  behavior.
- Remembered sessions validate hook, PID metadata, or transcript evidence before
  resume.
- Ambiguous same-root Codex transcript candidates are ignored instead of guessed.
- Immediately failing resumed CLIs clear the stale resume id and start fresh
  once.

Configuration:

- `terminal.auto_resume = false` or `terminal.resume.enabled = false` disables
  automatic resume.
- `terminal.resume.infer_from_transcripts = false` disables transcript-based
  inference.
- `terminal.resume.mechanisms` and `terminal.resume.resolver` let users replace
  the built-in mechanisms with a stricter local strategy.
