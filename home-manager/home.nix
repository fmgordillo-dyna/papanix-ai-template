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
  home.stateVersion = "26.05";

  # ── papanix-ai (CLIs / sandboxed claude) ─────────────────────────────
  programs.papanix-ai = {
    enable = true;

    # ── PAPA CLIs on PATH (~/.nix-profile/bin/…) ──────────────────────
    cliTools = {
      enable = true;
      selection = ["acli-pii" "bbctl" "dtctl" "junoctl"];

      # NOTE: Drop `acli-pii` for a pure switch:
      # selection = [ "bbctl" "dtctl" "junoctl" ];
    };

    # ── Sandboxed Claude Code wrapper ─────────────────────────────────
    sandboxing = {
      enable = true;

      # NOTE: Safe defaults are already included inside the wrapper:
      # git, rg, fd, jq, curl, file, tree, tar, zip, unzip, node, and
      # the PAPA CLIs. Add only what you need beyond that.
      # extraAllowedPackages = with pkgs; [ gh kubectl ];

      # NOTE: Persist extra tool state or individual config files.
      # extraRwDirs = [ "$HOME/.config/gh" "$HOME/.kube" ];
      # extraRwFiles = [ "$HOME/.gitconfig" ];

      # NOTE: Bind read-only config into the sandbox when needed.
      # extraRoDirs = [ "$HOME/.config/some-readonly-tree" ];
      # extraRoFiles = [ "$HOME/.config/readonly.conf" ];
      extraRwDirs = ["$HOME/.acli-pii" "$HOME/.config/bbctl"];

      # NOTE: Pass extra env vars through to the sandboxed process.
      # extraEnv = {
      #   GH_TOKEN = "$GH_TOKEN";
      #   KUBECONFIG = "$HOME/.kube/config";
      # };

      # NOTE: Keep fully open by default. Tighten only if wanted.
      # restrictNetwork = true;
      # allowedDomains = {
      #   "github.com" = [ "GET" "HEAD" ];
      #   "api.anthropic.com" = "*";
      # };
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
