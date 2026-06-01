# NOTE: CHANGE ONLY "NOTE" SECTIONS
# all changes made by you are at your own risk!
{
  description = "A minimal example with comments to modify";
  # External dependencies, pinned at flake.lock
  # To update do `nix flake update`
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # Base repository
    papanix-ai.url = "github:fmgordillo-dyna/papanix-ai"; # This repository
    flake-utils.url = "github:numtide/flake-utils"; # Helper to compile in MacOS + Linux
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    papanix-ai,
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        # We build packages for both MacOS and Linux
        pkgs = nixpkgs.legacyPackages.${system};

        # We create the `bundle` to ingest it into `papanix-ai` SKILL generation
        bundle = papanix-ai.lib.mkBundle {
          inherit pkgs;
          # NOTE: You can enable all skills
          # enableAll = true;
          # Or enable certain skills
          # enable = ["create-epic" "dt-github"];
        };

        # NOTE: MCP servers wired into .mcp.json on shell entry, wiped on exit.
        # Override `servers` to add/replace entries; defaults ship Dynatrace MCP
        # which needs DT_API_TOKEN + DT_ENVIRONMENT in your env.
        mcpServers = papanix-ai.lib.mcp.defaultServers;

        # NOTE: Claude Code plugin marketplaces wired into .claude/settings.json
        # on shell entry, wiped on exit. Claude Code clones each marketplace and
        # installs the listed plugins on first project trust.
        # Defaults register papa-ai-knowledgebase + rnd-ai-knowledgebase.
        pluginMarketplaces = papanix-ai.lib.plugins.defaultMarketplaces;
      in {
        # Here lives `dtctl` and frieds to use individually
        packages = papanix-ai.packages.${system};

        # Here we make `nix develop` magic happen:
        devShells.default = pkgs.mkShellNoCC {
          # We make `dtctl` and other packages available at PATH level
          packages = [papanix-ai.packages.${system}.default];
          # Run the SKILL + MCP + Claude plugins installers
          shellHook = ''
            ${papanix-ai.lib.mkShellHook {inherit pkgs bundle;}}
            ${papanix-ai.lib.mcp.mkShellHook {
              inherit pkgs;
              servers = mcpServers;
            }}
            ${papanix-ai.lib.plugins.mkShellHook {
              inherit pkgs;
              marketplaces = pluginMarketplaces;
              # NOTE: Pick individual plugins ("<mpKey>/<pluginName>"):
              # enable = ["papa/papa-jira" "rnd/dt-github"];
              # Or bulk-enable everything from the listed marketplaces:
              enableAll = true;
            }}
          '';
        };
      }
    );
}
