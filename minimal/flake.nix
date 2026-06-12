# minimal — papanix-ai CLIs + sandboxed `claude` on PATH only.
#
# No skills installed into .claude/ or .opencode/.
# No .mcp.json generated.
# Nothing wiped on shell exit.
#
# Use this when you want the Dynatrace internal CLIs
# (acli-pii, bbctl, dtctl, junoctl) plus the sandboxed `claude`
# wrapper inside `nix develop`, but you manage repo-local AI config
# separately (or not at all).
{
  description = "papanix-ai: minimal devShell — CLIs + sandboxed claude, no skills, no MCP";

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

        # NOTE: Customize the sandboxed `claude` wrapper here.
        sandbox = import (papanix-ai + "/vendor/agent-sandbox-nix") {inherit pkgs;};
        sandboxedClaude = sandbox.mkSandbox {
          pkg = pkgs.claude-code;
          binName = "claude";
          outName = "claude";
          # If you have your own package attrset, flatten it first:
          #   builtins.attrValues myPkgs ++ (with pkgs; [ git ripgrep ])
          # `allowedPackages = [ myPkgs ];` fails with "cannot coerce a set to a string".
          allowedPackages = with pkgs; [
            coreutils
            which
            git
            ripgrep
            fd
            gnused
            gnugrep
            findutils
            diffutils
            less
            gawk
            jq
            curl
            nodejs
          ];
          stateDirs = [
            "$HOME/.claude"
            "$HOME/.npm"
            "$HOME/.cache/claude"
          ];
          stateFiles = [];
          extraEnv = {
            CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
            ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY";
            GITHUB_TOKEN = "$GITHUB_TOKEN";
            CLAUDE_CONFIG_DIR = "$HOME/.claude";
            GIT_AUTHOR_NAME = "claude";
            GIT_AUTHOR_EMAIL = "claude@localhost";
            GIT_COMMITTER_NAME = "claude";
            GIT_COMMITTER_EMAIL = "claude@localhost";
          };
          restrictNetwork = false;
          # NOTE: Only used when `restrictNetwork = true;`.
          # allowedDomains = {
          #   "api.anthropic.com" = true;
          #   "github.com" = true;
          # };
        };
      in {
        # NOTE: Re-export the CLIs so `nix build .#dtctl` etc. works locally.
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          # All four CLIs plus sandboxed `claude` on PATH. Drop the `.default`
          # and list individual packages if you only want a subset:
          #   packages = with papanix-ai.packages.${system}; [ dtctl bbctl ];
          packages = [
            papanix-ai.packages.${system}.default
            sandboxedClaude
          ];
        };
      }
    );
}
