# default — papanix-ai CLIs + sandboxed `claude` + default MCP.
#
# `.mcp.json` and `opencode.jsonc` are generated on shell entry and
# wiped on exit.
{
  description = "papanix-ai: default devShell — CLIs + sandboxed `claude` + default MCP";
  # External dependencies, pinned at flake.lock
  # To update do `nix flake update`
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # Base repository
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai"; # This repository
    flake-utils.url = "github:numtide/flake-utils"; # Helper to compile in MacOS + Linux
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    papanix-ai,
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        # We build packages for both MacOS and Linux.
        # allowUnfree is required because the sandbox wraps `claude-code`.
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        cliPackages = with papanix-ai.packages.${system}; [
          acli-pii
          aimgr
          bbctl
          dtctl
          junoctl
        ];

        # NOTE: Customize the sandboxed `claude` wrapper here.
        # Safe defaults already include the selected PAPA CLIs plus common
        # helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`, `tree`,
        # `tar`, `zip`, `unzip`, `node`, and `nix`.
        sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox {
          inherit pkgs cliPackages;
          claudePkg = pkgs.claude-code;

          # NOTE: Add extra tools on PATH inside the sandbox only when needed.
          # extraAllowedPackages = with pkgs; [ gh kubectl ];

          # NOTE: Persist extra tool state or individual config files.
          # extraRwDirs = [ "$HOME/.config/gh" "$HOME/.kube" ];
          # extraRwFiles = [ "$HOME/.kube/config" ];

          # NOTE: Bind read-only config into the sandbox when needed.
          # extraRoDirs = [ "$HOME/.config/some-readonly-tree" ];
          # extraRoFiles = [ "$HOME/.gitconfig" ];

          # NOTE: Pass extra env vars through to the sandboxed process.
          # extraEnv = {
          #   GH_TOKEN = "$GH_TOKEN";
          #   KUBECONFIG = "$HOME/.kube/config";
          # };

          restrictNetwork = false;
          # NOTE: Only used when `restrictNetwork = true;`.
          # allowedDomains = {
          #   "github.com" = [ "GET" "HEAD" ];
          #   "api.anthropic.com" = "*";
          # };

          # NOTE: Enable if Claude needs SSH remotes from inside the sandbox.
          # exposeSsh = true;
        };

        # NOTE: MCP servers wired into .mcp.json and opencode.jsonc on shell
        # entry, wiped on exit. Override `servers` to add/replace entries;
        # defaults ship Dynatrace MCP (needs DT_API_TOKEN + DT_ENVIRONMENT)
        # and Juno MCP (no env vars required).
        mcpServers = papanix-ai.lib.mcp.defaultServers;
        # NOTE: Per-contributor dev tooling (Node.js / npm / Playwright …)
        # via `lib.devEnv.mk`. Returns `{ packages; shellHook; }` — splice
        # `devEnv.packages` into the shell's `packages` list and
        # `${devEnv.shellHook}` into the shellHook string. See the
        # `dev-env` template for a dedicated example.
        # devEnv = papanix-ai.lib.devEnv.mk {
        #   inherit pkgs;
        #   nodejs     = { version = "nodejs_22"; withCorepack = true; };
        #   playwright = true;
        #   # extraPackages = with pkgs.nodePackages; [ typescript prettier ];
        # };
      in {
        # Here lives `dtctl` and friends to use individually
        packages = papanix-ai.packages.${system};

        # Here we make `nix develop` magic happen:
        devShells.default = pkgs.mkShellNoCC {
          # We make the selected PAPA CLIs plus sandboxed `claude` available on PATH.
          packages =
            cliPackages
            ++ [
              sandboxedClaude
            ]
            # NOTE: Add nodejs, playwright, etc to your project
            # ++ devEnv.packages
            ;
          shellHook = ''
            ${papanix-ai.lib.mcp.mkShellHook {
              inherit pkgs;
              servers = mcpServers;
            }}
            # ''${devEnv.shellHook}
          '';
        };
      }
    );
}
