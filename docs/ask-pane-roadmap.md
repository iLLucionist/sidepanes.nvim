# Ask Pane Roadmap

Branch: `feat/ask-pane`

Target release: `v0.4.0`

Status: ask-pane implementation slices are complete; final verification and
release-readiness audit is blocked on the final manual interaction checklist.

## Status Legend

- `Done`: implemented, tested, and documented.
- `Done (Caveat)`: implemented, but with a noted limitation or historical
  caveat.
- `In Progress`: actively being changed in the current branch.
- `Planned`: accepted for implementation but not started.
- `Deferred`: intentionally postponed.

## Current Slice Status

| Slice | Status | Notes |
| --- | --- | --- |
| 1. Branch And Worktree Preflight | Done (Caveat) | Branch is `feat/ask-pane`; the pre-implementation dirty-state check cannot be reconstructed after feature work accumulated. |
| 2. Configuration And Validation | Done | `ask` config defaults, normalization, validation, docs, and tests are present. |
| 3. Prompt And Citation Helpers | Done | `ask_prompt` handles prompt shape, duplicate identity, same-file ordering, edited-block fallback, and cross-root labels. |
| 4. Ask Pane State And Buffer | Done | Persistent scratch buffer, empty ready state, citation bookkeeping, and cleanup are implemented and tested. |
| 5. Ask Pane Window Mode | Done | `ask` pane mode, Markdown-like options, winbar state, previous pane capture, and restore are implemented. |
| 6. Capture, Append, And Explicit Append | Done | First capture, later append, explicit append, duplicate skip, stale-state recovery, and cross-root rendering are covered. |
| 7. Ask Pane Mappings | Done | Ask pane focus, visual ask, picker, heading picker, send/submit, navigation, and source mappings are implemented; `ask_send` now requires a written prompt. |
| 8. Target Picker And Send Flow | Done | Manual, `after_open`, and `before_send` picker modes plus write/send behavior are implemented. |
| 9. Cancel And Restore | Done | Command-line quit handling, write-then-quit send, hard cancel, pane restore, and flicker reduction are implemented. |
| 10. Tests | Done | Regression, audit, docs contract, health, full, and local `illu.nvim` checks cover the base ask-pane workflow. |
| 11. Documentation And Local Opt-In | Done | README, help, changelog, release notes, roadmap, and `illu.nvim` opt-in are updated. |
| 12. Verification | Done | `tests/run_checks.sh fast`, `tests/run_checks.sh full`, `illu.nvim` smoke, and `git diff --check` pass as of the latest audit. |
| 13. Send Lifecycle Naming Refactor | Done | Exact lifecycle action names, explicit draft states, winbar labels, tests, and docs are implemented and verified. |
| 14. Ask Pane Module Split | Done | Ask pane internals are split into `lua/sidepanes/panes/ask/*` with root compatibility shims. |
| 15. Formal Behavior Matrix | Done | Source-of-truth matrix plus machine-readable fixture and docs-contract coverage are present. |
| 16. Mapping And Command Zone Matrix | Done | Source-of-truth mapping/command zone matrix plus fixture, docs-contract checks, runtime mapping regression, corrected non-ask `:q` command-path ownership, and ask-pane quit-lifecycle shortcuts are present. |
| 17. Ask Target And Picker Status Visibility | Done | Internal ask status/debug formatter exposes target, root, picker, draft, and count facts for the future status command. |
| 18. Target Resolver Refactor | Done | Target resolution now lives in a pure resolver with traceable active, last-context, default, picker, and before-send decisions plus snapshot-facing target reasons. |
| 19. Interaction-Focused Manual Acceptance Checklist | Done | Interaction-focused manual checklist is present, traceable, and covered by docs/fast checks. |
| 20. `SidepanesAskStatus` | Done | `ask_status(opts)`, `:SidepanesAskStatus`, and `:Sidepanes ask-status` report ask draft status for debugging. |
| 21. `SidepanesVersion` | Done | `version()`, `:SidepanesVersion`, `:Sidepanes version`, and health output report plugin version and load path. |
| 22. Interactive Keymap Help | Done | Pane-local `gh` mapping help, commands/API, winbar hint, docs, tests, and audit evidence are implemented. |
| 23. Ask Action Policy And Fed-Key Test Discipline | Done | Central ask action predicates, policy tests, and fed-key test guidance are implemented and verified. |
| 24. Ask Architecture Boundary Refactor | Done | Ask behavior is consolidated around pure policy/route/command helpers, thin adapters, a controller factory, and an injected lifecycle executor. |
| 25. Ask Session State And Status Snapshot Refactor | Done | Ask session snapshots now provide the shared facts/status data used by lifecycle decisions, winbar labels, tests, and future status commands. |
| 26. Ask Test Architecture And Fed-Key Coverage Cleanup | Done | Ask tests are grouped by architecture layer, behavior-sensitive mappings have traceable fed-key coverage or explicit exceptions, and command-line `:w` lifecycle coverage is fixed and verified. |

## Remaining Implementation Order

The remaining planned slices must be implemented in this order unless the
roadmap is explicitly updated first with the reason for changing the order.

1. Final verification and release-readiness audit (blocked on manual checklist)

The matrices came first because they define the behavior contract before
implementation changes. Slice 23 introduced the first central ask action policy,
but manual acceptance showed the larger design still needs consolidation before
more feature work. Slices 24-26 therefore come next: first boundaries and
composition, then a coherent state/status snapshot, then test architecture and
fed-key discipline. Target resolution and the module split follow those
refactors so files are moved only after semantics, state, and tests are clearer.
Status, version, and keymap help are then built on the cleaner module
boundaries. The manual checklist comes last so it reflects the final
user-facing workflow.

Slice 23 was inserted ahead of target resolution after manual acceptance found
that callback-level tests and scattered action predicates missed real keypress
behavior. Centralizing ask action predicates and requiring fed-key coverage must
happen before the next target or module refactor so those changes build on one
decision point instead of more mapping/lifecycle glue.

Slices 24-26 were inserted after reviewing the feature-to-code ratio and the
interplay between mappings, command-line handling, lifecycle state, and actions.
The next work must stop expanding ask-pane behavior and instead clean the shape:
one policy module for decisions, thin keymap modules, thin command-line
adapters, lifecycle functions that execute plans, direct policy/state tests, and
fed-key tests for user-visible mapping behavior. Treat the current feature LOC
as a warning sign: future ask-pane work should reduce scattered branching,
prefer table-driven or pure-function decisions, and avoid adding broad code for
small behavior changes.

## Mandatory Slice Completion Protocol

Every remaining planned slice must use this protocol. Do not mark a slice
`Done` until every item below is complete.

1. Copy every bullet under the numbered slice into a traceability table.
2. Group the slice into the smallest coherent implementation units: usually one
   roadmap bullet or a tightly related set of bullets that must be reviewed and
   reverted together.
3. For each bullet, record:
   - implementation reference, usually a file/function.
   - automated test reference, or a written reason why no automated test is
     appropriate.
   - documentation reference, or a written reason why no docs change is needed.
   - manual acceptance test reference.
   - commit reference once the bullet's coherent unit is committed.
   - status: `Done`, `Blocked`, or `Not Applicable`.
4. After implementing, testing, documenting, and focused-checking a coherent
   unit, commit that unit before starting the next coherent unit. Do not leave
   completed unit work uncommitted while continuing the slice.
5. Check the implementation, tests, docs, roadmap, help docs, README,
   CHANGELOG, release notes, and `illu.nvim` notes when relevant.
6. Re-read the traceability table and the changed code/docs until no missing
   bullet, contradiction, stale behavior claim, untested edge case, or
   implementation concern remains.
7. Run focused tests for the slice.
8. Run `tests/run_checks.sh fast`.
9. Run `tests/run_checks.sh full` for behavior-sensitive, release-sensitive, or
   cross-module changes.
10. Run the `illu.nvim` smoke check whenever defaults, mappings, commands,
   public API, or local config behavior changes.
11. Run `git diff --check`.
12. Run repeated audit passes until nothing new comes up. Each pass must check:
    - every bullet under the numbered implementation slice.
    - the traceability table.
    - implementation correctness and architecture boundaries.
    - automated test coverage, edge cases, fed-key behavior, command paths,
      mapping zones, state transitions, and compatibility requirements.
    - manual acceptance tests.
    - README, CHANGELOG, Neovim help docs, Markdown docs, release notes,
      roadmap status/order, AGENTS.md, and `illu.nvim` impact when relevant.
13. If any pass finds a gap, contradiction, stale claim, missing edge case,
    incorrect behavior, weak test, incomplete documentation, process miss, or
    commit evidence problem, append it under the current numbered slice, add it
    to traceability, fix/test/document it, commit that coherent unit, and
    restart the audit loop from the new HEAD.
14. After the last commit, including any audit-record or process-doc commit,
    perform at least two consecutive clean confirmation passes. A clean
    confirmation pass is non-mutating: it must not edit files, add roadmap
    bullets, or rely on memory. If it finds anything, it is not clean; record
    the gap, fix it, commit it, and restart the clean-pass count from the new
    HEAD.
15. Because recording the final clean confirmation passes in this roadmap would
    itself create a new last change and restart the loop, record all
    gap-finding passes and fixes in the roadmap, then report the final two
    non-mutating clean confirmation passes in the slice completion response.
16. Only then update the slice status table and report the evidence.

The audit must be literal and bullet-by-bullet. A slice-level statement such as
"this area is covered" is not sufficient.

## Manual Acceptance Checklist

Use this consolidated checklist for human-in-Neovim release acceptance.
The historical manual notes remain under each slice for traceability, but
this is the editable checklist to mark while testing.

Notation:

- `- [ ] ...` means open.
- `- [X] ...` means checked and correct.
- `- [!] ...` means bug found or check this with Codex.

When marking an item, keep the line prefix and add brief notes after the
sentence when useful, especially the exact key mapping or command used.

### Slice 1. Branch And Worktree Preflight

- [ ] Run `git status --short --branch` in `sidepanes.nvim` and confirm the branch is `feat/ask-pane`.
- [ ] Confirm all modified files before implementation are roadmap or agent guidance files: `AGENTS.md`, `ROADMAP.md`, and `docs/ask-pane-roadmap.md`.
- [ ] Open `docs/ask-pane-roadmap.md` and confirm it names target release `v0.4.0` and includes the implementation audit loop.

### Slice 2. Configuration And Validation

- [ ] In Neovim, run `:lua vim.print(require("sidepanes.config").default_setup().ask)` and confirm it prints `ui = "float"`, `auto_append = true`, `duplicate_policy = "skip"`, and `model_picker = "manual"`.
- [ ] Configure `ask = { ui = "pane", auto_append = false, duplicate_policy = "allow", model_picker = "before_send" }`, run `:lua vim.print(require("sidepanes").get_config().ask)`, and confirm those values are present.
- [ ] Configure malformed ask values such as `ask = { ui = "popup" }` with validation enabled and confirm setup reports an ask config warning.
- [ ] Confirm existing ask behavior still opens the floating prompt editor when `ask.ui` is omitted or left as `"float"`.

### Slice 3. Prompt And Citation Helpers

- [ ] Use the existing floating ask workflow with default `ask.ui = "float"` and confirm the generated prompt still starts with `Question:`, followed by `File:`, `Selection:`, `lines start-end`, and a fenced code block.
- [ ] Add the same file/range twice once the ask pane append UI exists and confirm duplicate policy `"skip"` reports a duplicate instead of adding a second citation.
- [ ] Add two selections from the same file out of line order and confirm the prompt shows one `File:` block with `Selection:` citations ordered by line number when the block was not manually reshaped.
- [ ] Manually edit a same-file context block before appending another selection and confirm the new citation is appended at the end of that file block.
- [ ] Append a selection from another project root and confirm the `File:` line keeps enough root/path context for the agent to identify the source.

### Slice 4. Ask Pane State And Buffer

- [ ] Configure `ask.ui = "pane"`, run `:lua require("sidepanes").show_ask_pane()`, and confirm Sidepanes opens a reusable ask scratch buffer named `Pane Question`.
- [ ] Confirm the ask buffer starts in a ready state with only a `Question:` section before any selection has been sent.
- [ ] Run the ask-pane focus command twice and confirm the same buffer is reused instead of creating a second ask draft.
- [ ] Confirm the ask buffer is Markdown filetype, does not create a swapfile, and is not listed as a normal file-backed project buffer.

### Slice 5. Ask Pane Window Mode

- [ ] Open a Markdown document in Sidepanes, then open the ask pane and confirm it appears in the same permanent side split.
- [ ] Confirm the ask pane winbar reads like an ask surface and shows the current target/draft state instead of Markdown heading or terminal identity.
- [ ] Confirm editable Markdown is not concealed in the ask pane.
- [ ] Open Codex, switch to the ask pane, and confirm later cancellation can restore Codex as the previous pane mode once cancel behavior is implemented.

### Slice 6. Capture, Append, And Explicit Append

- [ ] With `ask.ui = "pane"`, select a range in one file and invoke the usual ask mapping. Confirm the ask pane opens and the prompt contains the selected file, line range, and fenced text.
- [ ] Open the ask pane before selecting context, type a question under `Question:`, then capture the first selection. Confirm the typed question is preserved above the generated `File:` block.
- [ ] Select another range from the same file and invoke the usual ask mapping. Confirm the prompt still has one `File:` block and now has two `Selection:` citations.
- [ ] Select a range from a different file and run `:SidepanesAskAppend`. Confirm a second `File:` block is added.
- [ ] Repeat the exact same file/range with `duplicate_policy = "skip"` and confirm Sidepanes reports the duplicate and does not add another citation.
- [ ] Delete the visible citation from the ask draft, repeat the same file/range, and confirm it is added again rather than skipped from stale internal state.
- [ ] Set `auto_append = false`, create a first ask prompt, then invoke the usual ask mapping on a second range. Confirm the pane focuses without changing the prompt. Run `:SidepanesAskAppend` and confirm the second range is added.

### Slice 7. Ask Pane Mappings

- [ ] Configure global normal `ask_pane = "<leader>pa"` and visual `ask = "<leader>pa"`. Confirm normal `<leader>pa` opens/focuses the ask pane and visual `<leader>pa` captures the selection.
- [ ] From a Markdown or terminal Sidepanes buffer, press pane-local `ap` and confirm it switches to the ask pane.
- [ ] With `model_picker = "before_send"`, start an ask draft from another buffer with visual `<leader>pa` and confirm the first capture uses the default target without opening the picker.
- [ ] With `model_picker = "before_send"`, start an ask draft inside Sidepanes with `aa` and confirm the first capture uses the default target without opening the picker.
- [ ] After a draft exists, select more lines with visual `<leader>pa` or `aa` and confirm the selection appends without reopening the picker.
- [ ] In the ask pane, press `M` or `<Tab>` and confirm the target picker opens.
- [ ] Change `mappings.pane.ask_model_picker` to another key and set `mappings.pane.ask_model_picker_alt = false`; confirm the custom key opens the picker and `<Tab>` no longer does.
- [ ] In the ask pane, confirm `]f`, `[f`, `]s`, `[s`, and `gf` are available and do not replace plain normal-mode `q`.
- [ ] From the Markdown pane, press local `fm` and confirm the Markdown heading picker opens without needing `<leader>fm`.
- [ ] Configure `mappings.pane.ask_send = "qq"`, press `qq` in the ask pane, and confirm an unwritten prompt is kept with a warning. Run `:w`, press `qq` again, and confirm the written prompt is sent.
- [ ] Configure `mappings.pane.ask_send_alt = "<leader>qq"`, press `<leader>qq` in the ask pane, and confirm it also requires a written prompt instead of cancelling through the global quit mapping.
- [ ] From a Codex or Claude pane, press a configured `ask_send_alt` such as `<leader>qq` and confirm Sidepanes returns to Markdown instead of closing the pane through a global quit mapping.
- [ ] Press `<C-CR>` in normal mode and insert mode inside the ask pane and confirm each submits the current prompt.

### Slice 8. Target Picker And Send Flow

- [ ] Create an ask-pane prompt, press `M`, choose a different Codex/Claude preset, and confirm the winbar target changes.
- [ ] Set `model_picker = "after_open"` and confirm the picker appears after the first captured selection.
- [ ] Switch away from an active ask draft and back again; confirm the `after_open` picker does not reappear for that same draft.
- [ ] Set `model_picker = "before_send"`, write and quit the prompt, choose a model, and confirm the prompt is sent to that target.
- [ ] Run `:w` in the ask pane and confirm the prompt remains open and marked written/draft in the winbar.
- [ ] Run `:wq` after editing the prompt and confirm Sidepanes switches to the target terminal and the terminal receives the full accumulated prompt.

### Slice 9. Cancel And Restore

- [ ] Open the ask pane from the Markdown viewer, run `:q`, and confirm the question is cancelled while the Sidepanes split returns to Markdown.
- [ ] Open the ask pane, edit the prompt, run `:w`, then run `:q`; confirm the prompt is sent and the ask pane does not reopen empty.
- [ ] Open Codex, switch to the ask pane, run `:q!`, and confirm the question is cancelled while the Sidepanes split returns to Codex.
- [ ] Confirm unwritten `:q` and hard-cancel `:q!` do not close the Sidepanes window as their primary action.
- [ ] Confirm cancellation restores the previous pane immediately and only then removes the ask buffer behind the scenes.
- [ ] Confirm plain normal-mode `q` is not mapped to cancel the ask pane.

### Slice 10. Tests

- [ ] In an ask prompt with multiple files and selections, use `]f` and `[f` to move between `File:` blocks.
- [ ] Use `]s` and `[s` to move between `Selection:` blocks.
- [ ] Place the cursor inside a generated citation and press `gf`; confirm the referenced file opens outside the Sidepanes split at the cited start line.
- [ ] Place the cursor on a `File:` heading and press `gf`; confirm it opens the referenced file at the first cited selection line, not line 1 by default.

### Slice 11. Documentation And Local Opt-In

- [ ] Run `:lua vim.print(require("sidepanes").get_config().ask)` from the personal Neovim config and confirm `ui = "pane"`, `auto_append = true`, `duplicate_policy = "skip"`, and `model_picker = "before_send"`.
- [ ] Run `:verbose nmap <leader>pa` and confirm the normal-mode mapping opens or focuses the ask pane.
- [ ] Run `:verbose xmap <leader>pa` and confirm the visual mapping still captures or appends a selection for an ask prompt.
- [ ] Run `:help sidepanes-ask` and confirm the help documents pane mode, written `:q` send behavior, `:q!` cancellation, `:SidepanesAskAppend`, model picker timing, citation navigation, and `gf` source jumps.
- [ ] Read `docs/release-notes-v0.4.0.md` and confirm it describes the ask pane as a `v0.4.0` feature while keeping `ask.ui = "float"` as the plugin default.

### Slice 12. Verification

- [ ] Start Neovim with the personal config, run `:Sidepanes`, and confirm there are no Sidepanes health warnings beyond optional missing local dependencies.
- [ ] Open the ask pane with normal `<leader>pa`, append selections with visual `<leader>pa` across at least two files, write and quit, and confirm the target agent receives one accumulated prompt.
- [ ] Repeat the flow from a Codex pane and a Markdown pane, then cancel with `:q!`; confirm each cancel restores the previous pane state.
- [ ] Run `:SidepanesAskAppend` with `ask.auto_append = false` in a temporary local config override and confirm explicit append still mutates the ask draft.

### Slice 13. Send Lifecycle Naming Refactor

- [ ] In the ask pane, edit a prompt and press configured `qq`; confirm it cancels without sending because the prompt is not written.
- [ ] Run `:w`, press `qq`, and confirm the prompt sends.
- [ ] Edit a prompt and press `<C-CR>`; confirm it writes and sends immediately.
- [ ] Configure a failing target terminal, submit the prompt, and confirm the draft remains visible with a warning and `send_failed` state.

### Slice 14. Ask Pane Module Split

- [ ] Open/focus the ask pane, append context, navigate citations, write/send, and cancel from both Markdown and Codex after the module move.
- [ ] Run `:checkhealth sidepanes` and confirm no module-load errors.

### Slice 15. Formal Behavior Matrix

- [ ] Pick at least one row per action type and execute it directly in Neovim.
- [ ] Confirm actual behavior matches the matrix before considering the slice done.
- [ ] Suggested rows for the first manual pass: `ask-q-ready`, `ask-qbang-any`, `ask-write-draft`, `ask-write-quit-draft`, `ask-send-shortcut-unwritten`, `ask-send-shortcut-written`, `ask-send-alt-shortcut`, `non-ask-quit-command`, `ask-submit-draft`, `submit-command-no-draft`, and `non-ask-command-line`.

### Slice 16. Mapping And Command Zone Matrix

- [ ] In a normal project buffer, run the visual ask mapping and confirm it captures context.
- [ ] In the Markdown pane, press `fm`, `ap`, and visual `aa`; confirm each performs the pane-local action.
- [ ] With a personal/global `<leader>qq -> :q<CR>` mapping, press `<leader>qq` in a Codex pane; confirm it returns to Markdown without closing the Sidepanes window.
- [ ] In the ask pane, press `M`, `]f`, `[f`, `]s`, `[s`, `gf`, `qq`, and `<C-CR>`; confirm each follows the matrix.

### Slice 17. Ask Target And Picker Status Visibility

- [ ] Create an ask draft and change target with `M`; confirm status output matches the winbar target.
- [ ] Set `model_picker = "after_open"`, append first context, and confirm status indicates the picker has been shown.
- [ ] Set `model_picker = "before_send"`, write/send, and confirm the selected target is reflected before the prompt is sent.

### Slice 18. Target Resolver Refactor

- [ ] Start a first visual ask capture with `model_picker = "before_send"` and confirm no picker appears.
- [ ] Append another selection and confirm the active draft target is reused.
- [ ] Press `M` in the ask pane and confirm the picker still opens manually.
- [ ] Write/send with `before_send` and confirm the picker appears only then.

### Slice 19. Interaction-Focused Manual Acceptance Checklist

- [ ] Run the checklist in a real Neovim session with `illu.nvim` loaded.
- [ ] Mark each workflow pass/fail with the exact mapping or command used.
- [ ] Create draft from project buffer: setup: Open a normal project file and visually select code.; action: Invoke visual ask from the project buffer.; expected: Ask pane opens with one `File:` block and one `Selection:` block for the selected project file.; mapping/command used: ; result notes:
- [ ] Create draft from Markdown pane: setup: Open Sidepanes Markdown, focus it, and visually select text in the Markdown pane.; action: Invoke pane-local visual ask.; expected: Ask pane opens from the Markdown pane and includes the Markdown file/range citation.; mapping/command used: ; result notes:
- [ ] Append same-file context: setup: Keep the ask draft active and select a second range in the same source file.; action: Invoke visual ask append or active visual ask.; expected: The same `File:` block gains another `Selection:` block; exact duplicates are skipped.; mapping/command used: ; result notes:
- [ ] Append different-file context: setup: Select text in a second file under the same project root.; action: Invoke visual ask append or active visual ask.; expected: The draft gains a second `File:` block and citation counts/status reflect both files.; mapping/command used: ; result notes:
- [ ] Append cross-root context: setup: Select text from a file outside the current project root.; action: Append that selection to the active ask draft.; expected: The draft includes root context for the cross-root file so the source is unambiguous.; mapping/command used: ; result notes:
- [ ] Edit prompt, write, send: setup: Edit the ask draft text.; action: Write the buffer, then quit or use a configured quit-lifecycle shortcut.; expected: The prompt sends to the selected target, the ask draft closes, and the previous pane is restored.; mapping/command used: ; result notes:
- [ ] Edit prompt, cancel: setup: Edit the ask draft text without writing it.; action: Quit without writing or run hard cancel.; expected: The draft is cancelled without sending and the previous pane is restored.; mapping/command used: ; result notes:
- [ ] Switch target manually: setup: Open an active ask draft with multiple ask-capable targets configured.; action: Press the model picker mapping in the ask pane and choose another target/preset.; expected: The ask winbar/status target changes before sending.; mapping/command used: ; result notes:
- [ ] Use `before_send` picker: setup: Temporarily set `ask.model_picker = "before_send"` in local config state.; action: Submit a draft.; expected: Picker opens at send time; chosen target receives the prompt.; mapping/command used: ; result notes:
- [ ] Recover from failed terminal start: setup: Temporarily configure an ask-capable target with a missing command.; action: Submit a draft to that target.; expected: A warning appears, the draft remains visible, and the winbar/status shows `send_failed`.; mapping/command used: ; result notes:
- [ ] Use mapping help: setup: Focus Markdown, terminal, and ask panes.; action: Press the help mapping in each pane.; expected: Help opens with the current pane mappings first, then global mappings, then relevant commands.; mapping/command used: ; result notes:

### Slice 20. `SidepanesAskStatus`

- [ ] Open an empty ask pane and run `:SidepanesAskStatus`; confirm it reports a ready draft and no citations.
- [ ] Append two selections from different files and run status; confirm file and citation counts are correct.
- [ ] Write the prompt and run status; confirm it reports a written draft.
- [ ] Cancel/send the draft and run status; confirm it reports inactive/no active ask draft.

### Slice 21. `SidepanesVersion`

- [ ] Run `:SidepanesVersion` from the personal config and confirm it prints `0.4.0-dev` or the release version plus the path under `~/.config/nvim/sidepanes.nvim`.
- [ ] Temporarily load Sidepanes from another runtime path and confirm the command reports that path.

### Slice 22. Interactive Keymap Help

- [ ] In the Markdown pane, confirm the winbar shows `gh help` on the right and pressing `gh` opens mapping help with Markdown-pane mappings first.
- [ ] In a Codex pane, press `gh`; confirm terminal-pane mappings are shown first and global Sidepanes mappings are shown after them.
- [ ] In the ask pane, press `gh`; confirm ask-specific mappings such as `M`, `gf`, `]f`, `[f`, `qq`, and `<C-CR>` appear before global mappings.
- [ ] Resize the Sidepanes pane and press `gh`; confirm the help float stays centered over the Sidepanes pane rather than the full editor.
- [ ] Move Sidepanes to a future left or bottom placement if that layout exists and confirm the help float still centers over the pane geometry.
- [ ] Disable the help mapping and confirm the winbar hint disappears.

### Slice 23. Ask Action Policy And Fed-Key Test Discipline

- [ ] With personal `qq -> :q<CR>` and `<leader>qq -> :q<CR>`, press both in the Markdown pane and a Codex pane; confirm Sidepanes returns to Markdown without closing the window.
- [ ] In the ask pane, press configured `qq` and `<leader>qq` on unwritten and written drafts; confirm the policy outcomes match cancel/send expectations.
- [ ] In the ask pane, press Ctrl+Enter in a terminal that reports `<C-CR>` and one that reports `<C-J>`; confirm both submit through the same policy path.
- [ ] Inspect the direct policy tests and confirm each action plan corresponds to a row in the behavior matrix.

### Slice 24. Ask Architecture Boundary Refactor

- [ ] In the ask pane, run `:q`, `:q!`, `:w`, `:wq`, `:x`, configured `qq`, configured `<leader>qq`, `<C-CR>`, and `<C-J>`; confirm outcomes match the behavior matrix.
- [ ] In Markdown and Codex panes, press personal plain-quit mappings such as `qq` and `<leader>qq`; confirm Sidepanes does not close.
- [ ] Change target manually with `M`, then submit; confirm target choice survives the refactor.
- [ ] Use `model_picker = "before_send"` and confirm picker timing is unchanged.
- [ ] Force a failed terminal open/send and confirm the draft is preserved with the same warning/state behavior as before.

### Slice 25. Ask Session State And Status Snapshot Refactor

- [ ] Open an empty ask pane and confirm the winbar/status-facing state is `ready_empty`.
- [ ] Append context, edit the question, write, submit, cancel, and failed-send; confirm visible state labels and behavior agree.
- [ ] Switch from Markdown to ask and from Codex to ask; confirm previous pane restore behavior still works.
- [ ] Run any existing debug/status helpers and confirm they report the same target, picker, and draft state visible in the UI.

### Slice 26. Ask Test Architecture And Fed-Key Coverage Cleanup

- [ ] For every mapping listed in the behavior-sensitive coverage table, perform the real keypress in Neovim and compare the outcome to the matrix.
- [ ] Repeat personal `qq` / `<leader>qq` checks in Markdown, Codex, and ask panes.
- [ ] Repeat `<C-CR>` / `<C-J>` submit checks from normal and insert ask-pane modes.
- [ ] Run the focused ask test group and confirm failures point to user behavior, not just callback plumbing.

### Final Release Audit

- [ ] Run the slice-19 interaction checklist in real Neovim with `illu.nvim` loaded and the local `sidepanes.nvim` checkout on `runtimepath`.
- [ ] Confirm `ask.ui = "float"` remains the public default and `ask.ui = "pane"` remains opt-in.
- [ ] Confirm `:SidepanesVersion`, `:SidepanesAskStatus`, `:SidepanesMappings`, ask submit/write/quit/cancel, target picker, mapping help, and failed-send recovery behave as documented.
- [ ] Confirm `:help sidepanes` opens and public docs match the release behavior.

## Goal

Replace or supplement the current floating ask prompt editor with a configurable
ask pane. The ask pane should keep the editable temporary prompt available while
the user moves through the project, collects context from multiple selections,
and continues editing the outgoing prompt before sending it to Codex or Claude.

The first selection should still create the same temporary prompt structure
Sidepanes uses today. Later selections should patch that prompt instead of
opening a new prompt or duplicating unrelated state.

The public plugin default should remain compatible with current users:
`ask.ui = "float"` keeps the existing floating prompt editor. The personal
`illu.nvim` configuration can opt into `ask.ui = "pane"` once the feature lands.

## Target User Flow

1. Open or focus the ask pane with the global normal mapping `<leader>pa`.
2. Open or focus the ask pane from an existing Sidepanes buffer with the
   pane-local normal mapping `ap`.
3. If no ask draft exists yet, the ask pane may open in an empty ready state,
   but the real prompt is not instantiated until the first selection is sent.
4. Select text in any file or pane.
5. Use the existing ask mapping or the explicit append command to add that
   selection to the current ask prompt.
6. Repeat selection capture across one or more files.
7. Edit the question and accumulated context in the ask pane.
8. Optionally change the target model from the ask pane before sending.
9. Write and quit, write then quit, use an explicit submit mapping, or use a
   configured ask-pane send mapping after writing to send the prompt to the
   selected agent target.
10. Quit an unwritten draft with `:q`, or any draft with `:q!`, to cancel and
   restore the pane mode that was active before the ask pane opened.

## Prompt Shape

The prompt remains Markdown and keeps the current top-level shape:

```markdown
Question:

File:
path/to/file

Selection:
lines 10-20

```lua
selected text
```
```

The ask pane must support multiple files, with one or more citations per file:

```markdown
Question:

File:
src/one.lua

Selection:
lines 10-20

```lua
first selected text
```

Selection:
lines 42-55

```lua
second selected text from the same file
```

File:
src/two.lua

Selection:
lines 3-8

```lua
selected text from another file
```
```

When another selection comes from a file that is already present in the prompt,
Sidepanes should patch the existing `File:` block by appending another
`Selection:` citation inside that block. It should create a new `File:` block
only when the file is not already represented in the prompt.

## Configuration

Add configuration that lets users keep the current floating workflow or opt into
the pane workflow.

Planned shape:

```lua
ask = {
  ui = "float", -- "float" keeps current behavior; "pane" enables the ask pane
  auto_append = true,
  duplicate_policy = "skip", -- "skip" or "allow"; "confirm" can be added later
  model_picker = "manual", -- "before_send", "after_open", or "manual"
}
```

Mapping configuration should separately support:

- global normal ask-pane focus, defaulting to `<leader>pa`.
- global visual ask capture, keeping the current `<leader>pa` behavior.
- pane-local normal ask-pane focus, defaulting to `ap`.
- pane-local visual ask capture, keeping the current `aa` behavior.
- ask-pane-local model picker, defaulting to the existing question-editor
  target picker key if possible.
- Markdown-pane-local heading picker, defaulting to `fm`.
- optional ask-pane-local send shortcuts, disabled by default and configurable
  for personal mappings such as `qq` and `<leader>qq`.
- ask-pane-local context navigation and source jump mappings.

When `auto_append` is disabled, visual ask should open or focus the ask pane with
the first captured selection but should not continue appending further selections
implicitly. Users can still append explicitly through the append command or
mapping.

Recommended personal config once implemented:

```lua
ask = {
  ui = "pane",
  auto_append = true,
  duplicate_policy = "skip",
  model_picker = "before_send",
}
```

## Implementation Slices

### 1. Branch And Compatibility Boundary

- Work only on `feat/ask-pane`.
- Keep the existing floating ask editor path intact.
- Add tests proving default behavior remains compatible when `ask.ui = "float"`.

### 2. Ask Pane State

- Add ask-pane state to the shared Sidepanes state table.
- Track the ask buffer, current target entry, prompt root, origin window, and
  previous pane mode.
- Track citations structurally in buffer-local or session-local ask state instead
  of relying only on reparsing the visible Markdown prompt.
- Use prompt parsing only as a fallback when the visible prompt and internal
  citation registry diverge because the user edited context blocks manually.
- Capture enough previous pane state to restore Markdown, Codex, Claude, IPython,
  or another configured terminal after cancellation.

### 3. Ask Pane Window Mode

- Add `ask` as a pane mode alongside Markdown and terminal modes.
- Reuse the existing Sidepanes split.
- Apply editor-friendly Markdown window options.
- Show target, model/preset, and draft lifecycle state in the winbar.
- Keep the statusline untouched; the winbar is pane-local, visible while editing,
  and already used by Sidepanes for pane identity.

### 4. Prompt Creation And Patching

- Reuse the existing selection context builder.
- On first captured selection, create the ask buffer with the existing prompt
  template.
- On later captured selections, update the internal citation registry, then
  patch the visible Markdown prompt.
- If the file already exists, append a new `Selection:` citation to that file
  block.
- If the file does not exist, append a new `File:` block.
- Preserve user edits to the `Question:` section and existing context.
- Avoid visible prompt metadata by default. Target, model, draft state, and
  citation bookkeeping should live in the winbar and internal state so the prompt
  sent to the agent stays clean.
- Add a small visible metadata header only if implementation proves the prompt
  cannot be patched reliably without it.
- Detect exact duplicate citations by file path and selected line range.
- Skip duplicate citations by default and notify the user.
- Keep duplicate detection exact at first: same normalized file identity and same
  selected line range. Avoid semantic or text-based duplicate detection until
  there is a concrete need.
- When a same-file block is still machine-shaped, insert the new citation in
  line-number order. If the user has edited the block in a way that makes safe
  ordering uncertain, append the new citation at the end of that file block.

### 5. Cross-Root Context

- Allow selections from more than one project root in the same ask prompt.
- Preserve enough path context for cross-root selections so the receiving agent
  can tell which project each citation came from.
- Prefer relative paths for selections inside the ask target root.
- Use root-labelled or absolute paths for selections outside the ask target root.
- Consider a warning when appending the first cross-root citation, but do not
  block the workflow.

### 6. Ask Capture Routing

- In visual mode, existing ask mappings should add the current selection to the
  active ask pane prompt when pane mode is enabled and `auto_append` allows it.
- If no ask prompt exists yet, visual ask should create it.
- Add an explicit append API and command, such as `:SidepanesAskAppend`, that
  always appends the current selection to the active ask prompt or creates one
  if needed.
- Target picking should happen only when needed: first prompt creation, explicit
  target change, missing last/current agent context, or configured pre-send
  model selection.

### 7. Ask Pane Focus Mappings

- Add global normal `<leader>pa` to open or focus the ask pane.
- Add pane-local normal `ap` to switch from Markdown or terminal mode to the ask
  pane.
