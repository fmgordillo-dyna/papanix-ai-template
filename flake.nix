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
          Batteries included: CLIs on PATH + all skills + Dynatrace MCP.
          Perfect to bootstrap a PAPA project with AI tools.
        '';
        path = ./default;
      };
      minimal = {
        description = ''
          CLIs only (acli-pii, aimgr, dtctl, junoctl) on PATH.
          No skills, no MCP. Nothing wiped on shell exit.
        '';
        path = ./minimal;
      };
      skills-only = {
        description = ''
          Curated subset of AI skills installed into .claude/ and .opencode/.
          No MCP. Good starting point for tailoring the skill catalog.
        '';
        path = ./skills-only;
      };
      mcp-custom = {
        description = ''
          All skills + MCP with an extra server added on top of the
          default Dynatrace MCP. Shows how to extend lib.mcp.defaultServers.
        '';
        path = ./mcp-custom;
      };
      plugins-custom = {
        description = ''
          All skills + curated Claude Code plugin marketplaces.
          Generates project-scope .claude/settings.json that auto-enables
          plugins from papa-ai-knowledgebase / rnd-ai-knowledgebase.
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
          CLIs on PATH + opt-in per-contributor dev tooling via
          lib.devEnv.mk: Node.js / npm / corepack and Playwright with
          nixpkgs-built browsers. Bring your own MCP / skills / plugins.
        '';
        path = ./dev-env;
      };
    };
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
