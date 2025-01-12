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

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;

  # Time zone and internationalization
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override {fonts = ["Hack" "Iosevka" "NerdFontsSymbolsOnly"];})
    noto-fonts-cjk-sans
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
  services.nfs.server.enable = true;

  environment.systemPackages = with pkgs; [
    # Programming Languages and Dev Tools
    alejandra
    awscli
    clang
    deadnix
    docker-compose
    gh
    git
    lazygit
    lua-language-server
    neovim
    pyright
    nodejs
    python312Packages.black
    ruff-lsp
    rustc
    python312Packages.virtualenv
    python3Packages.django
    statix
    stylua

    # Software
    ardour
    blender
    brave
    discord
    floorp
    gimp
    godot_4
    gpu-screen-recorder
    handbrake
    heroic
    inkscape
    keepassxc
    kitty
    maestral
    obs-studio
    obsidian
    pocket-casts
    scribus
    spotify
    steam
    steam-run
    strawberry
    thunderbird
    vlc
    vscode

    # System Utilities
    bash
    betterlockscreen
    bspwm
    calc
    feh
    fastfetch
    flameshot
    fzf
    gdu
    killall
    mangohud
    networkmanager_dmenu
    nmap
    openssl
    picom
    playerctl
    polybar
    pywal
    ripgrep
    rofi
    solaar
    sxhkd
    thefuck
    unzip
    xclip
    zip
    zsh
  ];

  services.gnome.core-utilities.enable = false;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
  ];

  # NixOS services (enable only what you need)
  services.openssh.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # System state version
  system.stateVersion = "24.05";
}
