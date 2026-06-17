# Home-Manager (user-scope install)

The dev shell (`nix develop`) is project-scope. It is the right model
for **a project the team owns**, but it does not help when you want a
personal baseline of PAPA CLIs and a sandboxed `claude` wrapper in
*every* repo you open.

The `home-manager` template gives you that user-scope baseline:

- PAPA CLIs on your global PATH
- a sandboxed `claude` wrapper in `$HOME`
- optional user-scope dev tooling via `lib.devEnv.mk`

Per-project devShells still work and layer on top.

> Note: this template does **not** install Claude plugin marketplaces or
> MCP declaratively. Keep MCP in project devShells. Agent skills from the
> internal knowledge-base repos can be installed persistently at
> `~/.agents/skills/` via `programs.papanix-ai.skills.enable` — see
> [Declarative skills](#declarative-skills) below.

If you've never used Home-Manager, the fastest path is the guided
walkthrough — let an agent invoke `/papanix-ai-home-manager-setup`, or
follow this doc.

## Prerequisites

- Nix installed with flakes enabled (see [install-nix.md](install-nix.md)).
- GitHub PAT + Bitbucket SSH set up (see [auth-setup.md](auth-setup.md))
  if you want `acli-pii`, `bbctl`, or `junoctl` in `cliTools.selection`.
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
`# NOTE:` markers — see [Filling in the TODOs](#filling-in-the-todos).

Apply with:

```bash
nix run home-manager/master -- switch --flake .#me --impure
```

`--impure` is required because `acli-pii` is fetched over SSH at eval
time. Drop it from `cliTools.selection` if you want a pure build:

```nix
programs.papanix-ai.cliTools.selection = [ "aimgr" "bbctl" "dtctl" "junoctl" ];
```

## Filling in the TODOs

Two files, a handful of knobs to confirm:

### `flake.nix`

| TODO | What to change |
|---|---|
| `hmSystem` | Set it to the system you actually run `home-manager switch` on. |
| `homeConfigurations."me"` | Rename `"me"` to whatever you want to call this profile. Must match the `--flake .#<name>` you pass to `home-manager switch`. |

### `home.nix`

| TODO / NOTE | What to change |
|---|---|
| `home.username` | Your local user (`whoami`). |
| `home.homeDirectory` | `/home/<user>` on Linux/WSL, `/Users/<user>` on macOS. |
| `home.stateVersion` | Leave as-is on first install; only bump after reading the Home-Manager release notes. |
| `programs.papanix-ai.cliTools.selection` | The template sets five CLIs explicitly (`acli-pii`, `aimgr`, `bbctl`, `dtctl`, `junoctl`). Drop `acli-pii` if you want a pure switch (no `--impure`). |
| `programs.papanix-ai.sandboxing` | Enables sandboxed agent wrappers globally (Claude, Pi, OpenCode). Nested under `sandboxing` are per-agent enable flags: `claude.enable`, `pi.enable`, `opencode.enable`. Shared knobs (`extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`, `extraRoFiles`, `extraEnv`, `restrictNetwork`, `allowedDomains`, `exposeSsh`) apply identically to all enabled agents. Safe defaults include the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`. |
| `programs.papanix-ai.skills` (optional) | Set `skills.enable = true` for all skills from both internal repos, `skills.enable = [ "repo/skill-name" ]` for a selective subset, or leave the default `false`. Add local paths via `skills.extra = { my-skill = ./path; }`. Skills land at `~/.agents/skills/`. Requires `--impure` whenever `skills.enable != false`. |
| `programs.papanix-ai.devEnv` (optional) | Uncomment if you want Node.js / Playwright / extra packages at user scope too. |

> **For agents:** `/papanix-ai-home-manager-setup` walks the user
> through these prompts interactively and runs the final switch.

## What lands where

| Option | Path / effect | Mechanism |
|---|---|---|
| `cliTools.selection` | `~/.nix-profile/bin/...` | regular Nix package install |
| `sandboxing.claude.enable` | `claude` on PATH | high-priority sandboxed wrapper built by the module |
| `sandboxing.pi.enable` | `pi` on PATH | high-priority sandboxed wrapper built by the module |
| `sandboxing.opencode.enable` | `opencode` on PATH | high-priority sandboxed wrapper built by the module |
| `devEnv` | PATH additions + Playwright env vars | Home-Manager module wiring |
| `skills.enable` | `~/.agents/skills/<name>/` symlinks | persistent `home.file` entries via the module |

## Coexistence with project devShells

You can use both at the same time. **Project scope wins on conflicts**.

| Concern | User scope (HM) | Project scope (devShell) | On conflict |
|---|---|---|---|
| CLIs / sandboxed agents | global PATH (claude, pi, opencode if enabled) | devShell PATH while in `nix develop` | devShell wins inside the shell |
| MCP | not configured here | `$PWD/.mcp.json`, `$PWD/opencode.jsonc` in MCP-enabled templates | project only |
| Agent skills | `~/.agents/skills/` (persistent, if `skills.enable != false`) | `$PWD/.agents/skills/` (ephemeral, if project devShell wires `lib.skills.mkShellHook`) | project copy used inside the shell |
| Per-contributor dev tooling | global if enabled in `home.nix` | project-local if enabled in `dev-env` or custom shell | devShell wins inside the shell |

## Worked examples

### Pure CLI selection

```nix
programs.papanix-ai = {
  enable = true;
  cliTools.selection = [ "aimgr" "bbctl" "dtctl" "junoctl" ];
};
```

### Enable sandboxed agent wrappers

Start with the per-agent enable flags:

```nix
programs.papanix-ai = {
  enable = true;
  sandboxing = {
    claude.enable = true;   # sandboxed Claude → `claude` binary
    pi.enable = true;       # sandboxed Pi → `pi` binary
    opencode.enable = true; # sandboxed OpenCode → `opencode` binary
  };
};
```

### Extend the sandbox wrappers

Shared knobs apply identically to every enabled agent:

```nix
programs.papanix-ai = {
  enable = true;
  sandboxing = {
    claude.enable = true;
    pi.enable = true;
    opencode.enable = true;

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
      "api.openai.com" = "*";
    };
    exposeSsh = true;       # enable SSH authentication
  };
};
```

Per-agent package overrides:

```nix
programs.papanix-ai = {
  enable = true;
  sandboxing = {
    claude.enable = true;
    claude.package = pkgs.claude-code;  # override default

    pi.enable = true;
    # pi.package = pkgs.master.pi-coding-agent;  # override if needed

    opencode.enable = true;
    # opencode.package = pkgs.master.opencode;  # override if needed
  };
};
```

### Enable user-scope dev tooling

```nix
programs.papanix-ai = {
  enable = true;
  devEnv = {
    enable = true;
    nodejs = { version = "nodejs_22"; withCorepack = true; };
    playwright = true;
    # extraPackages = with pkgs; [ jq gh ];
  };
};
```

### Enable declarative agent skills

```nix
programs.papanix-ai = {
  enable = true;

  # Install all skills from both internal knowledge-base repos:
  skills.enable = true;

  # Or select only specific skills:
  # skills.enable = [ "papa-ai-knowledgebase/dt-jira" ];

  # Optionally add a local or fetched skill directory:
  # skills.extra = { my-team-skill = ./local/my-skill; };
};
```

Symlinks land at `~/.agents/skills/<name>/`. Consumed by OpenCode, Pi,
Devin CLI, and GitHub Copilot CLI. **Requires `--impure`** because the
two knowledge-base repos are SSO-gated private GitHub repos:

```bash
home-manager switch --flake .#<name> --impure
```

When the same skill name exists in both repos the directory is prefixed
as `<repo>--<name>/` to avoid silent overwrites (e.g.,
`rnd-ai-knowledgebase--dt-jira/` and `papa-ai-knowledgebase--dt-jira/`).

## Caveats

- **`--impure` is required for private packages or skills.** Use
  `home-manager switch --flake … --impure` while `acli-pii` is in
  `cliTools.selection` *or* while `skills.enable != false`. Both reasons
  involve SSO-gated private repos that are fetched at eval time.
- **Safe defaults are already included inside the sandbox.** Start with
  `programs.papanix-ai.sandboxing.enable = true;` and only add tools via
  `extraAllowedPackages` when you truly need them.
- **SSH inside the sandbox is opt-in.** Set
  `programs.papanix-ai.sandboxing.exposeSsh = true;` if any enabled agent needs to
  talk to SSH remotes from inside the sandbox.
- **MCP is intentionally project-scope.** This template does not manage
  `.mcp.json` or `opencode.jsonc`; use a project devShell for that.
- **No Claude plugin marketplace registration here.** If you need
  slash-command onboarding docs, use the `skills/` directory in this
  repo directly.
- **First switch with the sandbox wrapper may need a second pass.** Open
  a new shell after Home-Manager installs the wrapper and run the switch
  again if tools are not yet on PATH.
- **No NixOS / nix-darwin module here.** HM-on-darwin works fine via the
  standard `home-manager.darwinModules.home-manager` bridge. If you want
  the PAPA CLIs or sandboxed agents at system scope, file a request.
- **Shared provider API keys.** All sandboxed agents (Claude, Pi, OpenCode)
  read a common set of environment variables: `ANTHROPIC_API_KEY`,
  `OPENAI_API_KEY`, `GEMINI_API_KEY`, `GOOGLE_API_KEY`, and `GITHUB_TOKEN`.
  This lets users authenticate with whichever LLM provider they configure
  in each agent without extra wiring. Claude additionally reads
  `CLAUDE_CODE_OAUTH_TOKEN`.

## Troubleshooting

```bash
# What does the module evaluate to in your config?
nix eval --impure ~/.config/home-manager#homeConfigurations.<name>.config.programs.papanix-ai

# Re-run the activation script manually:
~/.local/state/nix/profiles/home-manager/activate
```
