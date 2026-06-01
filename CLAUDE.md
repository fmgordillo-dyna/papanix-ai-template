# CLAUDE.md

Guidance for Claude / OpenCode working in this repo.

## What this repo is

A Nix flake that exposes **templates** (via `outputs.templates`) for
consuming [`papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai).
Every template is a standalone `flake.nix` in its own subdirectory.

This repo does **not** package code, build artifacts, or run tests. It
is purely a registry of starter `flake.nix` files.

## Layout

- `flake.nix` — registers each template under `templates.<name>`.
- `default/` — full setup: CLIs + skills + Dynatrace MCP + Claude plugins.
- `minimal/` — CLIs only, no shell hook, nothing wiped.
- `skills-only/` — curated skill subset, no MCP, no plugins.
- `mcp-custom/` — all skills + extended MCP server set.
- `plugins-custom/` — all skills + curated Claude Code plugin marketplaces.
- `library/` — skills only, no CLIs, demonstrates BYO packages.

## When editing a template

- Each template's `flake.nix` carries comments. Sections marked
  `# NOTE:` are the user-editable knobs — preserve and update them when
  changing behavior.
- Header comment of `default/flake.nix` says:
  *"CHANGE ONLY 'NOTE' SECTIONS"* — that applies to downstream users,
  not to maintainers. Maintainers may touch anything but should keep
  the `NOTE` markers accurate.
- Templates must stay copy-pasteable: no relative paths outside the
  template dir, no references to sibling templates.
- If you add a template, also register it in the root `flake.nix`
  under `templates` and update `README.md`.

## papanix-ai surface used here

- `papanix-ai.packages.${system}.default` — bundle of PAPA CLIs
  (`acli-pii`, `aimgr`, `dtctl`, `junoctl`).
- `papanix-ai.lib.skills.mkBundle { pkgs; enable | enableAll; skills? }` —
  builds the skill bundle. See
  `vendor/agent-skills-nix/lib/default.nix` in the upstream repo for
  the skill schema.
- `papanix-ai.lib.skills.mkShellHook { pkgs; bundle; }` — installs skills
  into `.claude/` and `.opencode/`, registers an EXIT trap that wipes
  them.
- `papanix-ai.lib.mcp.defaultServers` — default MCP server set
  (Dynatrace MCP). Needs `DT_API_TOKEN` + `DT_ENVIRONMENT`.
- `papanix-ai.lib.mcp.mkShellHook { pkgs; servers; }` — writes
  `.mcp.json`, wipes on exit.
- `papanix-ai.lib.plugins.defaultMarketplaces` — default Claude Code
  plugin marketplaces (`papa-ai-knowledgebase` + `rnd-ai-knowledgebase`).
  Each entry is `{ name; source; path?; }`; `path` is a vendored flake
  input used for hermetic plugin enumeration via
  `.claude-plugin/marketplace.json`.
- `papanix-ai.lib.plugins.mkShellHook { pkgs; marketplaces?; enable?; enableAll?; }` —
  writes project-scope `.claude/settings.json` with
  `extraKnownMarketplaces` + `enabledPlugins`, wipes on exit. `enable`
  takes `"<mpKey>/<pluginName>"` strings; `enableAll = true` enables
  every plugin in every marketplace; `enableAll = ["rnd"]` bulk-enables
  one marketplace.
- `papanix-ai.lib.mkEphemeralShellHook` — composer mentioned in
  `library/flake.nix` for combining multiple ephemeral hooks (skills,
  mcp, plugins, custom) under one EXIT trap.

## Formatting

- Formatter is `alejandra` (see root `flake.nix`).
- Run `nix fmt` before committing Nix changes.

## Verification

There is nothing to build or test. To smoke-test a template change:

```sh
nix flake init -t /path/to/this/repo#<template> -o /tmp/scratch
cd /tmp/scratch && nix develop --command true
```

## Don't

- Don't add CI, build outputs, or non-template Nix code.
- Don't commit `.claude/`, `.opencode/`, `.mcp.json`, or
  `.claude/settings.json` — they are ephemeral artifacts of
  `mkShellHook`.
- Don't pin `papanix-ai` to a commit inside templates unless asked;
  templates track the branch tip on purpose.
