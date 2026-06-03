# Getting started

End-to-end first-time install for someone who has never used papanix-ai
on this machine. If your agent is doing this for you, ask it to run
`/papanix-ai-setup` (Nix + credentials + project devShell) or
`/papanix-ai-home-manager-setup` (user-scope across every repo).

## 1. Install Nix

Follow [install-nix.md](install-nix.md). Pick the section that matches
your OS (macOS 26+, macOS ≤15, or Linux/WSL).

Verify:

```bash
nix --version
```

## 2. Set up credentials

Follow [auth-setup.md](auth-setup.md). You need:

- A **GitHub PAT** with `repo` scope, **SSO-authorized** for
  `Dynatrace-Internal`, recorded in `~/.config/nix/nix.conf` — for
  `bbctl` and `junoctl`.
- A loaded **SSH key** registered with `bitbucket.lab.dynatrace.org` —
  for `acli-pii`.

`dtctl` is public and needs no credentials.

## 3. Pick a template

The shape of papanix-ai you want depends on where you want it active.
Pick one of:

| Template         | When to pick it |
|------------------|-----------------|
| `default`        | A team project. Wires CLIs + skills + Dynatrace MCP + Claude plugins into the repo via `nix develop`. Cleaned up on exit. |
| `minimal`        | Just the CLIs. Nothing ephemeral, nothing wiped. |
| `skills-only`    | Curated skill subset. No MCP, no plugins. |
| `mcp-custom`     | All skills + extra MCP servers on top of the default Dynatrace MCP. |
| `plugins-custom` | All skills + curated Claude Code plugin marketplaces. |
| `library`        | Library consumption only. Bring your own packages. |
| `dev-env`        | CLIs + opt-in Node.js / Playwright via `lib.devEnv.mk`. |
| `home-manager`   | **User-scope** install. Lives in `$HOME` and follows you across every repo. See [home-manager.md](home-manager.md). |

## 4. Initialize the template

In a fresh project directory:

```bash
nix flake init -t github:fmgordillo-dyna/papanix-ai-template
# or pick a specific template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#minimal
```

For `home-manager`, initialize in `~/.config/home-manager` instead of
your project directory — see [home-manager.md](home-manager.md).

## 5. Fill in the TODOs

Every template's `flake.nix` (and `home.nix` for `home-manager`) carries
inline `# TODO:` markers for the user-editable knobs and `# NOTE:`
markers for the safe-to-tweak ones.

Common edits:

- **Skills to enable** — either `enableAll = true` or
  `enable = [ "papa/dt-jira" "rnd/dt-github" ]`. List the catalog:
  ```bash
  nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog \
    --apply builtins.attrNames --json
  ```
- **Plugin marketplaces** (`plugins-custom`, `default`) — either
  `enableAll = true` or curate with `enable = [ "papa/papa-jira" "rnd/dt-github" ]`.
- **MCP servers** (`mcp-custom`) — extend `lib.mcp.defaultServers`
  with your own `{ type; command; args; env; }` entries.
- **Dev environment** (`dev-env`) — toggle `nodejs`, `playwright`, and
  `extraPackages` in the `lib.devEnv.mk` call.
- **Home-Manager identity** (`home-manager`) — see
  [home-manager.md → Filling in the TODOs](home-manager.md#filling-in-the-todos).

> **For agents:** invoke `/papanix-ai-template-init` to walk the user
> through these prompts and produce a fully-filled template.

## 6. Enter the dev shell

```bash
nix develop --impure
```

`--impure` is required while `acli-pii` is included (it fetches over SSH
at eval time). Drop the flag if you removed `acli-pii` from your CLI
selection.

On entry the chosen template installs skills, drops MCP config files
(`.mcp.json`, `opencode.jsonc`), and writes a project-scope
`.claude/settings.json`. All of those are **wiped on exit** — the
template is the source of truth, not the generated files.

Smoke test:

```bash
bbctl --version
dtctl --version
acli-pii --version
junoctl --version
```

(Replace with the subset you picked in your CLI selection.)

## 7. Day-to-day

- `nix develop --impure` — enter the shell.
- `direnv allow` — if you want auto-activation on `cd` into the project.
  Commit a `.envrc` containing `use flake --impure` and you're done.
- `nix flake update` — bump the pinned papanix-ai revision.

## Troubleshooting

- `404` on a private repo → PAT not SSO-authorized. See
  [auth-setup.md](auth-setup.md) step 2.
- `Permission denied (publickey)` → SSH key not loaded
  (`ssh-add ~/.ssh/id_ed25519`) or not registered with Bitbucket.
- `cannot run ssh: No such file or directory` → forgot `--impure`.
- MCP servers missing → set `PAPANIX_DEBUG=1` before
  `nix develop --impure` to print the generated config paths and
  server list.

Anything more involved is in the per-topic doc:

- Nix install edge cases: [install-nix.md](install-nix.md)
- Credentials: [auth-setup.md](auth-setup.md)
- User-scope install: [home-manager.md](home-manager.md)
