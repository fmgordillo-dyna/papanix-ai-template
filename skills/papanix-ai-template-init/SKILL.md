---
name: papanix-ai-template-init
description: Initialize a papanix-ai-template into the user's project and walk them through every `# TODO:` and key `# NOTE:` marker so the generated flake is ready to use. Helps pick the right template (default / minimal / skills-only / mcp-custom / plugins-custom / library / dev-env / home-manager), runs `nix flake init`, then fills CLI selection, skill enablement, MCP servers, plugin marketplaces, custom permissions, and per-contributor dev tooling. Trigger when the user says "init a template", "set up papanix-ai in this project", "fill out the template", "pick a template", "use papanix-ai here", or invokes /papanix-ai-template-init.
---

# papanix-ai-template-init

End-to-end template adoption. Source of truth:

- `README.md` (this repo) — template matrix.
- `docs/getting-started.md` — the human-readable version of these steps.
- Each `<template>/flake.nix` — the file shape you will edit.

This skill is the **interactive guide**. Pick → init → fill → smoke test. Do not duplicate file contents in chat; read the file, ask the question, run `Edit`.

If the user wants user-scope (Home-Manager), hand off immediately to
`/papanix-ai-home-manager-setup`. This skill is for **project-scope**
templates only (default / minimal / skills-only / mcp-custom /
plugins-custom / library / dev-env).

## Step 0 — Prerequisites

Confirm Nix + credentials work — otherwise the final `nix develop` fails:

```bash
nix --version
nix flake show github:fmgordillo-dyna/papanix-ai 2>&1 | head -5
grep -q "access-tokens = github.com=" ~/.config/nix/nix.conf 2>/dev/null && echo "PAT: ok" || echo "PAT: missing"
ssh-add -l 2>/dev/null | grep -q . && echo "SSH agent: ok" || echo "SSH agent: empty"
```

Any failure → hand off to `/papanix-ai-setup` (Steps 1–5) and resume.

## Step 1 — Pick a template

Ask the user what they want, then map to a template:

| Want | Template |
|---|---|
| Batteries included (CLIs + all skills + Dynatrace MCP + Claude plugins). | `default` |
| Just the CLIs, nothing else, nothing wiped. | `minimal` |
| A subset of skills, no MCP, no plugins. | `skills-only` |
| All skills + extend the default MCP server set with more entries. | `mcp-custom` |
| All skills + curated Claude Code plugin marketplaces. | `plugins-custom` |
| Use papanix-ai purely as a library (no CLIs on PATH). | `library` |
| CLIs + per-contributor Node.js / Playwright via `lib.devEnv.mk`. | `dev-env` |

If they describe a mix, prefer `default` and tweak — it's the closest superset.

## Step 2 — Initialize

```bash
cd <project-dir>
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#<template>
```

If a `flake.nix` already exists, `nix flake init` refuses to overwrite —
ask the user whether to (a) move it aside, (b) pick a different
directory, or (c) hand-merge from the template (read the template's
`flake.nix` and walk them through inserting the papanix-ai bits).

## Step 3 — Read the generated flake and locate TODOs

```bash
cat flake.nix | grep -n -E "TODO|NOTE"
```

Use this list to drive Step 4. Every template's TODOs differ — only
ask about the ones present.

## Step 4 — Walk the TODOs

Walk these as relevant for the chosen template. For each one: ask, then
`Edit` the file. Show the user the new section after each edit.

### 4a. CLI selection (every template that pulls in `papanix-ai.packages.<system>.default`)

The default exports all four CLIs (`acli-pii bbctl dtctl junoctl`).

Ask:

> Want all four CLIs on PATH, or curate?

If curate: replace
```nix
packages = [papanix-ai.packages.${system}.default];
```
with
```nix
packages = with papanix-ai.packages.${system}; [ bbctl dtctl junoctl ];
```
(or whichever subset they pick). Dropping `acli-pii` lets them use
`nix develop` without `--impure`.

### 4b. Skill enablement (default / skills-only / mcp-custom / plugins-custom / library / home-manager)

The template ships a `mkBundle` call. Read it. Ask:

> Enable all skills, or curate?

List the catalog if they want to curate:

```bash
nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog \
  --apply builtins.attrNames --json
```

Help them pick. Then `Edit` one of:

```nix
enableAll = true;                          # everything
enableAll = [ "rnd" ];                     # whole knowledgebase
enable    = [ "papa/dt-jira" "rnd/dt-github" ];  # curated
```

If they also have local skills:

```nix
extraSources = {
  local = { path = ./skills; subdir = "."; };
};
enableAll = [ "local" ];
```

### 4c. MCP servers (default / mcp-custom)

The template sets `mcpServers = papanix-ai.lib.mcp.defaultServers;` — that
ships Dynatrace MCP + Juno MCP.

Ask:

> Stick with the defaults, or add extra servers?

If extras: extend with `//`. Common pattern (uses npx, OK in dev shells):

```nix
mcpServers = papanix-ai.lib.mcp.defaultServers // {
  github = {
    type    = "stdio";
    command = "npx";
    args    = [ "-y" "@modelcontextprotocol/server-github" ];
    env     = { GITHUB_TOKEN = "\${GITHUB_TOKEN}"; };
  };
};
```

