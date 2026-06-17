# CLAUDE.md

Guidance for Claude / OpenCode working in this repo.

## What this repo is

A Nix flake that exposes **templates** for consuming
[`papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai), plus the
consumer-facing **install docs** and **guided onboarding skills**.

It is the canonical entry point for everything install-related —
installing Nix, setting up credentials, adopting a template, filling the
TODO / NOTE markers, and bringing Home-Manager into the picture. The
upstream `papanix-ai` repo is the library; this repo is the install
path.

Every template is a standalone `flake.nix` in its own subdirectory.

This repo does **not** package code, build artifacts, or run tests. It
is a registry of starter `flake.nix` files + Markdown docs + SKILLs.

> Important: this repo no longer installs agent skills or Claude Code
> plugin marketplaces declaratively. The `skills/` directory contains
> onboarding SKILL files for agents; the templates themselves focus on
> CLIs, sandboxing, MCP, and optional user-scope setup.

## Layout

- `flake.nix` — registers each template under `templates.<name>`.
- `default/` — CLIs + sandboxed `claude` + default MCP servers.
- `minimal/` — CLIs + sandboxed `claude` only, no shell hook.
- `mcp-custom/` — CLIs + sandboxed `claude` + extended MCP server set.
- `dev-env/` — CLIs + sandboxed `claude` + opt-in per-contributor dev tooling
  (Node.js / npm / corepack, Playwright with nixpkgs-built browsers) via
  `lib.devEnv.mk`.
- `home-manager/` — user-scope Home-Manager starter: CLIs + sandboxed
  claude in `$HOME`, with optional user-scope `devEnv`. MCP stays in the
  project devShell.
- `docs/` — consumer install + onboarding docs:
  - `getting-started.md` — end-to-end install sequence (Nix → creds → template → devShell).
  - `install-nix.md` — Nix install for macOS (incl. 26+), Linux, WSL.
  - `auth-setup.md` — SSH (Bitbucket) + GitHub PAT + SSO setup.
  - `home-manager.md` — user-scope install via Home-Manager.
- `skills/` — guided onboarding SKILL files:
  - `papanix-ai-setup` — first-time onboarding (Nix install + creds + template init + smoke build).
  - `papanix-ai-template-init` — adopt a project template, walk the generated markers, smoke-test the devShell.
  - `papanix-ai-home-manager-setup` — install Home-Manager, adopt the `home-manager` template, fill TODOs, run the first `switch`.

## When editing a template

- Project templates mainly use `# NOTE:` markers for safe user tweaks.
  The `home-manager` template also has required `# TODO:` markers for
  user / machine-specific values.
- When adding or removing a `# TODO:` marker, update the relevant skill
  and `docs/getting-started.md`.
- Templates must stay copy-pasteable: no relative paths outside the
  template dir, no references to sibling templates.
- If you add a template, also register it in the root `flake.nix` under
  `templates`, update `README.md`, update `docs/getting-started.md`, and
  decide if a SKILL needs a new branch.

## When editing a SKILL

- SKILL Markdown lives at `skills/<name>/SKILL.md`. The frontmatter
  `description` is the trigger surface — keep keyword coverage broad
  enough to catch likely phrasing.
- Source-of-truth for any step is the matching doc. SKILLs should quote
  commands and diagnose failures; they should not duplicate doc prose.
- All three SKILLs reference each other. When changing one, audit the
  other two for stale cross-links.
- Do not tell users that templates install skills or plugin
  marketplaces declaratively; that is no longer true in this repo.

## When editing docs

- `docs/getting-started.md` is the single human-readable entry point.
  Long sub-flows (Nix install edge cases, auth troubleshooting, full
  Home-Manager option matrix) belong in their dedicated doc.
- Each doc cross-links the relevant SKILL near the top so agents can
  hand off.
- Never copy install instructions into a template's `flake.nix` header
  comments — link to the doc.
- Keep template lists synchronized with the root `flake.nix` registry.

## papanix-ai surface used here

- `papanix-ai.packages.${system}` — package attrset containing
  `acli-pii`, `aimgr`, `bbctl`, `dtctl`, `junoctl`, plus upstream helper
  outputs like `claude-sandboxed`, `mcp-config`, and `opencode-config`.
- `papanix-ai.lib.mcp.defaultServers` — convenience MCP server set
  (`dynatrace-mcp` + `juno-mcp`). Dynatrace MCP needs `DT_API_TOKEN` +
  `DT_ENVIRONMENT`; Juno MCP requires no env vars.
- `papanix-ai.lib.mcp.mkConfig { pkgs; servers; }` — builds a
  `.mcp.json` derivation.
- `papanix-ai.lib.mcp.mkOpencodeConfig { pkgs; servers; }` — builds an
  `opencode.jsonc` derivation.
- `papanix-ai.lib.mcp.mkShellHook { pkgs; servers; }` — writes both
  `.mcp.json` and `opencode.jsonc`, wipes them on exit. Pass `servers`
  explicitly; downstream defaults are intentionally empty.
- `papanix-ai.lib.sandboxing.mkClaudeSandbox { ... }` — official helper
  for the sandboxed `claude` wrapper. Supports `cliPackages`,
  `extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`,
  `extraRoFiles`, `extraEnv`, `restrictNetwork`, `allowedDomains`, and
  `exposeSsh`.
- `papanix-ai.lib.devEnv.mk { pkgs; nodejs?; playwright?; extraPackages?; }`
  — per-contributor dev-environment helper. Returns
  `{ packages; shellHook; }`. `nodejs` accepts `true` or
  `{ version?; withCorepack?; }`; `playwright` accepts `true` or
  `{ withBrowsers?; }` and emits `PLAYWRIGHT_BROWSERS_PATH` +
  `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS` so the npm package reuses
  the Nix-built browser bundle.
- `papanix-ai.homeManagerModules.default` — exposes
  `programs.papanix-ai.*` for the `home-manager/` template. In this repo
  the template uses it for `cliTools`, `sandboxing`, and optional
  `devEnv`.

## Formatting

- Formatter for **this repo** is `alejandra` (see root `flake.nix`).
- Run `nix fmt` before committing Nix changes in the repo itself.
- Do not assume generated templates expose a formatter unless the file
  explicitly defines one.

## Verification

There is nothing to build or test. To smoke-test a template change:

```sh
mkdir -p /tmp/scratch
cd /tmp/scratch
nix flake init -t /path/to/this/repo#<template>
nix develop --impure --command true
```

For `home-manager`, verify the generated files and, if needed, run a
real `home-manager switch` in a scratch config dir.

## Don't

- Don't add CI, build outputs, or non-template Nix code.
- Don't commit `.mcp.json` or `opencode.jsonc` — they are ephemeral
  artifacts of `mkShellHook`.
- Don't pin `papanix-ai` to a commit inside templates unless asked;
  templates track the branch tip on purpose.
- Don't move install / onboarding docs into the upstream `papanix-ai`
  repo. That repo is the library; this repo is the install path. Keep
  them here.
