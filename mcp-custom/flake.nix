# mcp-custom — skills + MCP with an extra server added.
#
# Shows how to extend the default MCP server set (Dynatrace MCP + Juno MCP)
# with your own entry — e.g. a local stdio server or a third-party HTTP MCP —
# while keeping the ephemeral install/wipe semantics.
#
# Both .claude/ AND .mcp.json + opencode.jsonc are wiped on shell exit.
{
  description = "papanix-ai: devShell with all skills + custom MCP servers";

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

        # NOTE: Extend the default server set instead of replacing it,
        # so you keep Dynatrace MCP + Juno MCP and add your own.
        # Schema is whatever mcp-servers-nix accepts (claude-code flavor).
        mcpServers =
          papanix-ai.lib.mcp.defaultServers
          // {
            # Local stdio server example
            filesystem = {
              command = "npx";
              args = ["-y" "@modelcontextprotocol/server-filesystem" "/tmp"];
            };
            # HTTP server with bearer token from env example
            # github = {
            #   type = "http";
            #   url = "https://api.githubcopilot.com/mcp/";
            #   headers.Authorization = "Bearer \${GITHUB_TOKEN}";
            # };
          };
      in {
        packages = papanix-ai.packages.${system};

        devShells.default = pkgs.mkShellNoCC {
          packages = [papanix-ai.packages.${system}.default];
          shellHook = ''
            ${papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;}}
            ${papanix-ai.lib.mcp.mkShellHook {
              inherit pkgs;
              servers = mcpServers;
            }}
          '';
        };
      }
    );
}
