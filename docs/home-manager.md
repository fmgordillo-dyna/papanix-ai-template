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

> Note: this template intentionally does **not** install agent skills,
> Claude Code plugin marketplaces, or MCP declaratively. Keep MCP in
> project devShells; manage any agent-specific skill or plugin setup
> separately.

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
| `programs.papanix-ai.sandboxing` | Enables the sandboxed `claude` wrapper globally. Safe defaults already include the PAPA CLIs plus helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`, `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`. Extend with `extraAllowedPackages`, `extraRwDirs`, `extraRoDirs`, `extraRwFiles`, `extraRoFiles`, `extraEnv`, `restrictNetwork`, `allowedDomains`, and `exposeSsh`. |
| `programs.papanix-ai.devEnv` (optional) | Uncomment if you want Node.js / Playwright / extra packages at user scope too. |

> **For agents:** `/papanix-ai-home-manager-setup` walks the user
> through these prompts interactively and runs the final switch.

## What lands where

| Option | Path / effect | Mechanism |
|---|---|---|
| `cliTools.selection` | `~/.nix-profile/bin/...` | regular Nix package install |
| `sandboxing.enable` | `claude` on PATH | high-priority sandboxed wrapper built by the module |
| `devEnv` | PATH additions + Playwright env vars | Home-Manager module wiring |

## Coexistence with project devShells

You can use both at the same time. **Project scope wins on conflicts**.

| Concern | User scope (HM) | Project scope (devShell) | On conflict |
|---|---|---|---|
| CLIs / sandboxed `claude` | global PATH | devShell PATH while in `nix develop` | devShell wins inside the shell |
| MCP | not configured here | `$PWD/.mcp.json`, `$PWD/opencode.jsonc` in MCP-enabled templates | project only |
| Per-contributor dev tooling | global if enabled in `home.nix` | project-local if enabled in `dev-env` or custom shell | devShell wins inside the shell |

## Worked examples

### Pure CLI selection

```nix
programs.papanix-ai = {
  enable = true;
  cliTools.selection = [ "aimgr" "bbctl" "dtctl" "junoctl" ];
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

## Caveats

- **Impurity from `acli-pii`.** `home-manager switch --flake … --impure`
  is needed while `acli-pii` is in `cliTools.selection`. Drop it from
  the selection for a pure build.
- **Safe defaults are already included inside the sandbox.** Start with
  `programs.papanix-ai.sandboxing.enable = true;` and only add tools via
  `extraAllowedPackages` when you truly need them.
- **SSH inside the sandbox is opt-in.** Set
  `programs.papanix-ai.sandboxing.exposeSsh = true;` if Claude needs to
  talk to SSH remotes from inside the wrapper.
- **MCP is intentionally project-scope.** This template does not manage
  `.mcp.json` or `opencode.jsonc`; use a project devShell for that.
- **No declarative skills / marketplace registration here.** If you need
  slash-command onboarding docs, use the `skills/` directory in this
  repo directly. If you need Claude plugin marketplaces, configure them
  outside this template.
- **First switch with the sandbox wrapper may need a second pass.** Open
  a new shell after Home-Manager installs the wrapper and run the switch
  again if tools are not yet on PATH.
- **No NixOS / nix-darwin module here.** HM-on-darwin works fine via the
  standard `home-manager.darwinModules.home-manager` bridge. If you want
  the PAPA CLIs at system scope, file a request.

## Troubleshooting

```bash
# What does the module evaluate to in your config?
nix eval --impure ~/.config/home-manager#homeConfigurations.<name>.config.programs.papanix-ai

# Re-run the activation script manually:
~/.local/state/nix/profiles/home-manager/activate
```
