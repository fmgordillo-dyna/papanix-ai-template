# home.nix — user-scope papanix-ai configuration.
#
# Fill in the `# TODO:` markers below before running
# `home-manager switch`. The `# NOTE:` markers are optional tweaks.
#
# For a guided walkthrough, run `/papanix-ai-home-manager-setup`
# inside Claude Code. For the full option matrix, see
# `../docs/home-manager.md`.
{
  lib,
  pkgs,
  papanix-ai,
  ...
}: let
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
in {
  # ── Identity ─────────────────────────────────────────────────────────
  # TODO: Change these to match your account. They must match the
  # `homeConfigurations.<name>` key in flake.nix (here: "me").
  home.username = "me";
  home.homeDirectory = "/home/me"; # macOS: "/Users/me"

  # Home-Manager's own state version. Pin once; bump when you've read
  # the release notes. See:
  # https://nix-community.github.io/home-manager/release-notes.html
  home.stateVersion = "24.05";

  # ── papanix-ai (global skills / MCP / Claude settings / CLIs / claude) ─────
  programs.papanix-ai = {
    enable = true;

    # ── Skills (catalog of agent SKILL.md files) ──────────────────────
    # Lands under ~/.claude/skills/ by default. Add other agents under
    # `skills.targets` if you also use opencode / codex / cursor / etc.
    skills = {
      # NOTE: Bulk-enable everything from both knowledgebases, or pick:
      # enable = [ "papa/dt-jira" "rnd/dt-github" ];
      # enableAll = [ "rnd" ];   # every skill from source "rnd"
      enableAll = true;

      # NOTE: Enable other agent destinations. Defaults to claude only.
      # targets.opencode.enable = true;
      # targets.codex.enable    = true;
    };

    # ── Claude Code settings (~/.claude/settings.json) ────────────────
    # Two independent concerns: plugin marketplaces + arbitrary settings.
    claudeSettings = {
      # NOTE: Pre-enable plugin marketplaces. Either bulk:
      enableAll = true;
      # ...or curate:
      # enable = [ "papa/papa-jira" "rnd/dt-github" ];

      # NOTE: Register custom plugin marketplaces (merged with defaults).
      # In downstream flakes, custom marketplaces use explicit Claude
      # Code `source` metadata plus a discovery `path`. Pass `my-mp` via
      # `extraSpecialArgs` from flake.nix if you want to reference a
      # custom flake input here.
      # marketplaces = papanix-ai.lib.claudeSettings.defaultMarketplaces // {
      #   my-mp = {
      #     name = "my-mp";
      #     source = { source = "github"; repo = "my-org/my-mp"; };
      #     path = my-mp + "/plugins";
      #   };
      # };

      # NOTE: Custom Claude Code settings (permissions, hooks, env, …).
      # settings = {
      #   permissions = {
      #     allow = [ "Bash(git:*)" "Read(**)" ];
      #     deny  = [];
      #   };
      # };
    };

    # ── MCP (Model Context Protocol) ──────────────────────────────────
    mcp = {
      # NOTE: Home-Manager defaults to no MCP servers, so opt into the
      # canned set explicitly here.
      servers = papanix-ai.lib.mcp.defaultServers;

      # NOTE: To add custom servers on top, replace the line above with:
      # servers = papanix-ai.lib.mcp.defaultServers // {
      #   github = {
      #     type    = "stdio";
      #     command = "npx";
      #     args    = [ "-y" "@modelcontextprotocol/server-github" ];
      #     env     = { GITHUB_TOKEN = "\${GITHUB_TOKEN}"; };
      #   };
      # };

      # Claude Code at user scope. Cannot symlink ~/.claude.json
      # (the CLI writes mutable state into it), so we run
      # `claude mcp add-json --scope user` at activation time.
      claudeCode = {
        enable = true;

        # NOTE: "activation" (default) requires `claude` on PATH at HM
        # switch time. Switch to "snippet" if `claude` is not available
        # yet — that writes ~/.config/papanix-ai/mcp-servers.json and you
        # run `claude mcp import-json …` once.
        # strategy = "snippet";
      };

      # opencode at user scope (writes ~/.config/opencode/opencode.jsonc).
      opencode.enable = true;
    };

    # ── PAPA CLIs on PATH (~/.nix-profile/bin/…) ──────────────────────
    cliTools = {
      enable = true;
      selection = ["acli-pii" "bbctl" "dtctl" "junoctl"];

      # NOTE: Drop `acli-pii` for a pure switch:
      # selection = [ "bbctl" "dtctl" "junoctl" ];
    };

    # ── Per-contributor dev tooling (optional) ────────────────────────
    # NOTE: Uncomment to add Node.js / Playwright / arbitrary packages
    # at user scope. Same shape as lib.devEnv.mk.
    # devEnv = {
    #   enable     = true;
    #   nodejs     = { version = "nodejs_22"; withCorepack = true; };
    #   playwright = true;            # browsers + PLAYWRIGHT_* env vars
    #   # extraPackages = with pkgs; [ jq gh ];
    # };
  };

  # ── Sandboxed Claude Code wrapper ─────────────────────────────────
  # NOTE: We add the wrapper directly to `home.packages` so you can
  # customize `allowedPackages`, `stateDirs`, `extraEnv`, and network
  # policy above. `hiPrio` keeps this `claude` ahead of any raw one.
  home.packages = [(lib.hiPrio sandboxedClaude)];

  # ── Anything else you want in your $HOME ─────────────────────────────
  # NOTE: This is a regular Home-Manager file — add programs, files,
  # session variables freely below. The papanix-ai block above is
  # self-contained and does not conflict with the rest of HM.
  # home.packages = with pkgs; [ jq gh ];
  # programs.git = { enable = true; userName = "Me"; userEmail = "me@example.com"; };
}
