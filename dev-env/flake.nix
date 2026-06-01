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
{
  description = "papanix-ai: CLIs + opt-in per-contributor dev environment";

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
        pkgs = nixpkgs.legacyPackages.${system};

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
            # PAPA CLIs.
            [papanix-ai.packages.${system}.default]
            ++ devEnv.packages;

          # Playwright env vars live here.
          shellHook = devEnv.shellHook;
        };
      }
    );
}
