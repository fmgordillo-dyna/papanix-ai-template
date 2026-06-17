# Getting started

End-to-end first-time install for someone who has never used papanix-ai
on this machine. If your agent is doing this for you, ask it to run
`/papanix-ai-setup` (Nix + credentials + project template) or
`/papanix-ai-home-manager-setup` (user-scope across every repo).

> Note: this repo does not install Claude plugin marketplaces
> declaratively. The templates here focus on CLIs, sandboxing, MCP, and
> optional Home-Manager / dev-environment wiring. The `home-manager`
> template can install agent skills at `~/.agents/skills/` via
> `programs.papanix-ai.skills.enable`.

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

Pick one of:

| Template | When to pick it |
|---|---|
| `default` | A team project. Wires CLIs + sandboxed `claude` + the default MCP server set into the repo via `nix develop`. MCP config is cleaned up on exit. |
| `minimal` | Just the CLIs + sandboxed `claude`. Nothing ephemeral, nothing wiped. |
| `mcp-custom` | CLIs + sandboxed `claude` + extra MCP servers on top of `lib.mcp.defaultServers`. |
| `dev-env` | CLIs + sandboxed `claude` + opt-in Node.js / Playwright via `lib.devEnv.mk`. |
| `home-manager` | **User-scope** install. Lives in `$HOME` and follows you across every repo, including sandboxed `claude`. See [home-manager.md](home-manager.md). |

## 4. Initialize the template

In a fresh project directory:

```bash
nix flake init -t github:fmgordillo-dyna/papanix-ai-template
# or pick a specific template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#minimal
```

For `home-manager`, initialize in `~/.config/home-manager` instead of
your project directory — see [home-manager.md](home-manager.md).

## 5. Review the generated markers

The generated files carry inline comments:

- **Project templates** (`default`, `minimal`, `mcp-custom`, `dev-env`)
  mainly use `# NOTE:` markers for safe customization.
- **`home-manager`** also includes `# TODO:` markers for required,
  machine-specific values.

Common edits:

- **CLI selection** — project templates define a `cliPackages` list
  with the full PAPA CLI bundle (`acli-pii`, `aimgr`, `bbctl`, `dtctl`,
  `junoctl`). Drop entries if you want a subset. Dropping `acli-pii`
  lets you use pure builds.
- **Sandboxed `claude`** — project templates include a local
  `papanix-ai.lib.sandboxing.mkClaudeSandbox { ... }` block; tweak
  `extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`,
  `extraRoFiles`, `extraEnv`, `restrictNetwork`, `allowedDomains`, and
  `exposeSsh` there. The `home-manager` template instead uses
  `programs.papanix-ai.sandboxing.*`, with safe defaults already
  including the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`,
  `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`.
- **MCP servers** (`default`, `mcp-custom`) — `default` opts into
  `lib.mcp.defaultServers`; `mcp-custom` shows how to extend that set
  with your own `{ type; command; args; env; }` entries.
- **Dev environment** (`dev-env`, optional in `default` / `home-manager`)
  — toggle `nodejs`, `playwright`, and `extraPackages` in the
  `lib.devEnv.mk` call.
- **Home-Manager identity** (`home-manager`) — set `hmSystem`, rename
  the `homeConfigurations."me"` key, and fill in `home.username` /
  `home.homeDirectory`.

> **For agents:** invoke `/papanix-ai-template-init` for project-scope
> templates or `/papanix-ai-home-manager-setup` for user scope.

## 6. Enter the shell (or switch Home-Manager)

Project templates:

```bash
nix develop --impure
```

`--impure` is required while `acli-pii` is included (it fetches over SSH
at eval time). Drop the flag if you removed `acli-pii` from your CLI
selection.

Home-Manager:

```bash
nix run home-manager/master -- switch --flake .#me --impure
```

## 7. Smoke test

Project templates:

```bash
bbctl --version
aimgr --version
dtctl --version
acli-pii --version
junoctl --version
claude --version
```

Use the subset that matches your chosen package selection.

For `default` and `mcp-custom`, you can also confirm MCP config was
materialized inside the shell:

```bash
test -f .mcp.json && echo ".mcp.json: ok"
test -f opencode.jsonc && echo "opencode.jsonc: ok"
```

Home-Manager:

```bash
which bbctl aimgr dtctl acli-pii junoctl claude
```

## 8. Day-to-day

- `nix develop --impure` — enter a project devShell.
- `direnv allow` — if you want auto-activation on `cd` into the
  project. Commit a `.envrc` containing `use flake --impure` and you're
  done.
- `nix flake update` — bump the pinned `papanix-ai` revision.
- `cd ~/.config/home-manager && home-manager switch --flake .#<name> --impure`
  — re-apply your user-scope config after editing it.

## Troubleshooting

- `404` on a private repo → PAT not SSO-authorized. See
  [auth-setup.md](auth-setup.md) step 2.
- `Permission denied (publickey)` → SSH key not loaded
  (`ssh-add ~/.ssh/id_ed25519`) or not registered with Bitbucket.
- `cannot run ssh: No such file or directory` → forgot `--impure`.
- MCP servers missing in `default` / `mcp-custom` → set
  `PAPANIX_DEBUG=1` before `nix develop --impure` to print the generated
  config paths and server list.

Anything more involved is in the per-topic doc:

- Nix install edge cases: [install-nix.md](install-nix.md)
- Credentials: [auth-setup.md](auth-setup.md)
- User-scope install: [home-manager.md](home-manager.md)
