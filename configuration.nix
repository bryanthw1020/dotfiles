{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = false; # always show the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = false;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
  };
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      { name = "anomalyco/tap";       trusted = true; }
      { name = "kilo-org/tap";        trusted = true; }
      { name = "supabase/tap";        trusted = true; }
      { name = "teamookla/speedtest"; trusted = true; }
    ];
    brews = [
      "btop"
      "cocoapods"
      "ffmpeg"
      "gh"
      "go"
      "herdr"
      "kilo"
      "mysql-client"
      "openjdk"
      "opencode"
      "pandoc"
      "ripgrep"
      "railway"
      "speedtest"
      "supabase"
    ];
    casks = [
      "herd"
      "wezterm"
      "claude-code"
    ];
  };
}
