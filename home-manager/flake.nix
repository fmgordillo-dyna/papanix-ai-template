# home-manager — papanix-ai at USER scope.
#
# This is a starter Home-Manager configuration that installs the
# papanix-ai skills, Claude Code settings, MCP servers, PAPA CLIs, and
# sandboxed `claude` wrapper globally — into your $HOME, available
# across every repo you open.
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
  description = "papanix-ai user-scope (Home-Manager) starter with sandboxed claude";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai";

    # NOTE: Uncomment to add a custom Claude Code marketplace repo.
    # my-mp = {
    #   url = "github:my-org/my-mp";
    #   flake = false;
    # };
  };

  outputs = inputs @ {
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

    # Home-Manager is single-user / single-system, so it needs ONE `pkgs`
    # instance — not the per-system attrset above. Pick the system you run
    # `home-manager switch` on.
    # TODO: set this to match your machine.
    # Linux/WSL : "x86_64-linux" (or "aarch64-linux" on ARM)
    # macOS     : "aarch64-darwin" (Apple Silicon) or "x86_64-darwin" (Intel)
    hmSystem = "x86_64-linux";

    # NOTE: We import nixpkgs with allowUnfree because the customizable
    # sandbox wrapper in ./home.nix wraps `claude-code` locally.
    hmPkgs = import nixpkgs {
      system = hmSystem;
      config.allowUnfree = true;
    };
  in {
    packages = pkgs;

    # TODO: rename "me" to your username. The `home.username` /
    # `home.homeDirectory` fields in ./home.nix must match.
    homeConfigurations."me" = home-manager.lib.homeManagerConfiguration {
      pkgs = hmPkgs;
      modules = [
        # 1. Pull in the papanix-ai module — this is what exposes
        #    `programs.papanix-ai.*` in ./home.nix.
        papanix-ai.homeManagerModules.default

        # 2. Your actual configuration.
        ./home.nix
      ];

      # Pass the papanix-ai flake into ./home.nix so we can reference
      # its defaults (lib.mcp.defaultServers, etc.). If you add a custom
      # marketplace input above, also pass it here, e.g.
      #   extraSpecialArgs = { inherit papanix-ai; my-mp = inputs.my-mp; };
      extraSpecialArgs = {inherit papanix-ai;};
    };
  };
}
