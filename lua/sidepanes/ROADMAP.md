# Sidepanes Roadmap

This is the living roadmap for `sidepanes.nvim`.

When discussing "what's next?", use this file as the reference point:

- State what is already done.
- State what is currently in progress.
- Propose the next roadmap refinement.
- Update this file when the roadmap changes materially.

## Current Status

Sidepanes has grown from a Markdown side viewer into a pane system for Markdown, Codex, Claude, and IPython. The main refactor work has already split most behavior out of `init.lua` into focused modules for configuration, commands, mappings, terminal sessions, questions, rendering/reflow, picker behavior, lifecycle, validation, health checks, and integrations.

Recently completed or in progress:

- Public facade boundary: mutable pane state is hidden from `require("sidepanes")`.
- `get_config()` returns a defensive copy of normalized config.
- `_state()` remains internal for companion modules and tests.
- `switch_to(target, opts)` is the stable public switch API.
- `make_switch_entry(target, opts)` validates and normalizes advanced switch targets.
- `switch(entry)` is internal and not exposed on the public facade.
- `ask_with_entry(entry, opts)` is internal and not exposed on the public facade.
- Scratch-buffer lifecycle callbacks moved to `sidepanes.internal`.
- `show_last_terminal(opts)` and `toggle_markdown_terminal()` are documented as advanced workflow helpers; old agent-named helpers remain compatibility aliases.
- Runtime width API exists through `get_width()`, `set_width(value)`, and `adjust_width(delta)`.
- Width commands exist through `:SidepanesWidth` and `:Sidepanes width`.
- Width values support columns, percentages, screen fractions, numeric ratios, and deltas.
- Width changes reflow Markdown when the Markdown viewer is active and avoid Markdown reflow while a terminal pane is active.
- `layout.sticky_relative_width` can keep percentage/fraction widths tied to the total Neovim width.
- `layout.width` accepts the same width units during setup.
- `toggle_sticky_relative_width()` and `<leader>p%` toggle sticky relative width at runtime.
- `snap_width(direction)` and `<leader>p-` / `<leader>p+` move to configured width snap points.
- Width snapping reports the current, previous, and next snap points after use.
- `width_picker()` / `<leader>pw` / `:SidepanesWidthPick` pick from configurable common width points.
- Width command aliases cover next, previous, prev, +, -, and pick through both `:SidepanesWidth` and `:Sidepanes width`.
- Runtime width behavior lives in `lua/sidepanes/width.lua`; `init.lua` delegates width API calls through thin wrappers.
- The audit smoke test enforces top-level Purpose/Does/Architecture comments for all `lua/sidepanes/*.lua` modules.
- `doc/sidepanes.txt` provides `:help sidepanes`; `doc/sidepanes.md` carries the longer reference.
- `:Sidepanes help` opens the Neovim help page, falling back to the subcommand summary if helptags are unavailable.
- Pane-local smart `gf` is owned by `lua/sidepanes/smart_gf.lua`; the old `lua/smart_gf` shim has been removed.
- Markdown reflow is owned by `lua/sidepanes/markdown_reflow.lua`; the old `lua/markdown_reflow` shim has been removed.
- `:checkhealth sidepanes` reports global and pane-local mapping modes.
- Extraction boundary audit for the standalone plugin tree is complete.
- `sidepanes.nvim` has a portable plugin-owned file tree, standalone README,
  `:help sidepanes` smoke coverage, and `tests/run_checks.sh fast|full`.

## Roadmap

### 1. Commit Current API And Width Pass

Status: completed.

Commit the current public API, switch target, width command, documentation, and regression coverage work.

Completed commits:

- `fbf63a7` finalized the Sidepanes public API surface.
- `4bd0959` added relative Sidepanes width controls.
- `17030a1` added width snap mappings.
- `a5c2571` added width picker feedback.
- `fa3c077` hardened width picker checks.
- `b998d62` added Sidepanes width command aliases.

This includes setup-time width units, sticky relative width, the `<leader>p%` sticky toggle, width snap mappings, snap feedback, and width picker coverage.

Acceptance:

- `tests/run_sidepanes_checks.sh` passes.
- `:checkhealth sidepanes` has no Sidepanes warnings or errors in the normal configured environment.
- `ask_with_entry` remains absent from the public facade.
- `lua/sidepanes/api.lua` is tracked.

### 2. Public Surface Finalization

