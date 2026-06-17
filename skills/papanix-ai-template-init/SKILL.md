---
name: papanix-ai-template-init
description: Initialize a papanix-ai-template into the user's project and walk them through the generated `flake.nix` markers so it is ready to use. Helps pick the right project template (default / minimal / mcp-custom / dev-env), runs `nix flake init`, then tunes package selection, sandboxed `claude` config, MCP servers, and per-contributor dev tooling before smoke-testing the devShell. Trigger when the user says "init a template", "set up papanix-ai in this project", "fill out the template", "pick a template", "use papanix-ai here", or invokes /papanix-ai-template-init.
---

# papanix-ai-template-init

End-to-end template adoption. Source of truth:

- `README.md` — template matrix.
- `docs/getting-started.md` — the human-readable version of these steps.
- Each `<template>/flake.nix` — the file shape you will edit.

This skill is the **interactive guide**. Pick → init → review markers →
smoke test. Do not duplicate file contents in chat; read the file, ask
the question, run `Edit`.

If the user wants user-scope (Home-Manager), hand off immediately to
`/papanix-ai-home-manager-setup`. This skill is for **project-scope**
templates only (`default`, `minimal`, `mcp-custom`, `dev-env`).

> Note: these templates no longer install agent skills or Claude plugin
> marketplaces declaratively. Focus on CLIs, sandboxing, MCP, and
> optional dev tooling.

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
| Batteries included for most repos: CLIs + sandboxed `claude` + default MCP servers. | `default` |
| Just the CLIs + sandboxed `claude`, nothing else, nothing wiped. | `minimal` |
| CLIs + sandboxed `claude` + extend the default MCP server set with more entries. | `mcp-custom` |
| CLIs + sandboxed `claude` + per-contributor Node.js / Playwright via `lib.devEnv.mk`. | `dev-env` |

If they describe a mix, prefer `default` and tweak.

## Step 2 — Initialize

```bash
cd <project-dir>
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#<template>
```

If a `flake.nix` already exists, `nix flake init` refuses to overwrite.
Ask whether to:

- move it aside,
- pick a different directory, or
- hand-merge from the template.

## Step 3 — Read the generated flake and locate markers

```bash
grep -n -E "TODO|NOTE" flake.nix
```

Project templates in this repo usually have `# NOTE:` markers rather
than required `# TODO:` markers. Use the list to drive Step 4.

## Step 4 — Walk the markers

For each relevant section: ask, then `Edit` the file. Show the user the
updated section after each edit.

### 4a. Package selection

The project templates start from a `cliPackages` list with the full
PAPA CLI bundle and a locally built `sandboxedClaude` package.

Ask:

> Want the full CLI bundle plus sandboxed `claude` on PATH, or curate?

If curate, edit `cliPackages`, e.g.

```nix
cliPackages = with papanix-ai.packages.${system}; [
  aimgr
  bbctl
  dtctl
  junoctl
];
```

Dropping `acli-pii` lets them use `nix develop` without `--impure`.
Dropping `sandboxedClaude` removes the wrapper entirely.

### 4b. Sandboxed `claude` configuration

Every project template in this repo includes a local
` sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox { ... };`
block.

Ask:

> Keep the default sandbox config, or customize extra tools / bind mounts / network policy?

Common edits:

```nix
extraAllowedPackages = with pkgs; [ gh kubectl ];
extraRwDirs = [ "$HOME/.config/gh" "$HOME/.kube" ];
extraRwFiles = [ "$HOME/.kube/config" ];
restrictNetwork = true;
allowedDomains = {
  "github.com" = [ "GET" "HEAD" ];
  "api.anthropic.com" = "*";
};
exposeSsh = true;
```

If they want to expose a custom package attrset inside Claude, tell them
to flatten it first:

```nix
myPkgs = {
  inherit (pkgs) gh kubectl;
};

extraAllowedPackages = builtins.attrValues myPkgs;
```

Passing the attrset directly (`extraAllowedPackages = [ myPkgs ];`) fails
with `cannot coerce a set to a string`.

