{
  config,
  pkgs,
  ...
}: {
  # Include hardware configuration
  imports = [./hardware-configuration.nix];

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Hostname and networking
  networking.hostName = "rits";
  #networking.hostName = "mori";
  networking.networkmanager.enable = true;

  # Time zone and internationalization
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
  };

  environment.shellInit = ''export PS1='[󰾡:\w]\\$ ' '';

  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["Hack" "Iosevka" "NerdFontsSymbolsOnly"];})
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  # X11 and desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.xkb.layout = "gb";
  services.xserver.xkb.variant = "";
  console.keyMap = "uk";

  # Printing and sound
  services.printing.enable = true;
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # User account
  users.users.si = {
    isNormalUser = true;
    description = "Simon";
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Hardware settings
  hardware.opengl.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # BSPWM settings
  services.xserver.windowManager.bspwm.enable = true;

  # Steam settings
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # XDG portals and system packages
  xdg.portal.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    # Programming Languages and Dev Tools
    neovim
    git
    lazygit
    clang
    docker-compose
    nodePackages.pyright
    python311Packages.black
    python311Packages.virtualenv
    python311Packages.ruff-lsp
    python3Packages.django
    gh
    awscli
    nodejs
    statix
    deadnix
    alejandra
    stylua
    lua-language-server

    # System Utilities
    zsh
    fzf
    thefuck
    ripgrep
    rofi
    fastfetch
    flameshot
    bash
    openssl
    polybar
    pywal
    calc
    networkmanager_dmenu
    bspwm
    sxhkd
    betterlockscreen
    feh
    picom
    killall
    gdu
    xclip
    mangohud

    # Software
    kitty
    floorp
    thunderbird
    brave
    discord
    obsidian
    vscode
    spotify
    maestral
    blockbench
    keepassxc
    steam
    steam-run
    heroic
    gimp
    godot_4
    obs-studio
    strawberry
    vlc
    handbrake
  ];

  services.gnome.core-utilities.enable = false;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-25.9.0"
  ];

  # NixOS services (enable only what you need)
  services.openssh.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # System state version
  system.stateVersion = "24.05";
}