Status: completed.

Finalize which functions belong on `require("sidepanes")` and which belong behind internal/private module paths.

Current decision:

- Keep `switch_to(target, opts)` stable.
- Keep `make_switch_entry(target, opts)` advanced.
- Keep `switch(entry)` internal.
- Keep `ask_with_entry(entry, opts)` internal.
- Keep scratch-buffer lifecycle callbacks internal through `sidepanes.internal`.

Acceptance:

- `require("sidepanes").switch` is absent.
- `require("sidepanes").ask_with_entry` is absent.
- `require("sidepanes").finish_question`, `write_question`, `cancel_question`, and `change_question_target` are absent.
- Scratch prompt `:q` and `:wq` command-line mappings still work through `sidepanes.internal`.
- Full Sidepanes checks pass.

Completed refinement:

- Added `lua/sidepanes/internal.lua` for raw switch, raw ask-entry, and scratch-buffer lifecycle callbacks.
- Updated question-editor command-line mappings to call `sidepanes.internal`.
- Kept `require("sidepanes")` focused on stable and advanced public APIs.

### 3. Command And Mapping Polish

Status: completed for current width workflow.

Decide whether width changes deserve default mappings or should remain command/API-only.

Completed decisions:

- Keep `:SidepanesWidth` as the primary interface unless repeated manual resizing becomes common.
- Keep `<leader>p%` as the quick toggle for sticky relative width.
- Use `<leader>p+` and `<leader>p-` for snapping to configured width boundaries.
- Snapping understands columns, fractions, percentages, and numeric ratios.
- Snapping cooperates with `layout.sticky_relative_width` by preserving relative snap targets when enabled.
- Keep `width_picker_points` shorter than `width_snap_points` so the picker remains fast to read.
- Use `<leader>pw`, `:SidepanesWidthPick`, and `:Sidepanes width-pick` for explicit width picking.
- Support readable command aliases through `:Sidepanes width next`, `:Sidepanes width previous`, `:Sidepanes width prev`, `:Sidepanes width +`, `:Sidepanes width -`, and `:Sidepanes width pick`.
- Support the same aliases through the standalone `:SidepanesWidth` command.
- Keep width runtime behavior in `lua/sidepanes/width.lua` rather than growing `init.lua` again.

### 4. Docs Split

Status: completed.

The README was becoming dense, so detailed API/config documentation moved into Neovim-native and plugin-local docs.

Completed docs:

- `doc/sidepanes.txt` for `:help sidepanes`.
- `doc/sidepanes.md` for longer Markdown documentation.
- Keep README as a quickstart plus links.
- `:Sidepanes help` opens the help page.

Acceptance:

- Public API is documented.
- Advanced/unstable API is clearly labeled.
- Commands, mappings, config, health checks, and examples are discoverable.
- `:help sidepanes` resolves after helptags are generated.

### 5. Package Extraction

Status: in progress.

Extract the local plugin work from `illu.nvim` into a proper standalone GitHub repository and make `illu.nvim` consume it like any other Neovim config.

Target repository:

- `sidepanes.nvim`

Keep `illu.nvim` as the personal configuration repo that installs and configures Sidepanes from GitHub.

Current packaging decision:

- Ship Markdown reflow inside `sidepanes.nvim` for now as `sidepanes.markdown_reflow`.
- Keep the reflow implementation isolated behind its own module boundary so it can be extracted into `markdown-reflow.nvim` later if that becomes useful.
- Use only `sidepanes.markdown_reflow` as the supported require path.

Completed refinements:

- Moved pane-local smart `gf` into `lua/sidepanes/smart_gf.lua`.
- Removed `smart_gf` from external Sidepanes dependency validation.
- Made `:checkhealth sidepanes` report global and pane-local mapping modes.
- Moved Markdown reflow implementation into `lua/sidepanes/markdown_reflow.lua`.
- Made Sidepanes render logic require `sidepanes.markdown_reflow` directly.
- Removed the legacy `lua/smart_gf` and `lua/markdown_reflow` shim folders.

Possible work:

#### 5.1 Extraction Boundary Audit

Status: completed in the standalone `plugin-extraction` branch.

Prove `lua/sidepanes/**` can stand on its own outside `illu.nvim`.

Check for:

