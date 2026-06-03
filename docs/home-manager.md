# Home-Manager (user-scope install)

The dev shell (`nix develop`) is project-scope: it drops `.claude/`,
`.mcp.json`, and `opencode.jsonc` into the project directory and wipes
them on exit. That is the right model for **a project the team owns**,
but it does not help you when you want **your personal baseline of
skills, plugins, and MCP servers** to be present in *every* repo you
open — including third-party repos you don't want to add a flake to.

The `home-manager` template gives you exactly that. Declare it once and
Home-Manager installs the same skill catalog, Claude Code settings, MCP
servers, and PAPA CLIs at user scope. Per-project devShells (from any
of the other templates) still work — they layer on top.

If you've never used Home-Manager, the fastest path is the guided
walkthrough — let an agent invoke `/papanix-ai-home-manager-setup`, or
follow this doc.

## Prerequisites

- Nix installed with flakes enabled (see [install-nix.md](install-nix.md)).
- GitHub PAT + Bitbucket SSH set up (see [auth-setup.md](auth-setup.md))
  if you want `acli-pii` and `bbctl`/`junoctl` in `cliTools.selection`.
- Home-Manager: <https://nix-community.github.io/home-manager/>. The
  rest of this doc assumes the flake-based install.
- For Claude Code MCP setup with the default `activation` strategy, the
  `claude` CLI must be on `$PATH` when you run `home-manager switch`.
  If it isn't, the activation step warns and skips — re-run after
  installing claude-code.

## Install Home-Manager (if you don't have it)

The simplest path is the standalone flake-based install:

```bash
nix run home-manager/master -- init --switch ~/.config/home-manager
```

This creates `~/.config/home-manager/flake.nix` and `home.nix`. You will
replace those with the `home-manager` papanix-ai template in the next
step, so you can also just create the directory and skip `init`:

```bash
mkdir -p ~/.config/home-manager
```

Verify:

```bash
nix run home-manager/master -- --version
```

## Adopt the `home-manager` template

```bash
cd ~/.config/home-manager
nix flake init -t github:fmgordillo-dyna/papanix-ai-template#home-manager
```

