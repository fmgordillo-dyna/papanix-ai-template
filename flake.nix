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
          Batteries included: CLIs + sandboxed claude on PATH, all skills,
          and the default MCP server set. Perfect to bootstrap a PAPA project.
        '';
        path = ./default;
      };
      minimal = {
        description = ''
          CLIs plus sandboxed claude on PATH.
          No skills, no MCP. Nothing wiped on shell exit.
        '';
        path = ./minimal;
      };
      skills-only = {
        description = ''
          Curated subset of AI skills plus sandboxed claude on PATH.
          No MCP. Good starting point for tailoring the skill catalog.
        '';
        path = ./skills-only;
      };
      mcp-custom = {
        description = ''
          All skills + sandboxed claude + MCP with an extra server added on
          top of lib.mcp.defaultServers. Shows how to extend the canned set.
        '';
        path = ./mcp-custom;
      };
      plugins-custom = {
        description = ''
          All skills + sandboxed claude + curated Claude Code plugin
          marketplaces. Generates project-scope .claude/settings.json that
          auto-enables plugins from papa-ai-knowledgebase / rnd-ai-knowledgebase.
        '';
        path = ./plugins-custom;
      };
      library = {
        description = ''
          Consume papanix-ai purely as a library (skill catalog).
          No CLIs on PATH, no MCP. Bring your own packages.
        '';
        path = ./library;
      };
      dev-env = {
        description = ''
          CLIs + sandboxed claude on PATH + opt-in per-contributor dev
          tooling via lib.devEnv.mk: Node.js / npm / corepack and Playwright
          with nixpkgs-built browsers. Bring your own MCP / skills / plugins.
        '';
        path = ./dev-env;
      };
      home-manager = {
        description = ''
          USER-SCOPE install via Home-Manager: skills, Claude Code
          settings, MCP servers, PAPA CLIs, and sandboxed claude land in
          $HOME and persist across every repo you open. Project devShells
          still layer on top.
        '';
        path = ./home-manager;
      };
    };
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
