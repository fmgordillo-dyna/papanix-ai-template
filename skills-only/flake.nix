# skills-only — install a curated set of AI skills, no MCP.
#
# Picks specific skills from the papanix-ai catalog and installs them
# ephemerally into .claude/ and .opencode/ on `nix develop` entry.
# .claude/ and .opencode/ are wiped on shell exit (see warning in
# papanix-ai/docs/how-skill-install-works.md).
#
# List available skill IDs with:
#   nix eval github:fmgordillo-dyna/papanix-ai#lib.catalog \
#     --apply builtins.attrNames --json
{
  description = "papanix-ai: devShell with a curated skill subset, no MCP";

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

        # NOTE: Pick the skills you want here. IDs match the catalog.
        bundle = papanix-ai.lib.mkBundle {
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
          packages = [papanix-ai.packages.${system}.default];
          # Only the skills hook — no MCP setup.
          shellHook = papanix-ai.lib.mkShellHook {inherit pkgs bundle;};
        };
      }
    );
}
