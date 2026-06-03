# papanix-ai-template

> **The install path for papanix-ai.** If you want the Dynatrace
> internal CLI toolchain (`acli-pii`, `bbctl`, `dtctl`, `junoctl`),
> the AI-skill catalog, MCP servers, and Claude Code plugin
> marketplaces in your project or in `$HOME`, you are in the right
> repo. The upstream library lives at
> [`fmgordillo-dyna/papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai)
> — you do not need to clone it.

This repo ships **flake templates** for every supported install shape
and **guided agent skills** that walk a first-time user through the
end-to-end setup.

---

## Quick start (humans)

End-to-end walkthrough: **[docs/getting-started.md](docs/getting-started.md)**.

Short version:

```bash
# 1. Install Nix          → docs/install-nix.md
# 2. Set up credentials   → docs/auth-setup.md
# 3. Adopt a template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template
# 4. Fill the # TODO: markers in the generated flake.nix
# 5. Enter the shell:
nix develop --impure
```

For user-scope (every repo, via Home-Manager) see
[docs/home-manager.md](docs/home-manager.md) — or the `home-manager`
template below.

## Quick start (agents)

Three guided skills cover the entire onboarding surface. Drop a SKILL
symlink in your `.claude/skills/` (or use the user-scope install) and
invoke them as slash commands inside Claude Code:

| Skill | When to use |
|---|---|
| [`/papanix-ai-setup`](skills/papanix-ai-setup/SKILL.md) | First-time onboarding: install Nix on macOS / Linux / WSL, set up SSH + GitHub PAT + SSO, verify all four CLIs build, init a template. |
| [`/papanix-ai-template-init`](skills/papanix-ai-template-init/SKILL.md) | User has Nix + credentials but wants to adopt (or re-init) a template into a project. Picks the template, walks every `# TODO:` and `# NOTE:`, smoke-tests the resulting devShell. |
| [`/papanix-ai-home-manager-setup`](skills/papanix-ai-home-manager-setup/SKILL.md) | Install Home-Manager (if missing), init the `home-manager` template, fill TODOs in `flake.nix` + `home.nix`, run the first `home-manager switch`. Result: skills / MCP / Claude settings / CLIs in `$HOME`, available across every repo. |

The skills are designed for an LLM driving a developer's shell — they
ask before destructive operations, never overwrite existing configs
without confirmation, and surface failures verbatim.

---

## Templates

| Template         | Scope        | CLIs on PATH | Skills installed     | MCP wired      | Claude plugins        | Notes                                                  |
| ---------------- | ------------ | ------------ | -------------------- | -------------- | --------------------- | ------------------------------------------------------ |
| `default`        | project      | yes          | configurable         | Dynatrace MCP  | all (papa + rnd)      | Batteries-included starter.                            |
| `minimal`        | project      | yes          | none                 | none           | none                  | CLIs only. Nothing ephemeral, nothing wiped on exit.   |
| `skills-only`    | project      | yes          | curated subset       | none           | none                  | Tailor the skill catalog without MCP or plugins.       |
| `mcp-custom`     | project      | yes          | all                  | default + your | none                  | Extend `lib.mcp.defaultServers` with extra servers.    |
| `plugins-custom` | project      | yes          | all                  | none           | curated pick          | Pre-enable a subset of Claude Code plugins.            |
| `library`        | project      | no           | configurable         | none           | none                  | Pure library consumption. Bring your own packages.     |
| `dev-env`        | project      | yes          | none                 | none           | none                  | Adds opt-in Node.js / npm / Playwright via `lib.devEnv.mk`. |
| `home-manager`   | **user**     | yes (global) | configurable         | configurable   | configurable          | Install globally across every project via Home-Manager. |

## Usage

```sh
# In an empty directory:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template

# Pick a specific template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#minimal
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#skills-only
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#mcp-custom
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#plugins-custom
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#library
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#dev-env
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#home-manager

# Enter the dev shell (project-scope templates):
nix develop --impure

# Apply user-scope template (Home-Manager):
nix run home-manager/master -- switch --flake .#me --impure
```

Every generated `flake.nix` carries `# TODO:` markers (things you must
fill) and `# NOTE:` markers (safe tweaks). `/papanix-ai-template-init`
walks you through every one of them; `docs/getting-started.md` lists
them by hand.

## CLIs (when included)

`acli-pii`, `bbctl`, `dtctl`, `junoctl` — exposed via
`papanix-ai.packages.${system}.default`.

## Skills

List the catalog:

```sh
nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog \
  --apply builtins.attrNames --json
```

Pick them via `lib.skills.mkBundle { enable = [ ... ]; }` or grab everything
with `enableAll = true;`.

## MCP

`lib.mcp.defaultServers` ships the Dynatrace MCP. It requires
`DT_API_TOKEN` and `DT_ENVIRONMENT` in your env. `.mcp.json` is
generated on shell entry and wiped on exit.

## Claude Code plugins

`lib.claudeSettings.defaultMarketplaces` pre-registers the
`papa-ai-knowledgebase` and `rnd-ai-knowledgebase` plugin marketplaces.
On shell entry the template writes `.claude/settings.json` with
`extraKnownMarketplaces` + `enabledPlugins`; Claude Code clones each
marketplace and installs the listed plugins automatically on first
project trust. Plugin enumeration is hermetic (read at eval time from
the vendored marketplace.json), so the enabled set matches your
`flake.lock`. List the plugin set with:

```sh
nix eval github:fmgordillo-dyna/papanix-ai#lib.claudeSettings.defaultMarketplaces \
  --apply 'm: builtins.attrNames m' --json
```

Pick a subset via `lib.claudeSettings.mkShellHook { enable = ["papa/papa-jira" "rnd/dt-github"]; }`,
bulk-enable with `enableAll = true` (or `enableAll = ["rnd"]`), or add
your own marketplace alongside the defaults. Pass `settings = { … }` to
inject custom Claude Code settings (e.g. `permissions`) alongside the
plugin config.

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
  shellHook = devEnv.shellHook;       # Playwright env vars
};
```

`nodejs` ships npm bundled; `withCorepack = true` adds pnpm / yarn
shims. `playwright = true` (or `{ withBrowsers = true; }`) exports
`PLAYWRIGHT_BROWSERS_PATH` so the npm `playwright` package reuses the
Nix-built browser bundle instead of downloading at runtime. Not an
ephemeral feature module — nothing written to or wiped from your
project tree. See the `dev-env` template.

## Caveats

- `.claude/`, `.opencode/`, `.mcp.json`, and `.claude/settings.json` are
  **wiped on shell exit** in any template that runs `mkShellHook`.
  Don't keep hand-edited files there.
- The `minimal` template does not run any shell hook and leaves your
  workspace untouched.

## Home-Manager (user-scope)

The `home-manager` template is the odd one out — it installs papanix-ai
into `$HOME` instead of `$PWD`, so the same skills/MCP/plugins are
available across every repo you open. Apply with
`home-manager switch --flake .#me --impure` (impure required while
`acli-pii` is in the selection). Project devShells from the other
templates still work and layer on top; project scope wins on conflicts.