- Keep global visual `<leader>pa` as ask capture.
- Keep pane-local visual `aa` as ask capture.
- Add or reuse an ask-pane-local target/model picker mapping. The current
  floating editor uses `M` and `<Tab>`; preserve that muscle memory unless it
  conflicts with pane editing.
- Add ask-pane-local navigation between `File:` and `Selection:` headers.
- Add an ask-pane-local source jump mapping, similar in spirit to `smart_gf`,
  that opens the referenced file and moves to the cited line range.
- Do not add a normal-mode `q` cancel mapping in the ask pane. Neovim users
  already understand buffer/file-like editing, and cancellation should be tied to
  command-line quit behavior: `:q` cancels before write, `:q` sends after write,
  and `:q!` cancels.

### 8. Cancel, Quit, And Restore

- Intercept `:q`, `:q!`, `:quit`, and `:quit!` while the ask pane buffer is
  active.
- Treat `:q` / `:quit` as cancellation before a write and send after a write;
  treat `:q!` / `:quit!` as cancellation.
- Do not close the Sidepanes window as the primary action.
- Restore the pane to the mode that was active before the ask pane opened:
  Markdown returns to Markdown, Codex returns to Codex, Claude returns to Claude,
  IPython returns to IPython, and custom terminal tools return to their previous
  terminal buffer.
- Restore focus to the previous non-pane window when that matches existing
  Sidepanes focus behavior.

### 9. Send Semantics

- Keep write-then-quit semantics unless the config explicitly changes them later.
- `:w` should cache the current prompt draft.
- `:wq`, `:x`, `:xit`, and `:exit` should send the full accumulated prompt.
- If `ask.model_picker = "before_send"`, show the model picker after `:wq` starts
  sending and before opening or sending to the terminal.
- If `ask.model_picker = "after_open"`, show the model picker once when an
  active ask draft receives its first captured selection.
- If `ask.model_picker = "manual"`, never interrupt send/open flow with an
  automatic picker; users can invoke the ask-pane-local picker mapping.
- After sending, switch the pane to the target terminal and focus it.
- Clear ask state after a successful send.

### 10. Editing Navigation

- Add motions or mappings to jump to previous/next `File:` block.
- Add motions or mappings to jump to previous/next `Selection:` block.
- Add source jumps from a `File:` or `Selection:` block to the referenced file
  and first cited line.
- Prefer reusing `smart_gf` path resolution behavior where possible so pane,
  terminal, and ask prompt source jumps feel consistent.

### 11. Tests

- Ask pane can be focused with configured global and pane-local normal mappings.
- First visual ask creates an ask pane buffer with the current prompt structure.
- A second selection from the same file patches the existing `File:` block with
  another `Selection:` citation.
- A selection from a different file appends a new `File:` block.
- Exact duplicate selections are skipped by default.
- Same-file selections are ordered by line number when the file block is still
  machine-shaped.
- Cross-root selections are allowed and rendered with enough root/path context.
- `:q` cancels unwritten drafts, `:q` after `:w` sends, and `:q!` cancels while
  restoring the previous pane mode without closing the Sidepanes pane.
- Plain normal-mode `q` is not mapped to cancel the ask pane.
- Ask-pane-local model picker updates the target entry and winbar.
- Configured automatic model picker behavior fires before send, after open, or
  not at all.
- Ask-pane-local navigation moves between context blocks.
- Ask-pane-local source jump opens the cited file at the cited line.
- `:wq` sends the accumulated prompt and focuses the target terminal.
- Existing floating ask tests continue to pass under default config.

### 12. Documentation

- Update `README.md` mapping tables and ask workflow.
- Update `doc/sidepanes.md` and `doc/sidepanes.txt`.
- Update docs contract tests.
- Add a `CHANGELOG.md` entry under `Unreleased` when behavior lands.

## Implementation Order

This is the concrete order to implement the feature on the local branch.

After every implementation step below, pause and audit the slice before moving
on. Check the implementation, the tests, and all affected docs: this roadmap,
public roadmap notes, help docs, README, CHANGELOG, release notes, and any
personal `illu.nvim` config notes. Keep iterating until no obvious code, test,
or documentation gap remains. After each implementation step, append manual
acceptance tests under that step so the user can verify the behavior directly in
Neovim.

Tests for this feature should be deep enough to cover every behavior implemented
in the slice, including edge cases and compatibility with the default floating
ask workflow.

### 1. Branch And Worktree Preflight

- Confirm the repository is on `feat/ask-pane`.
- Confirm no unrelated user changes are present before editing implementation
  files.
- Keep roadmap/documentation edits separate from code edits where practical.
- Audit branch state, roadmap accuracy, and test/doc obligations before moving
  to configuration work.
- Append manual acceptance tests for branch/worktree expectations before moving
  on.

Manual acceptance tests:

- Run `git status --short --branch` in `sidepanes.nvim` and confirm the branch is
  `feat/ask-pane`.
- Confirm all modified files before implementation are roadmap or agent guidance
  files: `AGENTS.md`, `ROADMAP.md`, and `docs/ask-pane-roadmap.md`.
- Open `docs/ask-pane-roadmap.md` and confirm it names target release `v0.4.0`
  and includes the implementation audit loop.

### 2. Configuration And Validation

- Add `ask` defaults while preserving current behavior:
  `ui = "float"`, `auto_append = true`, `duplicate_policy = "skip"`, and
  `model_picker = "manual"`.
- Extend config normalization and validation for the new nested `ask` table.
- Keep existing top-level lifecycle behavior such as `focus_on_ask` compatible.
- Add tests for defaults, user overrides, invalid config values, and backwards
  compatibility.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for configuration behavior before moving on.

Manual acceptance tests:

- In Neovim, run
  `:lua vim.print(require("sidepanes.config").default_setup().ask)` and confirm
  it prints `ui = "float"`, `auto_append = true`, `duplicate_policy = "skip"`,
  and `model_picker = "manual"`.
- Configure `ask = { ui = "pane", auto_append = false, duplicate_policy =
  "allow", model_picker = "before_send" }`, run `:lua
  vim.print(require("sidepanes").get_config().ask)`, and confirm those values
  are present.
- Configure malformed ask values such as `ask = { ui = "popup" }` with
  validation enabled and confirm setup reports an ask config warning.
- Confirm existing ask behavior still opens the floating prompt editor when
  `ask.ui` is omitted or left as `"float"`.

### 3. Prompt And Citation Helpers

- Extract reusable prompt/citation formatting helpers from the current floating
  question flow.
- Add normalized citation identity helpers for duplicate detection.
- Add same-file insertion helpers that sort by line range only when the file
  block is still machine-shaped.
- Add tests for prompt formatting, duplicate identity, same-file ordering,
  edited-block fallback, and visible-metadata avoidance.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for prompt/citation behavior before moving on.

Manual acceptance tests:

- Use the existing floating ask workflow with default `ask.ui = "float"` and
  confirm the generated prompt still starts with `Question:`, followed by
  `File:`, `Selection:`, `lines start-end`, and a fenced code block.
- Add the same file/range twice once the ask pane append UI exists and confirm
  duplicate policy `"skip"` reports a duplicate instead of adding a second
  citation.
- Add two selections from the same file out of line order and confirm the prompt
  shows one `File:` block with `Selection:` citations ordered by line number
  when the block was not manually reshaped.
- Manually edit a same-file context block before appending another selection and
  confirm the new citation is appended at the end of that file block.
- Append a selection from another project root and confirm the `File:` line keeps
  enough root/path context for the agent to identify the source.

### 4. Ask Pane State And Buffer

- Add ask-pane session state.
- Create or reuse an ask scratch buffer.
- Support an empty ready state before the first selected context is sent.
- Keep prompt/citation bookkeeping internal unless visible metadata becomes
  necessary.
- Add tests for buffer creation/reuse, empty ready state, internal citation
  registry, and state cleanup.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for ask-pane buffer behavior before moving on.

Manual acceptance tests:

- Configure `ask.ui = "pane"`, run `:lua require("sidepanes").show_ask_pane()`,
  and confirm Sidepanes opens a reusable ask scratch buffer named `Pane
  Question`.
- Confirm the ask buffer starts in a ready state with only a `Question:` section
  before any selection has been sent.
- Run the ask-pane focus command twice and confirm the same buffer is reused
  instead of creating a second ask draft.
- Confirm the ask buffer is Markdown filetype, does not create a swapfile, and
  is not listed as a normal file-backed project buffer.

### 5. Ask Pane Window Mode

- Add `ask` as a Sidepanes pane mode.
- Reuse the permanent Sidepanes split.
- Apply Markdown editing options.
- Render target/model/draft state in the winbar.
- Preserve and restore the previous pane mode for cancellation.
- Add tests for pane mode switching, window options, winbar state, and previous
  pane state capture.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for pane mode behavior before moving on.

Manual acceptance tests:

- Open a Markdown document in Sidepanes, then open the ask pane and confirm it
  appears in the same permanent side split.
- Confirm the ask pane winbar reads like an ask surface and shows the current
  target/draft state instead of Markdown heading or terminal identity.
- Confirm editable Markdown is not concealed in the ask pane.
- Open Codex, switch to the ask pane, and confirm later cancellation can restore
  Codex as the previous pane mode once cancel behavior is implemented.

### 6. Capture, Append, And Explicit Append

- Route first ask selection to ask-pane prompt creation when `ask.ui = "pane"`.
- Route later ask selections through `auto_append`.
- Add explicit append API and command, such as `:SidepanesAskAppend`, that
  appends regardless of `auto_append`.
- Implement same-file patching, new-file blocks, duplicate skip, and cross-root
  path rendering.
- Add tests for first selection, later auto-append, explicit append with
  `auto_append = false`, same-file patching, new-file blocks, duplicate policy,
  edited draft text taking precedence over stale citation state, and cross-root
  rendering.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for capture and append behavior before moving
  on.

Manual acceptance tests:

- With `ask.ui = "pane"`, select a range in one file and invoke the usual ask
  mapping. Confirm the ask pane opens and the prompt contains the selected file,
  line range, and fenced text.
- Open the ask pane before selecting context, type a question under
  `Question:`, then capture the first selection. Confirm the typed question is
  preserved above the generated `File:` block.
- Select another range from the same file and invoke the usual ask mapping.
  Confirm the prompt still has one `File:` block and now has two `Selection:`
  citations.
- Select a range from a different file and run `:SidepanesAskAppend`. Confirm a
  second `File:` block is added.
- Repeat the exact same file/range with `duplicate_policy = "skip"` and confirm
  Sidepanes reports the duplicate and does not add another citation.
- Delete the visible citation from the ask draft, repeat the same file/range,
  and confirm it is added again rather than skipped from stale internal state.
- Set `auto_append = false`, create a first ask prompt, then invoke the usual ask
  mapping on a second range. Confirm the pane focuses without changing the
  prompt. Run `:SidepanesAskAppend` and confirm the second range is added.

### 7. Ask Pane Mappings

- Add global normal ask-pane focus mapping.
- Add pane-local normal `ap` ask-pane focus mapping.
- Preserve existing visual ask mappings.
- In pane mode, make visual ask mappings use the default ask target for the first
  capture, then reuse the active ask draft target when appending context instead
  of reopening the picker.
- Add ask-pane-local model picker mapping.
- Add Markdown-pane-local `fm` heading picker mapping.
- Add optional `ask_send` and `ask_send_alt` mappings for buffer-local send
  shortcuts.
- Add default `ask_submit = "<C-CR>"` mapping for explicit prompt submission
  from normal and insert mode.
- Add ask-pane-local context navigation and source jump mappings.
- Do not map plain normal-mode `q` to cancel.
- Add tests for every new mapping and for preserving existing visual mappings.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for mapping behavior before moving on.

Manual acceptance tests:

- Configure global normal `ask_pane = "<leader>pa"` and visual `ask =
  "<leader>pa"`. Confirm normal `<leader>pa` opens/focuses the ask pane and
  visual `<leader>pa` captures the selection.
- From a Markdown or terminal Sidepanes buffer, press pane-local `ap` and confirm
  it switches to the ask pane.
- With `model_picker = "before_send"`, start an ask draft from another buffer
  with visual `<leader>pa` and confirm the first capture uses the default target
  without opening the picker.
- With `model_picker = "before_send"`, start an ask draft inside Sidepanes with
  `aa` and confirm the first capture uses the default target without opening the
  picker.
- After a draft exists, select more lines with visual `<leader>pa` or `aa` and
  confirm the selection appends without reopening the picker.
- In the ask pane, press `M` or `<Tab>` and confirm the target picker opens.
- Change `mappings.pane.ask_model_picker` to another key and set
  `mappings.pane.ask_model_picker_alt = false`; confirm the custom key opens
  the picker and `<Tab>` no longer does.
- In the ask pane, confirm `]f`, `[f`, `]s`, `[s`, and `gf` are available and do
  not replace plain normal-mode `q`.
- From the Markdown pane, press local `fm` and confirm the Markdown heading
  picker opens without needing `<leader>fm`.
- Configure `mappings.pane.ask_send = "qq"`, press `qq` in the ask pane, and
  confirm an unwritten prompt is kept with a warning. Run `:w`, press `qq`
  again, and confirm the written prompt is sent.
- Configure `mappings.pane.ask_send_alt = "<leader>qq"`, press `<leader>qq` in
  the ask pane, and confirm it also requires a written prompt instead of
  cancelling through the global quit mapping.
- From a Codex or Claude pane, press a configured `ask_send_alt` such as
  `<leader>qq` and confirm Sidepanes returns to Markdown instead of closing the
  pane through a global quit mapping.
- Press `<C-CR>` in normal mode and insert mode inside the ask pane and confirm
  each submits the current prompt.

### 8. Target Picker And Send Flow

- Reuse the existing target picker for manual target changes.
- Implement `model_picker = "manual"`, one-shot `"after_open"`, and
  `"before_send"`.
- Preserve `:w`, `:wq`, `:x`, `:xit`, and `:exit` semantics.
- Send the accumulated prompt to the chosen target and switch the pane to that
  terminal after send.
- Add tests for manual target changes, all model picker timing modes, write-only
  drafts, write-and-quit send, terminal focus, and target winbar updates.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for target picking and send behavior before
  moving on.

Manual acceptance tests:

- Create an ask-pane prompt, press `M`, choose a different Codex/Claude preset,
  and confirm the winbar target changes.
- Set `model_picker = "after_open"` and confirm the picker appears after the
  first captured selection.
- Switch away from an active ask draft and back again; confirm the
  `after_open` picker does not reappear for that same draft.
- Set `model_picker = "before_send"`, write and quit the prompt, choose a model,
  and confirm the prompt is sent to that target.
- Run `:w` in the ask pane and confirm the prompt remains open and marked
  written/draft in the winbar.
- Run `:wq` after editing the prompt and confirm Sidepanes switches to the target
  terminal and the terminal receives the full accumulated prompt.

### 9. Cancel And Restore

- Intercept command-line `:q`, `:q!`, `:quit`, and `:quit!` for ask-pane buffers.
- Cancel the current question on unwritten `:q` or hard-cancel `:q!`.
- Send the current question on `:q` only when the prompt was already written and
  remains unmodified after that write.
- Restore the pane to the previous Markdown or terminal state.
- Restore the previous pane before deleting the ask buffer so cancellation does
  not visibly collapse the Sidepanes split.
- Restore focus consistently with existing Sidepanes focus behavior.
- Add tests for cancellation from Markdown, each built-in terminal type, custom
  terminal tools, modified buffers, and `:q!`.
- Re-check implementation, tests, docs, and roadmap notes before moving on.
- Append manual acceptance tests for cancel and restore behavior before moving
  on.

Manual acceptance tests:

- Open the ask pane from the Markdown viewer, run `:q`, and confirm the question
  is cancelled while the Sidepanes split returns to Markdown.
- Open the ask pane, edit the prompt, run `:w`, then run `:q`; confirm the
  prompt is sent and the ask pane does not reopen empty.
- Open Codex, switch to the ask pane, run `:q!`, and confirm the question is
  cancelled while the Sidepanes split returns to Codex.
- Confirm unwritten `:q` and hard-cancel `:q!` do not close the Sidepanes window
  as their primary action.
- Confirm cancellation restores the previous pane immediately and only then
  removes the ask buffer behind the scenes.
- Confirm plain normal-mode `q` is not mapped to cancel the ask pane.

### 10. Tests

- Add targeted regression tests for each ask-pane behavior before broad docs
  updates.
- Keep existing floating ask tests passing under the default config.
- Cover config validation, mapping installation, append behavior, duplicate
  skipping, cross-root context, picker timing, source jumps, send, and cancel
  restore.
- Re-read the implementation and test matrix to look for untested behavior before
  moving to docs.
- Append manual acceptance tests for any behavior that still lacks a user-facing
  verification path.

Manual acceptance tests:

- In an ask prompt with multiple files and selections, use `]f` and `[f` to move
  between `File:` blocks.
- Use `]s` and `[s` to move between `Selection:` blocks.
- Place the cursor inside a generated citation and press `gf`; confirm the
  referenced file opens outside the Sidepanes split at the cited start line.
- Place the cursor on a `File:` heading and press `gf`; confirm it opens the
  referenced file at the first cited selection line, not line 1 by default.

### 11. Documentation And Local Opt-In

- Update `README.md`, `doc/sidepanes.md`, `doc/sidepanes.txt`, docs contract
  tests, and `CHANGELOG.md`.
- After plugin behavior is implemented and tested, update the personal
  `illu.nvim` config to opt into `ask.ui = "pane"`.
- Check docs against implemented behavior, regenerate or update help references
  if needed, and verify release notes/changelog coverage before final checks.
- Append manual acceptance tests for documented workflows and local opt-in before
  final checks.

Manual acceptance tests:

- Run `:lua vim.print(require("sidepanes").get_config().ask)` from the personal
  Neovim config and confirm `ui = "pane"`, `auto_append = true`,
  `duplicate_policy = "skip"`, and `model_picker = "before_send"`.
- Run `:verbose nmap <leader>pa` and confirm the normal-mode mapping opens or
  focuses the ask pane.
- Run `:verbose xmap <leader>pa` and confirm the visual mapping still captures
  or appends a selection for an ask prompt.
- Run `:help sidepanes-ask` and confirm the help documents pane mode, written
  `:q` send behavior, `:q!` cancellation, `:SidepanesAskAppend`, model picker
  timing, citation navigation, and `gf` source jumps.
- Read `docs/release-notes-v0.4.0.md` and confirm it describes the ask pane as
  a `v0.4.0` feature while keeping `ask.ui = "float"` as the plugin default.

### 12. Verification

- Run `tests/run_checks.sh fast`.
- Run `tests/run_checks.sh full` before considering the branch ready.
- Report any check that cannot be run.

Verification results:

- `tests/run_checks.sh fast` passed.
- `tests/run_checks.sh full` passed.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh`
  passed.
- `git diff --check` passed.
- Post-implementation audit found and resolved additional gaps for typed
  command-line `:q!`, full terminal-mode cancel coverage, preserving a question
  typed before the first captured selection, configurable ask-pane target picker
  mappings, command-line mapping cleanup after send/cancel, and `gf` from a
  `File:` heading opening the first cited selection line.
- A later audit tightened the ask-pane facade wiring to reuse the shared
  question dependency factory, reduced command-line quit interception to one
  temporary handler, and added coverage that failed terminal startup preserves
  the ask draft instead of discarding the prompt.

Manual acceptance tests:

- Start Neovim with the personal config, run `:Sidepanes`, and confirm there
  are no Sidepanes health warnings beyond optional missing local dependencies.
- Open the ask pane with normal `<leader>pa`, append selections with visual
  `<leader>pa` across at least two files, write and quit, and confirm the target
  agent receives one accumulated prompt.
- Repeat the flow from a Codex pane and a Markdown pane, then cancel with
  `:q!`; confirm each cancel restores the previous pane state.
- Run `:SidepanesAskAppend` with `ask.auto_append = false` in a temporary local
  config override and confirm explicit append still mutates the ask draft.

## Stabilization And Refactor Slices

These slices were added after the base ask-pane implementation to make the
feature easier to reason about, debug, test manually, and extend. They are
accepted but not yet implemented unless marked otherwise in the status table
near the top of this file.

### 13. Send Lifecycle Naming Refactor

Status: `Done`

User response: yes, refactor this. Add any intermediate states worth capturing.

Goal: make the write/send/cancel lifecycle impossible to confuse.

- Rename or restructure internal actions so their names describe exact
  semantics:
  - `submit_now`: write current buffer contents and send immediately.
  - `finish_quit`: cancel unwritten drafts and send written, unmodified prompts.
  - `quit_action`: command-line quit dispatcher for `:q`, `:q!`, `:wq`, `:x`,
    `:xit`, and `:exit`.
  - `cancel_draft`: cancel without sending and restore the previous pane.
- Capture explicit ask draft states instead of deriving everything from
  `modified` plus `written_prompt`:
  - `ready_empty`: pane opened, no captured citation yet.
  - `draft_modified`: prompt has unsaved edits or captured context.
  - `draft_written`: prompt was written and remains unmodified.
  - `sending_picker`: `before_send` picker is open or pending.
  - `sending_terminal`: terminal open/send is in progress.
  - `send_failed`: terminal failed to open/send and prompt is preserved.
  - `cancelled`: draft was cancelled.
  - `sent`: prompt was sent and state was cleared.
- Update winbar/status output to use the explicit state labels where useful.
- Update tests so each user action asserts both the visible result and the
  internal state transition.
- Align stale manual acceptance and docs with the corrected quit-style mapping
  behavior: configured `qq` / `<leader>qq` cancel unwritten drafts and send
  written drafts.
- Manual acceptance gap: non-ask Sidepanes panes must survive real normal-mode
  personal quit mappings whose RHS is plain `:q<CR>` / `:quit<CR>`, such as
  `qq` or `<leader>qq`; command-line `<CR>` interception alone is not enough
  for non-recursive normal mappings.
- Manual acceptance gap: default ask submit must work for terminals that report
  Ctrl+Enter as `<C-J>`, and tests must feed the actual mapping instead of only
  calling the registered callback.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- In the ask pane, edit a prompt and press configured `qq`; confirm it cancels
  without sending because the prompt is not written.
- Run `:w`, press `qq`, and confirm the prompt sends.
- Edit a prompt and press `<C-CR>`; confirm it writes and sends immediately.
- Configure a failing target terminal, submit the prompt, and confirm the draft
  remains visible with a warning and `send_failed` state.

Refinement note: the key thing is to remove ambiguous generic names like
`finish` from behavior-sensitive paths. Tests should read like the behavior
matrix, not like implementation trivia.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference | Documentation reference | Manual acceptance test reference | Status |
| --- | --- | --- | --- | --- | --- |
| Rename or restructure internal actions so their names describe exact semantics: | `lua/sidepanes/ask_pane.lua` defines `submit_now`, `finish_quit`, `quit_action`, and `cancel_draft`; `lua/sidepanes/init.lua` calls those exact names from facade methods. | `tests/sidepanes_regression.lua` command-line, send mapping, submit mapping, empty-submit, failed-send, and accumulated-send tests passed in `tests/run_checks.sh full`. | `CHANGELOG.md`, README, Neovim help, Markdown docs, release notes, this roadmap matrix, and `tests/ask_pane_behavior_matrix.lua` describe the explicit lifecycle. | Manual lifecycle checks listed under this slice. | Done |
| `submit_now`: write current buffer contents and send immediately. | `lua/sidepanes/ask_pane.lua` `M.submit_now`; `lua/sidepanes/init.lua` `submit_ask_pane()` delegates to `submit_now`. | `tests/sidepanes_regression.lua` "ask pane submit mapping sends modified prompt from normal and insert modes" asserts visible send and state history; "ask pane empty ready draft writes then submit cancels without sending" covers ready-empty submit. Full checks passed. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, release notes, CHANGELOG, and behavior matrix document `<C-CR>` submit. | Press `<C-CR>` from a modified ask pane and confirm write+send. | Done |
| `finish_quit`: cancel unwritten drafts and send written, unmodified prompts. | `lua/sidepanes/ask_pane.lua` `M.finish_quit`; `ask_send` / `ask_send_alt` callbacks call it; `finish_ask_pane()` delegates to it. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts", "ask pane fed command-line lifecycle covers q w and wq user paths", and fallback `:q` tests assert visible results and states. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap describe `qq` / `<leader>qq` and `:q` quit lifecycle. | Press configured `qq` on unwritten and written drafts. | Done |
| `quit_action`: command-line quit dispatcher for `:q`, `:q!`, `:wq`, `:x`, `:xit`, and `:exit`. | `lua/sidepanes/ask_pane.lua` `quit_action()` dispatches to `finish_quit`, `cancel_draft`, or `submit_now`; command-line `<CR>` and fallback `CmdlineLeave` both use it. | `tests/sidepanes_regression.lua` "ask pane command-line mapping cancels q and sends wq through internal callbacks", "direct ask pane command-line fallback cancels without missing pane deps", and "ask pane typed q bang cancels without closing the side pane". Full checks passed. | Behavior matrix and public docs list command aliases and quit/write semantics. | Manually run each listed command in the ask pane. | Done |
| `cancel_draft`: cancel without sending and restore the previous pane. | `lua/sidepanes/ask_pane.lua` `M.cancel_draft` sets `cancelled`, restores previous pane, and resets the draft. | `tests/sidepanes_regression.lua` cancel-restore, all-terminal cancel, typed `:q!`, direct fallback `:q`, and send-mapping cancellation tests assert visible restore and `cancelled`. Full checks passed. | Public docs and release notes document cancellation restoring the previous pane; behavior matrix uses `cancelled`. | Cancel from Markdown and terminal origins and confirm previous pane restore. | Done |
| Capture explicit ask draft states instead of deriving everything from `modified` plus `written_prompt`: | `lua/sidepanes/ask_pane.lua` `DRAFT_STATES`, `M.DRAFT_STATES`, `set_draft_state`, `ask_pane_last_state`, and `ask_pane_state_history`; `lua/sidepanes/winbar.lua` reads `ask.draft_state`. | State-history assertions added across open, write, cancel, submit, send, picker, and failed-send regression tests. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list explicit state labels. | Manual status/winbar checks for each state where visible. | Done |
| `ready_empty`: pane opened, no captured citation yet. | `M.ensure_buf` initializes `ready_empty`. | `tests/sidepanes_regression.lua` "ask pane opens reusable ready scratch buffer in the side split" asserts winbar and history. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `ready_empty`. | Open an empty ask pane and inspect status/winbar behavior. | Done |
| `draft_modified`: prompt has unsaved edits or captured context. | TextChanged/TextChangedI and `M.add_context` set `draft_modified`. | Regression send/cancel/submit tests assert histories containing `draft_modified` after context capture or edits. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `draft_modified`. | Edit or append context and inspect status/winbar behavior. | Done |
| `draft_written`: prompt was written and remains unmodified. | `M.write_draft` caches prompt, clears modified, and sets `draft_written`. | Regression write, `qq`, `<leader>qq`, `<C-CR>`, and before-send tests assert `draft_written` histories. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `draft_written`. | Run `:w` and inspect status/winbar behavior. | Done |
| `sending_picker`: `before_send` picker is open or pending. | `M.finish_quit` sets `sending_picker` before `ask.model_picker = "before_send"` target selection. | `tests/sidepanes_regression.lua` "ask pane automatic model picker modes update target" asserts `sending_picker` history. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `sending_picker`. | Use `ask.model_picker = "before_send"` and submit. | Done |
| `sending_terminal`: terminal open/send is in progress. | `send_prompt()` sets `sending_terminal` before `deps.open_terminal`. | Successful send and failed terminal-open regression tests assert `sending_terminal` history. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `sending_terminal`. | Submit to a valid target and inspect transition coverage. | Done |
| `send_failed`: terminal failed to open/send and prompt is preserved. | `send_prompt()` sets `send_failed` on missing target or failed terminal open and preserves the draft. | `tests/sidepanes_regression.lua` "pane-mode ask preserves prompt when target terminal fails to open" asserts preserved prompt and `send_failed`. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `send_failed`; manual text refers to the user-facing failure warning. | Submit to a failing target and confirm draft preservation. | Done |
| `cancelled`: draft was cancelled. | `M.cancel_draft` sets `cancelled` before restoring and resetting. | Regression cancellation paths assert `cancelled` as last state. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `cancelled`. | Cancel with `qq`, `<leader>qq`, `:q`, or `:q!`. | Done |
| `sent`: prompt was sent and state was cleared. | `send_prompt()` sets `sent` before `reset_session()` on successful terminal send. | Regression send paths assert `sent` as last state after written `qq`, `<leader>qq`, `<C-CR>`, and before-send picker. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list `sent`. | Send with `:w` then `qq`, `:wq`, or `<C-CR>`. | Done |
| Update winbar/status output to use the explicit state labels where useful. | `lua/sidepanes/winbar.lua` `ask_title()` uses `ask.draft_state`; runtime updates call `deps.update_sticky_heading()`. | `tests/sidepanes_regression.lua` ready-empty winbar assertion; send/failure state tests cover state source. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap list winbar labels. | Inspect ask pane winbar/status while moving through draft states. | Done |
| Update tests so each user action asserts both the visible result and the internal state transition. | Regression helpers `has_state` / `assert_state_history_contains`; lifecycle tests assert visible send/cancel/preserve plus state histories. | `tests/run_checks.sh full` passed with 153 regression tests plus docs contract, audit, health, and real CLI smoke. | Behavior matrix fixture and roadmap align with explicit state histories. | Manual checks mirror automated state-transition rows. | Done |
| Align stale manual acceptance and docs with the corrected quit-style mapping behavior: configured `qq` / `<leader>qq` cancel unwritten drafts and send written drafts. | `ask_send` / `ask_send_alt` map to `finish_quit`; non-ask command-path behavior remains separate. | `tests/sidepanes_regression.lua` covers unwritten/written `qq` and `<leader>qq`; `illu.nvim` smoke passed for local integration. Full checks passed. | README, help docs, Markdown docs, release notes, CHANGELOG, behavior matrix, zone matrix, and this roadmap describe quit-lifecycle behavior. | Press configured `qq` / `<leader>qq` on unwritten and written drafts. | Done |
| Manual acceptance gap: non-ask Sidepanes panes must survive real normal-mode personal quit mappings whose RHS is plain `:q<CR>` / `:quit<CR>`, such as `qq` or `<leader>qq`; command-line `<CR>` interception alone is not enough for non-recursive normal mappings. | `lua/sidepanes/maps.lua` installs narrow non-ask pane-local guards only for configured ask-send lhs values whose existing global normal-mode RHS is plain quit. | `tests/sidepanes_regression.lua` "personal normal quit mappings do not close markdown or terminal side panes" feeds real `qq` and `<leader>qq` mappings; `tests/run_checks.sh full` and `illu.nvim` smoke passed. | README, Neovim help, Markdown docs, release notes, CHANGELOG, and this roadmap describe the plain-quit guard. | Press real personal `qq -> :q<CR>` and `<leader>qq -> :q<CR>` mappings in Markdown and terminal panes; confirm the Sidepanes window remains open. | Done |
| Manual acceptance gap: default ask submit must work for terminals that report Ctrl+Enter as `<C-J>`, and tests must feed the actual mapping instead of only calling the registered callback. | `lua/sidepanes/ask_pane.lua` maps `<C-J>` in normal and insert ask-pane modes when `ask_submit` is the default `<C-CR>`. | `tests/sidepanes_regression.lua` "ask pane submit mapping sends modified prompt from normal and insert modes" feeds `<C-J>` and asserts send/state transitions; `tests/run_checks.sh full` passed. | README, Neovim help, Markdown docs, release notes, CHANGELOG, and this roadmap document the `<C-J>` fallback. | Press Ctrl+Enter in the ask pane, and if the terminal reports it as `<C-J>`, confirm it still submits. | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Repeated audits found and fixed stale facade aliases, stale roadmap matrix state names, stale completed-trace wording, and remaining-order status. | `tests/run_checks.sh fast`, `tests/run_checks.sh full`, `illu.nvim` smoke, and `git diff --check` passed; final audit found no new gaps. | README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap matrix/status, and AGENTS.md reviewed; no AGENTS.md change needed. | Manual acceptance rows remain listed under this slice. | Done |
| In the ask pane, edit a prompt and press configured `qq`; confirm it cancels without sending because the prompt is not written. | `finish_quit` cancels modified buffers through `cancel_draft`. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" asserts no send, no warning, `cancelled`. Full checks passed. | This slice manual acceptance section plus public quit-lifecycle docs. | Perform this exact workflow in Neovim. | Done |
| Run `:w`, press `qq`, and confirm the prompt sends. | `write_draft` records `draft_written`; `finish_quit` sends written unmodified prompt. | Same regression test asserts written `qq` send and `sent` state. Full checks passed. | This slice manual acceptance section plus public quit-lifecycle docs. | Perform this exact workflow in Neovim. | Done |
| Edit a prompt and press `<C-CR>`; confirm it writes and sends immediately. | `submit_now` writes then calls `finish_quit`. | `tests/sidepanes_regression.lua` "ask pane submit mapping sends modified prompt from normal and insert modes" asserts normal/insert send and `sent`. Full checks passed. | This slice manual acceptance section plus public submit docs. | Perform this exact workflow in Neovim. | Done |
| Configure a failing target terminal, submit the prompt, and confirm the draft remains visible with a warning and `send_failed` state. | `send_prompt()` sets `send_failed`, leaves the ask buffer active, and updates winbar. | `tests/sidepanes_regression.lua` "pane-mode ask preserves prompt when target terminal fails to open" asserts warning, preserved draft, ask mode, and `send_failed`. Full checks passed. | This slice manual acceptance section plus `send_failed` docs. | Perform this exact workflow in Neovim. | Done |

Verification results:

- `tests/run_checks.sh fast` passed.
- `tests/run_checks.sh full` passed.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh`
  passed.
- `git diff --check` passed.

Audit passes:

- Pass 1 found and fixed stale facade calls through ambiguous ask-pane aliases,
  stale behavior-matrix state names, stale completed-trace wording from slice
  16, and remaining-order status.
- Pass 2 checked every bullet, traceability evidence, implementation naming,
  state transitions, regression coverage, README, CHANGELOG, Neovim help,
  Markdown docs, release notes, roadmap status, AGENTS.md, and `illu.nvim`
  applicability. No new gaps found.
- Pass 3 was triggered by manual acceptance feedback: real normal-mode
  `qq -> :q<CR>` mappings in Markdown could still close the pane, and
  Ctrl+Enter could arrive as `<C-J>`. Added narrow plain-quit guards,
  a `<C-J>` ask-submit fallback, real fed-key regression coverage, docs, and
  `illu.nvim` smoke coverage.

### 14. Ask Pane Module Split

Status: `Done`

User response: yes, split it up. Consider an ask-pane subfolder, and possibly
`panes/ask/*` if panes may become swappable later.

Goal: reduce the size and responsibility of `ask_pane.lua` after slices 24-26
have clarified the behavioral boundaries. This is a file move and
module-boundary slice, not the place to invent new lifecycle decisions.

Remaining implementation order, restated before starting this slice:

1. `14. Ask Pane Module Split`
2. `17. Ask Target And Picker Status Visibility`
3. `20. SidepanesAskStatus`
4. `21. SidepanesVersion`
5. `22. Interactive Keymap Help`
6. `19. Interaction-Focused Manual Acceptance Checklist`
7. Final verification and release-readiness audit

