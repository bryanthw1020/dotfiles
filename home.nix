{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # mise owns Node version management (see programs.mise below). Non-interactive
  # shells do not source .zshrc, so expose mise's shims dir from .zshenv
  # (envExtra). The check keeps nested shells from stacking PATH entries.
  miseShims = ''
    case ":$PATH:" in
      *":$HOME/.local/share/mise/shims:"*) ;;
      *) export PATH="$HOME/.local/share/mise/shims:$PATH" ;;
    esac
  '';
  # GUI/extension processes (VS Code server, kilo serve) don't source a shell
  # profile either, so mise's shims never reach them. The Nix profile bin dir is
  # on their PATH, so a shim here resolves mise's npx on demand. Not a second
  # Node: it just dispatches to whatever mise currently has installed.
  npxShim = pkgs.writeShellScriptBin "npx" ''
    mise_shims="$HOME/.local/share/mise/shims"
    export PATH="$mise_shims:$PATH"
    exec "$mise_shims/npx" "$@"
  '';
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";

  # Skip the generated `man home-configuration.nix` page. It renders the
  # nixpkgs `meta.maintainers` option, whose declaration site is a raw nixpkgs
  # store path; nixosOptionsDoc strips string context from that JSON, so
  # Determinate Nix warns about a dangling store reference on every rebuild.
  # The page is cosmetic, so dropping it keeps rebuilds quiet.
  manual.manpages.enable = false;
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    npxShim   # npx for GUI/extension processes; dispatches to mise's Node
    # agent tooling
    treehouse    # isolated git worktrees so parallel jobs can't collide
    no-mistakes  # review-and-test gate for PR work
    pi           # terminal coding agent; flake pins the upstream release
    # Flutter/Dart development. `flutter` bundles a matching Dart SDK, so it
    # provides both `flutter` and `dart`; do not also add `dart` here or the two
    # packages collide on bin/dart in the profile.
    flutter
    # VS Code is the official Microsoft build, installed via the Homebrew cask
    # in configuration.nix (MS Marketplace). It is not managed here on purpose:
    # nixpkgs only ships Code - OSS, and a second install would duplicate `code`.
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    envExtra = miseShims;
    initContent = ''
      bindkey '^f' autosuggest-accept

      # SSH sessions (including Tailscale SSH) don't run the GUI login that
      # unlocks the login keychain, so keychain-backed tools fail. Unlock once
      # per connection; KEYCHAIN_UNLOCKED guards the nested-shell case. The
      # variable is session-local, so a fresh SSH login prompts again.
      if [ -n "$SSH_CONNECTION" ] && [ -z "$KEYCHAIN_UNLOCKED" ]; then
        echo "🔑 SSH session detected. Unlocking Mac login keychain..."
        security unlock-keychain ~/Library/Keychains/login.keychain-db
        export KEYCHAIN_UNLOCKED=true
      fi
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  # Node version manager (replaces Laravel Herd's bundled nvm). The global
  # default is pinned here; per-project versions come from a repo's .mise.toml
  # or .nvmrc. PHP and composer stay on Homebrew, not mise.
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.tools = {
      node = "22";
      # firebase-tools comes from mise's npm backend, not the brew `firebase-cli`
      # formula: that formula hardcodes its shebang to Homebrew's own node, so it
      # ignored mise entirely. Installed here it runs on mise's node.
      "npm:firebase-tools" = "latest";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".config/opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/opencode/opencode.json";
  home.file.".config/kilo/kilo.jsonc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kilo/kilo.jsonc";
  # TUI plugins are a separate config surface from kilo.jsonc; tui.json lists
  # them explicitly (there is no directory auto-discovery).
  home.file.".config/kilo/tui.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kilo/tui.json";
  home.file.".config/kilo/tui-plugins".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/kilo/tui-plugins";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Agent rules
  home.file.".agents/rules".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/rules";
  home.file.".codebuddy/rules".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/rules";
  home.file.".kilo/rules".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.agents/rules";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  # Antigravity specific
  home.file.".gemini/config/config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.gemini/config/config.json";
  home.file.".gemini/config/mcp_config.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.gemini/config/mcp_config.json";
  home.file.".gemini/antigravity-cli/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.gemini/antigravity-cli/settings.json";

  # AGENTS.md setup
  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".gemini/GEMINI.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/kilo/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
