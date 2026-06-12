---
name: papanix-ai-home-manager-setup
description: Install Home-Manager (if missing) and adopt the papanix-ai `home-manager` template so skills / Claude Code settings / MCP servers / PAPA CLIs / sandboxed claude live in $HOME and follow the user across every repo. Walks through Home-Manager install, `nix flake init`, filling the TODO markers in flake.nix + home.nix (including sandbox config), and the first `home-manager switch`. Trigger when the user says "install home-manager", "user-scope install", "global papanix-ai", "across every repo", "home-manager setup", or invokes /papanix-ai-home-manager-setup.
---

# papanix-ai-home-manager-setup

End-to-end Home-Manager onboarding for papanix-ai. Source of truth:

- `docs/home-manager.md` — full user-scope reference (conflict matrix, MCP `activation` vs `snippet`, caveats).
- `home-manager/flake.nix` + `home-manager/home.nix` in this template — the file shapes you'll generate and fill in.

This skill is the **interactive guide**. Diagnose, run, verify, fill TODOs. Do not duplicate doc prose.

## Step 0 — Prerequisites

Confirm — these are non-negotiable:

1. Nix is installed with flakes enabled.
   ```bash
   nix --version
   nix flake show github:fmgordillo-dyna/papanix-ai 2>&1 | head -5
   ```
   If `nix` is missing OR the flake show fails on `experimental Nix feature`, hand off to `/papanix-ai-setup` (Step 1) and resume here when done.

2. GitHub PAT + Bitbucket SSH are set up. Skill `/papanix-ai-setup` covers this; check:
   ```bash
   grep -q "access-tokens = github.com=" ~/.config/nix/nix.conf 2>/dev/null && echo "PAT: configured" || echo "PAT: MISSING"
   ssh-add -l 2>/dev/null | grep -q . && echo "SSH agent: has key" || echo "SSH agent: empty"
   ```
   If either is missing AND the user wants `acli-pii` / `bbctl` / `junoctl` in `cliTools.selection`, send them to `/papanix-ai-setup` first.

3. Ask which CLIs the user wants on PATH globally, and whether they want the sandboxed `claude` wrapper. The template defaults to all four CLIs plus a customizable sandbox wrapper; dropping `acli-pii` lets them run `home-manager switch` without `--impure`.

## Step 1 — Install Home-Manager

```bash
command -v home-manager
```

Found → skip to Step 2.

Missing → install the standalone flake-based variant:

```bash
nix run home-manager/master -- --version
```

If that errors out (no internet, channel resolution issue), surface the
error verbatim — do not retry with random flags.

> Home-Manager has two install modes: standalone (managed by Nix flakes,
> what we use) or NixOS-module. We pick standalone because it works on
> macOS too. See <https://nix-community.github.io/home-manager/> if the
> user wants the other path.

## Step 2 — Prepare `~/.config/home-manager`

```bash
ls -la ~/.config/home-manager 2>/dev/null
```

Empty / non-existent → create it:

```bash
mkdir -p ~/.config/home-manager
```

Existing `flake.nix` / `home.nix` → **ASK** before clobbering. They may
already have a Home-Manager config we should merge into, not overwrite.
If they want to keep it, hand off — they need to add the papanix-ai
module by hand using the snippet from `docs/home-manager.md` → "Minimal
flake-based setup".

## Step 3 — Initialize the template

```bash
cd ~/.config/home-manager
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#home-manager
```

This drops two files: `flake.nix` and `home.nix`. Both have `# TODO:`
markers Claude will walk through next.

## Step 4 — Fill `flake.nix` TODOs

Read the file and identify these markers:

| Marker | Action |
|---|---|
| `homeConfigurations."me"` | Rename `"me"` to whatever the user calls this profile. Will be the `<name>` in `home-manager switch --flake .#<name>`. Default — `whoami` or `me`. Confirm before editing. |

That's the only TODO in `flake.nix`. The `# NOTE:` markers are
maintainer-tweakable; do not touch unless the user asks.

## Step 5 — Fill `home.nix` TODOs

Read the file and walk these prompts:

1. **`home.username`** —
   ```bash
   whoami
   ```
   Set to whatever it prints.

2. **`home.homeDirectory`** —
   ```bash
   echo "$HOME"
   ```
   Linux/WSL → `/home/<user>`. macOS → `/Users/<user>`. Use the printed
   value.

3. **`home.stateVersion`** — leave as-is on a first install. Only bump
   after the user reads the Home-Manager release notes.

4. **`programs.papanix-ai.skills`** — ask:
   > Enable every skill from both knowledgebases, or curate?
   - Bulk → `enableAll = true;` (default in the template).
   - Curate → `enable = [ ... ];`. List available IDs:
     ```bash
     nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog --apply builtins.attrNames --json
     ```
     Help them pick. Common picks: `papa/dt-jira`, `rnd/dt-github`,
     `rnd/dt-adr`, `rnd/dt-skill-creator`.