If they don't use Dynatrace MCP, swap `//` for a full replacement:

```nix
mcpServers = { github = { … }; };
```

Remind them the file is written on `nix develop` entry, wiped on exit —
no commits needed.

### 4d. Claude Code plugin marketplaces (default / plugins-custom)

The template wires `papanix-ai.lib.claudeSettings.mkShellHook` with
`enableAll = true;`.

Ask:

> Bulk-enable all plugins from both knowledgebases, curate, or
> register-only (don't auto-install anything)?

- Bulk → keep `enableAll = true;`.
- One whole marketplace → `enableAll = [ "rnd" ];`.
- Curate → `enable = [ "papa/papa-jira" "rnd/dt-github" ];`. List with:
  ```bash
  nix eval github:fmgordillo-dyna/papanix-ai#lib.claudeSettings.defaultMarketplaces \
    --apply 'm: builtins.attrNames m' --json
  ```
- Register-only → `enableAll = false; enable = [];`. Claude Code will
  list the marketplaces but not auto-install plugins.

### 4e. Custom Claude Code settings (any template that calls `claudeSettings.mkShellHook`)

The template's `mkShellHook` call has a commented `settings = { … }`
block. Ask:

> Want to set Claude Code permissions / hooks / env in this project?

If yes, uncomment and fill, e.g.:

```nix
settings = {
  permissions = {
    allow = [ "Bash(git:*)" "Read(**)" ];
    deny  = [ "Bash(rm:*)" ];
  };
};
```

Otherwise leave the block commented.

### 4f. Per-contributor dev tooling (`dev-env`, optionally `default`)

The `dev-env` template wires `lib.devEnv.mk` at the top. Ask:

> Need Node.js, Playwright, or extra Nix packages in this shell?

Tune the call:

```nix
devEnv = papanix-ai.lib.devEnv.mk {
  inherit pkgs;
  nodejs     = { version = "nodejs_22"; withCorepack = true; };
  playwright = true;
  extraPackages = with pkgs; [ jq gh ];
};
```

`withBrowsers = true;` on `playwright` exports `PLAYWRIGHT_BROWSERS_PATH`
so the npm `playwright` package reuses the Nix-built browser bundle. Do
not double-install Playwright browsers via npm.

### 4g. `library` template specifics

No CLIs on PATH by design. Ask the user what packages they want in their
own `mkShell` and help them splice in the bundle's shellHook. Reference
`docs/getting-started.md` if they're unsure.

### 4h. Multi-knob templates: the `# NOTE:` markers

`# NOTE:` sections are safe-to-tweak but not strictly required. Walk
them only if the user asks. Examples:

- `targets.opencode.enable = true;` — also drop skills into opencode dir.
- `extraSources` — add a local skill directory.
- Per-marketplace overrides — register a third-party marketplace.

## Step 5 — Format

```bash
nix fmt
```

If `nix fmt` errors with `formatter not configured`, add to
`flake.nix`:

```nix
formatter.${system} = pkgs.alejandra;
```

Then re-run. Templates that include `formatter.<system>` already work
out of the box.

## Step 6 — Smoke test

```bash
nix develop --impure --command bash -c '
  bbctl --version
  dtctl --version
  acli-pii --version
  junoctl --version
' 2>&1
```

(Replace with the curated subset if they dropped CLIs.)

For `library`, smoke-test by listing skills installed into `.claude/`:

```bash
nix develop --impure --command ls -la .claude/skills/
```

Failure map:

- `cannot run ssh` → forgot `--impure`. Add it.
- `404 / SSO not authorized` → credentials. Send to `/papanix-ai-setup`.
- `attribute 'foo' missing` in the bundle → bad skill ID in `enable`.
  Re-list with `lib.skills.catalog --apply builtins.attrNames`.

## Step 7 — Wrap up

Concise summary:

- Template name + path.
- Which CLIs / skills / MCP servers / plugins are wired.
- The ephemeral guarantee — `.claude/`, `.mcp.json`, `opencode.jsonc`,
  `.claude/settings.json` are wiped on shell exit, so don't commit them.
- If they want a `.envrc` for auto-activation:
  ```bash
  echo "use flake --impure" > .envrc
  direnv allow
  ```
- Pointer to `/papanix-ai-home-manager-setup` if they later want
  user-scope on top.

## Conventions

- Always read the file before editing — templates evolve, and the TODO
  set changes. Do not edit from memory.
- Only edit `# TODO:` markers without asking. `# NOTE:` markers are
  user-opt-in — ask first.
- Never commit the ephemeral output files (`.claude/`, `.mcp.json`,
  `opencode.jsonc`, `.claude/settings.json`). Surface the warning if
  the user staged any of them.
- If the user wants a template that does not exist, do **not** invent
  one. Pick the closest template and tweak in-place. Suggest filing an
  upstream issue for a new template instead.
- Build failures from the underlying papanix-ai flake (vendor hash,
  Go module path) → surface verbatim and tell the user to file an
  issue against `github.com/fmgordillo-dyna/papanix-ai`. Do not patch
  templates around an upstream bug.
