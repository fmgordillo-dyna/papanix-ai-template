# home-manager — papanix-ai at USER scope.
#
# This is a starter Home-Manager configuration that installs the
# papanix-ai skills, Claude Code settings, MCP servers, and PAPA CLIs
# globally — into your $HOME, available across every repo you open.
#
# Differences from the project-scope templates (default/, skills-only/,
# …): those drop files into $PWD/.claude/ etc. and wipe them on
# `nix develop` exit. THIS template lives in your $HOME and persists.
# Per-project devShells still work and layer on top — project scope
# wins on duplicate keys.
#
# Apply with:
#   home-manager switch --flake .#me --impure
#
# `--impure` is required while `acli-pii` is in cliTools.selection
# (fetched from a private Bitbucket repo over SSH at eval time). Drop
# it for a pure build — see ./home.nix.
#
# If you're new to Home-Manager: https://nix-community.github.io/home-manager/
{
  description = "papanix-ai user-scope (Home-Manager) starter";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai";
  };

  outputs = {
    nixpkgs,
    home-manager,
    papanix-ai,
    ...
  }: let
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
  in {
    packages = forAllSystems (system: nixpkgs.legacyPackages.${system});
    # TODO: rename "me" to your username. The `home.username` /
    # `home.homeDirectory` fields in ./home.nix must match.
    inherit pkgs;
    homeConfigurations."me" = home-manager.lib.homeManagerConfiguration {
      modules = [
        # 1. Pull in the papanix-ai module — this is what exposes
        #    `programs.papanix-ai.*` in ./home.nix.
        papanix-ai.homeManagerModules.default

        # 2. Your actual configuration.
        ./home.nix
      ];

      # Pass the papanix-ai flake into ./home.nix so we can reference
      # its defaults (lib.mcp.defaultServers, etc.).
      extraSpecialArgs = {inherit papanix-ai;};
    };
  };
}
