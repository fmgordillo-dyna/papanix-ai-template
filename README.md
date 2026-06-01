# papanix-ai-template

Flake templates for bootstrapping projects that consume
[`papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai) —
the Nix-packaged PAPA CLI + AI skill catalog + MCP wiring.

papanix-ai is a Nix Flake that pins, delivers the Dynatrace internal CLI
toolchain (`acli-pii`, `aimgr`, `dtctl`, `junoctl`), installs SKILLs
for Claude and Opencode, wires up MCP (Model Context Protocol) servers,
and pre-registers Claude Code plugin marketplaces — to any macOS or
Linux machine, reproducibly, from a single source of truth.

Each template is a self-contained `flake.nix` you can drop into a new
repo via `nix flake init -t`.

## Templates

| Template         | CLIs on PATH | Skills installed     | MCP wired      | Claude plugins        | Notes                                                  |
| ---------------- | ------------ | -------------------- | -------------- | --------------------- | ------------------------------------------------------ |
| `default`        | yes          | configurable         | Dynatrace MCP  | all (papa + rnd)      | Batteries-included starter.                            |
| `minimal`        | yes          | none                 | none           | none                  | CLIs only. Nothing ephemeral, nothing wiped on exit.   |
| `skills-only`    | yes          | curated subset       | none           | none                  | Tailor the skill catalog without MCP or plugins.       |
| `mcp-custom`     | yes          | all                  | default + your | none                  | Extend `lib.mcp.defaultServers` with extra servers.    |
| `plugins-custom` | yes          | all                  | none           | curated pick          | Pre-enable a subset of Claude Code plugins.            |
| `library`        | no           | configurable         | none           | none                  | Pure library consumption. Bring your own packages.     |

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

# Enter the dev shell:
nix develop
```

## CLIs (when included)

`acli-pii`, `aimgr`, `dtctl`, `junoctl` — exposed via
`papanix-ai.packages.${system}.default`.

## Skills

Listed catalog IDs available with:

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

`lib.plugins.defaultMarketplaces` pre-registers the
`papa-ai-knowledgebase` and `rnd-ai-knowledgebase` plugin marketplaces.
On shell entry the template writes `.claude/settings.json` with
`extraKnownMarketplaces` + `enabledPlugins`; Claude Code clones each
marketplace and installs the listed plugins automatically on first
project trust. Plugin enumeration is hermetic (read at eval time from
the vendored marketplace.json), so the enabled set matches your
`flake.lock`. List the plugin set with:

```sh
nix eval github:fmgordillo-dyna/papanix-ai#lib.plugins.defaultMarketplaces \
  --apply 'm: builtins.attrNames m' --json
```

Pick a subset via `lib.plugins.mkShellHook { enable = ["papa/papa-jira" "rnd/dt-github"]; }`,
bulk-enable with `enableAll = true` (or `enableAll = ["rnd"]`), or add
your own marketplace alongside the defaults.

## Caveats

- `.claude/`, `.opencode/`, `.mcp.json`, and `.claude/settings.json` are
  **wiped on shell exit** in any template that runs `mkShellHook`.
  Don't keep hand-edited files there. See
  `papanix-ai/docs/how-skill-install-works.md`.
- The `minimal` template does not run any shell hook and leaves your
  workspace untouched.

## Layout

```
.
├── default/         # batteries-included
├── minimal/         # CLIs only
├── skills-only/     # curated skills, no MCP, no plugins
├── mcp-custom/      # all skills + extra MCP servers
├── plugins-custom/  # all skills + curated Claude Code plugins
├── library/         # library-only, no CLIs
└── flake.nix        # template registry
```
