# library — consume papanix-ai purely as a skill catalog provider.
#
# No CLIs on PATH. No MCP. Just the skill bundle installed into your
# project. Useful when:
#   - You already manage Go/CLI tools yourself.
#   - You want to compose papanix-ai skills with your own packages.
#   - You're building your own derivation/devShell on top.
#
# Demonstrates the `lib.skills.mkShellHook` + `lib.mkEphemeralShellHook`
# composer for combining multiple features (skills, custom hooks, etc.)
# into one shellHook with a shared EXIT trap.
{
  description = "papanix-ai: library-only consumer (skills, no CLIs, no MCP)";

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
          enable = ["dt-github" "dt-jira"];

          # NOTE: To include skills from a local directory:
          # extraSources = {
          #   local = { path = ./skills; subdir = "."; };
          # };
          # enableAll = ["local"]; # enable all from that source
          # enable = ["local/my-skill"]; # or specific ones
        };
      in {
        devShells.default = pkgs.mkShellNoCC {
          # NOTE: Bring your OWN packages. papanix-ai CLIs are not on PATH.
          packages = with pkgs; [
            go
            jq
            ripgrep
          ];

          shellHook = papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;};
        };
      }
    );
}
