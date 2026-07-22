# Agent Notes

This repository is `sidepanes.nvim`, a standalone Neovim plugin extracted from
the personal `illu.nvim` configuration. Keep changes small, practical, and in
the style already present in the Lua modules and documentation.

## Branch Naming

Use short intent-based branch names:

- `fix/<thing>` for user-visible bug fixes.
- `docs/<thing>` for documentation-only updates.
- `chore/<thing>` for maintenance without behavior changes.
- `refactor/<thing>` for internal restructuring.
- `feat/<thing>` for new user-facing behavior.
- `release/vX.Y.Z` only for release preparation branches.

Prefer specific names like `fix/heading-picker-empty-doc` over version-scoped
names like `v0.1.1-fixes`.

## Patch Release Scope

For patch releases such as `v0.1.1`, keep the scope narrow:

- Bug fixes.
- Documentation clarifications.
- Test and CI maintenance.
- Internal refactors that do not change user-facing behavior.

Avoid broadening patch work into new features unless the user explicitly asks
for that tradeoff.

## Local Checks

Use the repository check wrapper:

```sh
tests/run_checks.sh fast
```

Before release work or larger behavior changes, run:

```sh
tests/run_checks.sh full
```

If a check cannot be run, mention that clearly in the final response.

For larger feature branches, write tests deep enough to exercise every user
visible behavior and edge case that the implementation introduces. After each
implementation slice, review the code, the tests, and all affected documentation
before moving on. Keep iterating on that slice until no obvious implementation,
test, or documentation gaps remain. Also append manual acceptance tests under
the relevant implementation step or roadmap note so the user can verify the
behavior directly in Neovim.

For behavior-sensitive key mappings, callback tests are only registration
coverage. Also include real fed-key coverage for the user path whenever a
mapping decides or triggers lifecycle behavior, mode changes, pane/window
survival, sends, cancels, writes, or command-line expansion.

For roadmap-driven work, the review must be literal and bullet-by-bullet. Before
marking a numbered roadmap slice complete, create or update a traceability table
for every bullet in that slice with implementation references, automated test
references, documentation references, manual acceptance tests, and status. Do
not substitute a slice-level summary for this check. Re-read the implementation,
tests, docs, roadmap, help docs, README, CHANGELOG, release notes, and any
personal `illu.nvim` notes that are affected until no missing bullet,
contradiction, stale behavior claim, or untested edge case remains.

For roadmap-driven implementation work, commit completed work at the smallest
coherent unit inside a numbered slice: usually one roadmap bullet or a tightly
related set of bullets that must be reviewed and reverted together. Do not wait
until the end of a multi-slice branch, and do not start the next coherent unit
while the previous completed unit is still uncommitted. Record the commit hash
in the traceability table for the rows it satisfies. If a later audit changes
that unit, commit the fix as its own follow-up unit and update traceability.

Audit passes must be falsifiable, restarting, and non-negotiable. After every
numbered implementation slice, keep checking the work in repeated passes until
nothing else comes up. Each pass must check the internal roadmap bullets and
traceability table, implementation code, tests and edge cases, manual
acceptance tests, README, CHANGELOG, Neovim help, Markdown docs, release notes,
roadmap status/order, AGENTS.md, and `illu.nvim` impact when relevant.

If any pass finds a gap, contradiction, stale claim, missing edge case,
incorrect behavior, weak test, incomplete documentation, process miss, or commit
evidence problem, append it under the same numbered slice, add it to the
traceability table, fix/test/document it, commit that coherent unit, and restart
the audit loop from the new HEAD.

The final slice closeout requires at least two consecutive clean confirmation
passes after the last commit, including commits that only update audit evidence.
A clean confirmation pass is non-mutating: it must not edit files, create new
roadmap bullets, or rely on memory. If a confirmation pass reveals that the
roadmap needs another audit note, that pass is not clean; update the roadmap,
commit it, and restart. Because writing the final clean-pass results back into
the roadmap would itself create a new last change, report those final
non-mutating confirmation passes in the final slice response while ensuring all
gap-finding passes and fixes are recorded in the roadmap before the final
confirmation pair begins.

## Internal Architecture

Prefer a functional core with an imperative Neovim shell. This fits Lua and
Neovim well when applied pragmatically: keep UI-facing modules imperative where
they must call `vim.*`, but push decisions, predicates, state snapshots,
normalization, and formatting into small pure functions whenever practical.

Keep modules compact and boundary-focused:

- Each module should have a clear public surface and private internal helpers.
- Public functions are boundary functions: they adapt config, state, keymaps,
  commands, or UI events into explicit inputs for lower-level helpers.
- Internal helper functions should be pure when they can be, especially for
  state predicates, action planning, target resolution, path/label formatting,
  status snapshots, and mapping classification.
- Use higher-order functions and composition only when they simplify dependency
  injection, handler construction, or repeated adapter plumbing. Avoid clever
  chains that hide Neovim side effects or make control flow harder to audit.
- Keep keymap and command-line modules thin. They should register handlers,
  collect user input, and submit intents; they should not own lifecycle
  decisions.
- Keep lifecycle executors explicit. Policy decides what should happen;
  executors perform `vim.*`, window, buffer, picker, terminal, notification, and
  mutation effects.
- Treat line count as a design smell during feature work. Before adding a new
  module, large helper, or broad test block, check whether an existing pure
  helper, table-driven policy, or smaller boundary function can express the same
  behavior more simply.

## Documentation

Keep user-facing behavior documented in the public docs:

- `README.md` for quick-start, install, tutorial, and common mappings.
- `doc/sidepanes.md` for Markdown reference docs.
- `doc/sidepanes.txt` for Neovim help.
- `CHANGELOG.md` for user-facing changes.
- `ROADMAP.md` for short public planning notes.

Implementation notes that are no longer active should move under `docs/`.

## Release Notes

`CHANGELOG.md` is the source of truth for release-facing changes. Add entries
under `Unreleased` when a change affects users, documented behavior, release
process, or supported workflows.

When working on plugin updates from a feature or fix branch, keep
`CHANGELOG.md` updated as part of the branch instead of waiting until release
prep. This keeps small changes easy to review and makes patch releases less
error-prone.

Also note incidental fixes discovered along the way, even when they are not the
main branch goal. For example, if a Markdown reload branch exposes and fixes a
`smart_gf` path resolution bug, add a separate `CHANGELOG.md` entry for that
fix instead of hiding it inside the feature summary.
