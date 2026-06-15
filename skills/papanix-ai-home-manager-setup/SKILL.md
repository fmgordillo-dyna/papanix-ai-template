---
name: papanix-ai-home-manager-setup
description: Install Home-Manager (if missing) and adopt the papanix-ai `home-manager` template so skills for non-Claude agents (opencode, codex, …) and Claude Code plugin marketplaces are available across every repo. Walks through Home-Manager install, `nix flake init`, filling the TODO markers in flake.nix + home.nix (skills targets, marketplaces, CLIs, sandbox config), and the first `home-manager switch`. Trigger when the user says "install home-manager", "user-scope install", "global papanix-ai", "across every repo", "home-manager setup", or invokes /papanix-ai-home-manager-setup.
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

3. Ask which CLIs the user wants on PATH globally, whether they want the sandboxed `claude` wrapper, and which non-Claude agents they use (opencode, codex, cursor, etc.) — to know which skill targets to enable in Step 5.

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

4. **`programs.papanix-ai.skills` (non-Claude agents only)** —
   The template defaults to `enableAll = true` with `targets.claude.enable = false`
   (Claude skills are handled in the project devShell, not here).
   Ask which non-Claude agent targets to enable:
   - opencode → `targets.opencode.enable = true;` (enabled by default in template)
   - codex    → `targets.codex.enable = true;`
   - cursor   → `targets.cursor.enable = true;`
   Enable the matching targets; disable any that the user does not use.

5. **`programs.papanix-ai.claudeSettings`** —
   Explain: this block registers Claude Code plugin marketplaces so Claude Code
   can discover them. **Plugin activation happens via the Claude Code TUI**
   (Settings → Plugin Marketplace) — not via Nix.
   The template defaults to `papanix-ai.lib.claudeSettings.defaultMarketplaces`
   (papa-ai-knowledgebase + rnd-ai-knowledgebase). Ask whether to keep defaults or
   add a custom marketplace.

6. **`programs.papanix-ai.cliTools.selection`** —
   - Template default (all four) → requires `--impure` for the switch (acli-pii).
   - Pure → tell user to set `selection = [ "bbctl" "dtctl" "junoctl" ];`.

7. **`programs.papanix-ai.sandboxing` in `home.nix`** — explain that `enable = true;` already gives a safe default wrapper with the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, and `node`. Ask whether the user wants to extend it with `extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`, `extraRoFiles`, `extraEnv`, or tighter network policy via `restrictNetwork` + `allowedDomains`.

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

- Symlink skills into `~/.config/opencode/skills/` (and other enabled non-Claude targets).
- Write `~/.claude/settings.json` with registered plugin marketplaces.
- Install PAPA CLIs into `~/.nix-profile/bin/`.
- Install the sandboxed `claude` wrapper from `programs.papanix-ai.sandboxing.enable`.

Failure map:

- `error: SSO not authorized` / `404` on `acli-pii` or `bbctl`/`junoctl`
  → credentials missing or stale. Send to `/papanix-ai-setup` Step 4–5.
- `attribute 'me' missing` → name mismatch between `flake.nix`
  `homeConfigurations."<name>"` and the `--flake .#<name>` argument.
- `Conflict between … and …` → another Home-Manager-managed file
  already owns the path. Read the error verbatim, ask user.

## Step 7 — Verify

```bash
# Skills (opencode and other enabled targets)
ls -la ~/.config/opencode/skills/ 2>/dev/null | head -20

# Claude settings (marketplace registration)
test -f ~/.claude/settings.json && head -40 ~/.claude/settings.json

# CLIs + sandboxed claude
which bbctl dtctl acli-pii junoctl claude 2>/dev/null
```

Anything missing → cross-reference the relevant section of
`docs/home-manager.md` → "What lands where".

## Step 8 — Wrap up

Concise summary:

- What landed: which non-Claude skill targets are active (opencode etc.), plugin marketplaces registered, CLIs on PATH, sandboxed `claude`.
- That Claude plugins are registered but must be enabled via the Claude Code TUI (Settings → Plugin Marketplace).
- That project devShells still layer on top — project scope wins on conflicts. See `docs/home-manager.md` → "Coexistence with project devShells".
- Day-2: `cd ~/.config/home-manager && home-manager switch --flake .#<name> --impure` whenever they edit `home.nix`. `nix flake update papanix-ai` to pull in upstream changes.

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