- Hardcoded personal paths.
- Assumptions about personal mappings.
- References to personal `init.lua`.
- Dependence on unrelated local modules.
- Commands or mappings that only make sense in this personal config.
- Docs that say "this config" when they should say "default config" or "example config".
- Tests that append `/Users/maximl/.config/nvim/illu.nvim` instead of resolving the repo root dynamically.

Acceptance:

- The `sidepanes` module tree can be copied into another Neovim config and loaded with `require("sidepanes").setup(...)`.
- Markdown reflow works through `require("sidepanes.markdown_reflow").setup(...)`.
- Personal `init.lua` remains only a consumer of the public setup/config surface.

Completed audit results:

- Runtime modules only require `sidepanes.*` modules plus optional Telescope
  picker modules.
- Hardcoded `/Users/maximl/.config/nvim/illu.nvim` runtime paths were removed
  from tests.
- Tests resolve the repository root dynamically from each test file.
- Standalone setup smoke now exercises the public `setup()` surface instead of
  booting personal `init.lua`.
- README and docs now describe example/default config rather than a personal
  config.

#### 5.2 Fold Markdown Reflow Into Sidepanes

Status: completed in the local plugin tree.

Keep Markdown reflow as a dedicated Sidepanes submodule:

```text
sidepanes.nvim/
  lua/
    sidepanes/
      markdown_reflow.lua
```

Keep in this submodule:

- Internal Markdown reflow.
- External formatter support, including `mdfmt`.
- Table protection for external formatting.
- `:MarkdownReflow`.
- Configurable standalone reflow mappings.
- Tests for paragraphs, lists, code fences, tables, external fallback, and table protection.

Acceptance:

- Sidepanes render logic uses `sidepanes.markdown_reflow`, not `markdown_reflow`.
- `illu.nvim` can install one GitHub plugin, `sidepanes.nvim`, and keep the existing `<leader>mR` workflow.
- The module boundary remains clean enough that a later extraction to `markdown-reflow.nvim` would mostly move this file and add a deliberate compatibility boundary.

#### 5.3 Split `sidepanes.nvim`

Status: completed for the first standalone extraction pass.

Create a dedicated Sidepanes plugin repo:

```text
sidepanes.nvim/
  .gitignore
  README.md
  LICENSE
  CHANGELOG.md        # optional before first public release
  doc/
    sidepanes.txt
    tags
  lua/
    sidepanes/
      init.lua
    ...
  tests/
    run_checks.sh
    run_sidepanes_checks.sh
    sidepanes_regression.lua
    ...
```

Keep in this repo:

- Pane, window, viewer, switcher, picker, question, and terminal logic.
- Codex, Claude, and IPython pane support.
- Ask prompt editor workflow.
- `sidepanes.smart_gf`.
- `sidepanes.markdown_reflow`.
- Docs, health checks, defaults, config normalization, presets, mappings, and commands.

Do not keep in this repo:

- Personal `init.lua`.
- Unrelated local modules such as `svelte_*`.

Current leaning:

- Do not add `plugin/sidepanes.lua` initially.
- Keep Sidepanes setup-driven rather than auto-registering commands/mappings on runtimepath load.
- Keep Markdown reflow built in and require it as `sidepanes.markdown_reflow`.

Acceptance:

- `sidepanes.nvim` runs its checks as a standalone repo.
- `illu.nvim` can install it from GitHub and keep the current Sidepanes workflow.

Standalone verification:

- `tests/run_checks.sh fast` passes from `sidepanes.nvim`.
- `tests/run_checks.sh full` passes from `sidepanes.nvim`, including real
  Codex and Claude CLI smoke tests in the local environment.

Concrete migration sequence:

1. Clone the new GitHub repo into a sibling development folder, for example:

   ```sh
   git clone git@github.com:iLLucionist/sidepanes.nvim.git ../sidepanes.nvim
   ```

2. Copy only plugin-owned files from `illu.nvim` into the new repo:

   ```text
   lua/sidepanes/**
   doc/sidepanes.txt
   doc/sidepanes.md
   doc/tags
   tests/sidepanes_*.lua
   tests/run_sidepanes_checks.sh
   README.md content, rewritten for plugin users
   ```

3. Do not copy personal config or unrelated local modules:

   ```text
   init.lua
   lua/svelte_*
   local personal plugin manager config
   local project-specific files
   ```

4. Rename or add portable wrappers:

   ```text
   tests/run_checks.sh
   tests/run_checks.sh fast
   tests/run_checks.sh full
   ```

