# mcp-custom — MCP with an extra server added.
#
# Shows how to extend the default MCP server set (Dynatrace MCP + Juno MCP)
# with your own entry — e.g. a local stdio server or a third-party HTTP MCP —
# while keeping the ephemeral install/wipe semantics.
#
# Both .mcp.json and opencode.jsonc are wiped on shell exit.
{
  description = "papanix-ai: devShell with sandboxed claude + custom MCP servers";

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
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # NOTE: Customize the sandboxed `claude` wrapper here.
        sandbox = import (papanix-ai + "/vendor/agent-sandbox-nix") {inherit pkgs;};
        sandboxedClaude = sandbox.mkSandbox {
          pkg = pkgs.claude-code;
          binName = "claude";
          outName = "claude";
          # If you have your own package attrset, flatten it first:
          #   builtins.attrValues myPkgs ++ (with pkgs; [ git ripgrep ])
          # `allowedPackages = [ myPkgs ];` fails with "cannot coerce a set to a string".
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
          # NOTE: Only used when `restrictNetwork = true;`.
          # allowedDomains = {
          #   "api.anthropic.com" = true;
          #   "github.com" = true;
          # };
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
          packages = [
            papanix-ai.packages.${system}.default
            sandboxedClaude
          ];
          shellHook = papanix-ai.lib.mcp.mkShellHook {
            inherit pkgs;
            servers = mcpServers;
          };
        };
      }
    );
}
