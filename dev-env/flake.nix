# dev-env — papanix-ai CLIs + opt-in per-contributor dev tooling.
#
# `lib.devEnv.mk` bundles things individual contributors usually want
# in their shell but that don't belong in the core PAPA CLI set:
#
#   • Node.js (+ npm bundled, opt-in corepack for pnpm/yarn shims)
#   • Playwright (browsers prebuilt by nixpkgs; env vars wired so
#     `npx playwright` reuses them instead of downloading at runtime)
#   • Arbitrary extra packages
#
# Returns `{ packages; shellHook; }` — splice both into your devShell.
# Nothing is written to or wiped from your project tree (this is NOT
# an ephemeral feature module).
#
# No skills, no MCP, no Claude plugins by default — copy the relevant
# `mkShellHook` calls from `default/flake.nix` if you want them too.
# Sandboxed `claude` is still on PATH so contributors can use it without
# wiring any repo-local Claude settings.
{
  description = "papanix-ai: CLIs + sandboxed claude + opt-in per-contributor dev environment";

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

        # NOTE: Toggle the bits you want. Every key is optional; omit /
        # set to `false` to leave it out.
        devEnv = papanix-ai.lib.devEnv.mk {
          inherit pkgs;

          # nodejs — `true` for defaults, or an attrset:
          #   version       — nixpkgs attr name. Default "nodejs" (LTS).
          #                   Examples: "nodejs_20", "nodejs_22", "nodejs_23".
          #   withCorepack  — adds the `corepack` package for pnpm/yarn shims.
          nodejs = {
            version = "nodejs_22";
            withCorepack = true;
          };

          # playwright — `true` for defaults (driver + browsers + env vars
          # so `npx playwright` reuses the Nix-built browser bundle), or:
          #   withBrowsers — false to skip the prebuilt browsers and manage
          #                  them yourself.
          playwright = true;

          # Verbatim list appended to the result — handy for ad-hoc
          # global tooling that doesn't have a dedicated knob.
          # extraPackages = with pkgs.nodePackages; [ typescript prettier ];
        };
      in {
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          packages =
            # PAPA CLIs plus sandboxed `claude`.
            [
              papanix-ai.packages.${system}.default
              sandboxedClaude
            ]
            ++ devEnv.packages;

          # Playwright env vars live here.
          shellHook = devEnv.shellHook;
        };
      }
    );
}
