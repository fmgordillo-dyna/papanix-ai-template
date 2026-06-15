# Home-Manager (user-scope install)

The dev shell (`nix develop`) is project-scope: it drops `.claude/`,
`.mcp.json`, and `opencode.jsonc` into the project directory and wipes
them on exit. That is the right model for **a project the team owns**,
but it does not help you when you want **your personal baseline of
skills and Claude Code plugin marketplaces** to be present in *every*
repo you open — including third-party repos you don't want to add a
flake to.

The `home-manager` template gives you exactly that. Declare it once and
Home-Manager installs the same skill catalog for non-Claude agents
(opencode, codex, cursor, …), Claude Code plugin marketplace
registration, PAPA CLIs, and sandboxed `claude` wrapper at user scope.
Per-project devShells (from any of the other templates) still work —
they layer on top.

> **Why not Claude skills at user scope?** Claude Code loads every skill
> file into the context window on every invocation, which has a token
> cost. Installing skills globally for Claude would inflate context in
> repos that don't need them. The project devShell handles Claude skills
> ephemerally — installed on `nix develop` entry, wiped on exit.
> Non-Claude agents (opencode, codex, cursor, …) opt skills in per-call,
> so global installation has no overhead.

If you've never used Home-Manager, the fastest path is the guided
walkthrough — let an agent invoke `/papanix-ai-home-manager-setup`, or
follow this doc.

## Prerequisites

- Nix installed with flakes enabled (see [install-nix.md](install-nix.md)).
- GitHub PAT + Bitbucket SSH set up (see [auth-setup.md](auth-setup.md))
  if you want `acli-pii` and `bbctl`/`junoctl` in `cliTools.selection`.
- Home-Manager: <https://nix-community.github.io/home-manager/>. The
  rest of this doc assumes the flake-based install.

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

Two files, a handful of knobs to confirm:

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
| `programs.papanix-ai.skills` | Disable the `claude` target (`targets.claude.enable = false`); enable the non-Claude agents you use (`targets.opencode.enable = true`, etc.). Use `enableAll = true` (or curate with `enable = [...]`) to set which skill sources to install. |
| `programs.papanix-ai.claudeSettings` | Registers Claude Code plugin marketplaces so Claude Code can discover them. **Plugin enablement happens via the Claude Code TUI** (Settings → Plugin Marketplace) — not here. Keep `defaultMarketplaces` or extend with your own. |
| `programs.papanix-ai.cliTools.selection` | The module default is `[]`. The template sets all four explicitly; drop `acli-pii` if you want a pure build (no `--impure`). |
| `programs.papanix-ai.sandboxing` | Enables the sandboxed `claude` wrapper globally. Safe defaults already include the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, and `node`. Extend with `extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`, `extraRoFiles`, `extraEnv`, `restrictNetwork`, and `allowedDomains`. |

> **For agents:** the `/papanix-ai-home-manager-setup` skill walks the
> user through these prompts interactively, and runs the final
> `home-manager switch` invocation.

## What lands where

| Option | Path | Mechanism |
|---|---|---|
| `skills.targets.opencode` | `~/.config/opencode/skills/` | `home.file` symlinks per skill, `recursive = true` so hand-added siblings survive |
| `skills.targets.{codex,agents,copilot,cursor,windsurf,antigravity,gemini}` | per-agent dir under `$HOME` | same, opt-in |
| `claudeSettings` | `~/.claude/settings.json` | `home.activation` copies a Nix-generated file; Claude Code writes plugin state back at runtime (mutable) — not a symlink |
| `cliTools.selection` | `home.packages` | regular Nix package install |
| `sandboxing.enable` | `home.packages` (`claude`) | high-priority sandboxed wrapper built by the module |

## Coexistence with project devShells

You can use both at the same time. Claude Code and opencode both merge
user-scope and project-scope configuration. **Project scope wins on
conflicts** (matching server names, skill IDs, settings keys).

