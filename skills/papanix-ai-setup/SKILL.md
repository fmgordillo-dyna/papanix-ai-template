---
name: papanix-ai-setup
description: Walk a first-time user through papanix-ai onboarding end to end — install Nix (Determinate Systems on macOS / Linux / WSL, with alternatives), set up SSH credentials for the private packages, initialize a project template, and verify all four CLIs build. Trigger when the user says "getting started", "first setup", "set up credentials", "onboard", "help me get started", "install papanix-ai", or invokes /papanix-ai-setup.
---

# papanix-ai-setup

First-time onboarding for papanix-ai. Source of truth:

- `docs/install-nix.md` — Nix install commands. macOS 26+ (Tahoe) requires the official NixOS installer or the Determinate shell script with custom GIDs (GID 350 is taken by `_avectodaemon`); macOS ≤15 uses the Determinate `.pkg`; Linux + WSL use the Determinate curl one-liner.
- `docs/auth-setup.md` — SSH credentials for private packages.
- `docs/getting-started.md` — end-to-end install sequence including template init.

This skill is the **interactive guide**. Diagnose, fix, verify. Quote commands and outputs; do not duplicate doc prose.

Two private packages need credentials:

- `acli-pii` → Bitbucket (`bitbucket.lab.dynatrace.org`) — SSH key, `builtins.fetchGit`, **`--impure` required**
- `junoctl` / `bbctl` → GitHub `Dynatrace-Internal/*` — GitHub PAT in `~/.config/nix/nix.conf`, `fetchFromGitHub` / `builtins.fetchTree`, **no `--impure`**

`dtctl` is public and needs no auth.

If the user wants a **user-scope install** (Home-Manager, follows them
across every repo) hand off to `/papanix-ai-home-manager-setup` after
Step 4 — the credential / Nix steps below are still prerequisites.

## Step 0 — Greet + confirm scope

Tell user: skill installs Nix if missing, then SSH credentials, then runs real builds, then initializes a template into their project. Estimate 5–15 minutes depending on starting state (longest single manual step: GitHub SSO authorize via browser).

Ask:

1. Platform — `uname -s` (`Darwin` / `Linux`) plus check `/proc/version` or env `WSL_DISTRO_NAME` to detect WSL. For macOS also run `sw_vers -productVersion` to detect macOS 26+ (Tahoe). Linux + WSL → curl one-liner path.
2. Already have an SSH key registered with GitHub + Bitbucket, or starting blank?
3. Scope — **project** (this repo only, via `nix develop`) or **user** (every repo, via Home-Manager)? If user, finish credential steps below then hand off to `/papanix-ai-home-manager-setup`.

## Step 1 — Nix installed

```bash
nix --version
command -v nix
```

Nix present → skip to Step 2.

Missing → pick path by platform:

**macOS 26 (Tahoe) and later** — the `.pkg` installer fails with a scripts error, and GID 350 is reserved by `_avectodaemon`. Use the official NixOS installer (runs interactively, must be run by the user in their own terminal):

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

Flakes NOT enabled by default — after install, create/edit `~/.config/nix/nix.conf`:

```
experimental-features = nix-command flakes
```

Then open a new shell.

Alternative for macOS 26 if the user prefers Determinate Nix (flakes pre-enabled):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix -o /tmp/detsys-install.sh
sudo sh /tmp/detsys-install.sh install --no-confirm \
  --nix-build-group-id 30000 \
  --nix-build-user-id-base 30001
