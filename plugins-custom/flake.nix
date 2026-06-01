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
#   nix eval github:fmgordillo-dyna/papanix-ai#lib.plugins.defaultMarketplaces \
#     --apply 'builtins.attrNames' --json
{
  description = "papanix-ai: devShell with skills + curated Claude Code plugins";

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

        bundle = papanix-ai.lib.skills.mkBundle {
          inherit pkgs;
          enableAll = true;
        };
      in {
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          packages = [papanix-ai.packages.${system}.default];
          shellHook = ''
            ${papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;}}
            ${papanix-ai.lib.plugins.mkShellHook {
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
              # `path` is a vendored flake input — required for hermetic
              # plugin enumeration. Omit `path` for register-only (Claude
              # Code shows the marketplace but no auto-enable possible).
              # marketplaces = papanix-ai.lib.plugins.defaultMarketplaces // {
              #   my-mp = {
              #     name   = "my-mp";
              #     source = { source = "github"; repo = "my-org/my-marketplace"; };
              #     path   = inputs.my-mp;
              #   };
              # };
            }}
          '';
        };
      }
    );
}
