# Install Nix

Nix is a package manager that installs tools in isolation — no conflicts with Homebrew, apt, or anything else already on your machine. Once installed, you won't need to manage it day-to-day.

> **Learn more:** [zero-to-nix.com/concepts/nix-installer](https://zero-to-nix.com/concepts/nix-installer)

Works on macOS, Linux, and Windows Subsystem for Linux (WSL).

> **For agents:** run `/papanix-ai-setup` for a guided walkthrough of the
> steps below, including platform detection and credential setup.

## macOS

First check your macOS version:

```bash
sw_vers -productVersion
```

### macOS 26 (Tahoe) and later

The Determinate Systems `.pkg` installer fails on macOS 26 with a scripts error, and the default GID (350) is reserved by the system daemon `_avectodaemon`. Use the official NixOS installer instead — it runs interactively and handles the volume setup correctly:

```bash
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)
```

This downloads and runs the Nix installer interactively. It creates a dedicated APFS volume for Nix and patches your shell config so the `nix` command is available in new terminals. Follow the prompts and enter your admin password when asked. After it finishes, open a new shell.

Flakes are NOT enabled by default with the official installer. Add to `~/.config/nix/nix.conf` (create if missing):

```
experimental-features = nix-command flakes
```

This enables the modern `nix` CLI and Flakes — the format papanix-ai uses to define and pin packages.

**Alternative for macOS 26 — Determinate installer with custom GIDs:**

If you prefer Determinate Nix (flakes pre-enabled, cleaner uninstall), use the shell script with a GID range that avoids the system conflict:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix -o /tmp/detsys-install.sh
sudo sh /tmp/detsys-install.sh install --no-confirm \
  --nix-build-group-id 30000 \
  --nix-build-user-id-base 30001
```

Then source Nix in your current shell (or open a new one):

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

### macOS 15 (Sequoia) and earlier

Determinate Systems `.pkg` is recommended — graphical installer, flakes pre-enabled, clean uninstall:

```
https://install.determinate.systems/determinate-pkg/stable/Universal
```

Or fetch and open from a terminal:

```bash
curl -L -o /tmp/determinate.pkg https://install.determinate.systems/determinate-pkg/stable/Universal
open /tmp/determinate.pkg
```

## Linux / WSL

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

This downloads and runs the Determinate Systems Nix installer. It sets up a background daemon, creates a Nix store, and patches your shell config so `nix` is available in new terminals. Flakes are pre-enabled. Clean uninstall via `/nix/nix-installer uninstall`.

WSL note: on stock distros without `systemd`, recent WSL2 (`wsl --version` ≥ 2) supports systemd via `/etc/wsl.conf`; the installer detects what is available.

## Verify

```bash
nix --version
nix flake show github:fmgordillo-dyna/papanix-ai
```

Output should list `acli-pii`, `aimgr`, `bbctl`, `dtctl`, `junoctl`.

## Troubleshooting

### `.pkg` installer fails on macOS 26 with "scripts" error

**Cause:** The Determinate Systems `.pkg` does not support macOS 26 (Tahoe) yet.

**Fix:** Use the official installer or the Determinate shell script with custom GIDs as shown in the macOS 26 section above.

### GID 350 conflict — `_avectodaemon` (macOS 26)

**Error:**

```
GID already exists
```

**Cause:** macOS 26 reserves GID 350 for the system daemon `_avectodaemon`. Both the Determinate `.pkg` and the official NixOS installer default to GID 350 for the `nixbld` group.

**Fix:** Use the Determinate shell script with `--nix-build-group-id 30000 --nix-build-user-id-base 30001` (see macOS 26 section), or use the official NixOS installer which avoids the conflict.

Confirm which process owns GID 350:

```bash
dscl . -list /Groups PrimaryGroupID | awk '$2 == "350"'
```

### Leftover APFS "Nix Store" volume from a failed install

**Error:**

```
The keychain lacks a password for the already existing "Nix Store" volume
```

**Cause:** A previous failed install created the encrypted APFS volume but did not complete, leaving it in an unusable state.

**Fix:**

```bash
sudo launchctl bootout system/org.nixos.darwin-store 2>/dev/null
sudo launchctl bootout system/org.nixos.nix-daemon 2>/dev/null
sudo diskutil apfs deleteVolume "Nix Store"
```

Then re-run the installer.

### Leftover `nixbld` group or users from a failed install

**Error:**

```
Group `nixbld` existed but had a different gid than planned
```

or

```
Create called on existing record
```

**Cause:** A prior (possibly partial) install left `nixbld` group and/or `_nixbld*` users behind.

**Fix:**

1. Check what exists:
   ```bash
   dscl . -list /Groups | grep nix
   dscl . -list /Users  | grep nix
   ```
2. Delete any remaining entries:
   ```bash
   sudo dscl . -delete /Groups/nixbld
   # repeat for each _nixbld* user shown above, e.g.:
   sudo dscl . -delete /Users/_nixbld1
   ```
3. Re-run the installer.

Reference: https://github.com/DeterminateSystems/nix-installer/issues/1382

## Next

Configure auth before initializing a template: [auth-setup.md](auth-setup.md).

Or invoke the guided setup skill: `/papanix-ai-setup` (walks through Nix install, SSH keys, GitHub SSO, and verifies the CLI set builds).