5. Make tests discover the repo root dynamically instead of appending the
   `illu.nvim` path.

6. Run the standalone repo tests from inside `sidepanes.nvim`.

7. Commit the standalone repo.

8. Add the GitHub plugin to personal `illu.nvim` using the plugin manager.

9. Prove the personal workflow still works while the local source is still
   available as backup.

10. Remove local `lua/sidepanes/**` from `illu.nvim` only after the GitHub
    install path has passed acceptance testing.

First extraction commit target:

- Portable plugin file tree exists in `sidepanes.nvim`.
- README is written for external users, not for `illu.nvim`.
- `:help sidepanes` works.
- `tests/run_checks.sh fast` passes without `illu.nvim` in runtimepath.
- `tests/run_checks.sh full` passes in the normal local environment.

#### 5.4 Docs Contract Pass

Status: completed.

Keep each documentation surface focused:

- `README.md`: quickstart.
- `doc/sidepanes.txt`: Neovim-native help reference.
- `doc/sidepanes.md`: deeper explanation and examples.
- `lua/sidepanes/ROADMAP.md`: development state, not user docs.

Acceptance:

- Every Sidepanes command in `commands.lua` appears in Sidepanes help/docs.
- Every Sidepanes public API function appears in Sidepanes help/docs.
- Every Sidepanes default mapping key appears in Sidepanes help/docs.
- Every Sidepanes config group appears in Sidepanes help/docs.
- Every built-in Markdown Reflow command/config/mapping appears in Sidepanes help/docs.
- Help tags remain valid after doc changes.

Completed:

- Added root width alias coverage to README, help, and Markdown docs.
- Added an explicit Markdown Reflow help/reference section covering
  `:MarkdownReflow`, setup keys, mappings, fallback, and table protection.
- Added dependency and compatibility sections to help/docs.
- Added `tests/sidepanes_docs_contract_smoke.lua` to enforce command, API,
  mapping, config, Markdown Reflow, dependency, and compatibility docs.

#### 5.5 Portable Test / CI Wrapper

Make test scripts portable enough for standalone repos and later GitHub Actions.

Possible work:

- Remove hardcoded personal paths where practical.
- Resolve repo root dynamically.
- Exit nonzero on every failed subcheck.
- Test `:help sidepanes` in `sidepanes.nvim`.
- Test `:checkhealth sidepanes`.
- Test module top-level comments.
- Consider `fast` and `full` modes.

Target:

```sh
tests/run_checks.sh fast
tests/run_checks.sh full
```

Status: completed for local standalone checks.

Fast checks:

- Lua regression tests.
- Docs/help smoke.
- Health smoke.

Full checks:

- Everything in fast.
- Real Codex/Claude CLI smoke for Sidepanes when executables exist.
- External formatter smoke for built-in Markdown reflow when `mdfmt` exists.

#### 5.6 Update `illu.nvim` To Consume GitHub Plugins

Status: completed.

After the standalone repo works locally, update personal config to install it from GitHub.

Target lazy.nvim shape:

```lua
{
  "iLLucionist/sidepanes.nvim",
  config = function()
    require("sidepanes").setup({
      -- current personal Sidepanes config
    })

    require("sidepanes.markdown_reflow").setup({
      external_reflow_cmd = { "mdfmt", "--stdin", "--width", "{width}", "--wrap", "always" },
      external_reflow_protect_tables = true,
      commands = true,
      mappings = { reflow = "<leader>mR" },
    })
  end,
}
```

Acceptance:

- `illu.nvim` no longer needs local `lua/sidepanes/**` source.
- Existing mappings and commands still work from the GitHub-installed plugins.
- Existing Sidepanes and Markdown reflow tests pass before removing local source.

Current verification:

- Headless `illu.nvim` startup asserts `require("sidepanes")` loads from
  `/Users/maximl/.local/share/nvim/lazy/sidepanes.nvim/lua/sidepanes/init.lua`.
- `:help sidepanes` resolves to the lazy-installed plugin docs.
- Existing `illu.nvim` `tests/run_sidepanes_checks.sh` passes with the
  GitHub-installed plugin path active.
- `illu.nvim` `tests/run_sidepanes_checks.sh` selects the lazy-installed
  `sidepanes.nvim` runtime path first via `SIDEPANES_RUNTIME_PATH`, falling
  back to the local repo only when the installed plugin is absent.
