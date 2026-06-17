---
name: papanix-ai-home-manager-setup
description: Install Home-Manager (if missing) and adopt the papanix-ai `home-manager` template so PAPA CLIs and a sandboxed `claude` wrapper are available across every repo. Walks through Home-Manager install, `nix flake init`, filling the TODO markers in `flake.nix` + `home.nix` (system, profile name, CLIs, sandbox config, optional dev tooling), and the first `home-manager switch`. Trigger when the user says "install home-manager", "user-scope install", "global papanix-ai", "across every repo", "home-manager setup", or invokes /papanix-ai-home-manager-setup.
---

# papanix-ai-home-manager-setup

End-to-end Home-Manager onboarding for papanix-ai. Source of truth:

- `docs/home-manager.md` — full user-scope reference.
- `home-manager/flake.nix` + `home-manager/home.nix` — the file shapes you'll generate and fill in.

This skill is the **interactive guide**. Diagnose, run, verify, fill
TODOs. Do not duplicate doc prose.

> Note: this template intentionally does not install agent skills,
> Claude plugin marketplaces, or MCP declaratively. It is for global
> CLIs, sandboxed `claude`, and optional user-scope dev tooling.

## Step 0 — Prerequisites

Confirm:

1. Nix is installed with flakes enabled.
   ```bash
   nix --version
   nix flake show github:fmgordillo-dyna/papanix-ai 2>&1 | head -5
   ```
   If `nix` is missing OR flakes are disabled, hand off to
   `/papanix-ai-setup` Step 1 and resume here when done.

2. GitHub PAT + Bitbucket SSH are set up **if** the user wants private
   CLIs (`acli-pii`, `bbctl`, `junoctl`). Check:
   ```bash
   grep -q "access-tokens = github.com=" ~/.config/nix/nix.conf 2>/dev/null && echo "PAT: configured" || echo "PAT: MISSING"
   ssh-add -l 2>/dev/null | grep -q . && echo "SSH agent: has key" || echo "SSH agent: empty"
   ```
   If either is missing and they want those CLIs, send them to
   `/papanix-ai-setup` first.

3. Ask which CLIs the user wants on PATH globally, whether they want the
   sandboxed `claude` wrapper, and whether they also want optional
   user-scope Node.js / Playwright tooling.

## Step 1 — Install Home-Manager

```bash
command -v home-manager
```

Found → skip to Step 2.

Missing → install the standalone flake-based variant:

```bash
nix run home-manager/master -- --version
```

If that errors out, surface the error verbatim.

## Step 2 — Prepare `~/.config/home-manager`

```bash
ls -la ~/.config/home-manager 2>/dev/null
```

Empty / non-existent → create it:

```bash
mkdir -p ~/.config/home-manager
```

Existing `flake.nix` / `home.nix` → **ASK** before clobbering. If they
want to keep an existing Home-Manager config, they need to merge the
papanix-ai module by hand using `docs/home-manager.md`.

## Step 3 — Initialize the template

```bash
cd ~/.config/home-manager
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#home-manager
```

This creates `flake.nix` and `home.nix`.

## Step 4 — Fill `flake.nix` TODOs

Read the file and identify these markers:

| Marker | Action |
|---|---|
| `hmSystem` | Set it to the system the user actually runs `home-manager switch` on. |
| `homeConfigurations."me"` | Rename `"me"` to the profile name the user wants to use with `--flake .#<name>`. |

Do not touch `# NOTE:` markers unless the user asks.

## Step 5 — Fill `home.nix` TODOs

Read the file and walk these prompts:

1. **`home.username`**
   ```bash
   whoami
   ```
   Use the printed value unless the user says otherwise.

2. **`home.homeDirectory`**
   ```bash
   echo "$HOME"
   ```
   Use the printed value.

3. **`home.stateVersion`** — leave as-is on a first install.

4. **`programs.papanix-ai.cliTools.selection`**
   - Template default (all five) → requires `--impure` for the switch.
   - Pure build → set `selection = [ "aimgr" "bbctl" "dtctl" "junoctl" ];`.
   - Curate further if the user wants only a subset.

5. **`programs.papanix-ai.sandboxing`**
   Explain that `enable = true;` already gives a safe default wrapper
   with the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`,
   `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`.
   Ask whether they want to extend it with:
   - `extraAllowedPackages`
   - `extraRwDirs` / `extraRoDirs`
   - `extraRwFiles` / `extraRoFiles`
   - `extraEnv`
   - `restrictNetwork` + `allowedDomains`
   - `exposeSsh`

6. **`programs.papanix-ai.devEnv` (optional)**
   Ask whether they want Node.js / Playwright / extra packages at user
   scope too. If yes, uncomment and fill the block.

Apply edits via `Edit`. After each edit, show the updated section.

## Step 6 — Switch

```bash
cd ~/.config/home-manager
nix run home-manager/master -- switch --flake .#<name> --impure
```

Use the name from Step 4. Drop `--impure` only if they removed
`acli-pii` from the selection.

This will:

- install the selected PAPA CLIs into the user profile,
- install the sandboxed `claude` wrapper if enabled,
- install optional devEnv packages / env vars if enabled.

Failure map:

- `error: SSO not authorized` / `404` on private packages → credentials.
  Send to `/papanix-ai-setup` Step 4–5.
- `attribute 'me' missing` → mismatch between
  `homeConfigurations."<name>"` and the `--flake .#<name>` argument.
- file conflict errors → another Home-Manager-managed file already owns
  the path. Read the error verbatim, ask the user.

## Step 7 — Verify

```bash
which bbctl aimgr dtctl acli-pii junoctl claude 2>/dev/null
```

If they enabled user-scope devEnv, also verify the expected tools, e.g.:

```bash
node --version
corepack --version 2>/dev/null || true
```

Anything missing → cross-reference `docs/home-manager.md`.

## Step 8 — Wrap up

Concise summary:

- Which CLIs landed globally.
- Whether sandboxed `claude` is enabled.
- Whether optional user-scope dev tooling was enabled.
- That project devShells still layer on top and win on conflicts.
- Day-2 command:
  ```bash
  cd ~/.config/home-manager && home-manager switch --flake .#<name> --impure
  ```
- `nix flake update papanix-ai` to pull in upstream changes.

## Conventions

- **Never** rewrite an existing `~/.config/home-manager/` setup without
  explicit yes.
- **Never** remove `--impure` unless `acli-pii` is no longer selected.
- If a step needs the user's own terminal (browser auth, `sudo`, etc.),
  tell them to run it with `!` so output lands in the session.
- Non-auth build failures from upstream `papanix-ai` → surface the exact
  error and tell the user to file an issue there.
