{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  # Laravel Herd owns Node; expose it to login/non-interactive shells so
  # processes launched from them (VS Code, agents, `kilo mcp`) find node/npx.
  nvmInit = ''
    export NVM_DIR="$HOME/Library/Application Support/Herd/config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  '';
  # GUI/extension processes (VS Code server, kilo serve) don't source a shell
  # profile, so Herd's Node never reaches them. The Nix profile bin dir is on
  # their PATH, so a shim here resolves Herd's npx on demand. Not a second
  # Node: it just dispatches to whatever Herd currently has active.
  npxShim = pkgs.writeShellScriptBin "npx" ''
    export NVM_DIR="$HOME/Library/Application Support/Herd/config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    node_bin="$(dirname "$(command -v node)")"
    exec "$node_bin/npx" "$@"
  '';
  # Herd owns PHP too (php, composer, herd CLIs live in its bin dir). Its
  # installer can't add this itself because home-manager owns the shells.
  # Lives in .zshenv (envExtra), not home.sessionPath: session vars are
  # guarded once per process tree, so shells spawned under long-running
  # processes started before a rebuild (herdr, VS Code, kilo) would never
  # see the new PATH. .zshenv is re-read by every zsh, so those shells
  # self-heal. The check keeps nested shells from stacking PATH entries.
  # ./php is a Herd-managed symlink; switching versions follows along.
  herdPath = ''
    case ":$PATH:" in
      *":$HOME/Library/Application Support/Herd/bin:"*) ;;
      *) export PATH="$HOME/Library/Application Support/Herd/bin:$PATH" ;;
    esac
  '';
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    npxShim   # npx for GUI/extension processes; dispatches to Herd's Node
    # agent tooling
    treehouse    # isolated git worktrees so parallel jobs can't collide
    no-mistakes  # review-and-test gate for PR work
    # the font everything renders in
    nerd-fonts.hack
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    envExtra = herdPath;
    # Login shells: GUI apps and agents (VS Code, kilo) launched from one
    # inherit this environment. .zshrc alone only reaches interactive shells.
    profileExtra = nvmInit;
    initContent = ''
      bindkey '^f' autosuggest-accept
      ${nvmInit}
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
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";
  home.file.".kilo/rules".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.kilo/rules";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/kilo/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
