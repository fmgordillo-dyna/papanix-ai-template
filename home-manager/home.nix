# home.nix — user-scope papanix-ai configuration.
#
# Fill in the `# TODO:` markers below before running
# `home-manager switch`. The `# NOTE:` markers are optional tweaks.
#
# For a guided walkthrough, run `/papanix-ai-home-manager-setup`
# inside Claude Code. For the full option matrix, see
# `../docs/home-manager.md`.
{
  pkgs,
  papanix-ai,
  ...
}: {
  # ── Identity ─────────────────────────────────────────────────────────
  # TODO: Change these to match your account. They must match the
  # `homeConfigurations.<name>` key in flake.nix (here: "me").
  home.username = "me";
  home.homeDirectory = "/home/me"; # macOS: "/Users/me"

  # Home-Manager's own state version. Pin once; bump when you've read
  # the release notes. See:
  # https://nix-community.github.io/home-manager/release-notes.html
  home.stateVersion = "24.05";

  # ── papanix-ai (global skills / MCP / Claude settings / CLIs) ────────
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
      # NOTE: Add custom servers on top of the defaults, or replace.
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
        # switch time. Switch to "snippet" if you haven't installed
        # claude-code yet — that writes
        # ~/.config/papanix-ai/mcp-servers.json and you run
        # `claude mcp import-json …` once.
        # strategy = "snippet";
      };

      # opencode at user scope (writes ~/.config/opencode/opencode.jsonc).
      opencode.enable = true;
    };

    # ── PAPA CLIs on PATH (~/.nix-profile/bin/…) ──────────────────────
    cliTools = {
      enable = true;

      # NOTE: Defaults install ALL FOUR. `acli-pii` requires
      # `home-manager switch --flake … --impure` because it is fetched
      # from a private Bitbucket repo via SSH at evaluation time. Drop
      # it from the list for a pure build:
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

  # ── Anything else you want in your $HOME ─────────────────────────────
  # NOTE: This is a regular Home-Manager file — add programs, files,
  # session variables freely below. The papanix-ai block above is
  # self-contained and does not conflict with the rest of HM.
  # home.packages = with pkgs; [ jq gh ];
  # programs.git = { enable = true; userName = "Me"; userEmail = "me@example.com"; };
}