Remind them: `allowedDomains` only applies when `restrictNetwork = true;`.

### 4c. MCP servers (`default`, `mcp-custom`)

`default` sets:

```nix
mcpServers = papanix-ai.lib.mcp.defaultServers;
```

Ask:

> Stick with the defaults, or add extra servers?

If extras, extend with `//`. Common pattern:

```nix
mcpServers = papanix-ai.lib.mcp.defaultServers // {
  github = {
    type = "stdio";
    command = "npx";
    args = [ "-y" "@modelcontextprotocol/server-github" ];
    env = { GITHUB_TOKEN = "\${GITHUB_TOKEN}"; };
  };
};
```

If they do not want Dynatrace / Juno MCP, replace the whole set instead
of extending it.

Remind them: `.mcp.json` and `opencode.jsonc` are written on shell entry
and wiped on exit.

### 4d. Per-contributor dev tooling (`dev-env`, optionally `default`)

Ask:

> Need Node.js, Playwright, or extra Nix packages in this shell?

Tune the `lib.devEnv.mk` call:

```nix
devEnv = papanix-ai.lib.devEnv.mk {
  inherit pkgs;
  nodejs = { version = "nodejs_22"; withCorepack = true; };
  playwright = true;
  extraPackages = with pkgs; [ jq gh ];
};
```

`playwright = true` exports `PLAYWRIGHT_BROWSERS_PATH` so the npm
`playwright` package reuses the Nix-built browser bundle.

### 4e. `# NOTE:` markers

These are safe-to-tweak but not strictly required. Walk them only if
the user wants changes.

Examples:

- sandbox `extraAllowedPackages`
- sandbox `extraRwDirs` / `extraRwFiles`
- sandbox `extraRoDirs` / `extraRoFiles`
- sandbox `extraEnv` / `exposeSsh`
- MCP server replacement vs extension
- optional `devEnv` wiring in `default`

## Step 5 — Optional formatting

If the generated flake already has a formatter, run:

```bash
nix fmt
```

If it does not, skip formatting unless the user explicitly wants to add
`formatter.${system} = pkgs.alejandra;`.

## Step 6 — Smoke test

```bash
nix develop --impure --command bash -c '
  bbctl --version
  aimgr --version
  dtctl --version
  acli-pii --version
  junoctl --version
  claude --version
' 2>&1
```

Use the curated subset if they dropped any packages.

For `default` and `mcp-custom`, also verify the ephemeral MCP files:

```bash
nix develop --impure --command bash -c '
  test -f .mcp.json && echo ".mcp.json: ok"
  test -f opencode.jsonc && echo "opencode.jsonc: ok"
'
```

Failure map:

- `cannot run ssh` → forgot `--impure`.
- `404 / SSO not authorized` → credentials. Send to `/papanix-ai-setup`.
- missing MCP files in `default` / `mcp-custom` → inspect the `mcpServers` block and retry.

## Step 7 — Wrap up

Concise summary:

- Template name + path.
- Which CLIs and whether sandboxed `claude` are wired.
- Whether MCP is enabled and, if so, which server set was chosen.
- Whether optional `devEnv` tooling was enabled.
- The ephemeral guarantee for MCP-enabled templates — `.mcp.json` and
  `opencode.jsonc` are wiped on shell exit, so do not commit them.
- If they want a `.envrc` for auto-activation:
  ```bash
  echo "use flake --impure" > .envrc
  direnv allow
  ```
- Pointer to `/papanix-ai-home-manager-setup` if they later want
  user-scope on top.

## Conventions

- Always read the file before editing — templates evolve.
- Only edit required values without asking. `# NOTE:` markers are
  user-opt-in — ask first.
- Never commit ephemeral output files (`.mcp.json`, `opencode.jsonc`).
- If the user wants a template that does not exist, do **not** invent
  one. Pick the closest template and tweak in-place.
- Build failures from the underlying `papanix-ai` flake (vendor hash,
  Go module path) → surface verbatim and tell the user to file an issue
  against `github.com/fmgordillo-dyna/papanix-ai`.
