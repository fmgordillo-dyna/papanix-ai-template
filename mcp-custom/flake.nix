# mcp-custom — MCP with an extra server added.
#
# Shows how to extend the default MCP server set (Dynatrace MCP + Juno MCP)
# with your own entry — e.g. a local stdio server or a third-party HTTP MCP —
# while keeping the ephemeral install/wipe semantics.
#
# Both .mcp.json and opencode.jsonc are wiped on shell exit.
{
  description = "papanix-ai: devShell with sandboxed `claude` + custom MCP servers";

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

        cliPackages = with papanix-ai.packages.${system}; [
          acli-pii
          aimgr
          bbctl
          dtctl
          junoctl
        ];

        # NOTE: Customize the sandboxed `claude` wrapper here.
        sandboxedClaude = papanix-ai.lib.sandboxing.mkClaudeSandbox {
          inherit pkgs cliPackages;
          claudePkg = pkgs.claude-code;

          # NOTE: Safe defaults already include the selected PAPA CLIs plus
          # common helpers like `git`, `rg`, `fd`, `jq`, `curl`, `file`,
          # `tree`, `tar`, `zip`, `unzip`, `node`, and `nix`.
          # extraAllowedPackages = with pkgs; [ gh kubectl ];

          # NOTE: Persist extra tool state or individual config files.
          # extraRwDirs = [ "$HOME/.config/gh" "$HOME/.kube" ];
          # extraRwFiles = [ "$HOME/.kube/config" ];

          # NOTE: Bind read-only config into the sandbox when needed.
          # extraRoDirs = [ "$HOME/.config/some-readonly-tree" ];
          # extraRoFiles = [ "$HOME/.gitconfig" ];

          # NOTE: Pass extra env vars through to the sandboxed process.
          # extraEnv = {
          #   GH_TOKEN = "$GH_TOKEN";
          #   KUBECONFIG = "$HOME/.kube/config";
          # };

          restrictNetwork = false;
          # NOTE: Only used when `restrictNetwork = true;`.
          # allowedDomains = {
          #   "github.com" = [ "GET" "HEAD" ];
          #   "api.anthropic.com" = "*";
          # };

          # NOTE: Enable if Claude needs SSH remotes from inside the sandbox.
          # exposeSsh = true;
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
          packages = cliPackages ++ [sandboxedClaude];
          shellHook = papanix-ai.lib.mcp.mkShellHook {
            inherit pkgs;
            servers = mcpServers;
          };
        };
      }
    );
}
