# sidepanes.nvim v0.4.0 Release Notes

This release adds the optional ask pane workflow for building agent prompts
from multiple files and selections before sending them to Codex, Claude, or any
configured ask-capable terminal.

## Ask Pane

`ask.ui = "pane"` opens a persistent editable draft in the Sidepanes window
instead of the floating ask prompt. The plugin default remains
`ask.ui = "float"` for compatibility.

The ask pane is designed for prompt assembly:

- normal-mode `mappings.global.ask_pane` opens or focuses the pane,
- visual ask mappings append selected context when `ask.auto_append = true`,
- pane-local `mappings.pane.headings = "fm"` opens the Markdown heading picker
  from the Markdown pane,
- optional pane-local `mappings.pane.ask_send` / `ask_send_alt` runs the
  ask-pane quit lifecycle, cancelling unwritten drafts and sending written ones,
- in non-ask Sidepanes buffers, command-line `:q` / `:quit` returns to Markdown,
  so personal quit mappings such as `<leader>qq -> :q<CR>` do not close the pane
  or trigger ask-pane send,
- pane-local `mappings.pane.ask_submit = "<C-CR>"` submits the active ask draft
  from normal or insert mode,
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

`ask.model_picker` controls picker timing:

- `"manual"` only opens the picker from a mapping,
- `"after_open"` opens it once when a new ask draft receives its first captured
  selection, and
- `"before_send"` opens it just before sending.

Command-line `:q` cancels an unwritten draft, while `:q` after `:w` sends the
written prompt. `:q!` always cancels the current draft and restores the previous
Sidepanes state, such as Codex, Claude, IPython, a custom terminal, or
Markdown. `:wq`, `:x`, and `:exit` write and send the accumulated prompt. Plain
normal-mode `q` remains unmapped.

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
  },
}
```
