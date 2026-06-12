# skills-only — install a curated set of AI skills, no MCP.
#
# Picks specific skills from the papanix-ai catalog and installs them
# ephemerally into .claude/ on `nix develop` entry.
# .claude/ is wiped on shell exit (the default targets only enable claude;
# opencode is opt-in — pass a custom `targets` to lib.skills.mkShellHook).
#
# List available skill IDs with:
#   nix eval github:fmgordillo-dyna/papanix-ai#lib.skills.catalog \
#     --apply builtins.attrNames --json
{
  description = "papanix-ai: devShell with a curated skill subset + sandboxed claude, no MCP";

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

        # NOTE: Pick the skills you want here. IDs match the catalog.
        bundle = papanix-ai.lib.skills.mkBundle {
          inherit pkgs;
          enable = [
            "dt-jira"
            "dt-github"
            "create-epic"
          ];
          # Alternatives:
          # enableAll = true;                # every skill
          # enableAll = [ "papa" ];          # everything from the papa source
        };
      in {
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          packages = [
            papanix-ai.packages.${system}.default
            sandboxedClaude
          ];
          # Only the skills hook — no MCP setup.
          shellHook = papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;};
        };
      }
    );
}
