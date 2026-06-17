# papanix-ai-template

> **The install path for papanix-ai.** If you want the Dynatrace
> internal CLI toolchain (`acli-pii`, `aimgr`, `bbctl`, `dtctl`, `junoctl`),
> the sandboxed `claude` wrapper, optional MCP wiring, and a
> Home-Manager starter, you are in the right repo. The upstream library
> lives at
> [`fmgordillo-dyna/papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai)
> — you do not need to clone it.

This repo ships **flake templates** for the supported install shapes and
**guided onboarding skills** that walk a first-time user through setup.

> Note: this repo no longer installs agent skills or Claude Code plugin
> marketplaces declaratively. The `skills/` directory contains
> onboarding SKILL files for agents; the templates themselves focus on
> CLIs, sandboxing, MCP, and optional user-scope setup.

---

## Quick start (humans)

End-to-end walkthrough: **[docs/getting-started.md](docs/getting-started.md)**.

Short version:

```bash
# 1. Install Nix          → docs/install-nix.md
# 2. Set up credentials   → docs/auth-setup.md
# 3. Adopt a template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template
# 4. Review the generated flake.nix comments (# NOTE:, and # TODO: for home-manager)
# 5. Enter the shell:
nix develop --impure
```

For user-scope setup (every repo, via Home-Manager) see
[docs/home-manager.md](docs/home-manager.md) — or use the
`home-manager` template below.

## Quick start (agents)

Three guided skills cover the onboarding flow. This repo does **not**
install them for you; if you want slash-command access in your agent,
symlink the SKILL files manually into the agent's skill directory.

| Skill | When to use |
|---|---|
| [`/papanix-ai-setup`](skills/papanix-ai-setup/SKILL.md) | First-time onboarding: install Nix on macOS / Linux / WSL, set up SSH + GitHub PAT + SSO, verify the CLIs build, init a template. |
| [`/papanix-ai-template-init`](skills/papanix-ai-template-init/SKILL.md) | User has Nix + credentials and wants to adopt a **project-scope** template. Picks the template, reviews the generated `flake.nix`, and smoke-tests the devShell. |
| [`/papanix-ai-home-manager-setup`](skills/papanix-ai-home-manager-setup/SKILL.md) | Install Home-Manager (if missing), init the `home-manager` template, fill TODOs in `flake.nix` + `home.nix`, and run the first `home-manager switch`. |

The skills are designed for an LLM driving a developer's shell — they
ask before destructive operations, never overwrite existing configs
without confirmation, and surface failures verbatim.

---

## Templates

| Template | Scope | CLIs + sandboxed `claude` on PATH | MCP wired | Notes |
|---|---|---|---|---|
| `default` | project | yes | default set | Batteries-included starter for most repos. |
| `minimal` | project | yes | none | CLIs + sandboxed `claude` only. Nothing ephemeral. |
| `mcp-custom` | project | yes | default + your own | Extend `lib.mcp.defaultServers` with extra servers. |
| `dev-env` | project | yes | none | Adds opt-in Node.js / npm / Playwright via `lib.devEnv.mk`. |
| `home-manager` | **user** | yes (global) | none | CLIs + sandboxed `claude` in `$HOME`. MCP stays project-scope. |

## Usage

```sh
# In an empty directory:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template

# Pick a specific template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#minimal
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#mcp-custom
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#dev-env
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#home-manager

# Enter the dev shell (project-scope templates):
nix develop --impure

# Apply user-scope template (Home-Manager):
nix run home-manager/master -- switch --flake .#me --impure
```

Project templates primarily carry `# NOTE:` markers for safe tweaks.
The `home-manager` template also carries `# TODO:` markers for required
identity / machine-specific edits. `/papanix-ai-template-init` and
`/papanix-ai-home-manager-setup` walk you through them.

## CLIs (when included)

`acli-pii`, `aimgr`, `bbctl`, `dtctl`, `junoctl` — available from
`papanix-ai.packages.${system}`. The project templates define an
explicit `cliPackages` list so you can keep the full bundle or trim it
down per repo.

Project templates in this repo also add a sandboxed `claude` binary on
PATH. They build that wrapper via
`papanix-ai.lib.sandboxing.mkClaudeSandbox`, which brings in the chosen
CLI set plus safe defaults for common helpers, state dirs, and auth env
vars. The `home-manager` template uses `programs.papanix-ai.sandboxing.*`
instead.

If Claude needs SSH remotes from inside the sandbox, enable
`exposeSsh = true;`. If you want to expose a custom package attrset on
PATH inside Claude, flatten it first with `builtins.attrValues myPkgs`.

## MCP

`lib.mcp.defaultServers` is a convenience set containing the
`dynatrace-mcp` and `juno-mcp` servers. Dynatrace requires
`DT_API_TOKEN` and `DT_ENVIRONMENT`; Juno needs no extra env vars.

Upstream `papanix-ai` also exposes:

- `lib.mcp.mkConfig` → build a `.mcp.json`
- `lib.mcp.mkOpencodeConfig` → build an `opencode.jsonc`
- `packages.${system}.{mcp-config,opencode-config}`
- `apps.${system}.mcp-install` → install both files non-ephemerally in `$PWD`

This template repo uses `lib.mcp.mkShellHook` for the default workflow:
`default` and `mcp-custom` write `.mcp.json` and `opencode.jsonc` on
shell entry and wipe them on exit. The `home-manager` template does not
configure MCP — manage it per-project in the devShell.

## Per-contributor dev environment (Node.js, Playwright, …)

Opt in via:

```nix
devEnv = papanix-ai.lib.devEnv.mk {
  inherit pkgs;
  nodejs     = { version = "nodejs_22"; withCorepack = true; };
  playwright = true;                # browsers + env vars wired
  # extraPackages = [ pkgs.nodePackages.typescript ];
};

devShells.default = pkgs.mkShellNoCC {
  packages  = [ papanix-ai.packages.${system}.default ] ++ devEnv.packages;
  shellHook = devEnv.shellHook;     # Playwright env vars
};
```

`nodejs` ships npm bundled; `withCorepack = true` adds pnpm / yarn
shims. `playwright = true` (or `{ withBrowsers = true; }`) exports
`PLAYWRIGHT_BROWSERS_PATH` so the npm `playwright` package reuses the
Nix-built browser bundle instead of downloading at runtime. See the
`dev-env` template.

## Sandbox configuration

Each project-scoped sandbox-enabled template includes a
`sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox { ... };`
block. The `home-manager` template instead uses
`programs.papanix-ai.sandboxing`. Common tweaks:

- add tools to `extraAllowedPackages` if Claude needs them on PATH
- add persistent paths with `extraRwDirs` / `extraRwFiles`
- bind read-only config with `extraRoDirs` / `extraRoFiles`
- tighten egress with `restrictNetwork = true;` plus `allowedDomains = { ... };`
- pass through extra env vars with `extraEnv`
- enable `exposeSsh = true;` if Claude needs SSH remotes

Example:

```nix
sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox {
  inherit pkgs cliPackages;
  claudePkg = pkgs.claude-code;
  extraAllowedPackages = with pkgs; [ gh ];
  extraRwDirs = [ "$HOME/.config/gh" ];
  exposeSsh = true;
};
```

`allowedDomains` is ignored unless `restrictNetwork = true;`.

## Caveats

- `.mcp.json` and `opencode.jsonc` are **wiped on shell exit** in any
  template that runs `lib.mcp.mkShellHook` (`default`, `mcp-custom`).
  Don't keep hand-edited files there.
- The `minimal` and `dev-env` templates do not run an ephemeral shell
  hook and leave your workspace untouched.
- `acli-pii` requires `--impure` because it is fetched over SSH at eval
  time. Drop it from the selected CLI set if you want a pure build.

## Home-Manager (user-scope)

The `home-manager` template installs into `$HOME` instead of `$PWD`:

- **PAPA CLIs** — available globally.
- **Sandboxed `claude`** — available globally via
  `programs.papanix-ai.sandboxing.enable = true;`.
- **Optional user-scope dev tooling** — uncomment `devEnv` in
  `home.nix` if you want Node.js / Playwright outside a project shell.
- **MCP stays in the devShell** — project templates handle it
  ephemerally.

Apply with `home-manager switch --flake .#me --impure` (impure required
while `acli-pii` is in the selection). Project devShells still work and
layer on top; project scope wins on conflicts.

See [docs/home-manager.md](docs/home-manager.md) for the full option
matrix and caveats. Or run `/papanix-ai-home-manager-setup` for an
interactive walkthrough.

## Docs

- [docs/getting-started.md](docs/getting-started.md) — end-to-end install sequence.
- [docs/install-nix.md](docs/install-nix.md) — install Nix (macOS, Linux, WSL).
- [docs/auth-setup.md](docs/auth-setup.md) — SSH + GitHub token setup.
- [docs/home-manager.md](docs/home-manager.md) — user-scope install via Home-Manager.

## Layout

```text
.
├── default/         # project-scope, CLIs + sandboxed `claude` + default MCP
├── minimal/         # project-scope, CLIs + sandboxed `claude` only
├── mcp-custom/      # project-scope, extend the default MCP server set
├── dev-env/         # project-scope, CLIs + opt-in per-contributor dev tooling
├── home-manager/    # user-scope, global install via Home-Manager
├── docs/            # install-nix, auth-setup, getting-started, home-manager
├── skills/          # onboarding slash-command docs for agents
└── flake.nix        # template registry
```
