# plugins-custom — skills + Claude Code plugin marketplaces (custom pick).
#
# Generates a project-scope `.claude/settings.json` that pre-registers
# Claude Code plugin marketplaces (`extraKnownMarketplaces`) and
# pre-enables individual plugins (`enabledPlugins`). Claude Code clones
# each marketplace and installs the listed plugins automatically on
# first project trust — no manual `/plugin marketplace add` /
# `/plugin install` dance.
#
# Plugin enumeration is hermetic: at flake-eval time we read the
# vendored input's `.claude-plugin/marketplace.json`, so the enabled
# set always matches the pinned `flake.lock` revision.
#
# Both `.claude/` (skills + settings.json) is wiped on shell exit.
#
# List available plugins per marketplace:
#   nix eval github:fmgordillo-dyna/papanix-ai#lib.claudeSettings.defaultMarketplaces \
#     --apply 'builtins.attrNames' --json
{
  description = "papanix-ai: devShell with skills + sandboxed claude + curated Claude Code plugins";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ {
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

        bundle = papanix-ai.lib.skills.mkBundle {
          inherit pkgs;
          enableAll = true;
        };
      in {
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          packages = [
            papanix-ai.packages.${system}.default
            sandboxedClaude
          ];
          shellHook = ''
            ${papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;}}
            ${papanix-ai.lib.claudeSettings.mkShellHook {
              inherit pkgs;

              # NOTE: Pick individual plugins as "<mpKey>/<pluginName>".
              # `mpKey` is the attr key in `marketplaces` (papa, rnd, …),
              # `pluginName` matches the marketplace.json `plugins[].name`.
              enable = [
                "papa/papa-jira"
                "rnd/dt-github"
                "rnd/dt-adr"
                "rnd/dt-skill-creator"
              ];

              # Alternatives:
              # enableAll = true;          # every plugin in every marketplace
              # enableAll = ["rnd"];       # everything from the rnd marketplace

              # NOTE: Extend the default marketplaces with your own.
              # In downstream flakes, custom marketplaces use explicit
              # Claude Code `source` metadata plus a discovery `path`.
              # Add `my-mp` as a flake input first; if the marketplace is
              # below repo root, point `path` at that subdirectory.
              # marketplaces = papanix-ai.lib.claudeSettings.defaultMarketplaces // {
              #   my-mp = {
              #     name = "my-mp";
              #     source = { source = "github"; repo = "my-org/my-mp"; };
              #     path = inputs.my-mp + "/plugins";
              #   };
              # };

              # NOTE: Inject your own Claude Code settings (permissions, etc.)
              # alongside the plugin config — omit when not needed.
              # settings = {
              #   permissions = {
              #     allow = [ "Bash(git:*)" "Read(**)" ];
              #     deny  = [];
              #   };
              # };
            }}
          '';
        };
      }
    );
}