5. **`programs.papanix-ai.claudeSettings`** — ask:
   > Enable every Claude Code plugin from both knowledgebases?
   - Bulk → `enableAll = true;`.
   - Curate → `enable = [ "papa/papa-jira" "rnd/dt-github" ];`. List:
     ```bash
     nix eval github:fmgordillo-dyna/papanix-ai#lib.claudeSettings.defaultMarketplaces \
       --apply 'm: builtins.attrNames m' --json
     ```

6. **`programs.papanix-ai.mcp.servers`** — explain that upstream Home-Manager now defaults to `{}`. The template opts into `papanix-ai.lib.mcp.defaultServers`; ask whether to keep that canned set or extend it with extra servers.

7. **`programs.papanix-ai.mcp.claudeCode.strategy`** — check whether
   `claude` is on PATH:
   ```bash
   command -v claude
   ```
   - Found → keep `activation` (default). HM will run
     `claude mcp add-json --scope user` at switch time.
   - Missing → set `strategy = "snippet";`. After switch the user runs
     `claude mcp import-json ~/.config/papanix-ai/mcp-servers.json` once
     they install claude-code.

8. **`programs.papanix-ai.cliTools.selection`** —
   - Template default (all four) → requires `--impure` for the switch (acli-pii).
   - Pure → tell user to set `selection = [ "bbctl" "dtctl" "junoctl" ];`.

9. **custom `sandboxedClaude` block in `home.nix`** — ask whether the user wants to customize `allowedPackages`, `stateDirs`, `extraEnv`, or network policy. The template installs that package into `home.packages` with `lib.hiPrio` so `claude` resolves to the wrapper globally.

Apply the edits via the `Edit` tool. After each edit, show the user the
new content of the section you touched so they can sanity-check.

## Step 6 — Switch

```bash
cd ~/.config/home-manager
nix run home-manager/master -- switch --flake .#<name> --impure
```

Use the name set in Step 4. Drop `--impure` if the user picked the pure
selection.

This will:

- Symlink skills into `~/.claude/skills/` (and per-agent dirs if enabled).
- Write `~/.claude/settings.json`.
- For MCP `activation` → run `claude mcp add-json --scope user` per
  server, record in `~/.config/papanix-ai/mcp-managed.json`.
- For MCP `snippet` → symlink `~/.config/papanix-ai/mcp-servers.json`.
- Install PAPA CLIs into `~/.nix-profile/bin/`.
- Install the sandboxed `claude` wrapper from the custom `sandboxedClaude` package in `home.nix`.

Failure map:

- `error: SSO not authorized` / `404` on `acli-pii` or `bbctl`/`junoctl`
  → credentials missing or stale. Send to `/papanix-ai-setup` Step 4–5.
- `'claude' CLI not found in PATH` → activation skipped. If the template
  just installed sandboxing, open a new shell and re-run
  `home-manager switch`; otherwise install claude-code (or keep the
  sandboxed wrapper enabled) and re-run, or switch to `snippet`
  strategy in `home.nix`.
- `attribute 'me' missing` → name mismatch between `flake.nix`
  `homeConfigurations."<name>"` and the `--flake .#<name>` argument.
- `Conflict between … and …` → another Home-Manager-managed file
  already owns the path. Read the error verbatim, ask user.

## Step 7 — Verify

```bash
# Skills
ls -la ~/.claude/skills/ | head -20

# Claude settings
test -f ~/.claude/settings.json && head -40 ~/.claude/settings.json

# MCP (activation)
cat ~/.config/papanix-ai/mcp-managed.json 2>/dev/null
claude mcp list --scope user 2>/dev/null

# MCP (snippet)
ls -la ~/.config/papanix-ai/mcp-servers.json 2>/dev/null

# CLIs + sandboxed claude
which bbctl dtctl acli-pii junoctl claude 2>/dev/null
```

Anything missing → cross-reference the relevant section of
`docs/home-manager.md` → "What lands where".

## Step 8 — Wrap up

Concise summary:

- What landed (skills count, plugin marketplaces, MCP server names, CLIs, sandboxed `claude`).
- Whether the user is on `activation` or `snippet`, and the one-time
  manual step if `snippet`.
- That project devShells from other templates still layer on top —
  project scope wins on conflicts. See
  `docs/home-manager.md` → "Coexistence with project devShells".
- Day-2: `cd ~/.config/home-manager && home-manager switch --flake .#<name> --impure`
  whenever they edit `home.nix`. `nix flake update papanix-ai` to pull
  in upstream changes.

## Conventions

- **Never** rewrite an existing `~/.config/home-manager/` setup without
  explicit yes. They may already have a Home-Manager config worth
  preserving.
- **Never** edit `~/.claude.json` directly — Claude Code owns it, the
  module mutates only the MCP section via `claude mcp add-json`.
- **Never** symlink `~/.claude.json` from anywhere. The CLI writes to
  it; symlinking from `/nix/store` bricks it.
- If a step needs the user's own terminal (browser-based GitHub SSO,
  `sudo` for daemon restart), tell them to run it with `!` so output
  lands in this session.
- `--impure` is fine — it is required while `acli-pii` is in the
  selection. Do not strip it without first removing `acli-pii` from
  `cliTools.selection`.