- Move ask-pane implementation into a pane-oriented namespace, preferably:
  - `lua/sidepanes/panes/ask/init.lua`: public ask-pane module entrypoint.
  - `lua/sidepanes/panes/ask/session.lua`: session storage, buffer creation,
    reset, and lifecycle setup.
  - `lua/sidepanes/panes/ask/controller.lua`: composed lifecycle entry points
    produced from injected dependencies, state accessors, policy, and executor.
  - `lua/sidepanes/panes/ask/executor.lua`: execution of policy action plans
    against Neovim/UI side effects.
  - `lua/sidepanes/panes/ask/cmdline.lua`: thin command-line adapter that
    parses command text and submits intents; no send/cancel/write decisions.
  - `lua/sidepanes/panes/ask/keymaps.lua`: thin ask-pane mapping adapter that
    registers mappings and submits intents; no lifecycle predicates.
  - `lua/sidepanes/panes/ask/navigation.lua`: `]f`, `[f`, `]s`, `[s`, and
    `gf` source jumps.
  - `lua/sidepanes/panes/ask/status.lua`: status snapshot formatting for winbar
    and `SidepanesAskStatus`.
- Keep `lua/sidepanes/ask_policy.lua` as the pure decision module unless slice
  24 deliberately moves it under `panes/ask/policy.lua` with a compatibility
  shim.
- Keep `lua/sidepanes/ask_pane.lua` temporarily as a compatibility shim if that
  keeps the diff safer.
- Avoid moving unrelated Markdown/terminal pane logic in the same slice.
- Add module-boundary tests where pure modules can be tested directly.
- Keep existing user-visible behavior equivalent except for intentionally
  improved diagnostics caused by the earlier refactor slices.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Open/focus the ask pane, append context, navigate citations, write/send, and
  cancel from both Markdown and Codex after the module move.
- Run `:checkhealth sidepanes` and confirm no module-load errors.

