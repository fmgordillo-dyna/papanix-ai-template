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
        # We build packages for both MacOS and Linux.
        # allowUnfree is required because the sandbox wraps `claude-code`.
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # NOTE: Customize the sandboxed `claude` wrapper here. Anything in
        # `allowedPackages` lands on PATH inside the sandbox. `stateDirs` /
        # `stateFiles` persist across runs. `extraEnv` passes selected env vars
        # through. `allowedDomains` only applies when `restrictNetwork = true;`.
        sandbox = import (papanix-ai + "/vendor/agent-sandbox-nix") {inherit pkgs;};
        sandboxedClaude = sandbox.mkSandbox {
          pkg = pkgs.claude-code;
          binName = "claude";
          outName = "claude";
          allowedPackages = with pkgs; [
            coreutils
            which
            git
            ripgrep
            fd
            gnused
            gnugrep
            findutils
            diffutils
            less
            gawk
            jq
            curl
            nodejs
          ];
          stateDirs = [
            "$HOME/.claude"
            "$HOME/.npm"
            "$HOME/.cache/claude"
          ];
          stateFiles = [];
          extraEnv = {
            CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
            ANTHROPIC_API_KEY = "$ANTHROPIC_API_KEY";
            GITHUB_TOKEN = "$GITHUB_TOKEN";
            CLAUDE_CONFIG_DIR = "$HOME/.claude";
            GIT_AUTHOR_NAME = "claude";
            GIT_AUTHOR_EMAIL = "claude@localhost";
            GIT_COMMITTER_NAME = "claude";
            GIT_COMMITTER_EMAIL = "claude@localhost";
          };
          restrictNetwork = false;
          # allowedDomains = {
          #   "api.anthropic.com" = true;
          #   "github.com" = true;
          # };
        };

        # We create the `bundle` to ingest it into `papanix-ai` SKILL generation
        bundle = papanix-ai.lib.skills.mkBundle {
          inherit pkgs;
          # NOTE: You can enable all skills
          # enableAll = true;
          # NOTE: Or enable certain skills
          # enable = ["create-epic" "dt-github"];

          # NOTE: To include skills from a local directory, add an extraSources
          # entry and reference its key in `enable` or `enableAll`:
          # extraSources = {
          #   local = { path = ./skills; subdir = "."; };
          # };
          # enableAll = ["local"]; # enable all skills from that source
          # enable = ["local/my-skill"]; # or enable specific ones
        };
        # NOTE: MCP servers wired into .mcp.json and opencode.jsonc on shell
        # entry, wiped on exit. Override `servers` to add/replace entries;
        # defaults ship Dynatrace MCP (needs DT_API_TOKEN + DT_ENVIRONMENT)
        # and Juno MCP (no env vars required).
        mcpServers = papanix-ai.lib.mcp.defaultServers;
        # NOTE: Claude Code plugin marketplaces wired into .claude/settings.json
        # on shell entry, wiped on exit. Claude Code clones each marketplace and
        # installs the listed plugins on first project trust.
        # Defaults register papa-ai-knowledgebase + rnd-ai-knowledgebase.
        pluginMarketplaces = papanix-ai.lib.claudeSettings.defaultMarketplaces;
        # NOTE: Per-contributor dev tooling (Node.js / npm / Playwright …)
        # via `lib.devEnv.mk`. Returns `{ packages; shellHook; }` — splice
        # `devEnv.packages` into the shell's `packages` list and
        # `${devEnv.shellHook}` into the shellHook string. See the
        # `dev-env` template for a dedicated example.
        # devEnv = papanix-ai.lib.devEnv.mk {
        #   inherit pkgs;
        #   nodejs     = { version = "nodejs_22"; withCorepack = true; };
        #   playwright = true;
        #   # extraPackages = with pkgs.nodePackages; [ typescript prettier ];
        # };
      in {
        # Here lives `dtctl` and frieds to use individually
        packages = papanix-ai.packages.${system};

        # Here we make `nix develop` magic happen:
        devShells.default = pkgs.mkShellNoCC {
          # We make the PAPA CLIs plus sandboxed `claude` available on PATH.
          packages =
            [
              papanix-ai.packages.${system}.default
              sandboxedClaude
            ]
            # NOTE: Add nodejs, playwright, etc to your project
            # ++ devEnv.packages
            ;
          # Run the SKILL + MCP + Claude plugins installers
          shellHook = ''
            ${papanix-ai.lib.skills.mkShellHook {inherit pkgs bundle;}}
            ${papanix-ai.lib.mcp.mkShellHook {
              inherit pkgs;
              servers = mcpServers;
            }}
            ${papanix-ai.lib.claudeSettings.mkShellHook {
              inherit pkgs;
              marketplaces = pluginMarketplaces;

              # NOTE: Pick individual plugins ("<mpKey>/<pluginName>"):
              # enable = ["papa/papa-jira" "rnd/dt-github"];
              # Or bulk-enable everything from the listed marketplaces:
              # enableAll = true;

              # NOTE: Inject your own Claude Code settings (permissions, etc.)
              # alongside the plugin config — omit when not needed:
              # settings = {
              #   permissions = {
              #     allow = [ "Bash(git:*)" "Read(**)" ];
              #     deny  = [];
              #   };
              # };
            }}
            # ''${devEnv.shellHook}
          '';
        };
      }
    );
}