```

After install, source Nix or open a new shell:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

**macOS 15 (Sequoia) and earlier** — Determinate `.pkg` (flakes pre-enabled, clean uninstall):

```bash
curl -L -o /tmp/determinate.pkg https://install.determinate.systems/determinate-pkg/stable/Universal
open /tmp/determinate.pkg
```

GUI installer; user clicks through, enters admin password. After install, start a new shell, then return.

**Linux / WSL** — Determinate curl one-liner:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

User runs install **in their own terminal** (interactive prompts, sudo / admin password). After install, start a new shell, then return.

WSL note: curl one-liner is the only path (no `.pkg` on Linux). If the user is on a stock WSL distro with no `systemd`, recent WSL2 (`wsl --version` ≥ 2) supports systemd via `/etc/wsl.conf`; the Determinate installer will detect what is available. If install fails on WSL, surface the exact error to the user — do not guess a workaround.

Verify:

```bash
nix --version
nix flake show github:fmgordillo-dyna/papanix-ai
```

Output should list `acli-pii`, `bbctl`, `dtctl`, `junoctl`. If `experimental Nix feature 'nix-command' is disabled`, user picked official installer and skipped the `nix.conf` edit — fix before continuing.

## Step 2 — SSH key exists

```bash
ls -1 ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub 2>/dev/null
ls -1 ~/.ssh/id_rsa ~/.ssh/id_rsa.pub 2>/dev/null
```

Pair found → use it (record path). None → ask before generating:

> No SSH key found. Generate `~/.ssh/id_ed25519` now? You will upload the public key to GitHub and Bitbucket next.

On yes:

```bash
ssh-keygen -t ed25519 -C "facundo.gordillo@dynatrace.com" -f ~/.ssh/id_ed25519 -N ""
```

(Use user's email from session context. Empty passphrase only if user accepts — ask first; if they want a passphrase, drop `-N ""` and have them run it via `!` in their terminal.)

Print public key + upload targets:

```bash
cat ~/.ssh/id_ed25519.pub
```

- GitHub: https://github.com/settings/keys → **New SSH key**.
- Bitbucket: https://bitbucket.lab.dynatrace.org → user menu → **Personal settings → SSH keys**.

Wait for confirmation both uploaded.

## Step 3 — Agent has the key

```bash
ssh-add -l
```

- `The agent has no identities.` → `ssh-add ~/.ssh/id_ed25519` (or whichever pair).
- `Could not open a connection to your authentication agent.` → `eval "$(ssh-agent -s)"`, then re-add. On WSL, agent does not persist across shell sessions by default — user may need a shell init snippet; surface this only if it recurs.
- Key listed → continue.

## Step 4 — GitHub PAT (`bbctl` + `junoctl`)

### 4a. Create PAT

**Cannot be automated.** Tell user:

> https://github.com/settings/tokens → **Generate new token (classic)** → enable **`repo`** scope → generate → copy the `ghp_...` value.

### 4b. SSO-authorize the token

**Cannot be automated.** Tell user:

> On the tokens page, click **Configure SSO → Authorize** for `Dynatrace-Internal`. Without this, the download returns 404 even with a valid token.

Wait for confirmation.

### 4c. Add to Nix config

```bash
mkdir -p ~/.config/nix
echo "access-tokens = github.com=<PASTE_TOKEN_HERE>" >> ~/.config/nix/nix.conf
```

If on Linux with a multi-user Nix install, restart the daemon to pick up the config:

```bash
sudo systemctl restart nix-daemon   # Linux (systemd)
```

macOS (Determinate):

```bash
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

### 4d. Real build

```bash
nix build github:fmgordillo-dyna/papanix-ai#junoctl --no-link
nix build github:fmgordillo-dyna/papanix-ai#bbctl   --no-link
```

Failure map:

- `404 / cannot download source` → PAT not SSO-authorized (step 4b) or wrong scope. Re-check.
- `access-tokens not picked up` → daemon not restarted. Run step 4c restart command.

## Step 5 — Bitbucket SSH (`acli-pii`)

### 5a. Host trust + auth

```bash
ssh -T git@bitbucket.lab.dynatrace.org
```

Expected: Bitbucket welcome line.

Failures:

- `Permission denied (publickey)` → key not uploaded to Bitbucket or not loaded.
- `Host key verification failed` → first connection; accept fingerprint.

### 5b. Real build

```bash
nix build github:fmgordillo-dyna/papanix-ai#acli-pii --impure --no-link
```

Failure map:

- `Permission denied (publickey)` → Step 3 / Step 5a.
- `Host key verification failed` → Step 5a.
- `error: cannot run ssh: No such file or directory` → missing `--impure`.
- `error: getting status of '/nix/store/...-source': No such file or directory` → eval-time fetch interrupted; retry.

## Step 6 — Initialize a template

Ask user: project-scope (this repo only) or user-scope (every repo)?

**User-scope** → hand off to `/papanix-ai-home-manager-setup` now. The credential setup above is the only prerequisite.

**Project-scope** → ask which template (default / minimal / skills-only / mcp-custom / plugins-custom / library / dev-env). Then:

```bash
cd /path/to/their/project
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#<template>
```

After init, hand off to `/papanix-ai-template-init` to walk through
the `# TODO:` markers in the generated `flake.nix`, OR walk them
yourself using the table in `docs/getting-started.md` → "Fill in the
TODOs".

## Step 7 — Enter the shell + smoke test

```bash
nix develop --impure
```

(`--impure` only required if `acli-pii` is in the package selection — most templates include it by default.)

Inside the shell:

```bash
bbctl --version
dtctl --version
acli-pii --version
junoctl --version
```

All four (or the curated subset the user picked) should print versions. Done.

## Step 8 — Wrap up

Concise summary:

- Which of the four built and which are on PATH.
- Any remaining manual step (typical: SSO authorize if skipped, or template TODO left unfilled).
- Pointers: `docs/auth-setup.md` for re-reference, `docs/getting-started.md` for the full sequence, `/papanix-ai-template-init` to revisit template TODOs, `/papanix-ai-home-manager-setup` to add user-scope later.

## Conventions

- **Never** edit `~/.ssh/config`, generate keys, or upload keys without explicit user yes.
- **Never** suggest disabling host key checking (`StrictHostKeyChecking=no`).
- Interactive shell steps (`ssh -T` first time, `ssh-keygen` with passphrase, Determinate installer curl one-liner, macOS `.pkg` GUI, browser SSO) → user runs with `! <command>` so output lands in session, or in their own terminal.
- Non-auth build failure (Go module path, vendor hash) → these are upstream packaging concerns in the main `papanix-ai` flake. Stop, surface the exact error, and tell the user to file an issue against `github.com/fmgordillo-dyna/papanix-ai`. Do not guess fixes from this side.
