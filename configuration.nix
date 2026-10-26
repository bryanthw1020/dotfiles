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
      { name = "shivammathur/extensions"; trusted = true; }
      # Build-dep of the extension below; brew fails to resolve phpredis@8.5
      # without this tap even though it installs from a bottle.
      { name = "shivammathur/php";    trusted = true; }
      { name = "supabase/tap";        trusted = true; }
      { name = "teamookla/speedtest"; trusted = true; }
    ];
    brews = [
      "cocoapods"
      "composer"  # PHP dependency manager; not in mise's registry
      "ffmpeg"
      "gh"
      "ghidra"
      "go"
      "herdr"
      "kilo"
      "mole"
      "mysql-client"
      # Canonical JDK. Ghidra pulls openjdk@25 as its own dependency; it is
      # keg-only, so it never becomes the default `java`.
      "openjdk@21"
      "opencode"
      "pandoc"
      "php"  # prebuilt PHP; replaces Laravel Herd's bundled PHP
      # phpredis for the `php` formula above; the @NN suffix must match that
      # formula's minor version or the extension fatals on load. Bump both together.
      "shivammathur/extensions/phpredis@8.5"
      "ripgrep"
      "railway"
      "speedtest"
      "stripe-cli"  # provides `stripe`; in homebrew-core, no tap needed
      "supabase"
      # iOS/Android tooling. Xcode itself is installed separately by xcodes
      # (see scripts/mobile-setup.sh); these are the surrounding CLI tools.
      "xcodes"
      "xcbeautify"
      "swiftlint"
      "swiftformat"
    ];
    casks = [
      "wezterm"
      "visual-studio-code"  # official Microsoft build (MS Marketplace); ships the `code` CLI
      "claude-code"
      "antigravity-cli"  # `agy` terminal agent, shares the hub's agent engine
      "android-studio"
      # Google's android CLI (the sdkmanager replacement). SDK components
      # install into ANDROID_HOME, not here.
      "android-cli"
    ];
  };
}
