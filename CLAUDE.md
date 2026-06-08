# CLAUDE.md

Guidance for Claude / OpenCode working in this repo.

## What this repo is

A Nix flake that exposes **templates** for consuming
[`papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai), plus the
consumer-facing **install docs** and **guided onboarding skills**.

It is the canonical entry point for everything install-related —
installing Nix, setting up credentials, adopting a template, filling
the TODO markers, and bringing Home-Manager into the picture. The
upstream `papanix-ai` repo is the library; this repo is the install
path.

Every template is a standalone `flake.nix` in its own subdirectory.

This repo does **not** package code, build artifacts, or run tests. It
is a registry of starter `flake.nix` files + Markdown docs + SKILLs.

## Layout

- `flake.nix` — registers each template under `templates.<name>`.
- `default/` — full setup: CLIs + skills + Dynatrace MCP + Claude plugins.
- `minimal/` — CLIs only, no shell hook, nothing wiped.
- `skills-only/` — curated skill subset, no MCP, no plugins.
- `mcp-custom/` — all skills + extended MCP server set.
- `plugins-custom/` — all skills + curated Claude Code plugin marketplaces.
- `library/` — skills only, no CLIs, demonstrates BYO packages.
- `dev-env/` — CLIs + opt-in per-contributor dev tooling (Node.js / npm /
  corepack, Playwright with nixpkgs-built browsers) via `lib.devEnv.mk`.
- `home-manager/` — user-scope Home-Manager starter.
- `docs/` — consumer install + onboarding docs:
  - `getting-started.md` — end-to-end install sequence (Nix → creds → template → devShell).
  - `install-nix.md` — Nix install for macOS (incl. 26+), Linux, WSL.
  - `auth-setup.md` — SSH (Bitbucket) + GitHub PAT + SSO setup.
  - `home-manager.md` — user-scope install via Home-Manager.
- `skills/` — guided onboarding skills (canonical, do not duplicate their steps in docs):
  - `papanix-ai-setup` — first-time onboarding (Nix install + creds + template init + smoke build). Trigger: "getting started", "first setup", "set up credentials", "onboard", "install papanix-ai".
  - `papanix-ai-template-init` — adopt a template into a project, walk every `# TODO:` / `# NOTE:`, smoke-test the devShell. Trigger: "init a template", "set up papanix-ai in this project", "fill out the template".
  - `papanix-ai-home-manager-setup` — install Home-Manager, adopt the `home-manager` template, fill TODOs in `flake.nix` + `home.nix`, run the first `switch`. Trigger: "install home-manager", "user-scope install", "global papanix-ai".

## When editing a template

- Each template's `flake.nix` carries comments. Sections marked
  `# NOTE:` are the user-editable knobs — preserve and update them when
  changing behavior.
- Sections marked `# TODO:` are user-required edits. Skills walk users
  through these — when adding/removing a TODO marker, update the
  relevant skill (typically `papanix-ai-template-init` or
  `papanix-ai-home-manager-setup`) and `docs/getting-started.md`.
- Templates must stay copy-pasteable: no relative paths outside the
  template dir, no references to sibling templates.
- If you add a template, also register it in the root `flake.nix`
  under `templates`, update `README.md`, update
  `docs/getting-started.md`, and decide if a SKILL needs a new branch.

## When editing a SKILL

- SKILL Markdown lives at `skills/<name>/SKILL.md`. The frontmatter
  `description` is the trigger surface — keep keyword coverage broad
  enough to catch the user's likely phrasing.
- Source-of-truth for any step is the matching doc. SKILLs should
  quote commands and diagnose failures; they should not duplicate
  doc prose.
- All three SKILLs reference each other. When changing one, audit the
  other two for stale cross-links.
- If a SKILL needs a step that the upstream `papanix-ai` flake does
  not yet expose, surface it; do not work around an upstream gap
  inside the skill.

## When editing docs

- `docs/getting-started.md` is the single human-readable entry point.
  Long sub-flows (Nix install edge cases, auth troubleshooting, full
  Home-Manager option matrix) belong in their dedicated doc; the
  getting-started page links into them.
- Each doc cross-links the relevant SKILL near the top so agents can
  hand off.
- Never copy install instructions into a template's `flake.nix`
  header comments — link to the doc.

## papanix-ai surface used here

- `papanix-ai.packages.${system}.default` — bundle of PAPA CLIs
  (`acli-pii`, `bbctl`, `dtctl`, `junoctl`).
- `papanix-ai.lib.skills.mkBundle { pkgs; enable | enableAll; skills? }` —
  builds the skill bundle. See
  `vendor/agent-skills-nix/lib/default.nix` in the upstream repo for
  the skill schema.
- `papanix-ai.lib.skills.mkShellHook { pkgs; bundle; }` — installs skills
  into `.claude/` (default targets; opencode is opt-in), registers an EXIT
  trap that wipes them.
- `papanix-ai.lib.mcp.defaultServers` — default MCP server set
  (Dynatrace MCP + Juno MCP). Dynatrace MCP needs `DT_API_TOKEN` + `DT_ENVIRONMENT`;
  Juno MCP requires no env vars.
- `papanix-ai.lib.mcp.mkShellHook { pkgs; servers; }` — writes
  `.mcp.json` and `opencode.jsonc`, wipes on exit.
- `papanix-ai.lib.claudeSettings.defaultMarketplaces` — default Claude
  Code plugin marketplaces (`papa-ai-knowledgebase` + `rnd-ai-knowledgebase`).
  Marketplace shape is `{ name; input?; source?; path?; }`. The built-in
  defaults in `papanix-ai` are input-backed internally; when a consumer
  template adds its own marketplace repo, it usually sets explicit
  `source = { source = "github"; repo = "owner/repo"; };` plus
  `path = inputs.my-mp` (or a subdirectory under it).
- `papanix-ai.lib.claudeSettings.mkShellHook { pkgs; marketplaces?; enable?; enableAll?; settings?; }` —
  writes project-scope `.claude/settings.json` with
  `extraKnownMarketplaces` + `enabledPlugins` (plugin concern) and
  optionally merges user-defined fields via `settings` (e.g.
  `permissions`), wipes on exit. `enable` takes `"<mpKey>/<pluginName>"`
  strings; `enableAll = true` enables every plugin in every marketplace;
  `enableAll = ["rnd"]` bulk-enables one marketplace. Omit `settings`
  entirely when no custom config is needed.
- `papanix-ai.lib.mkEphemeralShellHook` — composer mentioned in
  `library/flake.nix` for combining multiple ephemeral hooks (skills,
  mcp, claudeSettings, custom) under one EXIT trap.
- `papanix-ai.lib.devEnv.mk { pkgs; nodejs? ; playwright? ; extraPackages? }` —
  per-contributor dev-environment helper. Returns
  `{ packages; shellHook; }`. `nodejs` accepts `true` or
  `{ version?; withCorepack?; }`; `playwright` accepts `true` or
  `{ withBrowsers?; }` and emits `PLAYWRIGHT_BROWSERS_PATH` +
  `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS` so the npm package
  reuses the Nix-built browser bundle. NOT an ephemeral hook; splice
  `packages` into `mkShell.packages` and `shellHook` into your shell.
- `papanix-ai.homeManagerModules.default` — exposes
  `programs.papanix-ai.*` for the `home-manager/` template. See
  `docs/home-manager.md` for the full option matrix.

## Formatting

- Formatter is `alejandra` (see root `flake.nix`).
- Run `nix fmt` before committing Nix changes.

## Verification

There is nothing to build or test. To smoke-test a template change:

```sh
nix flake init -t /path/to/this/repo#<template> -o /tmp/scratch
cd /tmp/scratch && nix develop --impure --command true
```

## Don't

- Don't add CI, build outputs, or non-template Nix code.
- Don't commit `.claude/`, `.opencode/`, `.mcp.json`, or
  `.claude/settings.json` — they are ephemeral artifacts of
  `mkShellHook`.
- Don't pin `papanix-ai` to a commit inside templates unless asked;
  templates track the branch tip on purpose.
- Don't move install / onboarding docs into the upstream
  `papanix-ai` repo. That repo is the library; this repo is the
  install path. Keep them here.
