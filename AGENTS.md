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
