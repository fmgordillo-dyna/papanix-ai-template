# minimal — papanix-ai CLIs + sandboxed `claude` on PATH only.
#
# No MCP config is generated.
# Nothing is wiped on shell exit.
#
# Use this when you want the PAPA CLI bundle
# (acli-pii, aimgr, bbctl, dtctl, junoctl) plus the sandboxed `claude`
# wrapper inside `nix develop`, but you manage repo-local AI config
# separately (or not at all).
{
  description = "papanix-ai: minimal devShell — CLIs + sandboxed `claude`, no MCP";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    papanix-ai,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
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
        sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox {
          inherit pkgs cliPackages;
          claudePkg = pkgs.claude-code;

          # NOTE: Safe defaults already include the selected PAPA CLIs plus
          # common helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`,
          # `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`.
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
      in {
        # NOTE: Re-export the CLIs so `nix build .#dtctl` etc. works locally.
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          # Selected PAPA CLIs plus sandboxed `claude` on PATH.
          # Drop entries from `cliPackages` above if you only want a subset.
          packages = cliPackages ++ [sandboxedClaude];
        };
      }
    );
}
