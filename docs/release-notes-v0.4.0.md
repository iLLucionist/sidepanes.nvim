# sidepanes.nvim v0.4.0 Release Notes

This release adds the optional ask pane workflow for building agent prompts
from multiple files and selections before sending them to Codex, Claude, or any
configured ask-capable terminal.

## Ask Pane

`ask.ui = "pane"` opens a persistent editable draft in the Sidepanes window
instead of the floating ask prompt. The plugin default remains
`ask.ui = "float"` for compatibility.

The ask pane is designed for prompt assembly:

- `show_ask_pane(opts)`, `:Sidepanes ask`, `mappings.global.ask_pane`, and
  `mappings.pane.ask_pane` open or focus an empty ask pane before any selection
  exists,
- visual ask mappings append selected context when `ask.auto_append = true`,
- pane-local `mappings.pane.headings = "fm"` opens the Markdown heading picker
  from the Markdown pane,
- optional pane-local `mappings.pane.ask_send` / `ask_send_alt` runs the
  ask-pane quit lifecycle, cancelling empty drafts, preserving modified drafts,
  and sending written ones,
- in non-ask Sidepanes buffers, command-line `:q` / `:quit` returns to Markdown,
  so personal quit mappings such as `<leader>qq -> :q<CR>` do not close the pane
  or trigger ask-pane send,
- pane-local `mappings.pane.ask_submit = "<C-CR>"` submits the active ask draft
  from normal or insert mode,
- `:SidepanesAskStatus`, `:Sidepanes ask-status`, and `ask_status(opts)`
  report the active ask draft state, target, picker, citation counts, previous
  pane mode, and modified/written flags,
- `:SidepanesVersion`, `:Sidepanes version`, and `version()` report the
  Sidepanes version and plugin load path for support/debugging,
- pane-local `mappings.pane.help = "gh"`, `:SidepanesMappings`,
  `:Sidepanes mappings`, and `mappings_help(opts)` open a Markdown help float
  showing active pane, global, and command mappings,
- `:SidepanesAskAppend`, `:Sidepanes ask-append`, and `append_to_ask(opts)`
  append explicitly even when auto-append is disabled,
- prompts group citations by `File:` and allow multiple `Selection:` blocks per
  file,
- same-file selections patch the existing file block when possible,
- exact duplicate file/range citations are skipped by default with
  `ask.duplicate_policy = "skip"`, and
- cross-root selections keep root context in the generated file heading.

## Editing Flow

Inside the ask pane, the winbar shows the selected target/model and explicit
draft state: `ready_empty`, `draft_modified`, `draft_written`,
`sending_picker`, `sending_terminal`, `send_failed`, `cancelled`, or `sent`.
Press `M` or `<Tab>` to open the model picker and change the target before
sending.

Normal-mode ask-pane focus mappings preserve modified drafts. If an unmodified
written draft is reopened and freshened back to a blank `Question:` prompt,
press `u` in the ask pane to restore the previous prompt and citation state.

`ask.model_picker` controls picker timing:

- `"manual"` only opens the picker from a mapping,
- `"after_open"` opens it once when a new ask-pane draft receives its first
  captured selection, and
- `"before_send"` opens it just before sending.

The `"before_send"` timing is respected in both ask UIs. With the floating
scratch prompt, visual `aa` / `ax` opens the editor first and defers model
selection until after write and quit. If `M` or `<Tab>` already selected a
target/model manually, Sidepanes reuses that choice instead of asking again.

Command-line `:q` cancels an empty draft, preserves a modified draft while
restoring the previous Sidepanes state, and sends after `:w`. `:q!` always
cancels the current draft and restores the previous Sidepanes state, such as
Codex, Claude, IPython, a custom terminal, or Markdown. `:wq`, `:x`, and
`:exit` write and send the accumulated prompt. Plain normal-mode `q` remains
unmapped.

When the default `ask_submit = "<C-CR>"` is used, the ask pane also maps
`<C-J>` as a submit fallback for terminals that report Ctrl+Enter that way.
Personal normal-mode mappings such as `qq -> :q<CR>` or
`<leader>qq -> :q<CR>` are guarded in non-ask Sidepanes buffers only when their
RHS is a plain quit command, so they return to Markdown instead of closing the
pane.

Cancellation restores the previous pane before deleting the draft buffer, so
the Sidepanes window stays visually stable. `ask.model_picker = "after_open"`
opens only for the first selection in an active draft; use the ask pane picker
mapping to change target/model later.

Visual ask mappings such as global `<leader>pa` and pane-local `aa` use the
default ask target for the first capture, then append to the active draft without
reopening the picker.

If the selected target terminal cannot be opened, the ask pane keeps the draft
visible and warns instead of discarding the prompt.

## Refactor And Maintainability

The ask workflow was also refactored substantially. Ask-pane behavior now flows
through smaller composable pieces instead of scattered keymap and command-line
branches:

- pure policy and route helpers decide write, submit, quit, cancel, picker, and
  send behavior,
- the target resolver owns active-target, last-context, default-target, picker,
  and before-send decisions,
- session/status snapshot helpers provide the shared facts used by lifecycle
  decisions, winbar labels, status output, and tests,
- controller and executor adapters keep Neovim buffer/window effects at the
  edge of the ask workflow, and
- ask-pane implementation modules now live under `lua/sidepanes/panes/ask/*`,
  with root compatibility shims for older internal module paths.

The test suite was reorganized around behavior matrices, mapping-zone coverage,
fed-key paths, and shared lifecycle facts so mapping behavior, command-line
behavior, status output, and internal policy decisions stay aligned.

## Navigation

Generated citation headings support quick movement:

- `]f` and `[f` jump between file headings,
- `]s` and `[s` jump between selection headings, and
- `gf` jumps from a generated citation heading to the referenced source file
  and line.

## Configuration

New defaults:

```lua
ask = {
  ui = "float",
  auto_append = true,
  duplicate_policy = "skip",
  model_picker = "manual",
}
```

New mapping keys:

```lua
mappings = {
  global = {
    ask_pane = "<leader>pa",
  },
  pane = {
    headings = "fm",
    ask_pane = "ap",
    ask_submit = "<C-CR>",
    ask_send = false,
    ask_send_alt = false,
    ask_next_file = "]f",
    ask_previous_file = "[f",
    ask_next_selection = "]s",
    ask_previous_selection = "[s",
    ask_source = "gf",
    ask_model_picker = "M",
    ask_model_picker_alt = "<Tab>",
    help = "gh",
  },
}
```

New help config:

```lua
help = {
  winbar = true,
  mapping = "gh",
  scope = "pane_first",
}
```

Setup validation now understands the `ask` and `help` config groups, including
`ask.ui`, `ask.duplicate_policy`, `ask.model_picker`, `help.mapping`, and
`help.scope`. It also validates `markdown.reload_badge.min_display_ms`.

## Diagnostics And Other Fixes

`:checkhealth sidepanes` now reports both the Sidepanes version and the loaded
plugin path, matching the new `:SidepanesVersion` / `version()` support output.

Markdown reload behavior also got a small polish pass:

- returning focus to an already-open Markdown side pane checks for source-file
  changes immediately instead of waiting for polling or idle checks, and
- `markdown.reload_badge.min_display_ms` keeps a fresh `[RELOADED]` badge
  visible through quick pane-switch gestures before interaction can clear it.
