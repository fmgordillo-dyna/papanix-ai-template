{
  description = "A minimal example with comments to modify";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # Base repository
  };

  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  in {
    templates = {
      default = {
        description = ''
          Batteries included: CLIs + sandboxed claude on PATH
          and the default MCP server set. Perfect to bootstrap a PAPA project.
        '';
        path = ./default;
      };
      minimal = {
        description = ''
          CLIs plus sandboxed claude on PATH.
          No MCP. Nothing wiped on shell exit.
        '';
        path = ./minimal;
      };
      mcp-custom = {
        description = ''
          Sandboxed claude + MCP with an extra server added on
          top of lib.mcp.defaultServers. Shows how to extend the canned set.
        '';
        path = ./mcp-custom;
      };
      dev-env = {
        description = ''
          CLIs + sandboxed claude on PATH + opt-in per-contributor dev
          tooling via lib.devEnv.mk: Node.js / npm / corepack and Playwright
          with nixpkgs-built browsers. Bring your own MCP.
        '';
        path = ./dev-env;
      };
      home-manager = {
        description = ''
          USER-SCOPE install via Home-Manager: PAPA CLIs and sandboxed claude
          in $HOME. MCP stays in the project devShell.
        '';
        path = ./home-manager;
      };
    };
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
