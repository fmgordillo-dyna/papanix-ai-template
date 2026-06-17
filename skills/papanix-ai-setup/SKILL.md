---
name: papanix-ai-setup
description: Walk a first-time user through papanix-ai onboarding end to end — install Nix (Determinate Systems on macOS / Linux / WSL, with alternatives), set up SSH credentials for the private packages, initialize a project or Home-Manager template, and verify the CLIs build. Trigger when the user says "getting started", "first setup", "set up credentials", "onboard", "help me get started", "install papanix-ai", or invokes /papanix-ai-setup.
---

# papanix-ai-setup

First-time onboarding for papanix-ai. Source of truth:

- `docs/install-nix.md` — Nix install commands. macOS 26+ (Tahoe) requires the official NixOS installer or the Determinate shell script with custom GIDs (GID 350 is taken by `_avectodaemon`); macOS ≤15 uses the Determinate `.pkg`; Linux + WSL use the Determinate curl one-liner.
- `docs/auth-setup.md` — SSH credentials for private packages.
- `docs/getting-started.md` — end-to-end install sequence including template init.

This skill is the **interactive guide**. Diagnose, fix, verify. Quote
commands and outputs; do not duplicate doc prose.

Two private packages need credentials:

- `acli-pii` → Bitbucket (`bitbucket.lab.dynatrace.org`) — SSH key, `builtins.fetchGit`, **`--impure` required**
- `junoctl` / `bbctl` → GitHub `Dynatrace-Internal/*` — GitHub PAT in `~/.config/nix/nix.conf`, `fetchFromGitHub` / `builtins.fetchTree`, **no `--impure`**

`dtctl` is public and needs no auth.

If the user wants a **user-scope install** (Home-Manager, follows them
across every repo) hand off to `/papanix-ai-home-manager-setup` after
Step 5 — the credential / Nix steps below are still prerequisites.

> Note: this repo's templates focus on CLIs, sandboxing, MCP, and
> optional dev tooling. They no longer install agent skills or Claude
> plugin marketplaces declaratively.

## Step 0 — Greet + confirm scope

Tell the user: skill installs Nix if missing, then SSH credentials,
then runs real builds, then initializes a template into their project.
Estimate 5–15 minutes depending on starting state.

Ask:

1. Platform — `uname -s` (`Darwin` / `Linux`) plus check `/proc/version`
   or env `WSL_DISTRO_NAME` to detect WSL. For macOS also run
   `sw_vers -productVersion` to detect macOS 26+ (Tahoe).
2. Already have an SSH key registered with GitHub + Bitbucket, or
   starting blank?
3. Scope — **project** (via `nix develop`) or **user** (via
   Home-Manager)? If user, finish credential steps then hand off to
   `/papanix-ai-home-manager-setup`.

## Step 1 — Nix installed

```bash
nix --version
command -v nix
```

Nix present → skip to Step 2.

Missing → pick path by platform:

**macOS 26 (Tahoe) and later** — the `.pkg` installer fails with a
scripts error, and GID 350 is reserved by `_avectodaemon`. Use the
official NixOS installer:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

Flakes are **not** enabled by default. After install, create/edit
`~/.config/nix/nix.conf`:

```text
experimental-features = nix-command flakes
```

Then open a new shell.

Alternative for macOS 26 if the user prefers Determinate Nix:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix -o /tmp/detsys-install.sh
sudo sh /tmp/detsys-install.sh install --no-confirm \
  --nix-build-group-id 30000 \
  --nix-build-user-id-base 30001
