# minimal — papanix-ai CLIs on PATH only.
#
# No skills installed into .claude/ or .opencode/.
# No .mcp.json generated.
# Nothing wiped on shell exit.
#
# Use this when you want the Dynatrace internal CLIs
# (acli-pii, bbctl, dtctl, junoctl) inside `nix develop`,
# but you manage your AI tooling separately (or not at all).
{
  description = "papanix-ai: minimal devShell — CLIs only, no skills, no MCP";

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
      in {
        # NOTE: Re-export the CLIs so `nix build .#dtctl` etc. works locally.
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          # All four CLIs on PATH. Drop the `.default` and list individual
          # packages if you only want a subset:
          #   packages = with papanix-ai.packages.${system}; [ dtctl bbctl ];
          packages = [papanix-ai.packages.${system}.default];
        };
      }
    );
}
