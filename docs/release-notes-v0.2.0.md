# sidepanes.nvim v0.2.0 Release Notes

This release makes Sidepanes more resilient during day-to-day agent-assisted
work: Markdown references now reload when edited outside Neovim, and Codex or
Claude panes can recover the last resumable session after pane-owned terminal
jobs exit or buffers are lost.

## Highlights

- Markdown panes auto-reload when the source file changes on disk.
- Reload detection uses an internal content fingerprint, so same-size rewrites
  and atomic saves are detected without relying on Neovim `autoread`,
  `:checktime`, file metadata, or filesystem watcher behavior.
- Reloaded Markdown panes try to restore the cursor near the same line and show
  a configurable `[RELOADED]` winbar badge.
- Codex and Claude panes now track process ids and resumable session ids.
- Reopening a lost or exited pane-owned Codex or Claude terminal resumes the
  last matching project session when Sidepanes can identify one.
- Recovered agent terminals show a configurable `[RESUMED]` winbar badge.

## Configuration

New Markdown reload options:

```lua
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
})
```

New agent recovery badge options:

```lua
require("sidepanes").setup({
  terminal = {
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
})
```

Badge `fg` and `bg` values accept hex colors or Neovim highlight group names.
Suffixes such as `CursorFG` and `CursorBG` select the foreground or background
from a highlight group explicitly.

## Fixes

- Pane-local smart `gf` now resolves wrapped terminal-output paths more
  reliably.
- Pane-local terminal toggles are installed in terminal-input mode as `nowait`
  mappings, so `<C-g>` and `<leader>gg` are intercepted by Sidepanes before
  Codex or Claude can receive them.
- Agent session tracking avoids adopting stale transcript fallbacks before a
  freshly started or just-stopped CLI has written new metadata.
- Codex session discovery requires `session_meta` JSONL entries and scans the
  transcript head instead of trusting any matching payload.
- Resumed-terminal badge timers clear the recovered terminal's badge even if
  another terminal becomes active before the timeout fires.
- Pane terminal shutdown refreshes remembered Codex and Claude session metadata
  before stopped terminal contexts are removed.

## Notes

Sidepanes resumes CLI sessions, not terminal ptys. In normal Neovim terminal
loss, the pane-owned job is gone too, so recovery starts a new CLI process with
the tool's resume command. If a remembered PID still appears alive in an unusual
case, Sidepanes reports it for context but still cannot reattach to that pty.
