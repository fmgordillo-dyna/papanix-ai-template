# Auth setup

Three of the five PAPA CLIs need credentials before they can build:

| Package    | Source                                   | Credential                  |
|------------|------------------------------------------|-----------------------------|
| `acli-pii` | Bitbucket SSH                            | SSH key                     |
| `bbctl`    | private GitHub repo (Dynatrace-Internal) | GitHub PAT in `nix.conf`    |
| `junoctl`  | private GitHub repo (Dynatrace-Internal) | GitHub PAT in `nix.conf`    |

`aimgr` and `dtctl` are public and need no auth.

`acli-pii` fetches its source at build time using your SSH credentials — Nix needs `--impure` to reach your SSH agent. `bbctl` and `junoctl` fetch from GitHub via `builtins.fetchTree` and use a PAT stored in your Nix config; no `--impure` required.

> **For agents:** run `/papanix-ai-setup` for an interactive walkthrough of
> the steps below — including SSH key generation, GitHub SSO authorization,
> and a real build smoke test.

## GitHub PAT (for `bbctl` and `junoctl`)

1. Create a classic PAT at https://github.com/settings/tokens with the **`repo`** scope.

2. SSO-authorize the token for the `Dynatrace-Internal` org. On the tokens page, click **Configure SSO → Authorize** next to your new token. Without this the download returns 404.

3. Add the token to your user Nix config:

```bash
mkdir -p ~/.config/nix
echo "access-tokens = github.com=<YOUR_PAT>" >> ~/.config/nix/nix.conf
```

4. Test:

```bash
nix build github:fmgordillo-dyna/papanix-ai#bbctl github:fmgordillo-dyna/papanix-ai#junoctl
```

Common errors:

- `404 / cannot download source` → PAT not SSO-authorized, or wrong scope. Re-check step 2.
- `access-tokens not picked up` → restart the Nix daemon: `sudo systemctl restart nix-daemon` (Linux) or `sudo launchctl kickstart -k system/org.nixos.nix-daemon` (macOS).

## Bitbucket SSH (for `acli-pii`)

1. Make sure you have an SSH key registered with Bitbucket:

```bash
ls ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

(Or another key — the agent picks any loaded key.)

2. Load the key into your agent:

```bash
ssh-add ~/.ssh/id_ed25519
```

3. Trust the host (first time only):

```bash
ssh -T git@bitbucket.lab.dynatrace.org
```

Accept the host key when prompted. Expected output is a Bitbucket welcome line.

4. Test:

```bash
nix build github:fmgordillo-dyna/papanix-ai#acli-pii --impure
```

Common errors:

- `Permission denied (publickey)` → SSH key not loaded. Run `ssh-add ~/.ssh/id_ed25519`.
- `Host key verification failed` → run the `ssh -T` step above and accept the host key.
- `error: cannot run ssh: No such file or directory` → you forgot `--impure`, so Nix fell back to the sandboxed `fetchgit` path. Re-run with `--impure`.
- `error: getting status of '/nix/store/...-source': No such file or directory` → eval-time fetch was interrupted; just retry.

## Verifying everything works

```bash
nix build github:fmgordillo-dyna/papanix-ai#aimgr \
          github:fmgordillo-dyna/papanix-ai#bbctl \
          github:fmgordillo-dyna/papanix-ai#dtctl \
          github:fmgordillo-dyna/papanix-ai#junoctl  # no --impure needed
nix build github:fmgordillo-dyna/papanix-ai#acli-pii --impure  # needs SSH credentials
```

All five should produce `result*` symlinks with no errors if you build them, or at least the subset you plan to use.

## Next

Initialize a template into your project:

```bash
nix flake init -t github:fmgordillo-dyna/papanix-ai-template
nix develop --impure
```

See the [template README](../README.md) for the full list of templates and
the generated `# NOTE:` / `# TODO:` markers you may need to review.
