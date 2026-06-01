# papanix-ai-template

Flake templates for bootstrapping projects that consume
[`papanix-ai`](https://github.com/fmgordillo-dyna/papanix-ai) —
the Nix-packaged PAPA CLI + AI skill catalog + MCP wiring.

Each template is a self-contained `flake.nix` you can drop into a new
repo via `nix flake init -t`.

## Templates

| Template      | CLIs on PATH | Skills installed     | MCP wired      | Notes                                                  |
| ------------- | ------------ | -------------------- | -------------- | ------------------------------------------------------ |
| `default`     | yes          | configurable         | Dynatrace MCP  | Batteries-included starter.                            |
| `minimal`     | yes          | none                 | none           | CLIs only. Nothing ephemeral, nothing wiped on exit.   |
| `skills-only` | yes          | curated subset       | none           | Tailor the skill catalog without MCP.                  |
| `mcp-custom`  | yes          | all                  | default + your | Extend `lib.mcp.defaultServers` with extra servers.    |
| `library`     | no           | configurable         | none           | Pure library consumption. Bring your own packages.     |

## Usage

```sh
# In an empty directory:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template

# Pick a specific template:
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#minimal
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#skills-only
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#mcp-custom
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
nix eval github:fmgordillo-dyna/papanix-ai#lib.catalog \
  --apply builtins.attrNames --json
```

Pick them via `lib.mkBundle { enable = [ ... ]; }` or grab everything
with `enableAll = true;`.

## MCP

`lib.mcp.defaultServers` ships the Dynatrace MCP. It requires
`DT_API_TOKEN` and `DT_ENVIRONMENT` in your env. `.mcp.json` is
generated on shell entry and wiped on exit.

## Caveats

- `.claude/`, `.opencode/`, and `.mcp.json` are **wiped on shell exit**
  in any template that runs `mkShellHook`. Don't keep hand-edited files
  there. See `papanix-ai/docs/how-skill-install-works.md`.
- The `minimal` template does not run any shell hook and leaves your
  workspace untouched.

## Layout

```
.
├── default/       # batteries-included
├── minimal/       # CLIs only
├── skills-only/   # curated skills, no MCP
├── mcp-custom/    # all skills + extra MCP servers
├── library/       # library-only, no CLIs
└── flake.nix      # template registry
```