See [docs/home-manager.md](docs/home-manager.md) for the conflict
matrix, the MCP `activation` vs `snippet` strategies, and caveats
around `~/.claude.json` mutability. Or run
`/papanix-ai-home-manager-setup` for an interactive walkthrough.

## Docs

- [docs/getting-started.md](docs/getting-started.md) — end-to-end install sequence.
- [docs/install-nix.md](docs/install-nix.md) — Install Nix (macOS, Linux, WSL).
- [docs/auth-setup.md](docs/auth-setup.md) — SSH + GitHub token setup.
- [docs/home-manager.md](docs/home-manager.md) — user-scope install via Home-Manager.

## Layout

```
.
├── default/         # project-scope, batteries-included
├── minimal/         # project-scope, CLIs only
├── skills-only/     # project-scope, curated skills, no MCP, no plugins
├── mcp-custom/      # project-scope, all skills + extra MCP servers
├── plugins-custom/  # project-scope, all skills + curated Claude Code plugins
├── library/         # project-scope, library-only, no CLIs
├── dev-env/         # project-scope, CLIs + opt-in per-contributor dev tooling
├── home-manager/    # USER-scope, global install via Home-Manager
├── docs/            # install-nix, auth-setup, getting-started, home-manager
├── skills/          # /papanix-ai-setup, /papanix-ai-template-init, /papanix-ai-home-manager-setup
└── flake.nix        # template registry
```