```

After install:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

**macOS 15 (Sequoia) and earlier** — Determinate `.pkg`:

```bash
curl -L -o /tmp/determinate.pkg https://install.determinate.systems/determinate-pkg/stable/Universal
open /tmp/determinate.pkg
```

**Linux / WSL** — Determinate curl one-liner:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Verify:

```bash
nix --version
nix flake show github:fmgordillo-dyna/papanix-ai
```

If flakes are disabled, fix `nix.conf` before continuing.

## Step 2 — SSH key exists

```bash
ls -1 ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub 2>/dev/null
ls -1 ~/.ssh/id_rsa ~/.ssh/id_rsa.pub 2>/dev/null
```

Pair found → use it.

None → ask before generating:

> No SSH key found. Generate `~/.ssh/id_ed25519` now?

On yes:

```bash
ssh-keygen -t ed25519 -C "facundo.gordillo@dynatrace.com" -f ~/.ssh/id_ed25519 -N ""
```

Use the user's email if known; if they want a passphrase, drop `-N ""`
and have them run it interactively.

Print the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Upload targets:

- GitHub: https://github.com/settings/keys
- Bitbucket: https://bitbucket.lab.dynatrace.org → Personal settings → SSH keys

## Step 3 — Agent has the key

```bash
ssh-add -l
```

- `The agent has no identities.` → `ssh-add ~/.ssh/id_ed25519`
- `Could not open a connection to your authentication agent.` →
  `eval "$(ssh-agent -s)"`, then re-add
- key listed → continue

## Step 4 — GitHub PAT (`bbctl` + `junoctl`)

### 4a. Create PAT

User does this manually:

> https://github.com/settings/tokens → Generate new token (classic) →
> enable `repo` → generate → copy the `ghp_...` value.

### 4b. SSO-authorize the token

User does this manually:

> Configure SSO → Authorize for `Dynatrace-Internal`.

### 4c. Add to Nix config

```bash
mkdir -p ~/.config/nix
echo "access-tokens = github.com=<PASTE_TOKEN_HERE>" >> ~/.config/nix/nix.conf
```

If on Linux with multi-user Nix:

```bash
sudo systemctl restart nix-daemon
```

macOS:

```bash
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

### 4d. Real build

```bash
nix build github:fmgordillo-dyna/papanix-ai#junoctl --no-link
nix build github:fmgordillo-dyna/papanix-ai#bbctl   --no-link
```

Failure map:

- `404 / cannot download source` → PAT not SSO-authorized or wrong scope
- daemon not picking config up → restart it

## Step 5 — Bitbucket SSH (`acli-pii`)

### 5a. Host trust + auth

```bash
ssh -T git@bitbucket.lab.dynatrace.org
```

Expected: Bitbucket welcome line.

### 5b. Real build

```bash
nix build github:fmgordillo-dyna/papanix-ai#acli-pii --impure --no-link
```

Failure map:

- `Permission denied (publickey)` → key not uploaded or not loaded
- `Host key verification failed` → accept fingerprint first
- `cannot run ssh` → missing `--impure`

## Step 6 — Initialize a template

Ask: project-scope or user-scope?

**User-scope** → hand off to `/papanix-ai-home-manager-setup`.

**Project-scope** → ask which template (`default`, `minimal`,
`mcp-custom`, `dev-env`). Then:

```bash
cd /path/to/their/project
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#<template>
```

After init, hand off to `/papanix-ai-template-init` to review the
markers in the generated `flake.nix`.

## Step 7 — Enter the shell + smoke test

```bash
nix develop --impure
```

Inside the shell:

```bash
bbctl --version
aimgr --version
dtctl --version
acli-pii --version
junoctl --version
claude --version
```

Use the subset that matches the chosen package selection.

## Step 8 — Wrap up

Concise summary:

- Which packages built and which are on PATH.
- Any remaining manual step.
- Pointers: `docs/auth-setup.md`, `docs/getting-started.md`,
  `/papanix-ai-template-init`, `/papanix-ai-home-manager-setup`.

## Conventions

- **Never** edit `~/.ssh/config`, generate keys, or upload keys without
  explicit yes.
- **Never** suggest disabling host key checking.
- Interactive shell steps (`ssh -T` first time, `ssh-keygen` with
  passphrase, installers, browser SSO) → user runs them in their own
  terminal or via `!`.
- Non-auth build failure from upstream packaging → stop, surface the
  exact error, and tell the user to file an issue against
  `github.com/fmgordillo-dyna/papanix-ai`.