| Concern | User scope (HM) | Project scope (devShell) | On conflict |
|---|---|---|---|
| Skills | `~/.config/opencode/skills/` (and other non-Claude targets) | `$PWD/.claude/skills/` etc. | project wins |
| CLIs / sandboxed `claude` | `home.packages` (global PATH) | devShell `packages` (PATH while in `nix develop`) | devShell entry takes precedence inside the shell |

The devShell's EXIT trap wipes only `$PWD/.claude/`, `$PWD/.mcp.json`,
`$PWD/opencode.jsonc` — never `~/.claude/` or `~/.config/…`. Your
HM-managed user-scope files are not touched.

## Worked examples

### Skills for non-Claude agents

```nix
programs.papanix-ai = {
  enable = true;
  skills.enableAll = true;
  skills.targets.opencode.enable = true;
};
```

### Marketplace registration only

```nix
programs.papanix-ai = {
  enable = true;
  claudeSettings.marketplaces = papanix-ai.lib.claudeSettings.defaultMarketplaces;
  # Enable plugins via the Claude Code TUI after switching.
};
```

### Extend the sandbox wrapper

```nix
programs.papanix-ai = {
  enable = true;
  sandboxing = {
    enable = true;
    extraAllowedPackages = with pkgs; [ gh kubectl ];
    extraRwDirs = [ "$HOME/.config/gh" "$HOME/.kube" ];
    extraRwFiles = [ "$HOME/.gitconfig" ];
    extraRoDirs = [ "$HOME/.config/some-readonly-tree" ];
    extraRoFiles = [ "$HOME/.config/readonly.conf" ];
    extraEnv = {
      GH_TOKEN = "$GH_TOKEN";
      KUBECONFIG = "$HOME/.kube/config";
    };
    restrictNetwork = true;
    allowedDomains = {
      "github.com" = [ "GET" "HEAD" ];
      "api.anthropic.com" = "*";
    };
  };
};
```

Start with the built-in safe defaults and add only the extra tools or
state you need.

## Caveats

- **Impurity from `acli-pii`.** `home-manager switch --flake … --impure`
  is needed while `acli-pii` is in `cliTools.selection`. The flake reads
  your SSH credentials at eval time to fetch the private repo. Drop
  `acli-pii` from the selection for a pure build.
- **First switch with the sandbox wrapper may need a second pass.** Open a new
  shell after Home-Manager installs the sandboxed wrapper and run
  `home-manager switch` again if tools are not yet on PATH.
- **Safe defaults are already included inside the sandbox.** Start with
  `programs.papanix-ai.sandboxing.enable = true;` and only add tools via
  `extraAllowedPackages` when you truly need them.
- **`~/.claude.json` is owned by the CLI, not HM.** We never symlink it.
  The `activation` strategy mutates only the MCP section via
  `claude mcp add-json`; the rest of the file (project trust, auth) is
  preserved.
- **Skill destination directories are HM-managed.** With
  `recursive = true` you can drop hand-rolled skills next to the
  HM-managed ones in the non-Claude agent dirs (e.g.
  `~/.config/opencode/skills/`); HM only owns the symlinks it created.
  Removing a skill from `programs.papanix-ai.skills.enable` removes its
  symlink on the next switch — the hand-rolled siblings stay.
- **Claude skills are not installed at user scope.** The `claude.enable` target
  is `false` by default. Use the project devShell (`nix develop`) for ephemeral
  Claude skill loading. Project-scope skills wipe on shell exit and never pollute
  other repos.
- **No NixOS / nix-darwin module yet.** HM-on-darwin works fine via the
  standard `home-manager.darwinModules.home-manager` bridge. If you
  want the PAPA CLIs at system scope, file a request.

## Troubleshooting

```bash
# What does the module evaluate to in your config?
nix eval --impure ~/.config/home-manager#homeConfigurations.me.config.programs.papanix-ai

# Re-run the activation script manually:
~/.local/state/nix/profiles/home-manager/activate
```