This writes a `flake.nix` and a `home.nix`. Both carry `# TODO:` and
`# NOTE:` markers — see the [Filling in the TODOs](#filling-in-the-todos)
section below.

Apply with:

```bash
nix run home-manager/master -- switch --flake .#me --impure
```

`--impure` is required because `acli-pii` is fetched over SSH at eval
time. Drop it from `cliTools.selection` if you want a pure build:

```nix
programs.papanix-ai.cliTools.selection = [ "bbctl" "dtctl" "junoctl" ];
```

## Filling in the TODOs

Two files, three things to change:

### `flake.nix`

| TODO | What to change |
|---|---|
| `homeConfigurations."me"` | Rename `"me"` to whatever you want to call this profile. Must match the `--flake .#<name>` you pass to `home-manager switch`. |

### `home.nix`

| TODO | What to change |
|---|---|
| `home.username` | Your local user (output of `whoami`). |
| `home.homeDirectory` | `/home/<user>` on Linux/WSL, `/Users/<user>` on macOS. |
| `home.stateVersion` | Leave as-is on first install; only bump after reading the Home-Manager release notes. |
| `programs.papanix-ai.skills` | Either `enableAll = true;` or `enable = [ "papa/dt-jira" "rnd/dt-github" ]` with the skill IDs you want. List the catalog: `nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog --apply builtins.attrNames --json`. |
| `programs.papanix-ai.claudeSettings` | `enableAll = true;` enables every plugin from `papa-ai-knowledgebase` + `rnd-ai-knowledgebase`. Curate with `enable = [ "papa/papa-jira" "rnd/dt-github" ]`. |
| `programs.papanix-ai.mcp.claudeCode.strategy` | Keep `activation` (default) if the `claude` CLI is on PATH at switch time. Switch to `snippet` otherwise and run `claude mcp import-json ~/.config/papanix-ai/mcp-servers.json` after activation. |
| `programs.papanix-ai.cliTools.selection` | Defaults to all four. Drop `acli-pii` if you want a pure build (no `--impure`). |

> **For agents:** the `/papanix-ai-home-manager-setup` skill walks the
> user through these prompts interactively, and runs the final
> `home-manager switch` invocation.

## What lands where

| Option | Path | Mechanism |
|---|---|---|
| `skills.targets.claude` (default on) | `~/.claude/skills/` | `home.file` symlinks per skill, `recursive = true` so hand-added siblings survive |
| `skills.targets.opencode` | `~/.config/opencode/skills/` | same |
| `skills.targets.{codex,agents,copilot,cursor,windsurf,antigravity,gemini}` | per-agent dir under `$HOME` | same, opt-in |
| `claudeSettings` | `~/.claude/settings.json` | declarative symlink (Claude Code reads, never writes) |
| `mcp.opencode` | `~/.config/opencode/opencode.jsonc` | declarative symlink |
| `mcp.claudeCode` (`activation`) | `~/.claude.json` (server entries only, under `--scope user`) | HM activation runs `claude mcp add-json --scope user`; manifest at `~/.config/papanix-ai/mcp-managed.json` tracks the set |
| `mcp.claudeCode` (`snippet`) | `~/.config/papanix-ai/mcp-servers.json` | declarative symlink; you run `claude mcp import-json …` once |
| `cliTools.selection` | `home.packages` | regular Nix package install |

Why two MCP strategies for Claude Code? `~/.claude.json` is **mutable**
state that the `claude` CLI writes to (project trust, auth tokens,
last-active-directory, …). Symlinking it from `/nix/store` would brick
the CLI. So:

- `activation` (default) — clean and drift-tracked. Requires `claude`
  on PATH at switch time.
- `snippet` — write a file you import manually once. Safer when you
  haven't installed claude-code yet at HM activation time.

## Coexistence with project devShells

You can use both at the same time. Claude Code and opencode both merge
user-scope and project-scope configuration. **Project scope wins on
conflicts** (matching server names, skill IDs, settings keys).

| Concern | User scope (HM) | Project scope (devShell) | On conflict |
|---|---|---|---|
| Skills | `~/.claude/skills/` | `$PWD/.claude/skills/` | project wins |
| Claude settings | `~/.claude/settings.json` | `$PWD/.claude/settings.json` | project keys win in deep-merge |
| MCP (Claude Code) | `--scope user` entries | `$PWD/.mcp.json` | project wins on duplicate server name |
| MCP (opencode) | `~/.config/opencode/opencode.jsonc` | `$PWD/opencode.jsonc` | project wins |
| CLIs | `home.packages` (global PATH) | devShell `packages` (PATH while in `nix develop`) | devShell entry takes precedence inside the shell |

The devShell's EXIT trap wipes only `$PWD/.claude/`, `$PWD/.mcp.json`,
`$PWD/opencode.jsonc` — never `~/.claude/` or `~/.config/…`. Your
HM-managed user-scope files are not touched.

## Worked examples

### Just skills, just Claude Code

```nix
programs.papanix-ai = {
  enable = true;
  skills.enable = [ "papa/dt-jira" "rnd/dt-github" ];
};
```

### Custom MCP server set

```nix
programs.papanix-ai = {
  enable = true;
  mcp = {
    servers = papanix-ai.lib.mcp.defaultServers // {
      github = {
        type    = "stdio";
        command = "npx";
        args    = [ "-y" "@modelcontextprotocol/server-github" ];
        env     = { GITHUB_TOKEN = "\${GITHUB_TOKEN}"; };
      };
    };
    claudeCode.enable = true;
    opencode.enable   = true;
  };
};
```

### Plugins + custom permissions, no MCP

```nix
programs.papanix-ai = {
  enable = true;
  claudeSettings = {
    enable   = [ "papa/papa-jira" "rnd/dt-github" ];
    settings = {
      permissions = {
        allow = [ "Bash(git:*)" "Read(**)" ];
        deny  = [];
      };
    };
  };
};
```

### Snippet strategy (no `claude` CLI yet)

```nix
programs.papanix-ai = {
  enable = true;
  mcp.claudeCode = {
    enable   = true;
    strategy = "snippet";
  };
};
```

After `home-manager switch`, run once:

```bash
claude mcp import-json ~/.config/papanix-ai/mcp-servers.json
```

## Caveats

- **Impurity from `acli-pii`.** `home-manager switch --flake … --impure`
  is needed while `acli-pii` is in `cliTools.selection`. The flake reads
  your SSH credentials at eval time to fetch the private repo. Drop
  `acli-pii` from the selection for a pure build.
- **`~/.claude.json` is owned by the CLI, not HM.** We never symlink it.
  The `activation` strategy mutates only the MCP section via
  `claude mcp add-json`; the rest of the file (project trust, auth) is
  preserved.
- **Skill destination directories are HM-managed.** With
  `recursive = true` you can drop hand-rolled skills next to the
  HM-managed ones; HM only owns the symlinks it created. Removing a
  skill from `programs.papanix-ai.skills.enable` removes its symlink on
  the next switch — the hand-rolled siblings stay.
- **MCP server drift.** With the `activation` strategy, removing a
  server from `programs.papanix-ai.mcp.servers` deletes it from
  `~/.claude.json` on the next switch (tracked via the manifest at
  `~/.config/papanix-ai/mcp-managed.json`). If you added servers
  manually via `claude mcp add` outside HM, those are not touched.
- **No NixOS / nix-darwin module yet.** HM-on-darwin works fine via the
  standard `home-manager.darwinModules.home-manager` bridge. If you
  want the PAPA CLIs at system scope, file a request.

## Troubleshooting

```bash
# What does the module evaluate to in your config?
nix eval --impure ~/.config/home-manager#homeConfigurations.me.config.programs.papanix-ai

# Re-run the MCP activation manually (after installing claude-code):
~/.local/state/nix/profiles/home-manager/activate

# List user-scope MCP servers managed by this module:
cat ~/.config/papanix-ai/mcp-managed.json
claude mcp list --scope user
```

If the activation step prints `'claude' CLI not found in PATH`, install
claude-code (e.g. `npm i -g @anthropic-ai/claude-code`) and re-run
`home-manager switch`.
