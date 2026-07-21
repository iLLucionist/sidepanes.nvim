# Sidepanes Roadmap

This is the short public roadmap for `sidepanes.nvim`.

Historical extraction notes are archived in `docs/extraction-notes.md`.
User-facing changes belong in `CHANGELOG.md`; detailed behavior belongs in
`:help sidepanes` and `doc/sidepanes.md`. Use GitHub issues and milestones for
day-to-day planning once the repository is managed primarily on GitHub.

## v0.1.0 Initial Standalone Release

Status: released.

Goal: publish the first named standalone release of Sidepanes as a Neovim
plugin, without expanding the scope beyond the already-extracted feature set.

Included:

- Standalone `sidepanes.nvim` plugin tree.
- Lazy.nvim installation docs.
- `:help sidepanes` and Markdown reference docs.
- `:checkhealth sidepanes`.
- Headless local checks through `tests/run_checks.sh fast|full`.
- GitHub Actions for headless Neovim checks.
- Current user-facing setup, command, mapping, health, help, and advanced helper
  APIs.
- Compatibility aliases for renamed helper and mapping keys:
  `show_last_agent()`, `toggle_markdown_agent()`, `toggle_agent`, and
  `toggle_agent_alt`.
- Built-in Markdown Reflow as `sidepanes.markdown_reflow`.
- `main` as the default install target.

Released as `v0.1.0` on 2026-07-19.

## v0.2.0 Platform And UI Pass

Status: in progress through the `v0.2.0` release.

Candidate work:

- Define stable, advanced, and internal API tiers for plugin authors.
- Decide whether Sidepanes should expose an extension registration API such as
  `register_tool(name, spec)`.
- Document lifecycle expectations for third-party pane tools if that API exists.
- Add tests that prove external integrations can register and use a tool without
  reaching into private state.
- Explore UI refinements and enhancements for pane controls, switcher/picker
  polish, visual feedback, and everyday workflow ergonomics.

## Later Considerations

- Consider adding an explicit fresh-vs-resume choice for Codex and Claude pane
  recovery. For now, if no live pane job exists, opening a supported agent tool
  prefers resuming the remembered or latest matching project session.
- Decide whether Markdown Reflow should remain bundled or split into a separate
  `markdown-reflow.nvim` plugin.
- Revisit compatibility aliases only when there is a clear reason to deprecate
  them.
- Keep this roadmap short. Move completed implementation details to
  `CHANGELOG.md`, GitHub releases, or archived notes.

## Release Checks

Before calling release work complete, run:

```sh
tests/run_checks.sh full
```

Also verify:

- `:help sidepanes` opens from the installed plugin.
- `:checkhealth sidepanes` has no unexpected Sidepanes warnings or errors.
- A real lazy.nvim install can load `sidepanes.nvim` from GitHub without a
  local source fallback.