- Local `illu.nvim/lua/sidepanes/**` and local Sidepanes docs were removed
  after the GitHub-installed plugin path passed acceptance testing.

#### 5.7 Dependency Contract Pass

Status: completed.

Make optional dependencies explicit and consistent.

For each feature document and test:

- Dependency.
- When it is required.
- What happens if missing.
- Health output.
- Setup validation output.
- Runtime fallback or warning.

Specific extraction decision:

- `sidepanes.markdown_reflow` is built in for Sidepanes reflow behavior.
- Later extraction should be possible by moving `sidepanes.markdown_reflow` into its own repo and making Sidepanes require the external module through one compatibility boundary.
- `sidepanes.smart_gf` stays built into `sidepanes.nvim`.

Completed:

- Documented each optional dependency, when it is required, runtime behavior
  when missing, setup validation behavior, and health behavior.
- Kept `sidepanes.smart_gf` and `sidepanes.markdown_reflow` as built-in
  required health checks.
- Fixed setup validation so `commands.width` is recognized alongside
  `commands.width_picker`.

#### 5.8 Compatibility And Deprecation Cleanup

Status: completed for the extraction pass.

Decide how long older public names and aliases remain.

Questions:

- Should old flat Sidepanes config keys remain permanently supported?
- Should command aliases be documented as stable or convenience-only?

Decisions:

- Older flat setup keys remain supported by config normalization for
  compatibility; grouped setup keys remain preferred in docs and examples.
- Width aliases are documented supported conveniences, with `next`,
  `previous`, and explicit width values presented as the clearest forms.
- `show_last_terminal()` and `toggle_markdown_terminal()` are now the preferred
  advanced helper names; `show_last_agent()` and `toggle_markdown_agent()`
  remain compatibility aliases.

#### 5.9 Release Readiness Later

Status: mostly completed for the first public-ish plugin pass.

Completed:

- README has a `lazy.nvim` install example.
- Added `CHANGELOG.md`.
- Documented a lightweight SemVer release policy in README and changelog:
  patch for fixes/docs/tests/refactors, minor for compatible features/API
  additions, major for breaking changes after `v1.0.0`; pre-`v1.0.0`
  breaking changes may happen in minor releases but must be called out.
- Resolved compatibility policy in item 5.8: older flat setup keys remain
  supported; documented command aliases are supported conveniences.
- Treated `sidepanes.nvim` as public-facing enough to keep README, help docs,
  dependency docs, and changelog maintained.
- README notes that Markdown Reflow may later split into
  `markdown-reflow.nvim`.
- Added a minimal GitHub Actions workflow for headless Neovim tests.

Remaining release-readiness work:

- Decide when to create the first tag, likely `v0.1.0`.
- Optionally add GitHub release notes when tagging.

### 6. Naming And API Cleanup Later

Status: completed for the current public helper rename pass.

Completed:

- Added `show_last_terminal()` and `toggle_markdown_terminal()` as the preferred
  terminal-oriented helper names.
- Kept `show_last_agent()` and `toggle_markdown_agent()` as documented
  compatibility aliases.
- Added `toggle_terminal` and `toggle_terminal_alt` as the preferred
  terminal-oriented pane-local mapping keys.
- Kept `toggle_agent` and `toggle_agent_alt` as documented compatibility
  aliases.

### 7. Platform API Design For `v0.2.0`

Status: deferred until after the initial `v0.1.0` standalone release.

Do not block `v0.1.0` on making Sidepanes a platform for other plugins.
For the initial release, maintain the documented user-facing setup, command,
mapping, help, health, and advanced helper surfaces.

`v0.2.0` candidate work:

- Define stable, advanced, and internal API tiers for plugin authors.
- Decide whether Sidepanes should expose an extension registration API such as
  `register_tool(name, spec)`.
- Document lifecycle expectations for third-party pane tools if that API exists.
- Add tests that prove external integrations can register and use a tool
  without reaching into private state.

## Testing Standard

Before calling roadmap work complete, run:

```sh
tests/run_checks.sh full
```

For public API or dependency work, also run or verify:

- `:checkhealth sidepanes`
- public facade assertions for stable/hidden functions
- legacy module-name scan
- module top-level comment sweep
- checkhealth smoke assertions for mode-aware mapping reports

The goal is not mathematical proof. The goal is targeted coverage deep enough to catch realistic regressions in the changed behavior.