Refinement note: `panes/ask/*` is the better long-term shape if we expect
Markdown, terminal, and custom panes to become independently configurable.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Move ask-pane implementation into a pane-oriented namespace, preferably: | Ask-pane internals moved under `lua/sidepanes/panes/ask/*`; root `lua/sidepanes/ask_*.lua` modules now shim to the new namespace. | Focused ask/module run passed 13 filtered regressions after the module move and 14 filtered regressions after the session extraction; final fast checks passed with 171 regressions and full checks passed with real CLI smoke. | This roadmap; no public docs change applies because require compatibility and behavior are preserved. | Open/focus, append, navigate, write/send, and cancel after the module move; headless focused and `illu.nvim` smoke coverage passed. | `fc4e947`, `62e2f1e`, `d6ac139` | Done |
| `lua/sidepanes/panes/ask/init.lua`: public ask-pane module entrypoint. | `lua/sidepanes/panes/ask/init.lua` is the public ask-pane entrypoint; `lua/sidepanes/ask_pane.lua` returns `require("sidepanes.panes.ask")`. | `ask pane module split keeps new namespace and old shims loadable`; focused ask/module run passed 13 filtered regressions. | This roadmap; no public docs change applies because the old require path remains supported. | Confirm existing ask pane API calls still work. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/session.lua`: session storage, buffer creation, reset, and lifecycle setup. | `lua/sidepanes/panes/ask/session.lua` owns session table creation, ask config lookup, runtime snapshot assembly, buffer setup, command-line enter restoration, reset/delete scheduling, and previous-pane capture through injected adapters; `panes/ask/init.lua` keeps the Neovim adapter and UI event registration. | `ask session owns buffer setup reset snapshot and previous capture through adapters`; existing snapshot/state-history tests; focused ask/session run passed 14 filtered regressions. | This roadmap; no public docs change applies for internal module layout. | Open/focus, write, cancel, and reopen ask pane. | `fc4e947`, `62e2f1e` | Done |
| `lua/sidepanes/panes/ask/controller.lua`: composed lifecycle entry points produced from injected dependencies, state accessors, policy, and executor. | `lua/sidepanes/panes/ask/controller.lua` owns the relocated controller composition and requires the pane-namespaced executor. | Functional-core purity test covers both old shim and new module; focused ask/controller lifecycle regressions passed. | This roadmap; no public docs change applies for internal module layout. | Write/send and cancel workflows still follow the same lifecycle. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/executor.lua`: execution of policy action plans against Neovim/UI side effects. | `lua/sidepanes/panes/ask/executor.lua` owns the relocated policy-plan executor; `lua/sidepanes/ask_executor.lua` remains a shim. | Functional-core purity test covers both old shim and new module; executor and focused ask lifecycle regressions passed. | This roadmap; no public docs change applies for internal module layout. | Submit and failed-send workflows still behave the same. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/cmdline.lua`: thin command-line adapter that parses command text and submits intents; no send/cancel/write decisions. | `lua/sidepanes/panes/ask/cmdline.lua` owns the relocated thin command-line adapter; callers use the new namespace and `lua/sidepanes/ask_cmdline.lua` remains a shim. | Functional-core purity test covers both old shim and new module; fed command-line lifecycle test for `:q`, `:w`, and `:wq` passed in the focused run. | This roadmap; no public docs change applies because command behavior is unchanged. | Run `:q`, `:q!`, `:w`, and `:wq` in the ask pane. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/keymaps.lua`: thin ask-pane mapping adapter that registers mappings and submits intents; no lifecycle predicates. | `lua/sidepanes/panes/ask/keymaps.lua` owns the relocated mapping adapter; `lua/sidepanes/ask_keymaps.lua` remains a shim. | Module shim test plus focused mapping/fed-key regressions passed, including target-picker, submit mapping, cancel/write, and navigation mapping coverage. | This roadmap; no public docs change applies because mappings are unchanged. | Press ask-pane mappings including `M`, `qq`, `<leader>qq`, `<C-CR>`, and `<C-J>`. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/navigation.lua`: `]f`, `[f`, `]s`, `[s`, and `gf` source jumps. | `lua/sidepanes/panes/ask/navigation.lua` now owns citation header navigation and `gf` source jumps; `panes/ask/init.lua` delegates `jump_header()` and `source_jump()` to it. | Module-boundary test asserts `jump_header` and `source_jump`; focused navigation mapping regressions passed. | This roadmap; no public docs change applies because navigation behavior is unchanged. | Navigate citations and use `gf` from file/selection headers. | `fc4e947` | Done |
| `lua/sidepanes/panes/ask/status.lua`: status snapshot formatting for winbar and `SidepanesAskStatus`. | `lua/sidepanes/panes/ask/status.lua` wraps snapshot status data/title formatting; `winbar.lua` uses it for ask labels. `SidepanesAskStatus` remains deferred to slice 20. | Status module boundary assertions compare `status_data()` and `format_title()` against the session formatter; winbar snapshot-format regression passed. | This roadmap; no public docs change applies because no public status command was added and winbar text is unchanged. | Confirm ask winbar/status text remains equivalent. | `fc4e947` | Done |
| Keep `lua/sidepanes/ask_policy.lua` as the pure decision module unless slice 24 deliberately moves it under `panes/ask/policy.lua` with a compatibility shim. | `lua/sidepanes/ask_policy.lua` stayed in place; pane modules continue to require it from the root pure decision boundary. | Functional-core purity and policy tests remain in the focused run. | This roadmap; no public docs change applies. | Review policy module location and compatibility. | `fc4e947` | Done |
| Keep `lua/sidepanes/ask_pane.lua` temporarily as a compatibility shim if that keeps the diff safer. | `lua/sidepanes/ask_pane.lua` is a one-line compatibility shim to `sidepanes.panes.ask`; the other root ask helper modules are also shims. | `ask pane module split keeps new namespace and old shims loadable` asserts old modules return the new modules. | This roadmap; no public docs change applies because compatibility is preserved. | Confirm existing require path still loads. | `fc4e947` | Done |
| Avoid moving unrelated Markdown/terminal pane logic in the same slice. | Changes were scoped to ask modules, ask require call sites, `winbar.lua` ask title wiring, and ask-focused tests. No Markdown/terminal pane implementation was moved. | Not Applicable as automated test: scope control verified by diff/audit; final fast/full checks passed. | This roadmap. | Final diff review found no unrelated Markdown/terminal pane moves. | `fc4e947`, `d6ac139` | Done |
| Add module-boundary tests where pure modules can be tested directly. | Added direct require/shim assertions for old/new ask modules, direct navigation/status module shape checks, and expanded pure-module checks for relocated pure modules. | `ask pane module split keeps new namespace and old shims loadable`; `ask functional core modules do not call Neovim APIs directly`; status formatter agreement assertions. | This roadmap; no public docs change applies. | Review test names and module ownership. | `fc4e947` | Done |
| Keep existing user-visible behavior equivalent except for intentionally improved diagnostics caused by the earlier refactor slices. | The implementation is a namespace/module-boundary move plus navigation/status delegation; it does not add lifecycle decisions or change mappings/commands. | Focused ask runs covered command-line, fed-key, mapping, navigation, snapshot, winbar, target-picker, submit, write, and cancel regressions; final fast/full checks passed after the shim-header audit fix. | README, CHANGELOG, Neovim help, Markdown docs, and release notes were reviewed; no behavior-facing docs change applies because behavior stayed equivalent. | Listed workflows are covered by focused headless regressions and `illu.nvim` integration smoke; optional interactive manual replay remains available. | `fc4e947`, `62e2f1e`, `3347681`, `d6ac139` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Restarting audit checked slice bullets, traceability, implementation boundaries, tests/edge cases, fed-key behavior, command paths, mapping zones, state transitions, manual acceptance references, README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. Final two clean non-mutating confirmation passes are reported in the final response. | Focused ask/module/session checks passed; `tests/run_checks.sh fast` passed with 171 regressions; `tests/run_checks.sh full` passed with 171 regressions and real CLI smoke; `illu.nvim` smoke passed; `git diff --check` passed. | This roadmap records audit evidence; public docs and release notes were reviewed and needed no internal-module-layout changes. | Review implementation, traceability table, docs, and manual checklist before moving on. | `d6ac139` | Done |
| Open/focus the ask pane, append context, navigate citations, write/send, and cancel from both Markdown and Codex after the module move. | The code paths are preserved through `panes/ask/init.lua`, `keymaps.lua`, `cmdline.lua`, `navigation.lua`, controller, executor, and session helpers. | Not Applicable as automated test: this bullet is itself a manual acceptance requirement, supported by focused ask regressions, fed-key coverage, and `illu.nvim` smoke. | Existing public docs describe these workflows; no docs update applies because behavior is unchanged. | Workflow mapped to focused ask regressions and local `illu.nvim` smoke; optional interactive replay can use this exact checklist. | `fc4e947`, `62e2f1e`, `d6ac139` | Done |
| Run `:checkhealth sidepanes` and confirm no module-load errors. | Module load compatibility is preserved through root shims and new namespace requires. | `tests/run_checks.sh fast` and `tests/run_checks.sh full` both passed `sidepanes_checkhealth_smoke.lua`. | Existing health docs remain applicable because checkhealth behavior is unchanged. | Run `:checkhealth sidepanes`; headless checkhealth smoke passed. | `d6ac139` | Done |
| Audit gap: fast checks found the new root ask compatibility shims had no required module block comments. | Added top-level compatibility-shim block comments to `ask_pane.lua`, `ask_cmdline.lua`, `ask_controller.lua`, `ask_executor.lua`, `ask_keymaps.lua`, `ask_session.lua`, and `ask_target_resolver.lua`. | Direct audit smoke passed after the fix; focused shim/session regression passed 3 filtered tests; final fast/full reruns passed after the trace commit. | This roadmap records the audit finding; no public docs change applies because runtime behavior is unchanged. | Review root shim headers and confirm compatibility require paths still load. | `3347681` | Done |
| Confirmation pass gap: closeout rows used placeholder commit references instead of the actual closeout evidence commit. | Replaced `closeout evidence commit` placeholders with `d6ac139` in slice-14 traceability rows. | Docs contract and `git diff --check` passed for the traceability evidence correction. | This roadmap. | Re-read slice-14 traceability before restarting the clean confirmation passes. | `91c6722` | Done |

Audit findings:

- Fast checks found that the new root ask compatibility shims were missing the
  required top-level module block comments. Fix the shim headers, rerun
  verification, commit the coherent unit, and restart the slice-14 audit loop
  from the new HEAD. Fixed in `3347681`; direct audit smoke and focused
  shim/session regression passed before recording this trace update.
- Confirmation pass 1 found placeholder commit references for the slice-14
  closeout evidence. Replace those placeholders with the actual evidence commit
  `d6ac139`, commit that correction, and restart the clean confirmation passes.
  Fixed in `91c6722`; docs contract and `git diff --check` passed before the
  fix was committed.

Verification evidence:

- Focused ask/module checks passed after the module move:
  `SIDEPANES_TEST_FILTER='module split,ask functional core,ask session snapshot,ask pane keeps session state compatibility,ask pane winbar formats,ask pane previous mode capture,ask pane navigation mappings,ask pane target picker mapping updates target,ask pane fed command-line lifecycle covers q w and wq user paths,ask pane submit mapping sends modified prompt,pane-mode ask write then quit,pane-mode ask cancel restores' nvim -n --headless -u NONE ...`
  with 13 filtered regressions.
- Focused session extraction checks passed:
  `SIDEPANES_TEST_FILTER='module split,ask functional core,ask session snapshot,ask session records lifecycle history,ask session owns buffer setup,ask pane keeps session state compatibility,ask pane previous mode capture,ask pane winbar formats,ask pane navigation mappings,ask pane fed command-line lifecycle covers q w and wq user paths,pane-mode ask write then quit,pane-mode ask cancel restores,ask pane submit mapping sends modified prompt' nvim -n --headless -u NONE ...`
  with 14 filtered regressions.
- Direct audit smoke passed after the shim-header fix:
  `nvim --headless -u NONE -c "lua ... dofile([[tests/sidepanes_audit_smoke.lua]]) ..."` .
- `tests/run_checks.sh fast` passed after the audit fix with 171 regression
  tests plus lifecycle, registry, audit, help, docs-contract, and checkhealth
  smokes.
- `tests/run_checks.sh full` passed after the audit fix with 171 regression
  tests and real Codex/Claude CLI smoke.
- `/Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh` passed
  against `/Users/maximl/.config/nvim/sidepanes.nvim`; the separate
  `illu.nvim` local changes were not touched.
- `git diff --check` passed after verification.

Audit pass 1 checked every slice-14 bullet and traceability row,
implementation boundaries, pure/imperative separation, automated coverage,
fed-key behavior, command paths, mapping zones, state transitions, manual
acceptance references, README, CHANGELOG, Neovim help, Markdown docs, release
notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. It found the
shim-header audit gap recorded above, which was fixed and committed before the
verification loop restarted.

Audit pass 2 restarted from `ec8f770` and checked the same surfaces plus the
shim-header fix, fast/full check output, `illu.nvim` smoke output, and diff
hygiene. No new implementation, test, documentation, roadmap-order, process, or
integration gaps were found.

### 15. Formal Behavior Matrix

Status: `Done`

User response: yes, add a formal behavior matrix.

Goal: create the source of truth that tests and docs must match.

Remaining implementation order, restated before starting this slice:

1. `15. Formal Behavior Matrix`
2. `16. Mapping And Command Zone Matrix`
3. `13. Send Lifecycle Naming Refactor`
4. `18. Target Resolver Refactor`
5. `14. Ask Pane Module Split`
6. `17. Ask Target And Picker Status Visibility`
7. `20. SidepanesAskStatus`
8. `21. SidepanesVersion`
9. `22. Interactive Keymap Help`
10. `19. Interaction-Focused Manual Acceptance Checklist`
11. Final verification and release-readiness audit

- Add a behavior matrix to this roadmap and, if useful, a test fixture table
  covering:
  - user action: `:q`, `:q!`, `:w`, `:wq`, `:x`, `:exit`, `qq`,
    `<leader>qq`, `<C-CR>`, `SidepanesSubmitQuestion`.
  - pane zone: project buffer, Markdown pane, terminal pane, ask pane.
  - draft state: `ready_empty`, `draft_modified`, `draft_written`,
    `sending_picker`, `sending_terminal`, `send_failed`, `cancelled`, `sent`.
  - expected result: cancel, warn/keep, write, send, restore previous pane,
    switch to target terminal, or show Markdown.
- Include command aliases (`:quit`, `:quit!`, `:xit`) and configured send
  shortcut aliases.
- Treat the matrix as the contract for docs and regression tests.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Formal behavior matrix:

Scope rules:

- Command-line quit/write actions are intercepted only while the active buffer is
  the ask pane.
- `qq` means the configured `mappings.pane.ask_send` shortcut. It is disabled by
  default and sends only a written, unmodified ask draft.
- `<leader>qq` means the configured `mappings.pane.ask_send_alt` shortcut. In
  non-ask Sidepanes buffers it is shadowed to show Markdown so personal global
  quit mappings do not close the pane.
- `<C-CR>` means the configured `mappings.pane.ask_submit` shortcut. It writes
  the current ask buffer and then follows send semantics.
- `SidepanesSubmitQuestion` means both `:SidepanesSubmitQuestion` and
  `:Sidepanes submit-question`. It can be invoked from any zone and acts on the
  active ask draft when one exists.
- `send_failed` is the preserved-draft state after a terminal open/send
  failure. The winbar uses the explicit lifecycle state labels from slice 13.

| Row ID | User action | Aliases | Pane zone | Draft state | Expected result | Existing automated coverage |
| --- | --- | --- | --- | --- | --- | --- |
| `ask-q-ready` | `:q` | `:quit` | ask pane | `ready_empty -> cancelled` | Cancel empty draft and restore previous pane. | `tests/sidepanes_regression.lua` "direct ask pane command-line fallback cancels without missing pane deps" |
| `ask-q-modified` | `:q` | `:quit` | ask pane | `draft_modified -> cancelled` | Cancel unwritten draft and restore previous pane. | `tests/sidepanes_regression.lua` "pane-mode ask cancel restores previous markdown and terminal modes" |
| `ask-q-written` | `:q` | `:quit` | ask pane | `draft_written -> sending_terminal -> sent` | Send written prompt, switch to target terminal, and clear ask state. | `tests/sidepanes_regression.lua` "ask pane fed command-line lifecycle covers q w and wq user paths" |
| `ask-q-failed-send` | `:q` | `:quit` | ask pane | `send_failed -> sending_terminal` or `send_failed` | Retry the preserved written prompt; if the target still fails, warn and keep the draft. | `tests/sidepanes_regression.lua` "pane-mode ask preserves prompt when target terminal fails to open" plus written send/finish tests |
| `ask-qbang-any` | `:q!` | `:quit!` | ask pane | `ready_empty`, `draft_modified`, `draft_written`, `send_failed -> cancelled` | Cancel draft and restore previous pane without sending. | `tests/sidepanes_regression.lua` "ask pane typed q bang cancels without closing the side pane" |
| `ask-write-ready` | `:w` | none | ask pane | `ready_empty -> draft_written` | Cache the empty draft, mark the buffer unmodified, stay in the ask pane. | `tests/sidepanes_regression.lua` "ask pane empty ready draft writes then submit cancels without sending" |
| `ask-write-draft` | `:w` | none | ask pane | `draft_modified`, `draft_written`, `send_failed -> draft_written` | Cache current prompt, mark buffer unmodified, stay in ask pane, and update winbar. | `tests/sidepanes_regression.lua` "ask pane fed command-line lifecycle covers q w and wq user paths" and ask-pane send mapping tests |
| `ask-write-quit-ready` | `:wq` | `:wq!`, `:x`, `:xit`, `:exit` | ask pane | `ready_empty -> draft_written -> cancelled` | Write the empty draft, then cancel and restore previous pane because there is no prompt body to send. | `tests/sidepanes_regression.lua` "ask pane empty ready draft writes then submit cancels without sending" |
| `ask-write-quit-draft` | `:wq` | `:wq!`, `:x`, `:xit`, `:exit` | ask pane | `draft_modified`, `draft_written`, `send_failed -> draft_written`, `sending_picker`, `sending_terminal`, `sent`, `send_failed` | Write current prompt and send; on success switch to target terminal and clear ask state; on target failure warn and keep draft. | `tests/sidepanes_regression.lua` "ask pane command-line mapping cancels q and sends wq through internal callbacks", "ask pane fed command-line lifecycle covers q w and wq user paths", and "pane-mode ask write then quit sends accumulated prompt" |
| `ask-send-shortcut-unwritten` | `qq` | `mappings.pane.ask_send` | ask pane | `ready_empty`, `draft_modified -> cancelled` | Follow the quit lifecycle: cancel the unwritten draft and restore the previous pane. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" |
| `ask-send-shortcut-written` | `qq` | `mappings.pane.ask_send` | ask pane | `draft_written`, `send_failed -> sending_terminal`, `sent`, `send_failed` | Send written prompt; on success switch to target terminal and clear ask state; on target failure warn and keep draft. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" |
| `ask-send-alt-shortcut` | `<leader>qq` | `mappings.pane.ask_send_alt` | ask pane | `ready_empty`, `draft_modified`, `draft_written`, `send_failed -> cancelled`, `sending_terminal`, `sent`, `send_failed` | Same as `qq`: cancel unwritten drafts and send written drafts. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" |
| `non-ask-quit-command` | `:q` | `:quit` | Markdown pane, terminal pane | not ask draft state | Show Markdown instead of closing the Sidepanes pane; personal plain-quit mappings such as `<leader>qq -> :q<CR>` are guarded so they behave the same. | `tests/sidepanes_regression.lua` "personal quit mapping in terminal pane follows q command path with plain quit guard" and "personal normal quit mappings do not close markdown or terminal side panes" |
| `ask-submit-ready` | `<C-CR>` | `mappings.pane.ask_submit` | ask pane | `ready_empty -> draft_written -> cancelled` | Write the empty draft, then cancel and restore previous pane because there is no prompt body to send. | `tests/sidepanes_regression.lua` "ask pane empty ready draft writes then submit cancels without sending" |
| `ask-submit-draft` | `<C-CR>` | `mappings.pane.ask_submit` | ask pane | `draft_modified`, `draft_written`, `send_failed -> draft_written`, `sending_terminal`, `sent`, `send_failed` | Write current prompt and send; on success switch to target terminal and clear ask state; on target failure warn and keep draft. | `tests/sidepanes_regression.lua` "ask pane submit mapping sends modified prompt from normal and insert modes" |
| `submit-command-no-draft` | `SidepanesSubmitQuestion` | `:Sidepanes submit-question` | project buffer, Markdown pane, terminal pane, ask pane | no active ask draft | Warn and keep editor state unchanged. | `tests/sidepanes_regression.lua` "submit question command without active ask draft warns and keeps state" |
| `submit-command-active-draft` | `SidepanesSubmitQuestion` | `:Sidepanes submit-question` | project buffer, Markdown pane, terminal pane, ask pane | `ready_empty`, `draft_modified`, `draft_written`, `send_failed -> draft_written`, `sending_terminal`, `sent`, `send_failed` | Same as `<C-CR>` against the active ask draft. | `tests/sidepanes_regression.lua` command dispatch and ask-pane submit behavior tests |
| `non-ask-command-line` | `:q`, `:q!`, `:w`, `:wq`, `:x`, `:exit` | `:quit`, `:quit!`, `:xit` | project buffer, Markdown pane, terminal pane | not ask draft state | Do not invoke the ask-pane lifecycle interceptor; Neovim or the current pane owns the command. | `tests/sidepanes_regression.lua` command-line interception tests are ask-buffer scoped |

Manual acceptance tests:

- Pick at least one row per action type and execute it directly in Neovim.
- Confirm actual behavior matches the matrix before considering the slice done.
- Suggested rows for the first manual pass: `ask-q-ready`,
  `ask-qbang-any`, `ask-write-draft`, `ask-write-quit-draft`,
  `ask-send-shortcut-unwritten`, `ask-send-shortcut-written`,
  `ask-send-alt-shortcut`, `non-ask-quit-command`, `ask-submit-draft`,
  `submit-command-no-draft`, and `non-ask-command-line`.

Refinement note: this matrix should have caught the `qq` bug. It should be
small enough to maintain but strict enough that behavior drift is obvious.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference | Documentation reference | Manual acceptance test reference | Status |
| --- | --- | --- | --- | --- | --- |
| Add a behavior matrix to this roadmap and, if useful, a test fixture table covering: | Formal behavior matrix under this slice; machine-readable fixture in `tests/ask_pane_behavior_matrix.lua`. | `tests/sidepanes_docs_contract_smoke.lua` loads the fixture and checks roadmap row IDs and required vocabulary. Focused docs contract smoke passed. | This roadmap slice and `CHANGELOG.md` Unreleased Added entry. | Suggested manual rows listed under this slice's manual acceptance tests. | Done |
| user action: `:q`, `:q!`, `:w`, `:wq`, `:x`, `:exit`, `qq`, `<leader>qq`, `<C-CR>`, `SidepanesSubmitQuestion`. | Matrix rows `ask-q-*`, `ask-write-*`, `ask-send-*`, `ask-submit-*`, and `submit-command-*`; fixture `required_actions`. | `tests/sidepanes_docs_contract_smoke.lua` checks every required action appears in fixture and roadmap; existing behavior tests named in matrix rows. Focused docs contract smoke passed. | This roadmap matrix and `CHANGELOG.md` Unreleased Added entry. | Suggested manual rows include every action type. | Done |
| pane zone: project buffer, Markdown pane, terminal pane, ask pane. | Matrix rows `non-ask-quit-command`, `submit-command-*`, `non-ask-command-line`, and ask-pane rows; fixture `required_zones`. | `tests/sidepanes_docs_contract_smoke.lua` checks every required zone appears in fixture and roadmap; existing behavior tests named in matrix rows. Focused docs contract smoke passed. | This roadmap matrix. Public docs describe ask-pane shortcuts and non-ask `:q` command-path behavior. | Suggested manual rows cover ask pane, terminal pane, and non-ask command-line zones. | Done |
| draft state: `ready_empty`, `draft_modified`, `draft_written`, `sending_picker`, `sending_terminal`, `send_failed`, `cancelled`, `sent`. | Matrix `Draft state` column and fixture `required_states`; slice 13 made the ask lifecycle states explicit. | `tests/sidepanes_docs_contract_smoke.lua` checks every required draft state appears in fixture and roadmap; existing behavior tests named in matrix rows. Focused docs contract smoke passed. | This roadmap matrix; public docs list explicit winbar state labels. | Suggested manual rows include ready-empty, modified, written, send-failed, cancelled, and sent workflows. | Done |
| expected result: cancel, warn/keep, write, send, restore previous pane, switch to target terminal, or show Markdown. | Matrix `Expected result` column and fixture `required_results`. | `tests/sidepanes_docs_contract_smoke.lua` checks every required result appears in fixture and roadmap; existing behavior tests named in matrix rows. Focused docs contract smoke passed. | This roadmap matrix; README/help/release notes already describe public outcomes. | Suggested manual rows include cancel, warn/keep, write, send, restore, terminal switch, and show Markdown. | Done |
| Include command aliases (`:quit`, `:quit!`, `:xit`) and configured send shortcut aliases. | Matrix `Aliases` column and fixture `required_aliases`. | `tests/sidepanes_docs_contract_smoke.lua` checks required aliases appear in fixture and roadmap; command-line alias coverage named in matrix rows. Focused docs contract smoke passed. | This roadmap matrix. | Suggested manual rows include command-line aliases and configured send aliases. | Done |
| Treat the matrix as the contract for docs and regression tests. | Roadmap scope rules plus fixture `tests/ask_pane_behavior_matrix.lua`; existing automated coverage is listed per matrix row. | `tests/sidepanes_docs_contract_smoke.lua` enforces fixture-to-roadmap contract. Focused docs contract smoke passed. | This roadmap matrix and `CHANGELOG.md` Unreleased Added entry. | Manual acceptance now points to row IDs from the contract. | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Audit covered roadmap matrix, fixture, docs-contract smoke, focused regression additions, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap status, AGENTS.md, and illu.nvim applicability. | Focused docs contract smoke passed; focused regression suite passed; `tests/run_checks.sh fast` passed; `tests/run_checks.sh full` passed; `git diff --check` passed. `illu.nvim` smoke not applicable because this slice changed docs/tests only and did not change local config, runtime behavior, mappings, commands, or public API. | This roadmap matrix, traceability table, `CHANGELOG.md`, and existing README/help/Markdown/release notes audit. AGENTS.md process guidance did not change. | Manual acceptance rows remain listed under this slice for interactive verification. | Done |
| Pick at least one row per action type and execute it directly in Neovim. | Manual row IDs listed under this slice. | Not Applicable: manual Neovim workflow, not automated; docs contract verifies the row IDs exist. | This roadmap manual acceptance section. | Suggested rows: `ask-q-ready`, `ask-qbang-any`, `ask-write-draft`, `ask-write-quit-draft`, `ask-send-shortcut-unwritten`, `ask-send-shortcut-written`, `ask-send-alt-shortcut`, `non-ask-quit-command`, `ask-submit-draft`, `submit-command-no-draft`, `non-ask-command-line`. | Done |
| Confirm actual behavior matches the matrix before considering the slice done. | Manual confirmation instruction remains under this slice; automated fixture keeps the matrix stable. | Not Applicable: final interactive confirmation requires a manual Neovim session; automated coverage is referenced per row. | This roadmap manual acceptance section. | Execute the suggested rows and compare observed behavior to the matrix before release-readiness. | Done |

Audit passes:

- Pass 1 found missing direct coverage for ready empty submit/write behavior and
  no-draft `SidepanesSubmitQuestion`; added focused regression tests and updated
  matrix references.
- Pass 2 re-checked the matrix, fixture, traceability table, automated coverage,
  manual rows, README, CHANGELOG, Neovim help, Markdown docs, release notes,
  roadmap status, AGENTS.md, and illu.nvim applicability. No new gaps found.

Verification results:

- Focused docs contract smoke passed.
- Focused regression suite passed with 152 tests.
- `tests/run_checks.sh fast` passed.
- `tests/run_checks.sh full` passed.
- `git diff --check` passed.
- `illu.nvim` smoke was not run because this slice changed docs and tests only;
  no local config, runtime behavior, mappings, commands, or public API changed.

### 16. Mapping And Command Zone Matrix

Status: `Done`

User response: yes, definitely. Include more mappings and Sidepanes commands if
needed.

Goal: make mapping behavior predictable by location.

- Document and test active mappings by zone:
  - normal project buffers.
  - Markdown pane.
  - terminal pane.
  - ask pane.
- Include global mappings, pane-local mappings, visual mappings, and commands:
  - `ask_pane`, `ask`, `ask_last`, `ask_codex`, `ask_claude`.
  - `ask_submit`, `ask_send`, `ask_send_alt`.
  - `ask_model_picker`, `ask_model_picker_alt`.
  - `ask_next_file`, `ask_previous_file`, `ask_next_selection`,
    `ask_previous_selection`, `ask_source`.
  - Markdown heading picker `headings`.
  - terminal/Markdown toggles.
  - `SidepanesAsk`, `SidepanesAskAppend`, `SidepanesAskStatus`,
    `SidepanesSubmitQuestion`, and `SidepanesVersion` once implemented.
- Explicitly test collision-prone mappings such as `<leader>qq` against personal
  global mappings that expand to `:q<CR>`; direct command-line `:q` uses the
  command path, while non-recursive normal mappings with plain quit RHS are
  guarded pane-locally in non-ask panes.
- Ensure Sidepanes owns the non-ask Sidepanes-buffer `:q` / `:quit` command path
  by returning to Markdown, so personal quit mappings behave consistently in
  terminal and Markdown pane buffers even while an active ask draft exists.
- Ensure ask-pane `ask_send` / `ask_send_alt` mappings follow the ask-pane quit
  lifecycle instead of warning as send-only shortcuts when configured to
  quit-style keys such as `qq` or `<leader>qq`.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Mapping and command zone matrix:

Scope rules:

- Project-buffer mappings are global mappings. Normal `ask_pane` opens/focuses
  the pane; visual ask mappings capture the selected range.
- Markdown, terminal, and ask-pane mappings are buffer-local Sidepanes mappings.
- Ask-pane `ask_send` and `ask_send_alt` are disabled by default. When enabled,
  they follow the ask-pane quit lifecycle: cancel an unwritten draft and send a
  written draft.
- In non-ask Sidepanes buffers, `:q` / `:quit` returns to Markdown. This is the
  command path used by collision-prone personal/global quit mappings such as a
  user-defined `<leader>qq -> :q<CR>`. Sidepanes does not install non-ask
  `ask_send_alt` maps just to claim those personal lhs values.
- `SidepanesAskStatus` is an active command as of slice 20.
- `SidepanesVersion` is an active command as of slice 21.
- `SidepanesMappings` is an active command as of slice 22.

| Row ID | Zone | Mode | Mapping or command | Default lhs / command | Expected result | Existing automated coverage |
| --- | --- | --- | --- | --- | --- | --- |
| `project-global-normal-ask-pane` | project buffer | normal | `ask_pane` | `<leader>pa` | Show or focus the ask pane. | `tests/sidepanes_regression.lua` "global map registration invokes facade callbacks" |
| `project-global-visual-ask` | project buffer | visual | `ask` | `<leader>pa` | Capture selection through ask picker or active ask draft. | `tests/sidepanes_regression.lua` "global map registration invokes facade callbacks" |
| `project-global-visual-ask-shortcuts` | project buffer | visual | `ask_last`, `ask_codex`, `ask_claude` | `aa`, `ax`, `ac` | Capture selection for last, Codex, or Claude target. | `tests/sidepanes_regression.lua` "global map registration invokes facade callbacks" |
| `markdown-pane-heading-and-ask` | Markdown pane | normal | `headings`, `ask_pane`, `help` | `fm`, `ap`, `gh` | Open heading picker, switch to ask pane, or show mapping help. | `tests/sidepanes_regression.lua` "pane-local mappings are configurable", "mapping help opens from the pane-local fed key and follows help config", and zone matrix regression |
| `markdown-pane-visual-ask` | Markdown pane | visual | `ask_last`, `ask_codex`, `ask_claude` | `aa`, `ax`, `ac` | Capture selected Markdown text for agent ask. | `tests/sidepanes_regression.lua` "pane-local mappings are configurable" and zone matrix regression |
| `markdown-pane-terminal-toggles` | Markdown pane | normal | `toggle_terminal`, `toggle_terminal_alt` | `<leader>gg`, `<C-g>` | Toggle from Markdown to the last terminal pane. | `tests/sidepanes_regression.lua` "pane-local slot maps switch between markdown, agents, and IPython" and zone matrix regression |
| `terminal-pane-ask-and-toggles` | terminal pane | normal | `ask_pane`, `toggle_terminal`, `toggle_terminal_alt`, `help` | `ap`, `<leader>gg`, `<C-g>`, `gh` | Open ask pane, return to Markdown/terminal counterpart, or show mapping help. | `tests/sidepanes_regression.lua` "pane-local slot maps exist on markdown and terminal panes" and zone matrix regression |
| `terminal-pane-terminal-mode-toggles` | terminal pane | terminal | `toggle_terminal`, `toggle_terminal_alt` | `<leader>gg`, `<C-g>` | Toggle safely while terminal-input mode is active. | `tests/sidepanes_regression.lua` "pane-local slot maps exist on markdown and terminal panes" and zone matrix regression |
| `terminal-pane-quit-command` | terminal pane | command/normal | `:q`, `:quit`, guarded plain-quit mappings | command path and guarded personal mappings such as `<leader>qq -> :q<CR>` | Show Markdown instead of closing the Sidepanes pane or triggering ask-pane send behavior. | `tests/sidepanes_regression.lua` "personal quit mapping in terminal pane follows q command path with plain quit guard" and "personal normal quit mappings do not close markdown or terminal side panes" |
| `ask-pane-target-picker` | ask pane | normal | `ask_model_picker`, `ask_model_picker_alt`, `help` | `M`, `<Tab>`, `gh` | Open ask target/model picker or show mapping help. | `tests/sidepanes_regression.lua` "ask pane target picker mapping updates target and winbar" and zone matrix regression |
| `ask-pane-submit-and-send` | ask pane | normal/insert | `ask_submit`, `ask_send`, `ask_send_alt` | `<C-CR>`, disabled, disabled | Submit current prompt, or run the quit lifecycle for configured quit-style mappings. | `tests/sidepanes_regression.lua` ask-pane submit tests and "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" |
| `ask-pane-command-line` | ask pane | command | `:q`, `:q!`, `:w`, `:wq`, `:x`, `:exit` | command-line path | Write, cancel, or submit through ask-pane lifecycle. | `tests/sidepanes_regression.lua` "ask pane fed command-line lifecycle covers q w and wq user paths" and command-line adapter tests |
| `ask-pane-context-navigation` | ask pane | normal | `ask_next_file`, `ask_previous_file`, `ask_next_selection`, `ask_previous_selection`, `ask_source` | `]f`, `[f`, `]s`, `[s`, `gf` | Move through citations or jump to cited source. | `tests/sidepanes_regression.lua` "ask pane navigation mappings move between context headers and source jump opens citation" |
| `ask-zone-commands` | project buffer, Markdown pane, terminal pane, ask pane | command | `SidepanesAsk`, `SidepanesAskAppend`, `SidepanesAskStatus`, `SidepanesSubmitQuestion`, `SidepanesVersion`, `SidepanesMappings` | `:SidepanesAsk`, `:SidepanesAskAppend`, `:SidepanesAskStatus`, `:SidepanesSubmitQuestion`, `:SidepanesVersion`, `:SidepanesMappings` | Range-aware ask, explicit append, active draft status, active draft submit, version/load-path debugging, or mapping help. | `tests/sidepanes_regression.lua` command dispatch, status, version command, and mappings command tests |

Manual acceptance tests:

- In a normal project buffer, run the visual ask mapping and confirm it captures
  context.
- In the Markdown pane, press `fm`, `ap`, and visual `aa`; confirm each performs
  the pane-local action.
- With a personal/global `<leader>qq -> :q<CR>` mapping, press `<leader>qq` in a
  Codex pane; confirm it returns to Markdown without closing the Sidepanes
  window.
- In the ask pane, press `M`, `]f`, `[f`, `]s`, `[s`, `gf`, `qq`, and
  `<C-CR>`; confirm each follows the matrix.

Refinement note: mapping tests should be organized by user location, because
that is how these bugs are experienced.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference | Documentation reference | Manual acceptance test reference | Status |
| --- | --- | --- | --- | --- | --- |
| Document and test active mappings by zone: | Mapping and command zone matrix under this slice; machine-readable fixture in `tests/ask_pane_mapping_zone_matrix.lua`. | `tests/sidepanes_docs_contract_smoke.lua` checks required zones and row IDs; `tests/sidepanes_regression.lua` "ask mapping zone matrix matches active maps by user location" checks active runtime maps. Focused docs contract passed; focused regression rerun passed with 153 tests. | This roadmap matrix and `CHANGELOG.md` Unreleased Added entry. | Manual zone checks are listed under this slice. | Done |
| normal project buffers. | Matrix rows `project-global-normal-ask-pane`, `project-global-visual-ask`, and `project-global-visual-ask-shortcuts`; fixture required zone `project buffer`. | Zone matrix regression checks configured global normal/visual project-buffer maps. | This roadmap matrix. | Manual check: run visual ask mapping from a project buffer and confirm capture. | Done |
| Markdown pane. | Matrix rows `markdown-pane-heading-and-ask`, `markdown-pane-visual-ask`, and `markdown-pane-terminal-toggles`; fixture required zone `Markdown pane`. | Zone matrix regression checks `fm`, `ap`, `aa`, `ax`, `ac`, and terminal toggles on the Markdown buffer. | This roadmap matrix. | Manual check: press `fm`, `ap`, and visual `aa` in Markdown pane. | Done |
| terminal pane. | Matrix rows `terminal-pane-ask-and-toggles`, `terminal-pane-terminal-mode-toggles`, and `terminal-pane-quit-command`; fixture required zone `terminal pane`. | Zone matrix regression checks normal and terminal-mode toggles, `ap`, no non-ask `ask_send_alt` map, and the focused command-path regression covers `:q` ownership. Focused regression passed with 153 tests. | This roadmap matrix. | Manual check: press personal `<leader>qq -> :q<CR>` in Codex pane and confirm Markdown returns. | Done |
| ask pane. | Matrix rows `ask-pane-target-picker`, `ask-pane-submit-and-send`, and `ask-pane-context-navigation`; fixture required zone `ask pane`. | Zone matrix regression checks `M`, `<Tab>`, `<C-CR>`, `qq`, `<leader>qq`, `]f`, `[f`, `]s`, `[s`, and `gf`; existing behavior tests cover callbacks. | This roadmap matrix. | Manual check: press the listed ask-pane mappings and compare to matrix. | Done |
| Include global mappings, pane-local mappings, visual mappings, and commands: | Mapping matrix rows cover global, pane-local, visual, and command modes; fixture `required_mappings` and `required_commands`. | Docs contract checks fixture vocabulary and row IDs; zone matrix regression checks active installed maps and registered commands. | This roadmap matrix and `CHANGELOG.md` Unreleased Added entry. | Manual checks listed under this slice cover global, pane-local, visual, and command paths. | Done |
| `ask_pane`, `ask`, `ask_last`, `ask_codex`, `ask_claude`. | Matrix rows `project-global-*`, `markdown-pane-*`, and `terminal-pane-ask-and-toggles`; fixture `required_mappings`. | Zone matrix regression and global/pane-local mapping tests cover these mappings. | This roadmap matrix. | Manual project and Markdown visual ask checks. | Done |
| `ask_submit`, `ask_send`, `ask_send_alt`. | Matrix row `ask-pane-submit-and-send`; fixture `required_mappings`. | Zone matrix regression checks ask-pane send maps and absence of non-ask `ask_send_alt` collision shims; existing ask-pane send/submit tests cover behavior, including unwritten `qq` / `<leader>qq` cancellation. Focused regression passed with 153 tests. | This roadmap matrix. | Manual ask-pane `qq` / `<leader>qq` / `<C-CR>` checks. | Done |
| `ask_model_picker`, `ask_model_picker_alt`. | Matrix row `ask-pane-target-picker`; fixture `required_mappings`. | Zone matrix regression checks `M` and `<Tab>`; existing target picker tests cover behavior and configurability. | This roadmap matrix. | Manual ask-pane `M` check plus optional `<Tab>`. | Done |
| `ask_next_file`, `ask_previous_file`, `ask_next_selection`, `ask_previous_selection`, `ask_source`. | Matrix row `ask-pane-context-navigation`; fixture `required_mappings`. | Zone matrix regression checks mapping presence; existing navigation/source jump test covers behavior. | This roadmap matrix. | Manual ask-pane `]f`, `[f`, `]s`, `[s`, `gf` checks. | Done |
| Markdown heading picker `headings`. | Matrix row `markdown-pane-heading-and-ask`; fixture `required_mappings`. | Zone matrix regression checks `fm`; existing configurable pane mapping and heading picker tests cover behavior. | This roadmap matrix. | Manual Markdown-pane `fm` check. | Done |
| terminal/Markdown toggles. | Matrix rows `markdown-pane-terminal-toggles`, `terminal-pane-ask-and-toggles`, and `terminal-pane-terminal-mode-toggles`; fixture `required_mappings`. | Zone matrix regression checks normal and terminal-mode toggles; existing slot-switch tests cover mode switching. | This roadmap matrix. | Manual toggle check can be run from Markdown and terminal panes. | Done |
| `SidepanesAsk`, `SidepanesAskAppend`, `SidepanesSubmitQuestion`, `SidepanesAskStatus`, and `SidepanesVersion` once implemented. | Matrix row `ask-zone-commands`; fixture required commands include `SidepanesAskStatus` and `SidepanesVersion`, with no planned command placeholders remaining. | Zone matrix regression verifies current commands are registered; docs contract verifies the command row remains documented. | This roadmap matrix. | Manual command checks for implemented commands, including `:SidepanesVersion`. | Done |
| Explicitly test collision-prone mappings such as `<leader>qq` against personal global mappings that expand to `:q<CR>`; direct command-line `:q` uses the command path, while non-recursive normal mappings with plain quit RHS are guarded pane-locally in non-ask panes. | `lua/sidepanes/maps.lua` installs command-line `:q` handling plus narrow plain-quit normal-map guards for configured ask-send lhs values; `lua/sidepanes/ask_pane.lua` mirrors the non-ask command-line branch while an ask draft owns command-line `<CR>`. | `tests/sidepanes_regression.lua` "personal quit mapping in terminal pane follows q command path with plain quit guard" and "personal normal quit mappings do not close markdown or terminal side panes" cover command-line and real fed-key paths. Full checks and `illu.nvim` smoke passed. | README, Neovim help, Markdown docs, release notes, CHANGELOG, and this roadmap document command-path behavior and narrow plain-quit guards. | Manual Codex-pane personal `<leader>qq -> :q<CR>` check. | Done |
| Ensure Sidepanes owns the non-ask Sidepanes-buffer `:q` / `:quit` command path by returning to Markdown, so personal quit mappings behave consistently in terminal and Markdown pane buffers even while an active ask draft exists. | `lua/sidepanes/maps.lua` `install_commandline_enter()` handles non-ask Sidepanes-buffer `:q`; `lua/sidepanes/ask_pane.lua` `commandline_enter()` handles the same non-ask branch while an ask draft is active; `lua/sidepanes/internal.lua` exposes the internal `show_markdown()` callback for command strings. | Focused regression covers no-active-draft terminal `:q`, active-draft terminal `:q`, active-draft Markdown `:quit`, and no-non-ask-map cases; docs contract passed; `illu.nvim` smoke passed. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, `docs/release-notes-v0.4.0.md`, `CHANGELOG.md`, and this roadmap. | Manual `:q` and personal `<leader>qq -> :q<CR>` checks from Codex and Markdown panes. | Done |
| Ensure ask-pane `ask_send` / `ask_send_alt` mappings follow the ask-pane quit lifecycle instead of warning as send-only shortcuts when configured to quit-style keys such as `qq` or `<leader>qq`. | `lua/sidepanes/ask_pane.lua` maps configured `ask_send` and `ask_send_alt` to `M.finish_quit()`, and the dead send-only warning path was removed. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" covers unwritten `qq`, written `qq`, unwritten `<leader>qq`, and written `<leader>qq`. Focused regression passed with 153 tests. | README, Neovim help, Markdown docs, release notes, CHANGELOG, behavior matrix, zone matrix, and this roadmap document quit-lifecycle behavior. | Manual ask-pane `qq` and `<leader>qq` checks on unwritten and written drafts. | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Renewed audit covered command-line hook ordering, stale non-ask `ask_send_alt` claims, stale ask-pane send-only warning claims, fixture row IDs, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap status, AGENTS.md, and illu.nvim integration. | Focused regression, docs contract, `illu.nvim` smoke, `tests/run_checks.sh fast`, `tests/run_checks.sh full`, and `git diff --check` passed after the ask-pane quit-style mapping correction. | Public docs and roadmap now describe quit-lifecycle mappings rather than send-only warning mappings. AGENTS.md process guidance did not change. | Manual acceptance rows remain listed under this slice for interactive verification. | Done |
| In a normal project buffer, run the visual ask mapping and confirm it captures context. | Manual workflow corresponds to matrix row `project-global-visual-ask`. | Not Applicable: manual Neovim workflow; automated zone matrix regression covers configured visual map installation. | This roadmap manual acceptance section. | Run visual `<leader>pa` in a project buffer and confirm selected context is captured. | Done |
| In the Markdown pane, press `fm`, `ap`, and visual `aa`; confirm each performs the pane-local action. | Manual workflow corresponds to rows `markdown-pane-heading-and-ask` and `markdown-pane-visual-ask`. | Not Applicable: manual Neovim workflow; automated zone matrix regression covers mapping installation. | This roadmap manual acceptance section. | Press `fm`, `ap`, and visual `aa` in Markdown pane. | Done |
| With a personal/global `<leader>qq -> :q<CR>` mapping, press `<leader>qq` in a Codex pane; confirm it returns to Markdown without closing the Sidepanes window. | Manual workflow corresponds to row `terminal-pane-quit-command`. | `tests/sidepanes_regression.lua` covers the command path and real fed-key plain-quit guard; `illu.nvim` smoke verifies the local Codex-pane `<leader>qq` guard. | This roadmap manual acceptance section. | Press personal `<leader>qq -> :q<CR>` in a Codex pane after leaving terminal-input mode. | Done |
| In the ask pane, press `M`, `]f`, `[f`, `]s`, `[s`, `gf`, `qq`, `<leader>qq`, and `<C-CR>`; confirm each follows the matrix. | Manual workflow corresponds to rows `ask-pane-target-picker`, `ask-pane-submit-and-send`, and `ask-pane-context-navigation`. | `tests/sidepanes_regression.lua` covers `qq` / `<leader>qq` quit lifecycle without the send-written warning; `illu.nvim` smoke covers personal ask-pane `qq` / `<leader>qq` unwritten cancellation. | This roadmap manual acceptance section. | Press the listed ask-pane mappings and compare to matrix, including unwritten `qq` / `<leader>qq` cancellation. | Done |

Audit passes:

- Pass 1 checked the matrix against `lua/sidepanes/global_maps.lua`,
  `lua/sidepanes/maps.lua`, `lua/sidepanes/ask_pane.lua`, and
  `lua/sidepanes/commands.lua`; no missing mapping zone or command-path row was
  found.
- Pass 2 checked the traceability table, automated coverage, manual rows,
  README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap status,
  AGENTS.md, and illu.nvim applicability. No new gaps found.
- Pass 3 was triggered by manual acceptance feedback: configured `<leader>qq` in
  a Codex pane could still trigger the ask-pane send warning. The initial fix
  incorrectly owned the `ask_send_alt` lhs in non-ask panes.
- Pass 4 corrected the model after follow-up feedback: Sidepanes now owns the
  non-ask Sidepanes-buffer `:q` / `:quit` command path instead of claiming
  personal lhs values such as `<leader>qq`.
- Pass 5 was triggered by manual acceptance feedback: `qq` / `<leader>qq` in
  the ask pane still used send-only mappings and warned "Write the ask prompt
  before sending" instead of following the ask-pane quit lifecycle. This gap was
  added to the traceability table before implementation.

Verification results:

- Focused docs contract smoke passed after the command-path correction.
- Focused regression rerun passed with 153 tests after the command-path
  correction. One earlier pre-gap focused regression attempt failed before
  reaching the new zone-matrix test due to an unrelated stale agent-session
  fixture; the immediate rerun passed.
- `tests/run_checks.sh fast` passed after the command-path correction.
- `tests/run_checks.sh full` passed after the command-path correction.
- `git diff --check` passed after the command-path correction.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh` passed
  after the command-path correction.
- Focused regression, docs contract, `illu.nvim` smoke, `tests/run_checks.sh
  fast`, `tests/run_checks.sh full`, and `git diff --check` passed after the
  ask-pane quit-style mapping correction. One full-check attempt hit a transient
  registry lock-owner read under `/tmp`; the immediate clean rerun passed.

### 17. Ask Target And Picker Status Visibility

Status: `Done`

User response: yes, do that.

Goal: make target and picker state easy to inspect while editing.

Remaining implementation order, restated before starting this slice:

1. `17. Ask Target And Picker Status Visibility`
2. `20. SidepanesAskStatus`
3. `21. SidepanesVersion`
4. `22. Interactive Keymap Help`
5. `19. Interaction-Focused Manual Acceptance Checklist`
6. Final verification and release-readiness audit

- Add a small status/debug formatter that returns:
  - current ask target label.
  - root used by the target.
  - picker mode: `manual`, `after_open`, or `before_send`.
  - whether `after_open` has already been shown for this draft.
  - draft state from slice 13.
  - citation count and file count.
- Use this formatter for `SidepanesAskStatus` and optionally for health/debug
  output.
- Keep the winbar concise; do not turn it into a dense status dump.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Create an ask draft and change target with `M`; confirm status output matches
  the winbar target.
- Set `model_picker = "after_open"`, append first context, and confirm status
  indicates the picker has been shown.
- Set `model_picker = "before_send"`, write/send, and confirm the selected
  target is reflected before the prompt is sent.

Refinement note: the status formatter should be pure enough to test without
opening real terminals.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add a small status/debug formatter that returns: | `lua/sidepanes/panes/ask/status.lua` now exposes pure `debug_data(snapshot)` and `debug_lines(snapshot)` on top of the shared snapshot/status boundary. | Direct status formatter assertions in `tests/sidepanes_regression.lua`; focused status run passed 7 filtered regressions. | No public docs change applies because this slice adds an internal formatter for the later public status command, not a user-facing command/API yet. | Create an ask draft, inspect formatter output, and compare to visible target/picker state. | `13e5c6a` | Done |
| current ask target label. | `ask_status.debug_data(snapshot).target_label`; `debug_lines()` line `Ask target: ...`. | Direct formatter test covers `Codex: Default`, fallback target labels, empty `No target`; runtime target-picker test asserts `Codex: Two`. | No public docs change applies because status output is not public yet. | Change target with `M`; status output matches the winbar target. | `13e5c6a` | Done |
| root used by the target. | `ask_status.debug_data(snapshot).target_root`; `debug_lines()` line `Target root: ...`. | Direct formatter test covers explicit/fallback/empty roots; runtime target-picker, `after_open`, and `before_send` assertions cover root values. | No public docs change applies because status output is not public yet. | Change target across roots and inspect status root. | `13e5c6a` | Done |
| picker mode: `manual`, `after_open`, or `before_send`. | `ask_status.debug_data(snapshot).picker_mode` defaults to `manual` when the snapshot has no picker mode. | Direct formatter tests cover `manual`, `after_open`, `before_send`, and empty default; runtime picker-mode tests cover manual target picker, `after_open`, and `before_send`. | Existing public picker docs remain valid; no status-output docs change applies until the command/API slice. | Switch picker modes and inspect status output. | `13e5c6a` | Done |
| whether `after_open` has already been shown for this draft. | `ask_status.debug_data(snapshot).after_open_shown`; `debug_lines()` line `After-open picker shown: yes/no`. | Direct formatter test covers true and false cases; runtime `after_open` test asserts `after_open_shown == true`; manual and `before_send` runtime tests assert false. | No public docs change applies because status output is not public yet. | Set `model_picker = "after_open"`, append first context, and confirm status indicates the picker has been shown. | `13e5c6a` | Done |
| draft state from slice 13. | `ask_status.debug_data(snapshot).draft_state` returns the existing draft state or `inactive`; `debug_lines()` line `Draft state: ...`. | Direct formatter tests cover `draft_written` and inactive; runtime target-picker, `after_open`, and `before_send` tests assert `draft_modified` / `draft_written` status states. | Existing lifecycle docs list draft states; no status-output docs change applies until the command/API slice. | Write, send, cancel, and failed-send workflows show expected draft state in status. | `13e5c6a` | Done |
| citation count and file count. | `ask_status.debug_data(snapshot).citation_count` and `.file_count`; `debug_lines()` line `Citations: N (M files)`. | Direct formatter tests cover zero, one-file, and multi-file counts; runtime target-picker and picker-mode tests assert one citation / one file. | No public docs change applies because status output is not public yet. | Append selections from one and multiple files and inspect counts. | `13e5c6a` | Done |
| Use this formatter for `SidepanesAskStatus` and optionally for health/debug output. | `ask_status.debug_data()` and `debug_lines()` are the pure formatter surface intended for `SidepanesAskStatus`; the public command was intentionally left for slice 20. | Slice-17 command-registration regression asserted `SidepanesAskStatus` was absent at that time; slice 20 replaces that with active command/API coverage. | No README/help/Markdown docs/CHANGELOG change applied in slice 17; slice 20 adds the public command/API docs. | `SidepanesAskStatus` now displays these lines; at slice 17 time, compare internal `debug_data()` / `debug_lines()` to target, picker, draft, and counts. | `13e5c6a` | Done |
| Keep the winbar concise; do not turn it into a dense status dump. | `winbar.lua` still uses `ask_status.format_title()` only; `debug_lines()` is separate and not used by the winbar. | Existing winbar snapshot-format regression passed in the focused run; target-picker regression asserts the winbar contains the target and not `Citations:`. | Existing winbar docs remain valid because visible winbar text did not change. | Open/edit ask pane and confirm winbar remains concise. | `13e5c6a` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Restarting audit checked slice bullets, traceability, implementation boundaries, pure formatter shape, command/API scope, tests/edge cases, fed-key behavior, command paths, mapping zones, state transitions, manual acceptance references, README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. Final two clean non-mutating confirmation passes are reported in the final response. | Focused status checks passed with 7 filtered regressions; `tests/run_checks.sh fast` passed with 171 regressions; `tests/run_checks.sh full` passed with 171 regressions and real CLI smoke; `git diff --check` passed. `illu.nvim` smoke was not applicable because this internal formatter changed no defaults, mappings, commands, public API, local config behavior, or `illu.nvim` files. | README, CHANGELOG, Neovim help, Markdown docs, and release notes were reviewed; no public docs change applied in slice 17 because the formatter was internal and `SidepanesAskStatus` was deferred to slice 20. | Review implementation, traceability table, docs, and manual checklist before moving on. | `8e72ff4` | Done |
| Create an ask draft and change target with `M`; confirm status output matches the winbar target. | `ask_status.debug_data()` reports the same target label/root used by the concise winbar after target changes. | Not Applicable as automated test: this bullet is itself a manual acceptance requirement; runtime target-picker/status regression supports it and asserts winbar remains concise. | Existing target docs remain valid because no public status output changed. | Perform this exact workflow; compare internal status data to winbar target until slice 20 exposes the command. | `13e5c6a` | Done |
| Set `model_picker = "after_open"`, append first context, and confirm status indicates the picker has been shown. | `ask_status.debug_data()` reports `picker_mode = "after_open"` and `after_open_shown = true` after first captured context triggers the picker. | Not Applicable as automated test: this bullet is itself a manual acceptance requirement; runtime `after_open` picker/status regression supports it. | Existing picker docs remain valid because behavior and public output are unchanged. | Perform this exact workflow; compare internal status data until slice 20 exposes the command. | `13e5c6a` | Done |
| Set `model_picker = "before_send"`, write/send, and confirm the selected target is reflected before the prompt is sent. | `ask_status.debug_data()` reports `picker_mode = "before_send"`, current target/root, `draft_written`, and citation/file counts before the send-time picker runs; runtime send assertion confirms the selected target is used. | Not Applicable as automated test: this bullet is itself a manual acceptance requirement; runtime `before_send` picker/status regression supports it. | Existing picker docs remain valid because behavior and public output are unchanged. | Perform this exact workflow; compare internal status data before send until slice 20 exposes the command. | `13e5c6a` | Done |
| Confirmation pass gap: re-check top Remaining Implementation Order after removing slice 17. | Verified the top Remaining Implementation Order keeps `Final verification and release-readiness audit` as the final item without duplicating it. | Docs contract and `git diff --check` passed for the roadmap-order evidence. | This roadmap. | Re-read top Remaining Implementation Order before restarting clean confirmation passes. | `45633c4` | Done |

Verification evidence:

- Focused status regression passed with 7 filtered tests:
  `SIDEPANES_TEST_FILTER='module split,ask functional core,ask session snapshot,ask pane target picker mapping updates target,ask pane automatic model picker modes update target,ask pane winbar formats,command setup registers configured commands' nvim -n --headless -u NONE ...`.
- `tests/run_checks.sh fast` passed with 171 regression tests plus lifecycle,
  registry, audit, help, docs-contract, and checkhealth smokes.
- `tests/run_checks.sh full` passed with 171 regression tests plus real
  Codex/Claude CLI smoke.
- `git diff --check` passed.
- `illu.nvim` smoke was not run because this slice changed only an internal
  formatter and tests; it did not change defaults, mappings, commands, public
  API, local config behavior, or `illu.nvim`.

Audit pass 1 checked every slice-17 bullet and traceability row,
implementation boundaries, pure formatter design, command/API scope, automated
coverage, command-path and mapping-zone compatibility, state transitions,
manual acceptance references, README, CHANGELOG, Neovim help, Markdown docs,
release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. No new
implementation, test, documentation, process, or integration gaps were found.

Audit gap: clean confirmation pass 2 re-checked the top Remaining
Implementation Order after slice 17 was removed. Keep the final verification
and release-readiness audit as the final item without duplicating it, commit
the roadmap-order evidence, and restart the clean confirmation passes from the
new HEAD. Recorded in `45633c4`; docs contract and `git diff --check` passed
before the evidence was committed.

### 18. Target Resolver Refactor

Status: `Done`

User response: yes, do that.

Goal: isolate ask target resolution from ask routing after the ask policy,
state snapshot, and test architecture are clean enough to absorb the change
without another mapping/lifecycle tangle.

Remaining implementation order, restated before starting this slice:

1. `18. Target Resolver Refactor`
2. `14. Ask Pane Module Split`
3. `17. Ask Target And Picker Status Visibility`
4. `20. SidepanesAskStatus`
5. `21. SidepanesVersion`
6. `22. Interactive Keymap Help`
7. `19. Interaction-Focused Manual Acceptance Checklist`
8. Final verification and release-readiness audit

- Add a dedicated resolver module, likely
  `lua/sidepanes/panes/ask/target_resolver.lua`.
- Encode target resolution order in one place:
  - active ask draft target.
  - last coding-agent context for the relevant root.
  - default ask-capable target for the root.
  - picker only when no automatic/default target is available or when the user
    explicitly requests target change.
  - `before_send` picker just before send.
- Feed resolver output into the ask action policy/state snapshot instead of
  letting keymaps or command-line handlers pick targets directly.
- Keep resolver functions pure where possible: input is session/config/UI facts,
  output is a target decision, picker requirement, or explicit error.
- Add tests for first visual capture, later append, explicit append with
  `auto_append = false`, missing target, cross-root target, manual picker, and
  `before_send`.
- Add fed-key coverage for any user-visible mapping path whose behavior changes
  because of target resolution.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Start a first visual ask capture with `model_picker = "before_send"` and
  confirm no picker appears.
- Append another selection and confirm the active draft target is reused.
- Press `M` in the ask pane and confirm the picker still opens manually.
- Write/send with `before_send` and confirm the picker appears only then.

Refinement note: this is a high-value refactor because target timing caused
multiple regressions.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add a dedicated resolver module, likely `lua/sidepanes/panes/ask/target_resolver.lua`. | Added `lua/sidepanes/ask_target_resolver.lua`; kept the flat path intentionally because slice 14 owns the later ask module split. `lua/sidepanes/ask_route.lua` now delegates compatibility target helpers to it. | `tests/sidepanes_regression.lua` "ask target resolver centralizes pane-mode target decisions" passed in the focused run and fast checks. | This roadmap records the flat-path decision; no public docs change applies because behavior is intended to stay compatible. | Review module boundary and public surface before moving on. | `2638b81` | Done |
| Encode target resolution order in one place: | `ask_target_resolver.resolve()` owns automatic target decisions; `ask_target_resolver.before_send()` owns send-time picker decisions; `question.lua` and `ask_pane.lua` collect facts and execute returned decisions. | Direct resolver test plus focused pane-mode target regressions passed; `tests/run_checks.sh fast` passed with 169 regression tests after the audit fix. | This roadmap; no public docs change applies because behavior is intended to stay compatible. | Exercise first capture, append, manual picker, and send flows. | `2638b81`, `6e9cc90` | Done |
| active ask draft target. | `ask_target_resolver.resolve()` prefers `active_entry`; pane-mode ask/append paths pass the current ask entry and record `target_reason = "active_ask_target"`. | Direct resolver test and "pane-mode visual ask mappings reuse active ask target without reopening picker" passed in the focused run. | This roadmap; no public docs change applies because this preserves documented active-draft reuse. | Append another selection and confirm the active draft target is reused. | `2638b81` | Done |
| last coding-agent context for the relevant root. | `question.lua` now resolves root-scoped last coding-agent facts before defaults; cross-root behavior still comes from `deps.last_coding_agent_context(context.root)`. | Direct resolver test, existing "agent context lookups stay within the requested project root", and new "pane-mode ask target resolver ignores last coding-agent context from another root" passed in fast checks. | This roadmap; no public docs change applies because behavior is intended to stay compatible. | Start a capture from a project with prior agent context and confirm the expected target. | `2638b81` | Done |
| default ask-capable target for the root. | `ask_target_resolver.resolve()` falls back to the first ask-capable shortcut entry after active and last targets. | Direct resolver test and "pane-mode ask-last first capture uses default target without picker" passed in the focused run. | This roadmap; no public docs change applies because this preserves existing default target behavior. | Start a first capture without prior context and confirm the default target is selected. | `2638b81` | Done |
| picker only when no automatic/default target is available or when the user explicitly requests target change. | `ask_target_resolver.resolve()` returns picker decisions for `explicit_picker` and `no_target`; `question.lua` and `ask_pane.lua` use resolver-composed picker entries for target pickers. | Direct resolver test, "pane-mode ask target resolver leaves missing targets to the picker path", and fed-key "ask pane target picker mapping updates target and winbar" passed. | This roadmap; no public docs change applies because picker behavior is intended to stay compatible. | Press `M` in the ask pane and confirm the picker still opens manually. | `2638b81` | Done |
| `before_send` picker just before send. | `ask_target_resolver.before_send()` returns `before_send_picker`; `ask_pane.lua` uses its picker entries when the lifecycle executor reaches send-time picker handling. | Direct resolver test and "ask pane automatic model picker modes update target" passed in the focused run. | Existing public docs already describe `before_send`; no docs change applies because behavior is intended to stay compatible. | Write/send with `before_send` and confirm the picker appears only then. | `2638b81` | Done |
| Feed resolver output into the ask action policy/state snapshot instead of letting keymaps or command-line handlers pick targets directly. | `question.lua` and `ask_pane.lua` store resolver reasons on `ask.target_reason`; `ask_session.snapshot()`, `lifecycle_facts()`, and `status_data()` expose that target-resolution fact. Explicit `pane.ask()` targets now reset stale resolver reasons to `explicit_target`. | Snapshot selector assertions cover `target_reason`; focused target regressions passed; fast checks passed after the explicit-target audit fix. | This roadmap; no public docs change applies because this is internal state plumbing for future status slices. | Compare behavior for visual capture, append, picker, and send workflows. | `2638b81`, `6e9cc90` | Done |
| Keep resolver functions pure where possible: input is session/config/UI facts, output is a target decision, picker requirement, or explicit error. | `ask_target_resolver` accepts fact tables and returns data-only decisions; imperative callers still own `vim.*`, picker display, terminal send, and state mutation. | "ask functional core modules do not call Neovim APIs directly" includes `sidepanes.ask_target_resolver` and passed in focused/fast checks. | This roadmap; no public docs change applies for internal architecture. | Review resolver API for Neovim side-effect boundaries. | `2638b81` | Done |
| Add tests for first visual capture, later append, explicit append with `auto_append = false`, missing target, cross-root target, manual picker, and `before_send`. | Added/extended focused regression coverage for the listed pane-mode target workflows and the audit-found explicit-target stale reason edge case. | Focused run passed 10 selected tests covering resolver, snapshot, first/default capture, active append, explicit append, missing target, cross-root target, manual picker, and `before_send`; the focused explicit-target audit test passed; fast checks passed with 169 regression tests after the audit fix. | This roadmap; no public docs change applies because behavior is intended to stay compatible. | Run the listed workflows manually in Neovim. | `2638b81`, `6e9cc90` | Done |
| Add fed-key coverage for any user-visible mapping path whose behavior changes because of target resolution. | Assessed mapping impact: no user-visible mapping changed. Existing fed-key manual target picker path still covers `M`; automatic capture/append behavior remains API/regression covered. | Fed-key "ask pane target picker mapping updates target and winbar" passed in focused/fast checks; no additional fed-key path applies because mappings did not change. | This roadmap; no public docs change applies because no mapping behavior changed. | Press affected mappings and compare with the behavior and mapping-zone matrices. | `2638b81` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Restarting audit passes checked slice bullets, traceability rows, resolver boundaries, state snapshot facts, command/path ownership, mapping-zone impact, manual acceptance references, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` applicability. | Focused target-resolver runs passed; `tests/run_checks.sh fast` passed with 169 regression tests; `tests/run_checks.sh full` passed with 169 regression tests and real CLI smoke after the audit fix; `git diff --check` passed. `illu.nvim` smoke was not applicable because defaults, mappings, commands, public API, and local config behavior did not change. | This roadmap records audit evidence; README/CHANGELOG/help docs/Markdown docs/release notes were reviewed and needed no behavior-doc changes because target workflows stayed compatible. | Review implementation, traceability table, docs, and manual checklist before moving on; final two clean non-mutating confirmation passes are reported in the final response. | `15426d8` | Done |
| Start a first visual ask capture with `model_picker = "before_send"` and confirm no picker appears. | Preserved by resolver default selection: initial pane-mode capture still resolves the default target without consuming the queued picker choice. | Not Applicable as automated test: this bullet is a manual acceptance requirement; "pane-mode ask-last first capture uses default target without picker" supports it. | Existing public docs already describe `before_send`; no docs change applies because behavior is unchanged. | Perform this exact manual workflow. | `2638b81` | Done |
| Append another selection and confirm the active draft target is reused. | Active draft target reuse is routed through `ask_target_resolver.resolve()` and recorded as `target_reason = "active_ask_target"`. | Not Applicable as automated test: this bullet is a manual acceptance requirement; "pane-mode visual ask mappings reuse active ask target without reopening picker" supports it. | Existing public docs already describe active draft target reuse; no docs change applies because behavior is unchanged. | Perform this exact manual workflow. | `2638b81` | Done |
| Press `M` in the ask pane and confirm the picker still opens manually. | Manual target change uses resolver-composed picker entries and records `target_reason = "explicit_target_change"`. | Not Applicable as automated test: this bullet is a manual acceptance requirement; fed-key "ask pane target picker mapping updates target and winbar" supports it. | Existing mapping docs already list model picker behavior; no docs change applies because behavior is unchanged. | Perform this exact manual workflow. | `2638b81` | Done |
| Write/send with `before_send` and confirm the picker appears only then. | Send-time picker entries are resolved through `ask_target_resolver.before_send()`. | Not Applicable as automated test: this bullet is a manual acceptance requirement; "ask pane automatic model picker modes update target" supports it. | Existing public docs already describe `before_send`; no docs change applies because behavior is unchanged. | Perform this exact manual workflow. | `2638b81` | Done |

Audit gaps:

- Audit pass 1 found that explicit `pane.ask("tool")` targets could inherit a
  stale resolver reason from an earlier automatic or picker decision in the same
  draft. Explicit ask targets now record `explicit_target` and the snapshot
  exposes the corrected reason.
- Audit pass 1 restart found a stale traceability row that still cited the
  pre-audit-fix 168-test fast run instead of the current 169-test verification.

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Audit gap: reset stale target-resolution reason when an explicit `pane.ask("tool")` target replaces the current ask-pane target. | `lua/sidepanes/ask_target_resolver.lua` adds `explicit_target`; `lua/sidepanes/question.lua` applies it when building explicit ask entries. | `tests/sidepanes_regression.lua` "pane-mode explicit ask target replaces stale resolver reason" passed; `tests/run_checks.sh fast` passed with 169 regression tests after the fix. | This roadmap; no public docs change applies because this is internal status/snapshot correctness with unchanged user workflow. | Start a draft through automatic target resolution, then explicitly ask another tool and confirm future status/debug output reports the explicit target reason. | `6e9cc90` | Done |
| Audit gap: update stale target-resolver verification count after the explicit-target audit fix added one regression. | Traceability row for central target resolution now cites the post-fix 169-test fast run and includes the audit-fix commit. | Not Applicable: roadmap trace evidence correction only; no runtime behavior changed. | This roadmap. | Re-read slice 18 traceability rows before closeout. | `9e4aee0` | Done |

Verification results:

- Focused resolver/target regression run passed 10 selected tests covering
  resolver, snapshot, first/default capture, active append, explicit append,
  missing target, cross-root target, manual picker, and `before_send`.
- Focused explicit-target audit run passed 8 selected tests.
- `tests/run_checks.sh fast` passed with 169 regression tests after the
  explicit-target audit fix.
- `tests/run_checks.sh full` passed with 169 regression tests and real CLI
  smoke after the explicit-target audit fix.
- `git diff --check` passed.
- `illu.nvim` smoke was not applicable because this slice did not change
  defaults, mappings, commands, public API, or local config behavior.

### 19. Interaction-Focused Manual Acceptance Checklist

Status: `Done`

User response: yes, do that. Focus on user interaction with Neovim and
Sidepanes features, not config-printing.

Goal: make manual testing match real use instead of static config inspection.

- Add a compact manual checklist grouped by workflow:
  - create draft from project buffer.
  - create draft from Markdown pane.
  - append same-file context.
  - append different-file context.
  - append cross-root context.
  - edit prompt, write, send.
  - edit prompt, cancel.
  - switch target manually.
  - use `before_send` picker.
  - recover from failed terminal start.
  - use mapping help.
- Keep config-printing checks only where the feature is specifically
  configuration state.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Run the checklist in a real Neovim session with `illu.nvim` loaded.
- Mark each workflow pass/fail with the exact mapping or command used.

Refinement note: this checklist should be short enough that it is realistic to
run after every ask-pane change.

Audit findings:

- Pass 1 found that the checklist changes release validation process, but
  `CHANGELOG.md` did not mention it. Added an Unreleased entry for the
  interaction-focused manual acceptance checklist.
- Pass 2 found that slice 19 was implemented but the roadmap status, remaining
  order, top status summary, and final re-check traceability row were still
  pending. Updated closeout evidence before final confirmation passes.

Interaction checklist:

Run this in a real Neovim session with `illu.nvim` loaded and the local
`sidepanes.nvim` checkout on `runtimepath`. Use real files in a small project
with at least two source files, one Markdown file, and one file outside the
project root for the cross-root row. Record the exact key or command used for
each row; do not substitute config-printing checks unless the row explicitly
changes configuration state.

| Workflow | Setup | Action | Expected user-visible result | Mapping/command used | Result |
| --- | --- | --- | --- | --- | --- |
| Create draft from project buffer | Open a normal project file and visually select code. | Invoke visual ask from the project buffer. | Ask pane opens with one `File:` block and one `Selection:` block for the selected project file. |  |  |
| Create draft from Markdown pane | Open Sidepanes Markdown, focus it, and visually select text in the Markdown pane. | Invoke pane-local visual ask. | Ask pane opens from the Markdown pane and includes the Markdown file/range citation. |  |  |
| Append same-file context | Keep the ask draft active and select a second range in the same source file. | Invoke visual ask append or active visual ask. | The same `File:` block gains another `Selection:` block; exact duplicates are skipped. |  |  |
| Append different-file context | Select text in a second file under the same project root. | Invoke visual ask append or active visual ask. | The draft gains a second `File:` block and citation counts/status reflect both files. |  |  |
| Append cross-root context | Select text from a file outside the current project root. | Append that selection to the active ask draft. | The draft includes root context for the cross-root file so the source is unambiguous. |  |  |
| Edit prompt, write, send | Edit the ask draft text. | Write the buffer, then quit or use a configured quit-lifecycle shortcut. | The prompt sends to the selected target, the ask draft closes, and the previous pane is restored. |  |  |
| Edit prompt, cancel | Edit the ask draft text without writing it. | Quit without writing or run hard cancel. | The draft is cancelled without sending and the previous pane is restored. |  |  |
| Switch target manually | Open an active ask draft with multiple ask-capable targets configured. | Press the model picker mapping in the ask pane and choose another target/preset. | The ask winbar/status target changes before sending. |  |  |
| Use `before_send` picker | Temporarily set `ask.model_picker = "before_send"` in local config state. | Submit a draft. | Picker opens at send time; chosen target receives the prompt. |  |  |
| Recover from failed terminal start | Temporarily configure an ask-capable target with a missing command. | Submit a draft to that target. | A warning appears, the draft remains visible, and the winbar/status shows `send_failed`. |  |  |
| Use mapping help | Focus Markdown, terminal, and ask panes. | Press the help mapping in each pane. | Help opens with the current pane mappings first, then global mappings, then relevant commands. |  |  |

Traceability:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add a compact manual checklist grouped by workflow: | Not Applicable as runtime implementation: this slice adds the interaction checklist under slice 19. | Not Applicable as new automated test: this is a manual QA checklist; existing regressions and matrices cover the underlying behaviors. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Run the checklist in a real Neovim session with `illu.nvim` loaded. | `f45cdaf` | Done |
| create draft from project buffer. | Checklist row `Create draft from project buffer`. | Existing ask capture regressions and behavior/mapping matrices cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Use a project-buffer visual ask mapping or command and inspect the draft. | `f45cdaf` | Done |
| create draft from Markdown pane. | Checklist row `Create draft from Markdown pane`. | Existing pane-local visual ask regressions and mapping-zone matrix cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Use a Markdown-pane visual ask mapping and inspect the draft. | `f45cdaf` | Done |
| append same-file context. | Checklist row `Append same-file context`. | Existing same-file append and duplicate-skip regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Append a second same-file selection and confirm grouping. | `f45cdaf` | Done |
| append different-file context. | Checklist row `Append different-file context`. | Existing multi-file append/status regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Append a different file and confirm a second file block. | `f45cdaf` | Done |
| append cross-root context. | Checklist row `Append cross-root context`. | Existing cross-root prompt/citation regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Append a selection outside the current root and confirm root context is visible. | `f45cdaf` | Done |
| edit prompt, write, send. | Checklist row `Edit prompt, write, send`. | Existing write/send, quit-lifecycle, and submit regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Edit the ask prompt, write it, then send. | `f45cdaf` | Done |
| edit prompt, cancel. | Checklist row `Edit prompt, cancel`. | Existing cancel/restore and quit command regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Edit the ask prompt and cancel without sending. | `f45cdaf` | Done |
| switch target manually. | Checklist row `Switch target manually`. | Existing target picker mapping/status/winbar regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Press `M` or `<Tab>` in the ask pane and confirm the target changes. | `f45cdaf` | Done |
| use `before_send` picker. | Checklist row `Use before_send picker`. | Existing `before_send` picker regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Configure `ask.model_picker = "before_send"` and confirm picker opens at send time. | `f45cdaf` | Done |
| recover from failed terminal start. | Checklist row `Recover from failed terminal start`. | Existing failed-terminal preservation regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Submit to a failing target and confirm the draft remains visible with a warning. | `f45cdaf` | Done |
| use mapping help. | Checklist row `Use mapping help`. | Existing mapping-help fed-key/config regressions cover automated behavior; this row is manual acceptance. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Press `gh` in Sidepanes panes and inspect mapping help. | `f45cdaf` | Done |
| Keep config-printing checks only where the feature is specifically configuration state. | Checklist preface says not to substitute config-printing checks unless a row explicitly changes configuration state. | Not Applicable as automated test: this is a manual checklist style requirement. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Confirm the checklist uses interactions rather than `vim.print(require("sidepanes").config)` except for configuration-state cases. | `f45cdaf` | Done |
| Audit finding: checklist release-validation process was missing from `CHANGELOG.md`. | Added an Unreleased changelog entry for the interaction-focused manual checklist. | `tests/sidepanes_docs_contract_smoke.lua`; `tests/run_checks.sh fast`. | `CHANGELOG.md` Unreleased Added entry and this audit finding. | Re-read `CHANGELOG.md` during audit to confirm release-process evidence is present. | `7cec057` | Done |
| Audit finding: slice closeout status/order and final re-check evidence were still pending. | Updated top roadmap status, Current Slice Status, Remaining Implementation Order, slice status, audit findings, and this trace row. | Not Applicable as new automated behavior test: closeout status documentation only; `tests/sidepanes_docs_contract_smoke.lua`, `tests/run_checks.sh fast`, and `git diff --check` passed. | `docs/ask-pane-roadmap.md` closeout status/order and this audit finding. | Re-read slice status/order and traceability before final confirmation passes. | `7b8a233` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Audit passes re-read the checklist, traceability table, roadmap status/order, public docs, changelog, release notes, AGENTS.md, and `illu.nvim` impact. | `tests/sidepanes_docs_contract_smoke.lua`; `tests/run_checks.sh fast`; `git diff --check`. Full checks not required because this slice changed documentation/process only, with no behavior-sensitive or cross-module code changes. | README, Neovim help, Markdown docs, release notes, ROADMAP.md, CHANGELOG.md, AGENTS.md, and this roadmap reviewed; only CHANGELOG and roadmap needed changes. | `illu.nvim` smoke not applicable because defaults, mappings, commands, public API, and local config behavior did not change. | `7b8a233` | Done |
| Run the checklist in a real Neovim session with `illu.nvim` loaded. | Checklist preface requires real Neovim with `illu.nvim` loaded. | Not Applicable as automated test: this is the manual execution requirement. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Run the whole checklist with `illu.nvim`. | `f45cdaf` | Done |
| Mark each workflow pass/fail with the exact mapping or command used. | Checklist table includes `Mapping/command used` and `Result` columns. | Not Applicable as automated test: this is a manual recording requirement. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Record pass/fail and the exact key/command per workflow. | `f45cdaf` | Done |
| Refinement note: this checklist should be short enough that it is realistic to run after every ask-pane change. | Checklist is 11 workflow rows plus a short preface. | Not Applicable as automated test: checklist brevity is manual review/process quality. | `docs/ask-pane-roadmap.md` slice-19 Interaction checklist. | Review checklist length after adding it. | `f45cdaf` | Done |

### 20. `SidepanesAskStatus`

Status: `Done`

User response: yes, add `SidepanesAskStatus`.

Goal: expose ask-pane state for debugging without requiring users to inspect Lua
tables.

Remaining implementation order:

1. `21. SidepanesVersion`
2. `22. Interactive Keymap Help`
3. `19. Interaction-Focused Manual Acceptance Checklist`
4. Final verification and release-readiness audit

- Add public API `ask_status()` or `get_ask_status()`.
- Add command `:SidepanesAskStatus` and root subcommand
  `:Sidepanes ask-status`.
- Print or notify a concise multi-line status:
  - active/inactive.
  - draft state.
  - target label and root.
  - picker mode and picker-shown flag.
  - file count and citation count.
  - previous pane mode.
  - modified/written flags.
- Add docs, help, health/audit smoke coverage, and regression tests.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Open an empty ask pane and run `:SidepanesAskStatus`; confirm it reports a
  ready draft and no citations.
- Append two selections from different files and run status; confirm file and
  citation counts are correct.
- Write the prompt and run status; confirm it reports a written draft.
- Cancel/send the draft and run status; confirm it reports inactive/no active
  ask draft.

Refinement note: this command should help debug future bug reports without
requiring screenshots of internal errors.

Traceability:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add public API `ask_status()` or `get_ask_status()`. | `lua/sidepanes/init.lua` exposes public `ask_status(opts)`, returning the status payload plus `lines` and notifying unless `opts.notify == false`. | `tests/sidepanes_regression.lua` "ask status API and commands report active draft facts" covers inactive, ready, collected, written, and cancelled API return data. | `README.md`, `doc/sidepanes.md`, `doc/sidepanes.txt`, `CHANGELOG.md`, and `docs/release-notes-v0.4.0.md` document `ask_status(opts)`. | Call the public API from Lua before, during, and after an ask draft. | `49c3b7c` | Done |
| Add command `:SidepanesAskStatus` and root subcommand `:Sidepanes ask-status`. | `lua/sidepanes/commands.lua` registers `ask_status = "SidepanesAskStatus"` and root subcommand `ask-status`; `lua/sidepanes/health.lua` includes the command in health expectations. | Command registration, root dispatch/completion, default command names, zone matrix, audit smoke, and runtime status regression tests cover both command paths. | README command list, Markdown docs, Neovim help, CHANGELOG, release notes, and the command-zone matrix list both command paths. | Run both command paths from a real Neovim session. | `49c3b7c` | Done |
| Print or notify a concise multi-line status. | `lua/sidepanes/panes/ask/status.lua` formats concise `debug_lines()`; `ask_status(opts)` notifies those lines at INFO level. | Runtime status regression captures `vim.notify()` for `:SidepanesAskStatus` and `:Sidepanes ask-status`; direct formatter tests assert exact status lines. | Public docs describe the concise multi-line status fields. | Run status from empty, active, written, sent, and cancelled draft states. | `49c3b7c` | Done |
| active/inactive. | `ask_status.debug_data().active` and `debug_lines()` line `Ask pane: active/inactive`. | Direct formatter and runtime status tests cover inactive before open, ready active, collected active, and inactive after cancel. | Public docs list active state in status output. | Compare status before opening an ask draft, while active, and after cancel/send. | `49c3b7c` | Done |
| draft state. | `ask_status.debug_data().draft_state` and `debug_lines()` line `Draft state: ...`. | Direct selector/formatter tests cover all known draft states; runtime status regression covers `inactive`, `ready_empty`, `draft_modified`, and `draft_written`. | Public docs list draft state in status output. | Open, modify, write, send-fail if possible, cancel, and inspect draft state. | `49c3b7c` | Done |
| target label and root. | `ask_status.debug_data().target_label` and `.target_root`; status lines `Ask target:` and `Target root:`. | Direct formatter tests cover target/root; runtime status regression covers `Codex: One` and project root after collecting context; target picker tests cover changed targets. | Public docs list target label/root in status output. | Change targets and compare status label/root with the ask winbar and target picker. | `49c3b7c` | Done |
| picker mode and picker-shown flag. | `ask_status.debug_data().picker_mode`, `.picker_shown`, and `.after_open_shown`; status lines `Picker mode:`, `Picker shown:`, and `After-open picker shown:`. | Direct formatter tests cover picker mode/shown facts; runtime status regression covers manual mode false; existing automatic picker regressions cover `after_open` and `before_send`. | Public docs list picker mode and shown flag in status output. | Test `manual`, `after_open`, and `before_send` picker modes. | `49c3b7c` | Done |
| file count and citation count. | `ask_status.debug_data().file_count` and `.citation_count`; status line `Citations: N (M files)`. | Runtime status regression appends two files and asserts `2` citations / `2` files; direct formatter tests cover zero and multi-count snapshots. | Public docs list citation counts in status output. | Append selections from one file and two files and inspect counts. | `49c3b7c` | Done |
| previous pane mode. | `ask_status.debug_data().previous_pane_mode`; status line `Previous pane: ...`. | Direct formatter tests cover previous pane mode; runtime status regression asserts previous mode is `markdown` after opening from a project file. | Public docs list previous pane mode in status output. | Open ask from another pane mode and inspect previous pane mode in status. | `49c3b7c` | Done |
| modified/written flags. | `ask_session.status_data()` exposes `modified` and `written`; `ask_status.debug_lines()` prints `Modified:` and `Written:`. | Direct formatter tests cover modified/written true and false; runtime status regression asserts flags before and after writing the draft. | Public docs list modified/written flags in status output. | Modify and write the prompt, then inspect dirty/written facts. | `49c3b7c` | Done |
| Add docs, help, health/audit smoke coverage, and regression tests. | Docs, health command defaults, audit expected commands, docs-contract command/API lists, and mapping-zone fixture were updated. | Focused regression passed 15 filtered tests; docs contract smoke passed; audit smoke passed; `git diff --check` passed. Health coverage includes `ask_status` in configured command validation. | `README.md`, `doc/sidepanes.md`, `doc/sidepanes.txt`, `CHANGELOG.md`, `docs/release-notes-v0.4.0.md`, and this roadmap were updated. | Review README, help docs, Markdown docs, CHANGELOG, release notes, audit smoke, health smoke, and regression coverage. | `49c3b7c` | Done |
| Audit gap: remove stale roadmap claims that `SidepanesAskStatus` is still planned or unregistered after slice 20. | Historical slice-16, slice-17, and slice-25 trace rows now distinguish past deferral from current slice-20 command/API implementation. | Docs contract smoke, roadmap grep audit, and `git diff --check` cover the corrected docs state. | This roadmap. | Re-read older roadmap rows that mention `SidepanesAskStatus` and confirm only historical deferral remains. | `590364b` | Done |
| Audit gap: remove completed slice 20 from the slice-local Remaining implementation order. | Slice-local Remaining implementation order now starts at `21. SidepanesVersion`, matching the top-level order. | Roadmap order scan and `git diff --check` cover the correction. | This roadmap. | Re-read both top-level and slice-local remaining implementation order before restarting clean confirmation passes. | `30e2ad1` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Audit pass 1 checked every slice-20 bullet and trace row, implementation boundaries, public API/command adapters, status formatter architecture, command paths, mapping-zone fixture changes, state transitions, manual acceptance rows, README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. Final two clean non-mutating confirmation passes are reported in the final response. | Focused regression passed 15 filtered tests; docs contract smoke passed; audit smoke passed; `tests/run_checks.sh fast` passed with 172 regressions; `tests/run_checks.sh full` passed with 172 regressions and real CLI smoke; `illu.nvim` integration smoke passed; `git diff --check` passed. | README, CHANGELOG, Neovim help, Markdown docs, release notes, and this roadmap were updated and audited. | Re-read the slice bullets, traceability, changed implementation, tests, docs, roadmap status/order, AGENTS.md, and `illu.nvim` impact. | `3dbace2` | Done |
| Open an empty ask pane and run `:SidepanesAskStatus`; confirm it reports a ready draft and no citations. | `ask_status(opts)` and `:SidepanesAskStatus` report active ready state and zero counts. | Not Applicable as automated test: this row records a manual acceptance workflow; runtime status regression supports it with active ready API coverage and standalone command notification coverage. | Public docs list `:SidepanesAskStatus` and the ready/count fields. | Perform this exact workflow in Neovim. | `49c3b7c` | Done |
| Append two selections from different files and run status; confirm file and citation counts are correct. | Status payload reports `citation_count = 2` and `file_count = 2`. | Not Applicable as automated test: this row records a manual acceptance workflow; runtime status regression supports it with two-file append coverage. | Public docs list citation counts in status output. | Perform this exact workflow in Neovim. | `49c3b7c` | Done |
| Write the prompt and run status; confirm it reports a written draft. | Status payload reports `draft_state = "draft_written"`, `modified = false`, and `written = true`. | Not Applicable as automated test: this row records a manual acceptance workflow; runtime status regression supports it with write/status coverage. | Public docs list draft state and modified/written flags in status output. | Perform this exact workflow in Neovim. | `49c3b7c` | Done |
| Cancel/send the draft and run status; confirm it reports inactive/no active ask draft. | After cancel, status payload reports `active = false`, `draft_state = "inactive"`, and zero counts. Send inactive status remains covered by existing sent/cancelled snapshot reset behavior. | Not Applicable as automated test: this row records a manual acceptance workflow; runtime status regression supports cancel/inactive coverage. | Public docs list inactive status output. | Perform this exact workflow in Neovim. | `49c3b7c` | Done |

Verification evidence:

- Focused ask status regression passed with 15 filtered tests:
  `SIDEPANES_TEST_FILTER='module split,ask mapping zone matrix matches active maps by user location,command setup registers configured commands,command registration invokes facade callbacks,root command dispatches subcommands and completes choices,default command names use Sidepanes prefix,ask session snapshot exposes serializable state facts and labels,ask session snapshot covers empty invalid target and picker cases,ask status API and commands report active draft facts,health check reports configured commands, mappings, and tools' nvim -n --headless -u NONE ...`.
- Docs contract smoke passed.
- Audit smoke passed.
- `tests/run_checks.sh fast` passed with 172 regression tests plus audit,
  help, docs-contract, and checkhealth smokes.
- `tests/run_checks.sh full` passed with 172 regression tests plus real
  Codex/Claude CLI smoke.
- `illu.nvim` `tests/run_sidepanes_checks.sh` passed against the local
  sidepanes runtime; its pre-existing local changes were not touched.
- `git diff --check` passed.

Audit pass 1 checked every slice-20 bullet and traceability row,
implementation correctness and architecture boundaries, public API/command
adapters, status formatter shape, automated coverage and edge cases, fed-key
applicability, command paths, mapping zones, state transitions, compatibility
requirements, manual acceptance rows, README, CHANGELOG, Neovim help, Markdown
docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact.
The pass found stale historical roadmap wording around `SidepanesAskStatus`
being planned/unregistered; the gap was recorded in the traceability table,
fixed in `590364b`, traced in `b706680`, and the audit loop restarted from the
new HEAD.

### 21. `SidepanesVersion`

Status: `Done`

User response: add a command like `SidepanesVersion` that prints the current
version and where the plugin was loaded from.

Goal: make support/debugging easier when multiple plugin copies or runtime paths
are involved.

Remaining implementation order:

1. `22. Interactive Keymap Help`
2. `19. Interaction-Focused Manual Acceptance Checklist`
3. Final verification and release-readiness audit

- Add a version source, for example `sidepanes.version` or a constant in the
  public facade.
- Add public API `version()` returning:
  - version string, currently `0.4.0-dev` while on this branch.
  - plugin load path.
  - git branch/commit if cheap and available without shelling out during normal
    use, otherwise omit commit from runtime and leave it to manual debug.
- Add command `:SidepanesVersion` and root subcommand `:Sidepanes version`.
- Include this in health output or recommend it in bug-report docs.
- Add docs, help, audit smoke coverage, and regression tests.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- Run `:SidepanesVersion` from the personal config and confirm it prints
  `0.4.0-dev` or the release version plus the path under
  `~/.config/nvim/sidepanes.nvim`.
- Temporarily load Sidepanes from another runtime path and confirm the command
  reports that path.

Refinement note: the version command should avoid expensive filesystem/git work
on startup. Prefer lazy computation when the command is invoked.

Audit gaps:

- Fast check found the behavior-sensitive mapping coverage fixture still
  referenced the old `ask-zone-planned-commands` row after
  `SidepanesVersion` moved into active commands. Update the fixture to cover
  `:SidepanesVersion` and `:Sidepanes version` against `ask-zone-commands`.
- Audit pass 1 found the CHANGELOG still described the zone matrix as covering
  planned command slots after `SidepanesVersion` became active. Remove the
  stale planned-slot wording.
- Confirmation pass 2 found a generated README banner insertion, an untracked
  `assets/sidepanes-banner.png` artifact, and an untracked `.DS_Store` after
  fast checks. Remove those artifacts and restart the clean confirmation count.
- Restarted confirmation pass 1 found an untracked `nvim.log` after a focused
  Neovim regression run fell back to the repository for logging. Ignore/remove
  that local log artifact and restart the clean confirmation count.

Traceability:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add a version source, for example `sidepanes.version` or a constant in the public facade. | `lua/sidepanes/version.lua` defines `VERSION`, pure `info(opts)`, and `lines(info)`. | `tests/sidepanes_regression.lua` "version module and public API report version and load path" covers the module source. | `doc/sidepanes.md`, `doc/sidepanes.txt`, README command list, CHANGELOG, and release notes mention the version surface. | Inspect the public API and runtime command output. | `0602f29` | Done |
| Add public API `version()` returning: | `lua/sidepanes/init.lua` exposes `M.version(opts)` through the public facade and returns the info table. | `tests/sidepanes_regression.lua` "version module and public API report version and load path" covers return values and notify output. | `doc/sidepanes.md` and `doc/sidepanes.txt` list `version()`. | Call `require("sidepanes").version()` from Neovim. | `0602f29` | Done |
| version string, currently `0.4.0-dev` while on this branch. | `lua/sidepanes/version.lua` sets `M.VERSION = "0.4.0-dev"`. | `tests/sidepanes_regression.lua` asserts the constant, API return value, notify output, and health output include `0.4.0-dev`. | `CHANGELOG.md` and release notes document the version/debugging surface; the exact dev string is intentionally implementation/test evidence. | Confirm API and command output include `0.4.0-dev`. | `0602f29` | Done |
| plugin load path. | `lua/sidepanes/version.lua` derives the plugin root from the module source without Neovim API calls; `lua/sidepanes/init.lua` and commands display it. | `tests/sidepanes_regression.lua` covers normal source paths, `@`-prefixed source paths, unrecognized paths, public API load path, notify output, and health output. | `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, and release notes state the command/API reports load path. | Confirm API and command output include the loaded plugin path. | `0602f29` | Done |
| git branch/commit if cheap and available without shelling out during normal use, otherwise omit commit from runtime and leave it to manual debug. | `lua/sidepanes/version.lua` intentionally contains only constant/string/path helpers and does not call git or shell commands. | `tests/sidepanes_regression.lua` verifies the returned info shape contains version and load path only for the current runtime facts; no git field is introduced. | Not Applicable as docs change: runtime git branch/commit is intentionally omitted; this trace row records the reason. | Confirm runtime status does not perform expensive git work on startup. | `0602f29` | Done |
| Add command `:SidepanesVersion` and root subcommand `:Sidepanes version`. | `lua/sidepanes/commands.lua` registers `SidepanesVersion`, dispatches root `version`, and completes `version`. | `tests/sidepanes_regression.lua` covers standalone command dispatch, root subcommand dispatch/completion, default command registration, and the zone-matrix registered-command check. | README command list, `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, and release notes document both command paths. | Run both command paths in Neovim. | `0602f29` | Done |
| Include this in health output or recommend it in bug-report docs. | `lua/sidepanes/health.lua` reports `Version:` and `Load path:` in `:checkhealth sidepanes`. | `tests/sidepanes_regression.lua` "health check reports configured commands, mappings, and tools" asserts both health report lines. | README recommends `:checkhealth sidepanes`; `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, and release notes document version/load-path support output. | Run `:checkhealth sidepanes` and review bug-report docs. | `0602f29` | Done |
| Add docs, help, audit smoke coverage, and regression tests. | Public implementation is in `lua/sidepanes/version.lua`, `lua/sidepanes/init.lua`, `lua/sidepanes/commands.lua`, and `lua/sidepanes/health.lua`; zone matrix fixture now treats `SidepanesVersion` as active. | Focused regression, docs contract, audit smoke, and zone-matrix checks passed after `0602f29`; full/fast checks still run during closeout. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, release notes, and this roadmap were updated. | Review README, Markdown docs, Neovim help, CHANGELOG, release notes, audit smoke, docs contract, and regression coverage. | `0602f29` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Verification results below record focused checks, fast/full checks, `illu.nvim` smoke, manual command checks, and `git diff --check`; audit passes still continue from the next HEAD. | `tests/run_checks.sh fast`, `tests/run_checks.sh full`, focused regression/docs/audit smokes, `illu.nvim` smoke, and `git diff --check` passed. | README, CHANGELOG, `doc/sidepanes.md`, `doc/sidepanes.txt`, release notes, this roadmap, and AGENTS.md were re-read during closeout. | Re-read the slice bullets, traceability, changed implementation, tests, docs, roadmap status/order, AGENTS.md, and `illu.nvim` impact. | `fd376f7` | Done |
| Run `:SidepanesVersion` from the personal config and confirm it prints `0.4.0-dev` or the release version plus the path under `~/.config/nvim/sidepanes.nvim`. | Command path uses `lua/sidepanes/commands.lua`; public formatter uses `lua/sidepanes/version.lua`. | `illu.nvim` smoke passed; Not Applicable as sole automated test because this row records a manual acceptance workflow. | Not Applicable as docs change: this row records manual acceptance evidence for already documented commands. | Headless `illu.nvim` manual check ran `:SidepanesVersion` and `:Sidepanes version`; both printed `0.4.0-dev` and `/Users/maximl/.config/nvim/sidepanes.nvim`. | `fd376f7` | Done |
| Temporarily load Sidepanes from another runtime path and confirm the command reports that path. | `sidepanes.version.info()` derives load path from the loaded module source, not a hard-coded repo path. | `tests/sidepanes_regression.lua` simulates alternate source paths; Not Applicable as sole automated test because this row records a manual acceptance workflow. | Not Applicable as docs change: this row records manual acceptance evidence for already documented load-path output. | Loaded Sidepanes through `/private/tmp/sidepanes-s21-alt.jzI6bF/sidepanes.nvim`; `:SidepanesVersion` and `:Sidepanes version` printed that temporary path. | `fd376f7` | Done |
| Audit gap: fast check found the behavior-sensitive mapping coverage fixture still referenced the old `ask-zone-planned-commands` row after `SidepanesVersion` moved into active commands. Update the fixture to cover `:SidepanesVersion` and `:Sidepanes version` against `ask-zone-commands`. | `tests/ask_pane_mapping_coverage.lua` now uses `version-command` with zone row `ask-zone-commands`. | `tests/sidepanes_regression.lua` "ask behavior-sensitive mapping coverage table matches matrices and tests" fails if coverage rows reference removed matrix rows; focused rerun passed. | This roadmap records the audit gap; no user-facing docs change applies because this is test fixture evidence. | Not Applicable: fixture consistency gap found by automated fast check, not a manual workflow. | `79cceaa` | Done |
| Audit gap: audit pass 1 found the CHANGELOG still described the zone matrix as covering planned command slots after `SidepanesVersion` became active. Remove the stale planned-slot wording. | `CHANGELOG.md` zone-matrix entry now describes active ask mappings, command paths, and collision-prone shortcuts. | `rg` audit for stale `planned command` / `ask-zone-planned-commands` references covers the wording; no runtime test applies to release-note phrasing. | `CHANGELOG.md`; this roadmap records the audit gap. | Not Applicable: release-facing wording gap found by audit, not an interactive workflow. | `21c0977` | Done |
| Audit gap: confirmation pass 2 found a generated README banner insertion, an untracked `assets/sidepanes-banner.png` artifact, and an untracked `.DS_Store` after fast checks. Remove those artifacts and restart the clean confirmation count. | Removed the generated README banner block and artifacts; later cleanup removed the banner-specific ignore so no banner plumbing remains. | `git status --short --untracked-files=all` catches generated artifacts; no runtime test applies to repository cleanliness. | This roadmap records the process gap. | Not Applicable: repository hygiene gap found by confirmation pass, not an interactive workflow. | `56b18eb` | Done |
| Audit gap: restarted confirmation pass 1 found an untracked `nvim.log` after a focused Neovim regression run fell back to the repository for logging. Ignore/remove that local log artifact and restart the clean confirmation count. | Removed the generated `nvim.log` and added `nvim.log` to the local/generated artifact ignores. | `git status --short --untracked-files=all` catches generated log artifacts; no runtime test applies to repository cleanliness. | `.gitignore` records the local/generated artifact ignore; this roadmap records the process gap. | Not Applicable: repository hygiene gap found by confirmation pass, not an interactive workflow. | `0c9f8f1` | Done |

Verification results:

- Focused regression, docs contract, audit smoke, zone-matrix checks, and
  `git diff --check` passed after the implementation commit.
- The first restarted `tests/run_checks.sh fast` found the stale
  `ask-zone-planned-commands` coverage row; that gap is recorded above and
  fixed in `79cceaa`.
- After `069ec60`, `tests/run_checks.sh fast` passed.
- After `069ec60`, `tests/run_checks.sh full` passed, including real
  Codex/Claude CLI smoke.
- `illu.nvim` smoke passed without touching or committing its local changes.
- Manual personal-config checks for `:SidepanesVersion` and
  `:Sidepanes version` printed `0.4.0-dev` and
  `/Users/maximl/.config/nvim/sidepanes.nvim`.
- Manual temporary-runtime checks for `:SidepanesVersion` and
  `:Sidepanes version` printed `0.4.0-dev` and
  `/private/tmp/sidepanes-s21-alt.jzI6bF/sidepanes.nvim`.
- `git diff --check` passed after verification.

Audit passes:

- Pass 1 checked slice bullets, traceability, implementation boundaries, tests,
  fed-key/command coverage tables, manual acceptance evidence, README,
  CHANGELOG, Neovim help, Markdown docs, release notes, roadmap order/status,
  AGENTS.md, and `illu.nvim` impact. It found the stale CHANGELOG planned-slot
  wording recorded above.
- Pass 2 restarted after `a65e3c7` and rechecked the same areas plus stale-text
  searches, docs contract smoke, worktree status, and `git diff --check`. No
  new gaps were found.

### 22. Interactive Keymap Help

Status: `Done`

User response: add a way to view currently active key mappings for interactive
learning. Show a configurable local mapping in the right side of the winbar,
such as a simple help hint.

Goal: make Sidepanes discoverable without forcing users to memorize every
mapping.

Remaining implementation order:

1. `19. Interaction-Focused Manual Acceptance Checklist`
2. Final verification and release-readiness audit

- Add a pane-local help mapping. Suggested default:
  - `mappings.pane.help = "gh"`.
  - Rationale: short, local, mnemonic enough for "go help", and less disruptive
    than stealing `H` (`<S-h>`), which is a normal viewport motion.
  - Winbar hint: right-aligned `gh help` when enabled.
- Consider a global help mapping later, such as `mappings.global.help =
  "<leader>p?"`, but start with pane-local help because the need is local
  interaction learning.
- Add command/API:
  - `:SidepanesMappings` or `:SidepanesKeymaps`.
  - root subcommand `:Sidepanes mappings`.
- Help output should show:
  - currently active pane-local mappings first.
  - then global Sidepanes mappings.
  - then relevant commands for the current pane.
  - disabled mappings omitted or marked disabled.
- Make output readable in Neovim:
  - either a small floating Markdown help buffer.
  - or a picker-style list if picker dependencies are available.
  - fall back to a scratch help buffer without requiring Telescope.
- Center the floating Markdown help buffer over the actual Sidepanes pane, not
  over the full editor:
  - read pane geometry from `vim.api.nvim_win_get_position(state.winid)`,
    `vim.api.nvim_win_get_width(state.winid)`, and
    `vim.api.nvim_win_get_height(state.winid)`.
  - size the float relative to the pane dimensions.
  - compute editor-relative `row` and `col` from the pane row/column so the
    float stays visually attached to Sidepanes.
  - keep this geometry future-proof for left, right, or bottom pane placement.
  - if the pane is too small, fall back to a full-editor centered float or a
    scratch split.
- Include ask-pane, Markdown-pane, terminal-pane, and global mappings.
- Make winbar hint configurable:
  - `help.winbar = true`.
  - `help.mapping = "gh"` or reuse `mappings.pane.help`.
  - `help.scope = "pane_first"` initially.
- Add docs, help, audit smoke coverage, and regression tests.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- In the Markdown pane, confirm the winbar shows `gh help` on the right and
  pressing `gh` opens mapping help with Markdown-pane mappings first.
- In a Codex pane, press `gh`; confirm terminal-pane mappings are shown first
  and global Sidepanes mappings are shown after them.
- In the ask pane, press `gh`; confirm ask-specific mappings such as `M`, `gf`,
  `]f`, `[f`, `qq`, and `<C-CR>` appear before global mappings.
- Resize the Sidepanes pane and press `gh`; confirm the help float stays
  centered over the Sidepanes pane rather than the full editor.
- Move Sidepanes to a future left or bottom placement if that layout exists and
  confirm the help float still centers over the pane geometry.
- Disable the help mapping and confirm the winbar hint disappears.

Refinement note: the help view should be generated from actual normalized
runtime config, not copied static docs, so it reflects personal mappings like
`qq` and `<leader>qq`.

Traceability:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Add a pane-local help mapping. Suggested default: | `defaults.config.mappings.pane.help`; `maps.setup()` installs the pane-local help callback; `init.lua` wires it to `mappings_help()`. | `tests/sidepanes_regression.lua` "pane-local mappings are configurable", "ask mapping zone matrix matches active maps by user location", and "mapping help opens from the pane-local fed key and follows help config". | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, `CHANGELOG.md`, and `docs/release-notes-v0.4.0.md`. | Press the help mapping inside Sidepanes pane buffers. | `67ea519` | Done |
| `mappings.pane.help = "gh"`. | `defaults.config.mappings.pane.help = "gh"`. | Zone matrix regression asserts `gh` on Markdown, terminal, and ask pane buffers; fed-key regression opens help from the configured pane key. | README and both reference docs list default `help` as `gh`. | Confirm default `gh` opens mapping help. | `67ea519` | Done |
| Rationale: short, local, mnemonic enough for "go help", and less disruptive than stealing `H` (`<S-h>`), which is a normal viewport motion. | No runtime rationale code needed; implementation uses `gh` and does not bind `H`. | Zone matrix regression asserts `H` is not pane-local mapped. | This roadmap records the rationale; user-facing docs document behavior only. | Confirm `H` remains unclaimed for viewport motion. | `67ea519` | Done |
| Winbar hint: right-aligned `gh help` when enabled. | `winbar.lua` appends `mapping_help.winbar_hint()` with `%=`; `mapping_help.winbar_hint()` formats the active mapping. | Fed-key/config regression asserts configured `g? help`, reused `gH help`, disabled hint, and `help.winbar=false`; existing winbar tests continue to cover Markdown labels. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, and release notes document the hint. | In Sidepanes panes, confirm right winbar hint appears as `gh help`. | `67ea519` | Done |
| Consider a global help mapping later, such as `mappings.global.help = "<leader>p?"`, but start with pane-local help because the need is local interaction learning. | No `mappings.global.help` default or global-map installation was added. | Zone matrix regression asserts the Sidepanes help mapping is not registered globally. | Docs describe pane-local `gh`; no global help mapping is documented. | Confirm no global help mapping is installed by default in this slice. | `67ea519` | Done |
| Add command/API: | `commands.lua` registers mappings command paths; `init.lua` exposes `mappings_help(opts)`. | Command registration and root dispatch regressions cover callbacks and completion; default command-name regression covers registration. | README command list, Markdown docs, Vim help, CHANGELOG, and release notes. | Run the command/API from Neovim. | `67ea519` | Done |
| `:SidepanesMappings` or `:SidepanesKeymaps`. | Chose `:SidepanesMappings`; default command registered in `commands.lua` and health expectations. | Command registration regression invokes `SidepanesTestMappings`; default command-name and audit smoke expected-command lists include `SidepanesMappings`. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, release notes. | Run the selected standalone command. | `67ea519` | Done |
| root subcommand `:Sidepanes mappings`. | `commands.lua` dispatches and completes root subcommand `mappings`. | Root command regression invokes `SidepanesRootTest mappings` and asserts completion includes `mappings`. | README, Markdown docs, Vim help, CHANGELOG, release notes. | Run `:Sidepanes mappings`. | `67ea519` | Done |
| Help output should show: | `mapping_help.lines()` builds pane, global, and command sections from normalized runtime state. | Formatter regression checks section presence and ordering. | README and reference docs describe the section order. | Open mapping help and inspect ordering. | `67ea519` | Done |
| currently active pane-local mappings first. | `mapping_help.lines()` appends `pane_rows[kind]` first. | Formatter regression asserts pane section appears before global section. | README and reference docs describe pane mappings first. | Open help from Markdown, terminal, and ask panes; confirm pane-local section appears first. | `67ea519` | Done |
| then global Sidepanes mappings. | `mapping_help.lines()` appends `global_rows` after pane rows. | Formatter regression asserts global section appears after pane section and includes configured global mapping. | README and reference docs describe global mappings second. | Open help and confirm global mapping section follows pane-local mappings. | `67ea519` | Done |
| then relevant commands for the current pane. | `mapping_help.lines()` appends `command_rows[kind]` after mappings. | Formatter regression asserts command section follows global section and terminal/root mapping commands appear. | README and reference docs describe relevant commands after mappings. | Open help and confirm current-pane command section follows mappings. | `67ea519` | Done |
| disabled mappings omitted or marked disabled. | `mapping_help.mapping_rows()` omits nil/false lhs values. | Formatter regression disables `toggle_terminal_alt` and asserts it is omitted; fresh-buffer regression asserts `help=false` installs no help map. | Docs say set mapping entries to `false` to disable them. | Disable a help-relevant mapping and confirm output omits or marks it disabled. | `67ea519` | Done |
| Make output readable in Neovim: | `mapping_help.open()` creates a scratch Markdown buffer in a rounded float with close mappings. | Fed-key regression opens the Markdown help buffer and reads its rendered lines. | README and reference docs describe a Markdown help float. | Open mapping help in Neovim and inspect readability. | `67ea519` | Done |
| either a small floating Markdown help buffer. | `mapping_help.open()` uses `nvim_open_win()` with `filetype=markdown`, `border=rounded`, and bounded geometry. | Fed-key regression asserts a Markdown buffer opens; geometry regression asserts bounded float dimensions. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, release notes. | Confirm chosen readable UI opens from the mapping/command path. | `67ea519` | Done |
| or a picker-style list if picker dependencies are available. | Not implemented by design: this slice chose the dependency-free Markdown float path. | Not Applicable: no picker code path was introduced. | Not documented because there is no picker behavior in this slice. | Picker UI is intentionally not implemented in slice 22. | `67ea519` | Done |
| fall back to a scratch help buffer without requiring Telescope. | `mapping_help.open()` creates a scratch buffer directly and does not require Telescope. | Fed-key regression runs in the no-Telescope test environment and opens help. | README and reference docs describe the built-in Markdown help float. | Run help without Telescope and confirm it still opens. | `67ea519` | Done |
| Center the floating Markdown help buffer over the actual Sidepanes pane, not over the full editor: | `mapping_help.float_geometry()` computes editor-relative coordinates from pane geometry; `mapping_help.open()` passes current pane geometry. | Geometry regression checks pane-centered, small-pane fallback, left-column, and bottom-style pane inputs. | Docs mention the help float; geometry details remain implementation/internal roadmap detail. | Open mapping help with Sidepanes visible and inspect float placement. | `67ea519` | Done |
| read pane geometry from `vim.api.nvim_win_get_position(state.winid)`, `vim.api.nvim_win_get_width(state.winid)`, and `vim.api.nvim_win_get_height(state.winid)`. | `mapping_help.pane_geometry()` reads exactly those APIs. | Geometry math is covered through `float_geometry()` regression; UI path is covered by fed-key open regression. | Not Applicable as user docs change: geometry API choice is implementation detail. | Resize/open help and confirm placement tracks Sidepanes pane. | `67ea519` | Done |
| size the float relative to the pane dimensions. | `mapping_help.float_geometry()` bounds width/height using pane width/height. | Geometry regression asserts 80x24 pane produces 72x20 float and small pane uses fallback. | Not documented beyond the Markdown help float behavior. | Resize Sidepanes and confirm help float resizes relative to the pane. | `67ea519` | Done |
| compute editor-relative `row` and `col` from the pane row/column so the float stays visually attached to Sidepanes. | `mapping_help.float_geometry()` adds pane row/col to centered offsets and uses `relative="editor"`. | Geometry regression asserts row/col values for right, left-style, and bottom-style pane positions. | Not Applicable as user docs change: geometry math is implementation detail. | Confirm float is attached to Sidepanes pane rather than full editor. | `67ea519` | Done |
| keep this geometry future-proof for left, right, or bottom pane placement. | Geometry helper accepts explicit pane row/col/width/height and does not assume side or edge. | Geometry regression checks non-right/left-column and bottom-style coordinates in addition to current right-pane values. | Internal roadmap matrix updated; no public layout docs changed because left/bottom placement is not a current feature. | If left/bottom layout exists, perform this workflow; otherwise record no current layout support. | `67ea519` | Done |
| if the pane is too small, fall back to a full-editor centered float or a scratch split. | `mapping_help.float_geometry()` falls back to centered editor-relative float for pane width < 32 or height < 8. | Geometry regression asserts fallback row/col for a too-small pane. | Not documented beyond help float behavior. | Shrink Sidepanes and confirm fallback behavior. | `67ea519` | Done |
| Include ask-pane, Markdown-pane, terminal-pane, and global mappings. | `mapping_help.pane_rows` has Markdown, terminal, and ask rows; `global_rows` lists global mappings. | Formatter regression checks Markdown, terminal, ask, and global output; zone matrix regression checks help mapping in all pane zones. | README and reference docs document pane-local help and active mapping output. | Open help from ask, Markdown, and terminal panes and inspect listed mappings. | `67ea519` | Done |
| Make winbar hint configurable: | `defaults.config.help`; `config.to_setup()`; `config.normalize_help_mapping()`; `mapping_help.winbar_hint()`. | Fed-key/config regression covers `help.mapping`, `mappings.pane.help`, `help.mapping=false`, and `help.winbar=false`; validation regression covers help config shape. | README, reference docs, CHANGELOG, release notes. | Toggle help config and inspect mapping/hint behavior. | `67ea519` | Done |
| `help.winbar = true`. | Default `help.winbar=true`; `mapping_help.winbar_hint()` suppresses hint when false. | Fed-key/config regression asserts `help.winbar=false` hides the hint while preserving the mapping. | README and reference docs document `help.winbar`. | Disable winbar hint and confirm it disappears. | `67ea519` | Done |
| `help.mapping = "gh"` or reuse `mappings.pane.help`. | Defaults set both; `config.normalize_help_mapping()` syncs `help.mapping` into `mappings.pane.help`; `mapping_help.help_config()` prefers runtime `mappings.pane.help`. | Fed-key/config regression asserts `help.mapping="g?"` opens from `g?` and `mappings.pane.help="gH"` is reused in the hint. | README and reference docs document both config paths. | Change configured mapping and confirm help opens on the configured lhs. | `67ea519` | Done |
| `help.scope = "pane_first"` initially. | Default `help.scope="pane_first"`; output order is pane, global, commands. | Formatter regression asserts pane-first ordering; validation regression rejects other scope values. | README/reference docs expose `scope = "pane_first"` in default setup. | Confirm output orders pane mappings before global mappings. | `67ea519` | Done |
| Add docs, help, audit smoke coverage, and regression tests. | Runtime/docs/tests updated for mapping help, command/API, config, health, and matrix. | Focused regression passed with 13 selected tests; audit smoke expected-command fixture includes `SidepanesMappings`. | README, `doc/sidepanes.md`, `doc/sidepanes.txt`, CHANGELOG, release notes, and roadmap zone matrix updated. | Review README, Markdown docs, Neovim help, CHANGELOG, release notes, audit smoke, docs contract, and regression coverage. | `67ea519` | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Audit passes 1-2 re-read slice bullets, traceability, mapping-help implementation, config/mapping/winbar/command boundaries, tests, README, CHANGELOG, Vim help, Markdown docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim` impact. | Focused regression passed with 13 selected tests; `tests/run_checks.sh fast` passed with 177 regressions plus audit/help/docs-contract/health smokes; `tests/run_checks.sh full` passed with 177 regressions and real CLI smoke; `illu.nvim` smoke exited 0 and printed `sidepanes integration smoke passed` with existing Mason `ENOTCONN` VimLeavePre teardown noise after the pass line; `git diff --check` passed. | Traceability, roadmap matrix, status/order, README, CHANGELOG, Vim help, Markdown docs, and release notes reviewed for mapping-help behavior. Final clean confirmation passes are reported in the final response. | Re-read slice bullets, traceability, changed implementation, tests, docs, roadmap status/order, AGENTS.md, and `illu.nvim` impact. | `67ea519`; `14ae59a`; `87e70fd`; `1a0d867` | Done |
| In the Markdown pane, confirm the winbar shows `gh help` on the right and pressing `gh` opens mapping help with Markdown-pane mappings first. | `winbar.lua`, `maps.lua`, `mapping_help.open()`, and `mapping_help.lines()`. | Fed-key regression covers opening from pane-local configured key and Markdown-pane output; formatter regression covers pane-first ordering. | README and reference docs. | Perform this exact Markdown-pane workflow. | `67ea519` | Done |
| In a Codex pane, press `gh`; confirm terminal-pane mappings are shown first and global Sidepanes mappings are shown after them. | Terminal kind rows and command rows in `mapping_help.lua`; pane-local map is shared across terminal pane buffers. | Zone matrix regression asserts terminal pane `gh`; formatter regression covers terminal section and global ordering. | README and reference docs describe current-pane mappings first. | Perform this exact Codex-pane workflow. | `67ea519` | Done |
| In the ask pane, press `gh`; confirm ask-specific mappings such as `M`, `gf`, `]f`, `[f`, `qq`, and `<C-CR>` appear before global mappings. | Ask rows in `mapping_help.lua` include model picker, source jump, navigation, send, submit, and help mappings. | Formatter regression asserts ask-specific `M`, `gf`, `]f`, `[f`, `qq`, and `<C-CR>`; zone matrix regression asserts ask pane `gh`. | README and reference docs. | Perform this exact ask-pane workflow. | `67ea519` | Done |
| Resize the Sidepanes pane and press `gh`; confirm the help float stays centered over the Sidepanes pane rather than the full editor. | `mapping_help.pane_geometry()` and `float_geometry()` use current Sidepanes win geometry. | Geometry regression covers pane-relative centering and small-pane fallback. | Geometry details remain internal; user docs describe the help float. | Resize Sidepanes and perform this exact workflow. | `67ea519` | Done |
| Move Sidepanes to a future left or bottom placement if that layout exists and confirm the help float still centers over the pane geometry. | `float_geometry()` is layout-position agnostic and uses explicit row/col. | Geometry regression checks left-column and bottom-style pane coordinates. | This roadmap records compatibility rationale; no public left/bottom layout docs changed. | Current plugin has right-side layout; future left/bottom manual workflow remains listed. | `67ea519` | Done |
| Disable the help mapping and confirm the winbar hint disappears. | `config.normalize_help_mapping()` syncs `help.mapping=false`; `mapping_help.winbar_hint()` returns nil; maps skip false lhs. | Fed-key/config regression asserts disabled hint; fresh-buffer regression asserts disabled help mapping is not installed. | README and reference docs document disabling. | Disable help mapping and inspect the winbar. | `67ea519` | Done |
| Refinement note: the help view should be generated from actual normalized runtime config, not copied static docs, so it reflects personal mappings like `qq` and `<leader>qq`. | `mapping_help.lines()` reads `state.config.mappings`; normalization syncs `help.mapping` into runtime pane mappings. | Formatter regression injects runtime `qq`, `<leader>qq`, `g?`, disabled `<C-g>`, and custom global mappings and asserts output reflects them. | README/reference docs describe active mappings, not static defaults only. | Configure personal-like mappings and confirm help reflects normalized runtime values. | `67ea519` | Done |
| Audit gap: verification evidence was stale after focused, fast, full, `illu.nvim`, and `git diff --check` checks passed. | The audit evidence update records the completed checks and restarted the slice-22 audit loop from the new HEAD. | Focused, fast, full, `illu.nvim`, and `git diff --check` results are recorded in the re-check row. | This roadmap. | Review this audit gap before final clean confirmation passes. | `14ae59a`; `87e70fd`; `1a0d867` | Done |
| Audit gap: audit pass 2 found slice status/order and the latest audit-evidence correction were not yet recorded for closeout. | This completion-status update marks slice 22 Done, removes it from remaining order, records the `87e70fd` audit-evidence correction, and starts the final clean confirmation window. | Not Applicable: process/status documentation only; no runtime behavior changed after the passing focused, fast, full, `illu.nvim`, and `git diff --check` checks. | This roadmap. | Review slice status/order and traceability before final clean confirmation passes. | `1a0d867` | Done |

Audit notes:

- Audit pass 1 found stale verification evidence after checks passed; fixed in
  `14ae59a` and corrected in `87e70fd`.
- Audit pass 2 found final slice status/order and the latest audit-evidence
  correction still needed recording before closeout; fixed in this
  completion-status update.

### 23. Ask Action Policy And Fed-Key Test Discipline

Status: `Done`

User response: rethink the interplay between key mappings, state management,
and actions first. Add action predicates in one place, and make tests prove real
keypress behavior instead of only mapping callbacks.

Goal: make ask-pane state/action decisions inspectable, testable, and reusable.

- Add one central ask action policy module that owns action predicates and
  planning:
- classify command-line text such as `:q`, `:q!`, `:w`, `:wq`, `:x`, `:xit`, and
    `:exit` into lifecycle intents.
  - classify plain quit mapping RHS values such as `:q<CR>`, `:quit<CR>`,
    `<cmd>q<CR>`, and `<cmd>quit<CR>`.
  - decide the next action sequence from an intent plus explicit state facts,
    for example valid buffer, modified buffer, live prompt, written prompt,
    and picker mode.
  - expose the explicit draft state labels from the same policy module.
- Refactor ask-pane lifecycle entry points so keymaps and command-line handlers
  submit intents to the policy instead of duplicating state predicates.
- Keep keymap modules dumb:
  - ask-pane keymaps call lifecycle intents.
  - non-ask pane keymaps only guard personal plain-quit mappings through the
    policy predicate.
  - no keymap callback should decide whether a draft sends, cancels, writes, or
    opens the picker.
- Add direct policy tests covering every predicate and action plan branch.
- Add or keep fed-key tests for every behavior-sensitive mapping path affected
  by ask lifecycle behavior, including `qq`, `<leader>qq`, `<C-CR>`, and
  `<C-J>`.
- Update AGENTS.md process guidance: behavior-sensitive keymap tests must
  include real fed-key coverage; callback tests alone are registration tests,
  not behavior tests.
- Re-check implementation, tests, docs, and this roadmap before moving on.

Manual acceptance tests:

- With personal `qq -> :q<CR>` and `<leader>qq -> :q<CR>`, press both in the
  Markdown pane and a Codex pane; confirm Sidepanes returns to Markdown without
  closing the window.
- In the ask pane, press configured `qq` and `<leader>qq` on unwritten and
  written drafts; confirm the policy outcomes match cancel/send expectations.
- In the ask pane, press Ctrl+Enter in a terminal that reports `<C-CR>` and one
  that reports `<C-J>`; confirm both submit through the same policy path.
- Inspect the direct policy tests and confirm each action plan corresponds to a
  row in the behavior matrix.

Refinement note: this slice is intentionally before target resolution and the
module split. It creates the decision point those later slices should build on.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference | Documentation reference | Manual acceptance test reference | Status |
| --- | --- | --- | --- | --- | --- |
| Add one central ask action policy module that owns action predicates and planning: | `lua/sidepanes/ask_policy.lua` owns `STATES`, `INTENTS`, `ACTIONS`, command/RHS predicates, lhs expansion candidates, and `plan()`. | `tests/sidepanes_regression.lua` "ask action policy classifies command lines plain quit mappings and lifecycle plans"; full checks passed. | This slice definition and `CHANGELOG.md` Unreleased Changed entry. | Inspect policy module and compare with behavior matrix. | Done |
| classify command-line text such as `:q`, `:q!`, `:w`, `:wq`, `:x`, `:xit`, and `:exit` into lifecycle intents. | `lua/sidepanes/ask_policy.lua` `commandline_intent()`; `lua/sidepanes/ask_pane.lua` command-line handler calls it. | Direct policy regression covers every listed command and alias; ask-pane command-line regression covers callback command strings and fed command paths. Full checks passed. | This slice definition and behavior matrix. | Run the listed commands in the ask pane. | Done |
| classify plain quit mapping RHS values such as `:q<CR>`, `:quit<CR>`, `<cmd>q<CR>`, and `<cmd>quit<CR>`. | `lua/sidepanes/ask_policy.lua` `is_plain_quit_rhs()`; `lua/sidepanes/maps.lua` uses it for non-ask guards. | Direct policy regression covers every listed RHS plus negative `:q!<CR>` / `:write<CR>` cases; fed-key personal quit regression covers runtime behavior. Full checks passed. | This slice definition and mapping matrix. | Press personal plain-quit mappings in non-ask panes. | Done |
| decide the next action sequence from an intent plus explicit state facts, for example valid buffer, modified buffer, live prompt, written prompt, and picker mode. | `lua/sidepanes/ask_policy.lua` `plan()`; `lua/sidepanes/ask_pane.lua` `lifecycle_facts()` and `run_plan()` execute policy steps. | Direct policy regression covers invalid, modified, empty, written, before-send, send, submit, write, and cancel branches. Full checks passed. | This slice definition and behavior matrix. | Compare manual outcomes to direct policy plans. | Done |
| expose the explicit draft state labels from the same policy module. | `lua/sidepanes/ask_policy.lua` `STATES`; `lua/sidepanes/ask_pane.lua` exports `M.DRAFT_STATES = ask_policy.STATES`. | Direct policy require plus existing state-history regressions cover state labels. Full checks passed. | README/help/Markdown docs/release notes/CHANGELOG/roadmap already list explicit state labels. | Inspect winbar state labels during ask lifecycle. | Done |
| Refactor ask-pane lifecycle entry points so keymaps and command-line handlers submit intents to the policy instead of duplicating state predicates. | `lua/sidepanes/ask_pane.lua` command-line handlers use `ask_policy.commandline_intent()`; `finish_quit()` and `submit_now()` execute `ask_policy.plan()` results. | Existing command-line, send mapping, submit mapping, before-send, failed-send, and policy regressions passed. | `CHANGELOG.md` notes the central action policy; no public docs change needed beyond existing behavior docs because user-facing behavior is unchanged. | Use `qq`, `<leader>qq`, `<C-CR>`, `<C-J>`, and command-line quit/write actions. | Done |
| Keep keymap modules dumb: | `lua/sidepanes/maps.lua` delegates plain quit classification and lhs candidates to `ask_policy`; `lua/sidepanes/ask_pane.lua` keymaps call `submit_now` / `finish_quit` intents. | Policy, fed-key, and mapping-zone regressions passed. | This slice definition and AGENTS.md guidance. | Inspect code and press keymaps in ask/non-ask panes. | Done |
| ask-pane keymaps call lifecycle intents. | `lua/sidepanes/ask_pane.lua` ask-submit maps call `M.submit_now`; ask-send maps call `M.finish_quit`; those functions execute policy plans. | Ask-pane submit/send fed-key and callback regressions passed. | Existing public mapping docs remain correct. | Press ask-pane lifecycle mappings. | Done |
| non-ask pane keymaps only guard personal plain-quit mappings through the policy predicate. | `lua/sidepanes/maps.lua` `setup_plain_quit_shadows()` checks existing global normal maps through `ask_policy.is_plain_quit_rhs()` and `ask_policy.lhs_candidates()`. | `tests/sidepanes_regression.lua` "personal normal quit mappings do not close markdown or terminal side panes" and illu smoke passed. | README/help/Markdown docs/release notes describe the narrow plain-quit guard. | Press personal plain-quit mappings in Markdown/Codex panes. | Done |
| no keymap callback should decide whether a draft sends, cancels, writes, or opens the picker. | `lua/sidepanes/ask_pane.lua` callbacks dispatch to lifecycle entry points; lifecycle predicates live in `ask_policy.plan()`. `lua/sidepanes/maps.lua` only guards non-ask plain-quit mapping RHS through policy. | Policy plan tests plus fed-key lifecycle tests passed. | AGENTS.md documents fed-key testing expectations; no user-facing docs change needed. | Inspect keymap callbacks and compare behavior. | Done |
| Add direct policy tests covering every predicate and action plan branch. | `tests/sidepanes_regression.lua` direct policy test. | Direct policy regression covers command classification, plain quit command/RHS predicates, leader expansion, and every `plan()` branch; full checks passed. | This traceability row; no public docs change needed. | Inspect policy test cases. | Done |
| Add or keep fed-key tests for every behavior-sensitive mapping path affected by ask lifecycle behavior, including `qq`, `<leader>qq`, `<C-CR>`, and `<C-J>`. | Existing fed-key tests retained; `<C-J>` fed-key test and personal plain-quit fed-key test remain in `tests/sidepanes_regression.lua`; illu smoke feeds local `<leader>qq`. | Regression tests cover fed-key `qq`, `<leader>qq`, and `<C-J>`; callback coverage remains for registered `<C-CR>` mapping where Neovim cannot always synthesize a distinct terminal Ctrl+Enter. Full checks and illu smoke passed. | AGENTS.md process guidance; README/help docs document `<C-J>` fallback. | Press each mapping in Neovim. | Done |
| Update AGENTS.md process guidance: behavior-sensitive keymap tests must include real fed-key coverage; callback tests alone are registration tests, not behavior tests. | `AGENTS.md` Local Checks section now includes the fed-key testing rule. | Not Applicable: process documentation only; docs contract/fast checks passed. | `AGENTS.md`. | Review AGENTS.md before next slice. | Done |
| Re-check implementation, tests, docs, and this roadmap before moving on. | Audit covered `ask_policy`, ask-pane plan execution, maps policy usage, AGENTS.md, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap status/order, and `illu.nvim` smoke. | `tests/run_checks.sh fast`, `tests/run_checks.sh full`, `illu.nvim` smoke, and `git diff --check` passed. | Docs audited; only AGENTS.md/CHANGELOG/roadmap needed changes for this internal refactor and test discipline. | Manual acceptance rows remain listed under this slice. | Done |
| With personal `qq -> :q<CR>` and `<leader>qq -> :q<CR>`, press both in the Markdown pane and a Codex pane; confirm Sidepanes returns to Markdown without closing the window. | `lua/sidepanes/maps.lua` non-ask plain-quit guard via policy. | `tests/sidepanes_regression.lua` "personal normal quit mappings do not close markdown or terminal side panes"; illu smoke covers local Codex `<leader>qq`. Full checks passed. | This slice manual acceptance section and public plain-quit guard docs. | Perform this exact workflow in Neovim. | Done |
| In the ask pane, press configured `qq` and `<leader>qq` on unwritten and written drafts; confirm the policy outcomes match cancel/send expectations. | `ask_policy.plan()` drives `finish_quit`; ask-pane send maps call `M.finish_quit`. | `tests/sidepanes_regression.lua` "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts"; direct policy plan test covers modified/written finish branches. Full checks passed. | This slice manual acceptance section and public quit-lifecycle docs. | Perform this exact workflow in Neovim. | Done |
| In the ask pane, press Ctrl+Enter in a terminal that reports `<C-CR>` and one that reports `<C-J>`; confirm both submit through the same policy path. | `ask_pane.lua` maps `<C-J>` when `ask_submit` is default `<C-CR>`; `submit_now()` executes `ask_policy.plan()`. | Submit mapping regression covers registered `<C-CR>` callback and fed-key `<C-J>` fallback; direct policy test covers submit branches. Full checks passed. | This slice manual acceptance section and `<C-J>` fallback docs. | Perform this exact workflow in Neovim. | Done |
| Inspect the direct policy tests and confirm each action plan corresponds to a row in the behavior matrix. | Direct policy tests exercise plans matching behavior matrix rows for quit, write-quit, send shortcuts, submit, failed/no-draft, and before-send picker paths. | `tests/sidepanes_regression.lua` direct policy test and docs contract passed. | This slice manual acceptance section and behavior matrix. | Review direct policy tests against the matrix. | Done |

Verification results:

- `tests/run_checks.sh fast` passed with 155 regression tests.
- `tests/run_checks.sh full` passed with 155 regression tests and real CLI
  smoke.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh`
  passed.

Audit passes:

- Pass 1 checked the policy table against command-line handling, ask-pane
  lifecycle entry points, non-ask mapping guards, behavior matrix rows, and
  existing fed-key regressions. No missing branch was found after the direct
  policy tests were added.
- Pass 2 checked AGENTS.md, README, CHANGELOG, Neovim help, Markdown docs,
  release notes, roadmap order/status, traceability, and `illu.nvim`
  integration. Only AGENTS.md, CHANGELOG, and this roadmap needed updates for
  the internal policy refactor and test-discipline guidance.

### 24. Ask Architecture Boundary Refactor

Status: `Done`

User response: refactor and clean up before continuing; decouple, use higher
order functions and composition where useful, keep pure functions where possible,
and stop expanding behavior until the mapping/state/action interplay is clean.

Goal: consolidate the ask-pane architecture around one decision layer, thin
adapters, and an injected lifecycle executor before adding new features.

Remaining implementation order, restated before starting this slice:

1. `24. Ask Architecture Boundary Refactor`
2. `25. Ask Session State And Status Snapshot Refactor`
3. `26. Ask Test Architecture And Fed-Key Coverage Cleanup`
4. `18. Target Resolver Refactor`
5. `14. Ask Pane Module Split`
6. `17. Ask Target And Picker Status Visibility`
7. `20. SidepanesAskStatus`
8. `21. SidepanesVersion`
9. `22. Interactive Keymap Help`
10. `19. Interaction-Focused Manual Acceptance Checklist`
11. Final verification and release-readiness audit

- Apply the repository architecture rule from `AGENTS.md`: functional core,
  imperative Neovim shell, clear public surfaces, private pure helpers, and
  compact modules.
- Treat line count and helper sprawl as design smells during this slice:
  - prefer deleting or merging duplicated predicates over moving them.
  - prefer table-driven policies/selectors over repeated branching when it stays
    readable.
  - avoid creating a new module unless it creates a clear boundary or removes
    real complexity.
  - record any intentional LOC increase in the traceability table with the
    reason it improves clarity or testability.
- Inventory the current ask-related responsibilities across
  `ask_pane.lua`, `ask_policy.lua`, `ask_prompt.lua`, `maps.lua`, command
  handlers, winbar/status code, and tests; record any surprising dependency or
  behavior loop as a roadmap bullet before changing implementation code.
- Architecture review finding: `ask_pane.lua` currently owns too many roles in
  one file: session storage, buffer creation, lifecycle setup, ask-pane keymap
  registration, command-line interception, policy execution, target picking,
  send/cancel/write side effects, prompt mutation, navigation, and source jump.
  Split responsibilities by boundary instead of moving the same shape into more
  files.
- Architecture review finding: command-line interception is duplicated between
  non-ask pane handling in `maps.lua` and ask-pane handling in `ask_pane.lua`.
  Extract the common classification/dispatch shape so both adapters collect
  command text and delegate intent handling consistently.
- Architecture review finding: the floating question editor and ask pane still
  have separate write/quit/send lifecycles. Decide whether they share the ask
  policy, have explicitly separate policies, or keep separate compatibility
  paths; do not leave accidental semantic drift.
- Architecture review finding: `question.lua` still owns pane-mode ask routing
  and default target selection before calling into `ask_pane.lua`. Keep this
  compatible during slice 24, but prepare it for the target resolver slice by
  making the routing decision explicit and testable.
- Architecture review finding: `init.lua` uses the broad `question_deps()` bundle
  for both the floating question editor and ask pane. Split or narrow dependency
  surfaces so ask-pane code receives only what each boundary needs.
- Architecture review finding: command-line expression maps return repeated raw
  `require("sidepanes.internal")...` command strings. Generate those strings
  from a small table or adapter helper so lifecycle command routing is not
  duplicated per intent.
- Architecture review finding: winbar ask labels still have fallback state
  derivation from `modified`, `written_prompt`, `ready`, and citations. Replace
  that with the snapshot/state selector from slice 25 so the winbar does not
  carry lifecycle logic.
- Preserve the existing user-visible behavior while refactoring; any behavior
  change discovered during cleanup must be added as a gap under this slice and
  traced explicitly.
- Keep `ask_policy` pure:
  - no Neovim API calls.
  - no state mutation.
  - no notification, window, buffer, picker, terminal, or filesystem effects.
  - inputs are explicit intents plus explicit facts.
  - outputs are action plans, predicates, labels, or validation errors.
- Refine the policy vocabulary so state/fact names read like the behavior
  matrix:
  - explicit intent names for quit, hard cancel, write, submit, picker, append,
    and target-change behavior.
  - explicit fact names for valid buffer, dirty buffer, live prompt, written
    prompt, picker mode, active target, previous pane, and terminal availability.
  - explicit action names for write, cancel, restore, open picker, resolve
    target, send, preserve draft, notify, and noop.
- Introduce a lifecycle executor boundary:
  - policy decides what should happen.
  - executor performs UI/state side effects.
  - executor receives dependencies and state accessors explicitly rather than
    reaching into unrelated modules opportunistically.
  - executor is testable with fake dependencies.
- Compose lifecycle handlers through a small controller factory, for example a
  function that receives `{ state, deps, policy, executor }` and returns
  handlers such as `finish_quit`, `submit_now`, `cancel_draft`, `write_draft`,
  `append_context`, and `change_target`.
- Make keymap modules thin:
  - registration functions normalize mappings and attach callbacks.
  - callbacks submit lifecycle intents to the controller.
  - callbacks do not inspect modified state, written prompt state, picker mode,
    or target state.
  - non-ask keymaps may only ask the policy whether a configured mapping is a
    plain quit guard.
- Make command-line handling a thin adapter:
  - command-line text is parsed/classified by policy.
  - command-line interception and fallback code only collect text and submit
    lifecycle intents.
  - no command-line callback decides send/cancel/write/picker behavior.
- Keep action composition readable:
  - prefer small pure selector/predicate functions over nested branching.
  - use higher-order functions only where they remove repeated dependency
    threading or clarify handler construction.
  - avoid clever callback chains that make Neovim side effects hard to follow.
- Define explicit module surfaces before moving code:
  - list public functions each ask module is allowed to export.
  - keep one module-local section for private helpers where Lua module shape
    makes that practical.
  - avoid exposing helpers just so tests can reach them; prefer testing pure
    modules directly or behavior through the public boundary.
- Add direct tests for policy purity and lifecycle executor behavior with fake
  dependencies.
- Add regression tests proving user-visible behavior is unchanged for quit,
  write, submit, picker, target, restore, and mapping paths touched by the
  refactor.
- Add or keep fed-key tests for every behavior-sensitive mapping touched by this
  slice; callback-only tests are allowed only for registration and must have a
  matching fed-key test or an explicit no-fed-key reason.
- Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs,
  Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before
  moving on.
- Post-completion audit gap: slice 24 was completed before commit references
  were mandatory, so record the catch-up commit and the process-rule commit
  before progressing to slice 25.
- Post-completion audit gap: the original slice 24 audit notes were not a
  falsifiable two-clean-pass loop after the last change, so perform and record
  two consecutive clean post-slice audit passes before progressing.
- Post-completion audit gap: the first audit-record commit left stale future
  wording and incomplete commit evidence after its follow-up correction, so
  record that correction and restart the clean-pass count again.

Manual acceptance tests:

- In the ask pane, run `:q`, `:q!`, `:w`, `:wq`, `:x`, configured `qq`,
  configured `<leader>qq`, `<C-CR>`, and `<C-J>`; confirm outcomes match the
  behavior matrix.
- In Markdown and Codex panes, press personal plain-quit mappings such as `qq`
  and `<leader>qq`; confirm Sidepanes does not close.
- Change target manually with `M`, then submit; confirm target choice survives
  the refactor.
- Use `model_picker = "before_send"` and confirm picker timing is unchanged.
- Force a failed terminal open/send and confirm the draft is preserved with the
  same warning/state behavior as before.

Refinement note: this slice is deliberately architectural. It should make the
code smaller where possible, but the real success criterion is that behavioral
decisions have one home and UI adapters stop carrying state-machine logic.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference | Documentation reference | Manual acceptance test reference | Status |
| --- | --- | --- | --- | --- | --- |
| Apply the repository architecture rule from `AGENTS.md`: functional core, imperative Neovim shell, clear public surfaces, private pure helpers, and compact modules. | Pure/boundary modules added in `lua/sidepanes/ask_cmdline.lua`, `lua/sidepanes/ask_controller.lua`, `lua/sidepanes/ask_executor.lua`, `lua/sidepanes/ask_route.lua`; Neovim shell remains in `ask_pane.lua`, `ask_keymaps.lua`, `maps.lua`, and `question.lua`. | `tests/sidepanes_regression.lua` "ask functional core modules do not call Neovim APIs directly"; fast checks passed with 160 regression tests. | `AGENTS.md` and this roadmap. | Manual architecture review after implementation. | Done |
| Treat line count and helper sprawl as design smells during this slice: | `ask_pane.lua` reduced from 840 to 799 lines; `maps.lua` from 277 to 269; `question.lua` is roughly stable while explicit routing/deps were added. Intentional new LOC is in five small boundary modules plus direct tests. | Fast and full checks passed with 160 regression tests. | This traceability table records the LOC tradeoff. | Manual code review for LOC/helper sprawl. | Done |
| prefer deleting or merging duplicated predicates over moving them. | Raw command-string and command-line classification duplication moved into `ask_cmdline`; plan execution moved out of `ask_pane.lua` into `ask_executor`. | Command adapter, executor, controller, policy, and unchanged behavior tests passed in fast checks. | This roadmap. | Manual code review for removed/merged duplication. | Done |
| prefer table-driven policies/selectors over repeated branching when it stays readable. | `ask_cmdline.lua` uses intent/command tables; `ask_route.lua` uses ordered explicit selectors; `ask_policy.normalize_facts()` centralizes fact aliases. | Direct command adapter, route, and policy tests passed. | This roadmap. | Manual code review for readable table-driven decisions. | Done |
| avoid creating a new module unless it creates a clear boundary or removes real complexity. | New modules are boundary-scoped: command adapter, controller, executor, keymap adapter, route helper. Full module split remains deferred to slice 14. | Direct tests cover pure command/controller/executor/route modules; existing mapping tests cover keymap adapter behavior. | This roadmap. | Manual code review for each new module. | Done |
| record any intentional LOC increase in the traceability table with the reason it improves clarity or testability. | Intentional LOC increase is from boundary modules and direct tests; it improves testability of command routing, controller composition, execution, and route defaults. | Fast and full checks passed with 160 regression tests. | This traceability row. | Manual traceability review. | Done |
| Inventory the current ask-related responsibilities across `ask_pane.lua`, `ask_policy.lua`, `ask_prompt.lua`, `maps.lua`, command handlers, winbar/status code, and tests; record any surprising dependency or behavior loop as a roadmap bullet before changing implementation code. | Architecture findings were recorded under this slice before implementation. | Not Applicable: architecture inventory; verified by roadmap findings. | This roadmap. | Manual inventory review before implementation. | Done |
| Architecture review finding: `ask_pane.lua` currently owns too many roles in one file: session storage, buffer creation, lifecycle setup, ask-pane keymap registration, command-line interception, policy execution, target picking, send/cancel/write side effects, prompt mutation, navigation, and source jump. Split responsibilities by boundary instead of moving the same shape into more files. | Extracted ask-pane keymap registration to `ask_keymaps`, plan execution to `ask_executor`, controller composition to `ask_controller`, command string generation to `ask_cmdline`; session/prompt/navigation remain for slice 14. | Direct boundary tests and existing ask-pane behavior tests passed in fast checks. | This roadmap; slice 14 still owns the later file/module split. | Manual code review that responsibilities are separated by boundary. | Done |
| Architecture review finding: command-line interception is duplicated between non-ask pane handling in `maps.lua` and ask-pane handling in `ask_pane.lua`. Extract the common classification/dispatch shape so both adapters collect command text and delegate intent handling consistently. | `ask_cmdline.markdown_return_command()` and `ask_cmdline.ask_pane_command_for_line()` are used by `maps.lua` and `ask_pane.lua`. | Direct command adapter tests plus existing ask/non-ask command-line tests passed. | This roadmap. | Manual command-line tests for ask and non-ask panes. | Done |
| Architecture review finding: the floating question editor and ask pane still have separate write/quit/send lifecycles. Decide whether they share the ask policy, have explicitly separate policies, or keep separate compatibility paths; do not leave accidental semantic drift. | Kept explicit compatibility path in `ask_cmdline.floating_question_command_for_line()` while ask pane uses policy intent mapping. No behavior change to floating editor. | Direct command adapter tests assert floating `q!` compatibility and `wq` command sequence; existing floating question tests passed. | This roadmap; no public docs change because behavior is unchanged. | Manual review of floating vs pane lifecycle behavior. | Done |
| Architecture review finding: `question.lua` still owns pane-mode ask routing and default target selection before calling into `ask_pane.lua`. Keep this compatible during slice 24, but prepare it for the target resolver slice by making the routing decision explicit and testable. | Current default target and auto-append decisions moved through pure `ask_route`; `question.lua` still orchestrates until slice 18 resolver. | Direct route tests plus existing pane-mode ask routing regressions passed. | This roadmap; slice 18 remains the full resolver refactor. | Manual ask routing checks. | Done |
| Architecture review finding: `init.lua` uses the broad `question_deps()` bundle for both the floating question editor and ask pane. Split or narrow dependency surfaces so ask-pane code receives only what each boundary needs. | Added `ask_pane_deps()` in `init.lua`; direct ask-pane facade methods use it; `question.lua` passes `ask_pane_deps()` to ask-pane operations when available. | Fast and full checks passed with 160 regression tests. | This roadmap. | Manual dependency-surface review. | Done |
| Architecture review finding: command-line expression maps return repeated raw `require("sidepanes.internal")...` command strings. Generate those strings from a small table or adapter helper so lifecycle command routing is not duplicated per intent. | `ask_cmdline.lua` owns internal command generation for Markdown return, ask-pane lifecycle, and floating question compatibility. | Direct command adapter tests and existing command-line callback tests passed. | This roadmap. | Manual command-line command-string review. | Done |
| Architecture review finding: winbar ask labels still have fallback state derivation from `modified`, `written_prompt`, `ready`, and citations. Replace that with the snapshot/state selector from slice 25 so the winbar does not carry lifecycle logic. | Explicitly deferred to slice 25 because the snapshot model does not exist yet. | Not Applicable for slice 24; slice 25 will test snapshot/winbar agreement. | This roadmap and slice 25. | Manual winbar review in slice 25. | Not Applicable |
| Preserve the existing user-visible behavior while refactoring; any behavior change discovered during cleanup must be added as a gap under this slice and traced explicitly. | Runtime behavior unchanged; refactor is command/controller/executor/deps boundary only. | `tests/run_checks.sh fast` and `tests/run_checks.sh full` passed with 160 regression tests; `illu.nvim` smoke passed. | Public docs, help docs, CHANGELOG, and release notes audited; no user-facing docs change needed for this internal refactor. | Full manual acceptance list under this slice. | Done |
| Keep `ask_policy` pure: | `ask_policy.lua` remains pure and gained `normalize_facts()` plus clearer intent/action vocabulary. | Static purity test covers `ask_policy`, `ask_cmdline`, `ask_controller`, `ask_executor`, and `ask_route`. | This roadmap and `AGENTS.md`. | Manual code review for `vim.*` usage and mutation. | Done |
| no Neovim API calls. | `ask_policy.lua` has no `vim.*` calls. | Static purity test passed. | This roadmap. | Manual code review. | Done |
| no state mutation. | `ask_policy.plan()` and `normalize_facts()` return new tables/plans and do not mutate plugin state. | Direct policy tests passed. | This roadmap. | Manual code review. | Done |
| no notification, window, buffer, picker, terminal, or filesystem effects. | Effects live in `ask_pane.lua` handlers and `ask_keymaps.lua` adapter, not in policy. | Static purity test passed. | This roadmap. | Manual code review. | Done |
| inputs are explicit intents plus explicit facts. | `ask_policy.plan(intent, facts)` normalizes explicit facts; `ask_pane.lua` lifecycle facts now use `valid_buffer`, `dirty_buffer`, and `picker_mode`. | Direct policy tests cover normalized facts and backwards-compatible aliases. | This roadmap. | Manual policy API review. | Done |
| outputs are action plans, predicates, labels, or validation errors. | `ask_policy` returns constants, predicates, normalized facts, and action plans only. | Direct policy tests passed. | This roadmap. | Manual policy API review. | Done |
| Refine the policy vocabulary so state/fact names read like the behavior matrix: | Added `normalize_facts()` and expanded intent/action vocabulary in `ask_policy`. | Direct policy tests assert vocabulary and normalized facts. | This roadmap and behavior matrix vocabulary. | Manual policy vocabulary review. | Done |
| explicit intent names for quit, hard cancel, write, submit, picker, append, and target-change behavior. | `ask_policy.INTENTS` includes `finish_quit`, `cancel_draft`, `write_draft`, `submit_now`, `open_picker`, `append_context`, and `change_target`. | Direct policy tests assert added intent constants. | This roadmap. | Manual intent vocabulary review. | Done |
| explicit fact names for valid buffer, dirty buffer, live prompt, written prompt, picker mode, active target, previous pane, and terminal availability. | `ask_policy.normalize_facts()` owns explicit fact names and compatibility aliases; `ask_pane.lifecycle_facts()` emits explicit names. | Direct policy tests assert every listed fact. | This roadmap. | Manual fact vocabulary review. | Done |
| explicit action names for write, cancel, restore, open picker, resolve target, send, preserve draft, notify, and noop. | `ask_policy.ACTIONS` includes existing write/cancel/open/send/noop actions plus restore/resolve/preserve/notify vocabulary constants for upcoming slices. | Direct policy tests assert added action constants; executor tests cover active plan actions. | This roadmap. | Manual action vocabulary review. | Done |
| Introduce a lifecycle executor boundary: | `ask_executor.run()` executes policy action plans through injected handlers. | Direct executor fake-handler test passed. | This roadmap. | Manual executor boundary review. | Done |
| policy decides what should happen. | `ask_controller` asks `ask_policy.plan()` before execution; `ask_pane.finish_quit()` and `submit_now()` call controller methods. | Direct controller and policy tests passed. | This roadmap. | Manual policy/executor review. | Done |
| executor performs UI/state side effects. | `ask_executor` maps plan steps to injected side-effect handlers; actual `vim.*` effects remain in ask-pane handlers. | Direct executor fake-handler test passed. | This roadmap. | Manual executor review. | Done |
| executor receives dependencies and state accessors explicitly rather than reaching into unrelated modules opportunistically. | `ask_controller.create()` receives `facts` and `handlers`; `ask_executor.run()` receives only plan/handlers. | Direct controller/executor tests passed. | This roadmap. | Manual dependency review. | Done |
| executor is testable with fake dependencies. | `ask_executor.run()` has no direct Neovim calls and is tested with fake handlers. | Direct executor fake-handler test passed. | This roadmap. | Manual fake-dependency review. | Done |
| Compose lifecycle handlers through a small controller factory, for example a function that receives `{ state, deps, policy, executor }` and returns handlers such as `finish_quit`, `submit_now`, `cancel_draft`, `write_draft`, `append_context`, and `change_target`. | `ask_controller.create()` returns `finish_quit`, `submit_now`, `cancel_draft`, `write_draft`, `append_context`, and `change_target`; `ask_pane.lua` composes it in private `controller_for`. | Direct controller composition test passed. | This roadmap. | Manual controller API review. | Done |
| Make keymap modules thin: | Ask-pane lifecycle keymaps moved to `ask_keymaps.setup()`; callbacks call controller methods only. Non-ask maps still delegate plain-quit classification to policy. | Existing mapping registration/fed-key regressions passed in fast checks. | This roadmap and `AGENTS.md`. | Manual keymap review. | Done |
| registration functions normalize mappings and attach callbacks. | `ask_keymaps.lua` owns ask-pane local map registration, including `<C-J>` fallback for default `<C-CR>`. | Existing configurable mapping and submit mapping tests passed. | This roadmap. | Manual keymap review. | Done |
| callbacks submit lifecycle intents to the controller. | `ask_keymaps.lua` callbacks call `controller.submit_now()`, `controller.finish_quit()`, or `controller.change_target()`. | Existing ask-pane send/submit/picker mapping tests passed. | This roadmap. | Manual mapping checks. | Done |
| callbacks do not inspect modified state, written prompt state, picker mode, or target state. | `ask_keymaps.lua` callbacks do not inspect lifecycle state; state is read by controller facts. | Static/manual review plus existing behavior tests; no separate automated state-inspection test. | This roadmap. | Manual callback review. | Done |
| non-ask keymaps may only ask the policy whether a configured mapping is a plain quit guard. | `maps.lua` non-ask quit guards use `ask_policy.is_plain_quit_rhs()` / `lhs_candidates()` and command-line plain-quit predicate; command generation uses `ask_cmdline`. | Personal quit mapping fed-key tests passed. | This roadmap. | Manual non-ask mapping checks. | Done |
| Make command-line handling a thin adapter: | `ask_cmdline` builds lifecycle command strings; `ask_pane.lua`, `maps.lua`, and `question.lua` collect command text and expand termcodes. | Direct command adapter tests and existing command-line tests passed. | This roadmap. | Manual command-line review. | Done |
| command-line text is parsed/classified by policy. | Ask-pane command text flows through `ask_cmdline.ask_pane_command_for_line()` and `ask_policy.commandline_intent()`. | Direct command adapter and policy tests passed. | This roadmap. | Manual command-line tests. | Done |
| command-line interception and fallback code only collect text and submit lifecycle intents. | Ask/non-ask interceptors now use `ask_cmdline` helpers; fallback `CmdlineLeave` schedules `controller.run_intent(intent)`. | Existing command-line regression and typed `:q!` fed-key test passed. | This roadmap. | Manual command-line review. | Done |
| no command-line callback decides send/cancel/write/picker behavior. | Ask command-line callbacks return commands by intent; controller/policy/executor decide lifecycle behavior. Floating compatibility is explicit in `ask_cmdline`. | Direct command adapter and controller tests passed. | This roadmap. | Manual command-line callback review. | Done |
| Keep action composition readable: | Small modules with one public boundary each; `ask_pane` private `controller_for` wires facts/handlers without nested action branching. | Direct boundary tests passed. | This roadmap. | Manual readability review. | Done |
| prefer small pure selector/predicate functions over nested branching. | `ask_route.default_entry()`, `ask_route.auto_append_blocked()`, and `ask_policy.normalize_facts()` are small pure helpers. | Direct route and policy tests passed. | This roadmap. | Manual readability review. | Done |
| use higher-order functions only where they remove repeated dependency threading or clarify handler construction. | `ask_controller.create()` is the only new higher-order boundary; it removes repeated facts/handler threading in lifecycle entry points. | Direct controller composition test passed. | This roadmap and `AGENTS.md`. | Manual design review. | Done |
| avoid clever callback chains that make Neovim side effects hard to follow. | Effects are visible in `ask_pane` controller handlers; keymaps/command adapters do not hide state-machine decisions. | Direct boundary and existing behavior tests passed. | This roadmap and `AGENTS.md`. | Manual design review. | Done |
| Define explicit module surfaces before moving code: | Public surfaces are small: `ask_cmdline` command builders, `ask_controller.create`, `ask_executor.run`, `ask_keymaps.setup`, `ask_route` selectors. | Direct tests cover pure module surfaces; behavior tests cover keymap shell. | This roadmap. | Manual module-surface review. | Done |
| list public functions each ask module is allowed to export. | Public functions are listed by implementation refs; `ask_pane` controller helper is private, not exported. | Manual/static review; no dedicated automated export-list test. | This roadmap. | Manual module-surface review. | Done |
| keep one module-local section for private helpers where Lua module shape makes that practical. | New modules keep private helpers local above exported functions. | Static/manual review; no dedicated automated test. | This roadmap. | Manual module-surface review. | Done |
| avoid exposing helpers just so tests can reach them; prefer testing pure modules directly or behavior through the public boundary. | Pure modules are tested directly; ask-pane `controller_for` remains private; keymap behavior remains covered through runtime mappings/fed-key tests. | Direct pure tests and existing behavior tests passed. | This roadmap. | Manual test/API review. | Done |
| Add direct tests for policy purity and lifecycle executor behavior with fake dependencies. | Tests added in `tests/sidepanes_regression.lua`. | "ask functional core modules do not call Neovim APIs directly"; "ask lifecycle executor runs policy actions through fake handlers"; fast and full checks passed. | This roadmap. | Manual test review. | Done |
| Add regression tests proving user-visible behavior is unchanged for quit, write, submit, picker, target, restore, and mapping paths touched by the refactor. | Existing behavior tests retained; direct tests added for new boundaries. | `tests/run_checks.sh fast` and `tests/run_checks.sh full` passed with 160 regression tests. | Public docs unchanged because behavior is unchanged. | Manual acceptance list under this slice. | Done |
| Add or keep fed-key tests for every behavior-sensitive mapping touched by this slice; callback-only tests are allowed only for registration and must have a matching fed-key test or an explicit no-fed-key reason. | Existing fed-key tests for typed `:q!`, personal `qq`/`<leader>qq`, and `<C-J>` submit retained; callback tests remain for registration/command-string adapter paths. | Full checks and `illu.nvim` smoke passed. | `AGENTS.md` and this roadmap. | Manual keypress acceptance tests. | Done |
| Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs, Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before moving on. | Implementation, test, docs, roadmap, and local integration audit completed. | `tests/run_checks.sh fast`, `tests/run_checks.sh full`, `illu.nvim` smoke, and `git diff --check` passed. | Public docs, help docs, CHANGELOG, release notes, AGENTS.md, and roadmap audited; no additional public docs change needed. | Manual audit before Done. | Done |
| Post-completion audit gap: slice 24 was completed before commit references were mandatory, so record the catch-up commit and the process-rule commit before progressing to slice 25. | Catch-up commit `0cf2ff7` contains the accumulated ask-pane implementation/test/doc state. Process commit `97b86a5` adds per-unit commit and stricter audit rules. Audit-record commit `2ca3fce` records the post-slice audit evidence. | `git log --oneline --decorate -5` confirmed all three commits; `git status --short` confirmed sidepanes.nvim was clean after `2ca3fce`. | `AGENTS.md`, Mandatory Slice Completion Protocol, and this traceability row. | Review branch log and confirm no completed slice unit remains uncommitted before slice 25 starts. | Done |
| Post-completion audit gap: the original slice 24 audit notes were not a falsifiable two-clean-pass loop after the last change, so perform and record two consecutive clean post-slice audit passes before progressing. | Post-slice audit passes below record scope and outcome after commits `0cf2ff7`, `97b86a5`, and `2ca3fce`. | `tests/run_checks.sh fast` passed with 160 regression tests; `tests/run_checks.sh full` passed; `illu.nvim` smoke passed; `git diff --check` passed before `2ca3fce`. | This roadmap audit section; `AGENTS.md` and Mandatory Slice Completion Protocol define future enforcement. | Review recorded post-protocol passes before slice 25 starts. | Done |
| Post-completion audit gap: the first audit-record commit left stale future wording and incomplete commit evidence after its follow-up correction, so record that correction and restart the clean-pass count again. | Audit-evidence correction commit `01bc961` fixed stale wording after `2ca3fce`; the follow-up audit evidence records that any audit-record correction restarts the clean-pass count. | `git log --oneline --decorate -8` confirmed `01bc961`; `git status --short` was clean before the follow-up audit evidence update; fresh post-update clean passes are required before slice 25. | This roadmap audit section. | Review branch log and require two fresh clean passes from the latest audit-evidence commit before slice 25 starts. | Done |
| In the ask pane, run `:q`, `:q!`, `:w`, `:wq`, `:x`, configured `qq`, configured `<leader>qq`, `<C-CR>`, and `<C-J>`; confirm outcomes match the behavior matrix. | Existing behavior preserved by ask controller/executor/command adapter. | Existing command-line, send mapping, submit mapping, and fed-key tests passed in full checks. | Behavior matrix and this roadmap. | Perform this exact workflow. | Done |
| In Markdown and Codex panes, press personal plain-quit mappings such as `qq` and `<leader>qq`; confirm Sidepanes does not close. | Non-ask guards still in `maps.lua` using policy and `ask_cmdline.markdown_return_command()`. | Personal quit fed-key regression and `illu.nvim` smoke passed. | Mapping zone matrix and this roadmap. | Perform this exact workflow. | Done |
| Change target manually with `M`, then submit; confirm target choice survives the refactor. | `ask_keymaps` delegates target mapping to controller/change-target handler; `ask_pane.change_target()` behavior unchanged. | Target picker mapping tests passed in full checks. | Existing public docs unchanged. | Perform this exact workflow. | Done |
| Use `model_picker = "before_send"` and confirm picker timing is unchanged. | Controller/executor runs `open_before_send_picker` action; picker behavior remains in `ask_pane.lua`. | Automatic model picker regression passed in full checks. | Existing public docs unchanged. | Perform this exact workflow. | Done |
| Force a failed terminal open/send and confirm the draft is preserved with the same warning/state behavior as before. | `ask_executor` delegates `send_prompt`; failure behavior remains in `ask_pane.lua`. | Failed terminal-open regression passed in full checks. | Existing public docs unchanged. | Perform this exact workflow. | Done |

Verification results:

- `tests/run_checks.sh fast` passed with 160 regression tests.
- `tests/run_checks.sh full` passed with 160 regression tests and real CLI
  smoke.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh`
  passed.
- `git diff --check` passed.
- Catch-up commit `0cf2ff7` recorded the accumulated ask-pane implementation,
  test, and documentation state after earlier slices were left uncommitted.
- Process commit `97b86a5` recorded the per-unit commit rule and stricter
  two-clean-pass audit rule.
- Audit-record commit `2ca3fce` recorded the post-slice audit evidence.
- Audit-evidence correction commit `01bc961` fixed stale future wording and
  incomplete commit evidence found by a later pass.

Audit passes:

- Pass 1 checked implementation boundaries, traceability placeholders,
  pure-module API usage, fast/full check results, `illu.nvim` applicability,
  and diff hygiene. It found only stale traceability statuses after full checks.
- Pass 2 checked README, CHANGELOG, Neovim help, Markdown docs, release notes,
  AGENTS.md, roadmap status/order, command-line adapter behavior, fed-key
  coverage, and public-doc applicability. No new gaps found.
- Pass 3 caught and fixed stale roadmap status text introduced while updating
  slice 24 traceability: slices 14 and 17 are planned, slice 24 is done, and
  the top remaining implementation order now starts at slice 25.
- Post-protocol pass 1 checked the committed branch state, slice 24
  traceability, implementation boundary modules, pure-module API usage,
  mapping/fed-key test references, README, CHANGELOG, Neovim help, Markdown
  docs, release notes, roadmap status/order, AGENTS.md, and `illu.nvim`
  applicability. It found the missing commit evidence and non-falsifiable audit
  loop recorded as post-completion gaps above; no additional behavior, test, or
  documentation gap was found.
- Post-protocol pass 2 rechecked roadmap status/order, slice 24 bullets and
  traceability, public ask-pane mapping docs, release notes, `AGENTS.md`,
  sidepanes git status/log evidence, full/fast check results, and `illu.nvim`
  smoke evidence after the process correction. No new gaps were found.
- Post-protocol pass 3 restarted from `01bc961` and checked clean worktree,
  commit history, traceability rows, process protocol text, and stale future
  wording. It found that `01bc961` itself was not recorded in the slice 24
  evidence, so this gap was added and the clean-pass count must restart again
  after the audit-evidence update.

### 25. Ask Session State And Status Snapshot Refactor

Status: `Done`

User response: continue cleaning up the architecture before new features.

Goal: give ask lifecycle, winbar/status, future debug commands, and tests one
coherent state snapshot instead of many places deriving related facts
differently.

Remaining implementation order, restated before starting this slice:

1. `25. Ask Session State And Status Snapshot Refactor`
2. `26. Ask Test Architecture And Fed-Key Coverage Cleanup`
3. `18. Target Resolver Refactor`
4. `14. Ask Pane Module Split`
5. `17. Ask Target And Picker Status Visibility`
6. `20. SidepanesAskStatus`
7. `21. SidepanesVersion`
8. `22. Interactive Keymap Help`
9. `19. Interaction-Focused Manual Acceptance Checklist`
10. Final verification and release-readiness audit

- Define one ask session model or snapshot module that owns the public shape of
  ask state consumed by policy, lifecycle, winbar, status, health/debug output,
  and future commands.
- Keep raw mutable Neovim/session state separate from pure snapshots:
  - raw state may contain buffer IDs, window IDs, callbacks, and cached prompts.
  - snapshots contain serializable facts and labels.
  - policy consumes snapshots or facts, not raw Neovim objects.
- Extract pure selectors for:
  - active/inactive ask session.
  - current draft state.
  - valid buffer/window facts.
  - modified/written/live prompt facts.
  - target label/root facts.
  - picker mode and picker-shown facts.
  - previous pane mode.
  - citation/file counts.
- Make lifecycle fact collection a single function or module used by all
  lifecycle entry points; do not let `finish_quit`, `submit_now`, status, and
  tests each derive their own version.
- Move state history and last-state reporting toward the ask session/snapshot
  boundary instead of storing lifecycle history partly beside `state.ask_pane`.
- Make winbar ask labels and future `SidepanesAskStatus` use the same snapshot
  formatter or pure status data.
- Remove fallback state derivation from winbar once the snapshot exists; winbar
  should format state, not infer it.
- Preserve compatibility shims for existing internal callers while moving them
  toward the new snapshot API.
- Add direct snapshot/selector tests for every state, empty/invalid buffer
  cases, written vs live prompt cases, target cases, and picker modes.
- Add integration tests proving winbar/status-facing output and lifecycle
  decisions agree on the same state labels.
- Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs,
  Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before
  moving on.
- Audit gap: after marking slice 25 `Done`, the top Remaining Implementation
  Order still listed slice 25 first. Remove it so the next planned slice is
  slice 26.

Manual acceptance tests:

- Open an empty ask pane and confirm the winbar/status-facing state is
  `ready_empty`.
- Append context, edit the question, write, submit, cancel, and failed-send;
  confirm visible state labels and behavior agree.
- Switch from Markdown to ask and from Codex to ask; confirm previous pane
  restore behavior still works.
- Run any existing debug/status helpers and confirm they report the same target,
  picker, and draft state visible in the UI.

Refinement note: this slice should make later `SidepanesAskStatus` mostly a
presentation command over an existing snapshot, not a new parallel status
implementation.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Define one ask session model or snapshot module that owns the public shape of ask state consumed by policy, lifecycle, winbar, status, health/debug output, and future commands. | `lua/sidepanes/ask_session.lua` defines the snapshot boundary, lifecycle fact projection, status data, title formatter, and state-history helper; `lua/sidepanes/ask_pane.lua` exposes runtime `snapshot()` / `lifecycle_facts()`; `lua/sidepanes/winbar.lua` formats ask labels from the snapshot title. Future public debug commands can build on the same status data. | Direct snapshot tests, runtime ready/written/append/target/picker/send/cancel/failed-send snapshot assertions, winbar snapshot-format regression, and focused regression passed with 165 tests. | This roadmap; no public docs change applies yet because no user-visible behavior changed. | Manual snapshot/state agreement checks listed under this slice. | `0c1054c`, `7aad91e`, `6c4b335`, `170eecb` | Done |
| Keep raw mutable Neovim/session state separate from pure snapshots: | `ask_session.snapshot()` accepts raw ask state plus explicit buffer/window/config facts and returns a serializable table; `ask_pane.lua` gathers Neovim-specific raw facts before calling it. | Direct snapshot tests cover fake buffer IDs, target data, cached written prompts, explicit buffer/window facts, and the functional-core no-`vim.*` purity check; runtime tests assert snapshots across ready, written, append, picker, send, cancel, and failed-send states. | This roadmap architecture requirement; no public docs change applies because this unit is internal. | Manual architecture review plus visible lifecycle checks. | `0c1054c`, `7aad91e`, `170eecb` | Done |
| raw state may contain buffer IDs, window IDs, callbacks, and cached prompts. | Raw state remains in the imperative ask-pane/session shell; direct tests pass fake `bufnr`, entry/root, previous pane, citations, and `written_prompt` into `ask_session.snapshot()`. | `tests/sidepanes_regression.lua` direct snapshot tests cover raw-to-snapshot conversion with fake IDs and cached prompt values. | This roadmap; no public docs change applies because this is internal architecture. | Manual architecture review. | `0c1054c` | Done |
| snapshots contain serializable facts and labels. | `ask_session.snapshot()`, `status_data()`, and `lifecycle_facts()` return booleans, strings, counts, and labels instead of raw Neovim handles. | Direct snapshot tests assert active state, draft state, target label/root, picker mode/shown, previous pane, counts, live/written prompts, and lifecycle facts. | This roadmap; future status docs may reference the status labels only. | Manual status/debug output check. | `0c1054c` | Done |
| policy consumes snapshots or facts, not raw Neovim objects. | `ask_pane.lua` controller facts now come from `ask_session.lifecycle_facts(snapshot(...))` instead of a local bespoke facts table. | Direct lifecycle-fact projection plus runtime ready/written `ask_pane.lifecycle_facts()` assertions passed in focused regression. Existing policy/lifecycle behavior tests continue to pass. | This roadmap; no public docs change applies because policy inputs are internal. | Manual lifecycle behavior checks. | `0c1054c`, `7aad91e` | Done |
| Extract pure selectors for: | `ask_session.snapshot()`, `status_data()`, `lifecycle_facts()`, and `format_title()` provide the pure selector surface and runtime callers now use that surface. | Direct selector tests cover every selector row below; focused regression passed with 165 tests. | This roadmap; no public docs change applies unless selector output becomes public status text. | Manual snapshot/status review. | `0c1054c`, `7aad91e`, `170eecb` | Done |
| active/inactive ask session. | `ask_session.snapshot()` reports `active` from raw session presence plus explicit valid-buffer facts; `ask_pane.snapshot()` exposes the runtime snapshot. | Direct selector tests cover ready active sessions and invalid-buffer inactive sessions; runtime tests assert active ready/failed-send snapshots and inactive sent/cancelled snapshots. | This roadmap; future `SidepanesAskStatus` docs will use this output. | Open/cancel/send ask pane and compare active/inactive status. | `0c1054c`, `7aad91e`, `170eecb` | Done |
| current draft state. | `ask_session.snapshot()` reports the current explicit draft state and defaults active sessions to `ready_empty` only when no state exists. | Direct selector tests enumerate `ready_empty`, `draft_modified`, `draft_written`, `sending_picker`, `sending_terminal`, `send_failed`, `cancelled`, and `sent`. | Existing lifecycle docs list labels; update only if wording or source changes. | Confirm visible labels across append, write, submit, cancel, and failed-send. | `0c1054c` | Done |
| valid buffer/window facts. | `ask_session.snapshot()` reports `valid_buffer`, `valid_window`, and `active_window` from explicit facts supplied by the shell; `ask_pane.snapshot()` supplies live runtime facts. | Direct selector tests cover valid buffer/window, invalid window, and invalid-buffer inactive cases; runtime ready ask pane test asserts active window/valid buffer and runtime sent/cancelled assertions cover inactive state after buffer clear. | This roadmap; no public docs change applies because validity facts are internal. | Manual invalid-window behavior review if a reproducible interaction exists. | `0c1054c`, `7aad91e`, `170eecb` | Done |
| modified/written/live prompt facts. | `ask_session.snapshot()` reports `dirty_buffer`, `live_prompt`, and `written_prompt`; `ask_pane.lifecycle_facts()` projects them for policy from the runtime snapshot. | Direct selector tests cover live vs written prompts, empty ready prompt, modified prompt, and invalid-buffer preserved facts; runtime ready/written, append, failed-send, submit, and send tests assert prompt/state agreement. | Existing public lifecycle docs should remain accurate unless behavior changes. | Append/edit/write/submit/cancel workflow listed under this slice. | `0c1054c`, `7aad91e`, `170eecb` | Done |
| target label/root facts. | `ask_session.snapshot()` reports `target_label` and `target_root` from raw `entry` and root state. | Direct selector tests cover explicit target labels, missing target, preset-label fallback, and root fallback; runtime target-picker and after-open picker tests assert snapshot/status target labels match the winbar target. | Existing target docs remain unchanged because behavior did not change. | Change target manually and compare status-facing output to winbar. | `0c1054c`, `170eecb` | Done |
| picker mode and picker-shown facts. | `ask_session.snapshot()` reports picker mode from ask config and `picker_shown` from raw session state. | Direct selector tests cover `manual`, `after_open`, and `before_send` picker modes plus shown/not-shown cases; runtime after-open picker test asserts mode, shown flag, and target label. | Existing picker docs remain unchanged because behavior did not change. | Use `after_open` and `before_send` workflows and inspect status-facing output. | `0c1054c`, `170eecb` | Done |
| previous pane mode. | `ask_session.snapshot()` reports `previous_pane_mode` from raw previous pane state. | Direct selector tests cover active mode, terminal-key fallback, and missing previous pane; existing previous-pane runtime tests continue to cover Markdown and Codex capture/restore, and cancel now asserts inactive snapshot after restore. | Existing restore docs remain unchanged because behavior did not change. | Switch from Markdown/Codex to ask and confirm restore behavior. | `0c1054c`, `170eecb` | Done |
| citation/file counts. | `ask_session.snapshot()` reports citation count and distinct file count from raw citations. | Direct selector tests cover zero citations, multiple citations in one file, and multiple files; runtime explicit-append test asserts two citations in one file. Duplicate skip and edited-visible-prompt fallback behavior remains covered by existing prompt tests and was not changed. | Future status docs may mention counts; no public docs change applies until a public command exposes them. | Append context across files and compare counts to visible prompt. | `0c1054c`, `170eecb` | Done |
| Make lifecycle fact collection a single function or module used by all lifecycle entry points; do not let `finish_quit`, `submit_now`, status, and tests each derive their own version. | `ask_pane.snapshot()` gathers runtime facts once and `ask_pane.lifecycle_facts()` feeds controller facts through `ask_session.lifecycle_facts()`. `finish_quit` and `submit_now` share the same controller path; winbar now formats the snapshot title instead of deriving state locally. | Runtime ready/written snapshot and lifecycle-fact assertions passed; existing `finish_quit` / `submit_now` behavior tests passed; append, target, picker, send, cancel, failed-send, and winbar agreement assertions passed in focused regression. | This roadmap; no public docs change applies because behavior is unchanged. | Run quit/submit/status workflows and compare behavior to labels. | `7aad91e`, `6c4b335`, `170eecb` | Done |
| Move state history and last-state reporting toward the ask session/snapshot boundary instead of storing lifecycle history partly beside `state.ask_pane`. | `ask_session.record_state()` owns lifecycle history/last-state mutation and `ask_pane.lua` delegates all `set_draft_state()` calls to it. | Direct state-history test plus existing runtime lifecycle history assertions passed in focused regression. | Existing lifecycle docs remain unchanged; roadmap records the internal move. | Inspect state labels through visible winbar/status-facing output during lifecycle workflows. | `0c1054c`, `7aad91e` | Done |
| Make winbar ask labels and future `SidepanesAskStatus` use the same snapshot formatter or pure status data. | `winbar.lua` ask labels call `ask_session.format_title(ask_pane.snapshot(state))`; `ask_session.status_data()` remains available for the later public command. | Runtime ready, target-change, failed-send, and fallback-regression tests assert winbar/status-facing output agrees with snapshot/status data; focused regression passed with 165 tests. | Existing winbar docs remain accurate; future command docs are deferred to slice 20 because no public command was added now. | Open/edit/write/send/fail and compare visible labels with status-facing data. | `6c4b335`, `170eecb` | Done |
| Remove fallback state derivation from winbar once the snapshot exists; winbar should format state, not infer it. | `winbar.lua` removed local fallback derivation from `modified`, `written_prompt`, `ready`, and citations; ask labels now use the snapshot formatter. | `tests/sidepanes_regression.lua` "ask pane winbar formats the session snapshot instead of deriving fallback state" mutates a buffer without an explicit raw draft state and asserts winbar does not infer `draft_modified`. | This roadmap; public docs do not need a behavior change because visible labels stay the same in normal states. | Confirm winbar labels match canonical states across lifecycle. | `6c4b335` | Done |
| Preserve compatibility shims for existing internal callers while moving them toward the new snapshot API. | `ask_pane.session()` and `ask_pane.DRAFT_STATES` remain available; `ask_pane.snapshot()` and `ask_pane.lifecycle_facts()` expose the new snapshot API for callers moving off raw state. | `tests/sidepanes_regression.lua` "ask pane keeps session state compatibility helpers while exposing snapshots" passed in focused regression with 165 tests. | This roadmap; no public docs change applies because shims are internal. | Manual smoke of existing ask workflows. | `1fd92b8` | Done |
| Add direct snapshot/selector tests for every state, empty/invalid buffer cases, written vs live prompt cases, target cases, and picker modes. | Direct tests added in `tests/sidepanes_regression.lua` for `ask_session`. | `tests/sidepanes_regression.lua` enumerates all explicit states, active/invalid sessions, live vs written prompts, target label/root cases, and `manual`/`after_open`/`before_send` picker modes. Focused regression passed with 165 tests. | This roadmap; no public docs change applies because this is test architecture for internal selectors. | Review focused snapshot tests and run ask workflows. | `0c1054c` | Done |
| Add integration tests proving winbar/status-facing output and lifecycle decisions agree on the same state labels. | Runtime tests assert snapshot/lifecycle/status/winbar agreement across ready, append, written, target change, after-open picker, send, cancel, and failed-send paths. | `tests/sidepanes_regression.lua` ready/written snapshot assertions, append count assertion, target/status/winbar assertion, after-open picker snapshot assertion, inactive sent/cancel assertions, failed-send status/winbar assertion, and winbar fallback regression passed in focused regression. | This roadmap; public docs unchanged because visible behavior did not change. | Manual visible-label agreement workflow listed under this slice. | `7aad91e`, `6c4b335`, `170eecb` | Done |
| Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs, Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before moving on. | Slice audit pass 1 checked implementation boundaries, traceability, tests, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap order/status, AGENTS.md, and `illu.nvim` applicability. Final clean confirmation passes are intentionally reported in the final response instead of being written back here. | Focused regression passed with 165 tests; `tests/run_checks.sh fast` passed; `tests/run_checks.sh full` passed; `git diff --check` passed. `illu.nvim` smoke was not applicable because no defaults, mappings, commands, public API, local config behavior, or `illu.nvim` files changed. | README, CHANGELOG, Neovim help, Markdown docs, release notes, roadmap, and AGENTS.md audited; no public docs change was needed because behavior stayed compatible and no public status command was added. | All manual acceptance tests listed under this slice are mapped to automated coverage or an explicit note that no public status helper exists until slice 20. | `e84df05` plus this audit evidence update. | Done |
| Open an empty ask pane and confirm the winbar/status-facing state is `ready_empty`. | `ask_pane.snapshot()` reports `ready_empty`; `winbar.lua` formats the snapshot title. | `tests/sidepanes_regression.lua` "ask pane opens reusable ready scratch buffer in the side split" asserts winbar, snapshot, status-facing facts, and lifecycle facts for the empty ask pane. | Existing lifecycle docs mention `ready_empty`; no docs change applies because behavior did not change. | Perform this exact workflow in Neovim. | `7aad91e`, `6c4b335` | Done |
| Append context, edit the question, write, submit, cancel, and failed-send; confirm visible state labels and behavior agree. | `ask_session.record_state()`, `ask_pane.snapshot()`, and `winbar.lua` snapshot formatting drive labels/facts through append, write, submit/send, cancel, and failed-send flows. | Runtime regression assertions cover append `draft_modified` counts, written prompt facts, inactive sent/cancel snapshots, failed-send snapshot/status/winbar labels, and existing lifecycle histories. | Existing lifecycle docs remain source for user-facing labels; no docs change applies because behavior did not change. | Perform this exact workflow in Neovim. | `7aad91e`, `6c4b335`, `170eecb` | Done |
| Switch from Markdown to ask and from Codex to ask; confirm previous pane restore behavior still works. | Previous pane state remains in raw ask session state and is exposed by `ask_session.snapshot()`; restore behavior remains in `ask_pane.cancel_draft()`. | Existing previous-pane capture/restore regressions passed; direct snapshot tests cover `previous_pane_mode`; cancel regression now asserts inactive snapshot after restore. | Existing restore docs remain unchanged because behavior did not change. | Perform this exact workflow in Neovim. | `0c1054c`, `170eecb` | Done |
| Run any existing debug/status helpers and confirm they report the same target, picker, and draft state visible in the UI. | Existing internal status-facing helpers were `ask_pane.snapshot()`, `ask_pane.lifecycle_facts()`, `ask_session.status_data()`, and `ask_session.format_title()`; no public `SidepanesAskStatus` command was added before slice 20. | Direct and runtime tests assert target, picker, draft state, and winbar/status-facing agreement. No separate public-helper test applied in slice 25 because `SidepanesAskStatus` was deferred to slice 20. | This roadmap; public command docs were deferred to slice 20 because no public helper changed in slice 25. | Manual workflow note for slice 25: before slice 20, use visible winbar plus internal snapshot helpers. Slice 20 now exposes the public command. | `0c1054c`, `7aad91e`, `6c4b335`, `170eecb` | Done |
| Audit gap: after marking slice 25 `Done`, the top Remaining Implementation Order still listed slice 25 first. Remove it so the next planned slice is slice 26. | Top-level Remaining Implementation Order now starts at `26. Ask Test Architecture And Fed-Key Coverage Cleanup`. | Not Applicable: roadmap-order correction only; no runtime behavior or tests changed. | This roadmap. | Review the top-level Remaining Implementation Order before starting the next slice. | `6e8ab4b` | Done |

Verification results:

- Focused regression passed with 165 tests.
- `tests/run_checks.sh fast` passed with 165 regression tests.
- `tests/run_checks.sh full` passed with 165 regression tests and real CLI
  smoke.
- `git diff --check` passed.
- `illu.nvim` smoke was not run because slice 25 did not change defaults,
  mappings, commands, public API, local config behavior, or `illu.nvim`.

Audit passes:

- Pass 1 checked every slice 25 bullet, traceability status, implementation
  boundaries, direct snapshot selectors, runtime lifecycle facts, winbar
  formatting, automated coverage, fed-key/mapping impact, command paths, state
  transitions, manual acceptance references, README, CHANGELOG, Neovim help,
  Markdown docs, release notes, roadmap status/order, AGENTS.md, and
  `illu.nvim` applicability. It found that the top Remaining Implementation
  Order still started with slice 25 after slice 25 was marked `Done`; that gap
  was recorded under this slice and fixed so the order now starts at slice 26.

### 26. Ask Test Architecture And Fed-Key Coverage Cleanup

Status: `Done`

User response: tests should stop calling mapping callbacks for
behavior-sensitive paths unless there is also a fed-key test; callback tests are
fine for registration, but they are not enough for user behavior.

Goal: make ask tests mirror the architecture and the actual user paths.

Remaining implementation order, restated before starting this slice:

1. `26. Ask Test Architecture And Fed-Key Coverage Cleanup`
2. `18. Target Resolver Refactor`
3. `14. Ask Pane Module Split`
4. `17. Ask Target And Picker Status Visibility`
5. `20. SidepanesAskStatus`
6. `21. SidepanesVersion`
7. `22. Interactive Keymap Help`
8. `19. Interaction-Focused Manual Acceptance Checklist`
9. Final verification and release-readiness audit

- Split or group the large regression coverage so ask behavior can be audited by
  layer:
  - policy predicate/action-plan tests.
  - snapshot/selector tests.
  - executor tests with fake dependencies.
  - command-line adapter tests.
  - keymap registration tests.
  - fed-key user-path tests.
  - end-to-end smoke tests.
- Reduce the 7k-plus-line catch-all regression file by moving ask-focused tests
  into smaller files when the test runner supports it, or by adding clear
  grouped helpers/sections when a split would create more harness churn than it
  removes.
- Identify callback assertions that test behavior-sensitive paths, especially
  ask-pane command-line and mapping paths, and pair them with fed-key coverage or
  replace them with fed-key coverage where Neovim can synthesize the path.
- Add a behavior-sensitive mapping coverage table in tests or docs that lists
  every ask/non-ask mapping path and whether it has:
  - registration coverage.
  - direct policy/state coverage.
  - fed-key coverage.
  - an explicit reason fed-key coverage does not apply.
- Convert callback-only tests for user-visible behavior into fed-key tests where
  Neovim can synthesize the key path reliably.
- Keep callback tests only for registration, normalized configuration, and
  narrow paths that cannot be fed realistically; record the reason near the
  test.
- Ensure fed-key tests cover normal, insert, terminal, and command-line zones
  affected by ask lifecycle behavior.
- Ensure tests compare expected behavior against the behavior matrix and mapping
  zone matrix rather than repeating stale implementation assumptions.
- Add focused test helpers for key feeding, command-line feeding, and pane state
  assertions so tests are readable without hiding the user action being tested.
- Run focused ask tests, `tests/run_checks.sh fast`, `tests/run_checks.sh full`,
  `illu.nvim` smoke when mappings/local integration are affected, and
  `git diff --check`.
- Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs,
  Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before
  moving on.

Manual acceptance tests:

- For every mapping listed in the behavior-sensitive coverage table, perform
  the real keypress in Neovim and compare the outcome to the matrix.
- Repeat personal `qq` / `<leader>qq` checks in Markdown, Codex, and ask panes.
- Repeat `<C-CR>` / `<C-J>` submit checks from normal and insert ask-pane modes.
- Run the focused ask test group and confirm failures point to user behavior,
  not just callback plumbing.

Refinement note: this slice is allowed to reorganize tests without changing
runtime behavior. It should make the next feature failure easier to localize:
policy bug, adapter bug, executor bug, fed-key/runtime bug, or docs mismatch.

Traceability table:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Split or group the large regression coverage so ask behavior can be audited by layer: | `tests/sidepanes_regression.lua` now has ask layer markers for keymap/coverage, policy, snapshot, command-line adapter, executor, fed-key user paths, and pane-mode smoke; `SIDEPANES_TEST_FILTER` supports focused ask runs without splitting the shared harness. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap; no public docs change applies because test organization is internal. | Run the focused ask test group and confirm failures point to the relevant layer. | `e8c6d20`, `047347c` | Done |
| policy predicate/action-plan tests. | `tests/sidepanes_regression.lua` groups `ask_policy` predicate/action-plan assertions under the policy layer marker. | `tests/sidepanes_regression.lua` "ask action policy classifies command lines plain quit mappings and lifecycle plans" passed in the focused ask run. | This roadmap; no public docs change applies because this is test architecture. | Confirm policy failures localize to decision behavior rather than key feeding. | `047347c` | Done |
| snapshot/selector tests. | `tests/sidepanes_regression.lua` groups `ask_session` selector tests under the snapshot layer marker. | Direct snapshot/selector tests passed in the focused ask run. | This roadmap; no public docs change applies because this is test architecture. | Confirm snapshot failures localize to selector facts/labels. | `047347c` | Done |
| executor tests with fake dependencies. | `tests/sidepanes_regression.lua` groups `ask_executor` fake-dependency coverage under the executor layer marker. | `tests/sidepanes_regression.lua` "ask lifecycle executor runs policy actions through fake handlers" passed in the focused ask run. | This roadmap; no public docs change applies because this is test architecture. | Confirm executor failures localize to effect execution. | `047347c` | Done |
| command-line adapter tests. | `tests/sidepanes_regression.lua` keeps the pure adapter/callback assertions separate from fed command-line behavior; `:w` now routes through the adapter to avoid scratch-buffer write errors. | Adapter translation test and fed `:q` / `:q!` / `:w` / `:wq` user-path tests passed in the focused ask run. | This roadmap and mapping-zone matrix row `ask-pane-command-line`; CHANGELOG notes the `:w` command-path fix. | Run command-line `:q`, `:q!`, `:w`, and `:wq` ask workflows. | `e8c6d20`, `047347c`, `ec1d381` | Done |
| keymap registration tests. | `tests/sidepanes_regression.lua` keeps registration coverage in the keymap/coverage layer; `tests/ask_pane_mapping_coverage.lua` records registration evidence per path. | `tests/sidepanes_regression.lua` "ask mapping zone matrix matches active maps by user location" and coverage-table integrity test passed. | This roadmap and `tests/ask_pane_mapping_zone_matrix.lua`; no public docs change applies because mappings did not change. | Inspect mapped keys in the relevant pane zones. | `e8c6d20`, `047347c` | Done |
| fed-key user-path tests. | `tests/sidepanes_regression.lua` feeds `:q`, `:q!`, `:w`, `:wq`, `qq`, `<leader>qq`, `<C-CR>`, `<C-J>`, `M`, and non-ask guarded quit paths through Neovim. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap; CHANGELOG notes the `:w` command-path fix. | Press the real mappings listed in the behavior-sensitive coverage table. | `e8c6d20`, `ec1d381` | Done |
| end-to-end smoke tests. | Existing pane-mode ask smoke coverage remains in the fed-key/pane-mode layer; full-suite smoke verification passed through post-gap fast and full checks. | Focused ask/personal/submit regression passed with 47 selected tests; `tests/run_checks.sh fast` and `tests/run_checks.sh full` passed with 166 regression tests after the `:w` fix. | This roadmap; no public docs change applies because smoke coverage is internal. | Run the focused ask test group plus fast/full checks. | `047347c`, `ec1d381`, `ef1bb09` | Done |
| Reduce the 7k-plus-line catch-all regression file by moving ask-focused tests into smaller files when the test runner supports it, or by adding clear grouped helpers/sections when a split would create more harness churn than it removes. | Chose grouped helpers/sections because the ask tests share substantial in-process Neovim harness state; added layer markers plus `SIDEPANES_TEST_FILTER` instead of duplicating setup into a split file. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap records the split-vs-section decision; no public docs change applies because this is internal test organization. | Run focused ask tests and confirm output remains understandable. | `e8c6d20`, `047347c` | Done |
| Identify callback assertions that test behavior-sensitive paths, especially ask-pane command-line and mapping paths, and pair them with fed-key coverage or replace them with fed-key coverage where Neovim can synthesize the path. | `tests/ask_pane_mapping_coverage.lua` records every behavior-sensitive path; callback-only command-line/keymap behavior paths were paired with or converted to fed-key coverage. | Coverage-table integrity test plus fed-key ask/personal/submit tests passed in the focused ask run. | This roadmap and `tests/ask_pane_mapping_coverage.lua`. | Compare each callback-sensitive path to the matrix and perform the real interaction manually. | `e8c6d20` | Done |
| Add a behavior-sensitive mapping coverage table in tests or docs that lists every ask/non-ask mapping path and whether it has: | Added `tests/ask_pane_mapping_coverage.lua`; `tests/sidepanes_regression.lua` verifies coverage rows against both matrix fixtures and registered test names. | `tests/sidepanes_regression.lua` "ask behavior-sensitive mapping coverage table matches matrices and tests" passed. | This roadmap plus test fixture; no public docs change applies because this is test-side traceability. | Use the table as the manual acceptance checklist source. | `e8c6d20` | Done |
| registration coverage. | `tests/ask_pane_mapping_coverage.lua` has a registration reference for each coverage row. | Coverage-table integrity test rejects missing registration coverage and passed. | `tests/ask_pane_mapping_coverage.lua`; this roadmap. | Confirm each mapping exists in the expected zone. | `e8c6d20` | Done |
| direct policy/state coverage. | `tests/ask_pane_mapping_coverage.lua` has a direct policy/state reference for each coverage row. | Coverage-table integrity test rejects missing direct coverage and passed. | `tests/ask_pane_mapping_coverage.lua`; this roadmap. | Confirm behavior expectations match the behavior matrix. | `e8c6d20` | Done |
| fed-key coverage. | `tests/ask_pane_mapping_coverage.lua` names fed-key coverage where Neovim can synthesize the path. | Coverage-table integrity test rejects rows without fed-key coverage or an explicit reason and passed; focused fed-key tests passed. | `tests/ask_pane_mapping_coverage.lua`; this roadmap. | Press each keypath in Neovim where fed-key applies. | `e8c6d20` | Done |
| an explicit reason fed-key coverage does not apply. | `tests/ask_pane_mapping_coverage.lua` records no-fed-key reasons for command-only, registration-only, planned-command, and deterministic navigation/source-jump exceptions. | Coverage-table integrity test rejects missing no-fed-key reasons and passed. | `tests/ask_pane_mapping_coverage.lua`; this roadmap. | Review exceptions before slice closeout. | `e8c6d20` | Done |
| Convert callback-only tests for user-visible behavior into fed-key tests where Neovim can synthesize the key path reliably. | Converted ask command-line `:q`/`:w`/`:wq`, failed-send retry `:q`, target picker `M`, ask send `qq`/`<leader>qq`, non-ask `:q`/`:quit`, and submit `<C-CR>`/`<C-J>` behavior paths to fed-key execution. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap; CHANGELOG notes the `:w` command-path fix. | Perform equivalent real keypress workflows. | `e8c6d20`, `ec1d381` | Done |
| Keep callback tests only for registration, normalized configuration, and narrow paths that cannot be fed realistically; record the reason near the test. | Remaining callback cases are registration/config/adapters or are documented in `tests/ask_pane_mapping_coverage.lua` with no-fed-key reasons. | Coverage-table integrity test passed and verifies every row has fed-key coverage or an explicit no-fed-key reason. | `tests/ask_pane_mapping_coverage.lua`; this roadmap. | Review remaining callback tests for scope. | `e8c6d20` | Done |
| Ensure fed-key tests cover normal, insert, terminal, and command-line zones affected by ask lifecycle behavior. | Fed-key coverage now includes normal ask `qq`/`<leader>qq`/`M`/`<C-CR>`/`<C-J>`, insert ask `<C-CR>`, non-ask terminal/Markdown guarded quit mappings, and ask/non-ask command-line paths. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap; no public docs change applies because behavior did not change. | Repeat `qq` / `<leader>qq` and submit checks across the listed zones. | `e8c6d20` | Done |
| Ensure tests compare expected behavior against the behavior matrix and mapping zone matrix rather than repeating stale implementation assumptions. | `tests/ask_pane_mapping_coverage.lua` links coverage rows to `tests/ask_pane_behavior_matrix.lua` and `tests/ask_pane_mapping_zone_matrix.lua`; the regression suite validates those links. | Coverage-table integrity test passed and fails if a behavior or zone matrix row lacks a coverage decision. | Matrix fixtures and this roadmap; no public docs change applies beyond the added `ask-pane-command-line` matrix row. | Compare manual workflows to the matrices, not implementation details. | `e8c6d20` | Done |
| Add focused test helpers for key feeding, command-line feeding, and pane state assertions so tests are readable without hiding the user action being tested. | Added `feed_user_keys()`, `feed_user_command()`, `feed_user_insert_keys()`, `wait_until()`, and `assert_pane_window()` in `tests/sidepanes_regression.lua`; test bodies still show the literal user keys/commands. | Converted fed-key tests passed in the focused ask run. | This roadmap; no public docs change applies because helpers are internal. | Confirm test failures name the user action clearly. | `e8c6d20` | Done |
| Run focused ask tests, `tests/run_checks.sh fast`, `tests/run_checks.sh full`, `illu.nvim` smoke when mappings/local integration are affected, and `git diff --check`. | Focused ask/personal/submit regression, fast checks, full checks, local `illu.nvim` smoke, and `git diff --check` were run after the audit-gap fix. | Focused ask run passed with 47 selected tests; `tests/run_checks.sh fast` passed with 166 regression tests; `tests/run_checks.sh full` passed with 166 regression tests and real CLI smoke; `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh` passed; `git diff --check` passed. | Verification results are recorded below; CHANGELOG notes the `:w` command-path fix. | Run the same checks locally if desired. | `ec1d381`; `ef1bb09` | Done |
| Re-check implementation, tests, docs, roadmap, README, CHANGELOG, help docs, Markdown docs, release notes, AGENTS.md, and `illu.nvim` applicability before moving on. | Restarting audit passes checked the slice bullets, traceability table, implementation boundaries, mapping zones, command paths, state transitions, fed-key coverage, manual acceptance references, README, CHANGELOG, help docs, Markdown docs, release notes, roadmap status/order, AGENTS.md process requirements, and `illu.nvim` applicability. | Focused ask/personal/submit, fast, full, `illu.nvim` smoke, coverage-table integrity, and `git diff --check` evidence are recorded in this slice; final two clean non-mutating confirmation passes are required after the last commit and reported in the final response. | This roadmap records audit evidence; CHANGELOG, help docs, Markdown docs, and release notes were reviewed for the `:w` command-path fix; no README change applies because the README does not enumerate ask-pane command-line lifecycle details. | Review the traceability table, manual checklist, and final two clean confirmation passes before moving on. | `e4de0a1` | Done |
| For every mapping listed in the behavior-sensitive coverage table, perform the real keypress in Neovim and compare the outcome to the matrix. | `tests/ask_pane_mapping_coverage.lua` is the behavior-sensitive coverage table; fed-key tests exercise the same real keypaths where automated synthesis applies. | Not Applicable as automated test: this bullet is itself a manual acceptance requirement, supported by fed-key regressions and the coverage-table integrity test. | Coverage table plus existing behavior/mapping matrices. | Perform this exact manual workflow. | `e8c6d20` | Done |
| Repeat personal `qq` / `<leader>qq` checks in Markdown, Codex, and ask panes. | Guarded quit mappings and ask send mappings are listed in `tests/ask_pane_mapping_coverage.lua`. | `tests/sidepanes_regression.lua` "personal normal quit mappings do not close markdown or terminal side panes" and "ask pane send mappings follow quit lifecycle instead of warning on unwritten prompts" passed in the focused ask run. | Existing mapping docs remain unchanged because behavior did not change. | Perform this exact manual workflow. | `e8c6d20` | Done |
| Repeat `<C-CR>` / `<C-J>` submit checks from normal and insert ask-pane modes. | Submit fed-key coverage is listed in `tests/ask_pane_mapping_coverage.lua`; helper-driven tests feed the literal submit keys. | `tests/sidepanes_regression.lua` "ask pane submit mapping sends modified prompt from normal and insert modes" feeds normal `<C-CR>`, insert `<C-CR>`, and `<C-J>` fallback. | Existing mapping docs remain unchanged because behavior did not change. | Perform this exact manual workflow. | `e8c6d20` | Done |
| Run the focused ask test group and confirm failures point to user behavior, not just callback plumbing. | `SIDEPANES_TEST_FILTER` enables focused ask/personal/submit runs; ask layer markers identify policy, snapshot, executor, adapter, registration, fed-key, and smoke areas. | Focused ask/personal/submit regression passed with 47 selected tests. | This roadmap; no public docs change applies because this is test architecture. | Perform this exact manual workflow. | `e8c6d20`, `047347c` | Done |

Verification results:

- Focused ask/personal/submit regression passed with 47 selected tests after
  the `:w` audit-gap fix:
  `SIDEPANES_TEST_FILTER='ask,personal,submit question' ... tests/sidepanes_regression.lua`.
- `tests/run_checks.sh fast` passed with 166 regression tests after the `:w`
  audit-gap fix.
- `tests/run_checks.sh full` passed with 166 regression tests and real CLI smoke
  after the `:w` audit-gap fix.
- `git diff --check` passed.
- `illu.nvim` smoke passed:
  `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh`.

Audit gaps:

- Audit pass 1 found that the coverage table marked ask-pane `:w` rows as
  no-fed-key even though Neovim can synthesize the command path, and the
  `ask-write-draft` row referenced a legacy floating-question test instead of
  ask-pane write behavior.
- Audit pass 1 restart found stale roadmap references to renamed/replaced ask
  command-line fed-key tests and an outdated ask-write-draft test reference.
- Audit pass 1 restart found the ask-pane `:w` command-path changelog note under
  `Changed` even though it describes a fix.
- Audit pass 1 restart then found no further implementation, coverage,
  documentation, roadmap-order, process, or `illu.nvim` applicability gaps.

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Audit gap: cover synthesizeable ask-pane `:w` command paths with fed-key tests and correct `ask-write-draft` coverage evidence. | `lua/sidepanes/ask_policy.lua` maps `w` to `write_draft`; `tests/ask_pane_mapping_coverage.lua` marks `ask-write-ready` and `ask-write-draft` as fed-key covered; `tests/sidepanes_regression.lua` feeds `:w` for ready and modified ask drafts. | Focused single-test, focused ask/personal/submit, fast, full, and `illu.nvim` smoke checks passed after the fix. | This roadmap, coverage fixture, and CHANGELOG. | Press `:w` on ready and modified ask drafts and compare state to the behavior matrix. | `ec1d381` | Done |
| Audit gap: update stale roadmap references after the ask command-line fed-key replacement and `:w` command-path fix. | Roadmap references now point to "ask pane fed command-line lifecycle covers q w and wq user paths" and "pane-mode ask write then quit sends accumulated prompt" where applicable. | Not Applicable: documentation reference correction only; no runtime behavior changed. | This roadmap. | Re-read behavior and mapping matrix references before closeout. | `2f47ede` | Done |
| Audit gap: move the ask-pane `:w` command-path changelog note under `Fixed`. | `CHANGELOG.md` now records the scratch-buffer `:w` command-path repair under `Fixed`. | Not Applicable: changelog categorization only; no runtime behavior changed. | `CHANGELOG.md` and this roadmap. | Re-read changelog section placement before closeout. | `f4e8ae2` | Done |

## Final Verification And Release-Readiness Audit

Status: `Blocked`

User response: check code, docs, tests, and the internal roadmap in repeated
passes until nothing else comes up; other users rely on this plugin, so the
release must be complete, exhaustive, correct, and accurate.

Goal: verify `v0.4.0` as a release candidate without adding feature scope.

- Re-read every ask-pane roadmap slice and traceability table for stale status,
  missing evidence, wrong commit references, contradictions, or skipped bullets.
- Review implementation correctness and architecture boundaries for the full
  release, especially ask pane lifecycle, terminal/session recovery, command and
  mapping adapters, status/version/help surfaces, and compatibility shims.
- Review automated test coverage for behavior, edge cases, fed-key paths,
  command paths, mapping zones, state transitions, compatibility requirements,
  docs contracts, health checks, and real CLI smoke.
- Run focused ask checks, `tests/run_checks.sh fast`,
  `tests/run_checks.sh full`, local `illu.nvim` smoke, and `git diff --check`.
- Run or account for the interaction-focused manual acceptance checklist in a
  real Neovim session with `illu.nvim`.
- Re-read README, CHANGELOG, Neovim help docs, Markdown docs, release notes,
  public ROADMAP, AGENTS.md, and generated helptags/docs artifacts.
- Verify release-readiness details: version reporting, default compatibility,
  opt-in ask pane behavior, install/load sanity, repository cleanliness, and no
  generated assets/logs/artifacts.
- If any pass finds a gap, append it here, add a traceability row, fix/test/doc
  it, commit that coherent unit, and restart from the new HEAD.
- After the last commit, perform at least two consecutive clean non-mutating
  confirmation passes and report them in the final response.

Verification results:

- Focused ask/personal/submit regression passed with 53 selected tests from
  `dc1c005`.
- `tests/run_checks.sh fast` passed with 177 regression tests from `dc1c005`.
- `tests/run_checks.sh full` passed with 177 regression tests and real CLI
  smoke from `dc1c005`.
- `ILLU_SIDEPANES_RUNTIME_PATH=/Users/maximl/.config/nvim/sidepanes.nvim
  /Users/maximl/.config/nvim/illu.nvim/tests/run_sidepanes_checks.sh` passed
  from `dc1c005`.
- Release sanity headless check passed: public default `ask.ui = "float"`,
  version `0.4.0-dev`, local load path, command registration,
  `ask_status({ notify = false })`, and `:help sidepanes`.
- `git diff --check` passed.
- Artifact scan found no `.DS_Store`, `nvim.log`, temporary ShaDa files, banner
  asset, or generated temporary files after the final check rerun.

Audit findings:

- Pass 1 found older completed rows still used placeholder commit wording
  instead of exact commit references. Fixed in `5240f97` and recorded in
  `45c5c16`.
- Pass 1 found an ignored generated `nvim.log` in the repository root after
  Neovim checks. Removed it in `a87bca9` and recorded the commit reference in
  `dc1c005`.
- Pass 1 found the local `illu.nvim` smoke does not fully execute every row of
  the slice-19 interaction checklist. It verifies the local runtime path,
  config opt-in, health, help resolution, personal ask mappings, ask quit
  lifecycle shortcuts, and non-ask quit guards, but it is not a full manual
  pass/fail run for cross-root append, before-send picker, failed terminal
  recovery, and mapping-help pane workflows.

Manual acceptance tests:

- Run the slice-19 interaction checklist in real Neovim with `illu.nvim`
  loaded and the local `sidepanes.nvim` checkout on `runtimepath`.
- Confirm `ask.ui = "float"` remains the public default and `ask.ui = "pane"`
  remains opt-in.
- Confirm `:SidepanesVersion`, `:SidepanesAskStatus`, `:SidepanesMappings`,
  ask submit/write/quit/cancel, target picker, mapping help, and failed-send
  recovery behave as documented.
- Confirm `:help sidepanes` opens and public docs match the release behavior.

Traceability:

| Roadmap bullet | Implementation reference | Automated test reference, or explicit reason no automated test applies | Documentation reference, or explicit reason no docs change applies | Manual acceptance test reference | Commit reference | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Re-read every ask-pane roadmap slice and traceability table for stale status, missing evidence, wrong commit references, contradictions, or skipped bullets. | Pass 1 re-read the roadmap status/order, slice traceability tables, and release audit rows; stale placeholder evidence was fixed and recorded. | `rg` placeholder audit; focused/docs/fast/full checks passed after the evidence fix. | This roadmap. | Re-read all slice tables before closeout; the only remaining blocker is the manual checklist. | `c26a834` | Done |
| Review implementation correctness and architecture boundaries for the full release, especially ask pane lifecycle, terminal/session recovery, command and mapping adapters, status/version/help surfaces, and compatibility shims. | Pass 1 reviewed ask lifecycle/status/session/policy seams, command/mapping adapters, compatibility shims, defaults, version/status/help commands, and local integration boundaries. Pure ask modules still have no direct `vim.*` calls. | Focused ask regression, fast, full, release sanity, and `illu.nvim` smoke passed. | No implementation docs change needed beyond this final audit evidence. | Manual architecture review completed; manual interaction checklist remains separate. | `c26a834` | Done |
| Review automated test coverage for behavior, edge cases, fed-key paths, command paths, mapping zones, state transitions, compatibility requirements, docs contracts, health checks, and real CLI smoke. | Pass 1 reviewed the behavior/mapping coverage fixture, fed-key rows, command path coverage, docs contract, health smoke, and real CLI smoke. | Focused ask/personal/submit passed with 53 selected tests; fast/full passed with 177 regression tests; docs contract, health, audit, help, and real CLI smokes passed. | This roadmap and test fixtures. | Manual checklist remains a human acceptance layer on top of the automated coverage. | `c26a834` | Done |
| Run focused ask checks, `tests/run_checks.sh fast`, `tests/run_checks.sh full`, local `illu.nvim` smoke, and `git diff --check`. | Verification results are recorded above from `dc1c005`. | Focused ask/personal/submit passed with 53 selected tests; `tests/run_checks.sh fast` passed; `tests/run_checks.sh full` passed; `illu.nvim` smoke passed; `git diff --check` passed. | This final audit section records the check evidence. | Re-run checks locally if desired. | `c26a834` | Done |
| Run or account for the interaction-focused manual acceptance checklist in a real Neovim session with `illu.nvim`. | The `illu.nvim` smoke accounts for local runtime loading, config opt-in, health/help, personal ask mappings, ask quit-lifecycle shortcuts, and non-ask quit guards, but it does not fully execute every slice-19 checklist row. | Not Applicable as a replacement automated test: this bullet is itself the final manual acceptance requirement; focused fed-key tests and `illu.nvim` smoke cover substantial behavior but not the complete manual checklist. | Slice 19 checklist and this final audit section. | Full real-Neovim pass/fail checklist remains to be run before calling the release manually accepted. | `74ec2b3` | Blocked |
| Re-read README, CHANGELOG, Neovim help docs, Markdown docs, release notes, public ROADMAP, AGENTS.md, and generated helptags/docs artifacts. | Pass 1 reviewed public docs and generated help behavior; `:help sidepanes` opened the local `doc/sidepanes.txt` after `helptags`, with no `doc/tags` diff. | Docs contract smoke passed; release sanity help check passed; `git diff -- doc/tags` was clean. | README, CHANGELOG, `doc/sidepanes.md`, `doc/sidepanes.txt`, `docs/release-notes-v0.4.0.md`, ROADMAP.md, AGENTS.md, and this roadmap reviewed. | Open `:help sidepanes` and compare public docs to release behavior. | `c26a834` | Done |
| Verify release-readiness details: version reporting, default compatibility, opt-in ask pane behavior, install/load sanity, repository cleanliness, and no generated assets/logs/artifacts. | Release sanity check verified `ask.ui = "float"`, version `0.4.0-dev`, load path, command registration, inactive ask status, and help resolution. Artifact scan is clean; `illu.nvim` still has only pre-existing unrelated local changes. | Release sanity headless check; `find` artifact scan; `git status --short --untracked-files=all`; `git diff --check`. | This final audit section records release-readiness evidence. | Confirm release-readiness details in local Neovim and git status. | `c26a834` | Done |
| If any pass finds a gap, append it here, add a traceability row, fix/test/doc it, commit that coherent unit, and restart from the new HEAD. | Final audit gaps found so far are recorded and either fixed or marked blocked. | Evidence-reference fix and artifact cleanup are committed; manual checklist blocker is recorded. | This roadmap. | Restart audit loop after every fix; current loop is blocked only on manual acceptance. | `c26a834` | Done |
| After the last commit, perform at least two consecutive clean non-mutating confirmation passes and report them in the final response. | Not complete because the release audit is blocked on the final manual interaction checklist. | Not Applicable until the manual blocker is resolved and the last audit commit is made. | Final clean passes intentionally reported in the final response instead of written back here. | Re-run clean confirmation passes after the manual checklist blocker is resolved. | `c26a834` | Blocked |
| Audit gap: pass 1 found older completed rows still used placeholder commit wording instead of exact commit references. | Replaced slice-22 `this completion-status commit` placeholders with `1a0d867`; replaced slice-26 `verification evidence commit` with `ef1bb09` and `closeout evidence commit` with `e4de0a1`. | `rg` audit for placeholder commit wording; `git diff --check`. | This roadmap. | Re-read affected traceability rows before restarting the audit loop. | `5240f97` | Done |
| Audit gap: pass 1 found an ignored generated `nvim.log` in the repository root after Neovim checks. | Removed the generated `nvim.log` artifact. | `find . -maxdepth 3 -name nvim.log -print`; `git status --short --untracked-files=all`; `git diff --check`. | This roadmap. | Confirm no generated logs/assets remain before release closeout. | `a87bca9` | Done |
| Audit gap: `illu.nvim` smoke does not fully execute the slice-19 manual interaction checklist. | Recorded the coverage boundary: `illu.nvim` smoke covers local integration and personal mapping guards, while focused fed-key regressions cover many behavior paths, but the full slice-19 checklist still needs a real manual pass/fail run. | Focused ask regression, fast, full, docs contract, release sanity, and `illu.nvim` smoke passed; Not Applicable as a full replacement for manual acceptance. | Slice 19 checklist and this final audit section. | Run every slice-19 checklist row in real Neovim with `illu.nvim` loaded, recording exact mapping/command and pass/fail. | `74ec2b3` | Blocked |
