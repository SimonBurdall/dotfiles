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
  networking.hostName = "mori";
  networking.networkmanager.enable = true;

  # Time zone and internationalization
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
  };

  fonts.fonts = with pkgs; [
    (nerdfonts.override {fonts = ["Hack"];})
  ];

  # X11 and desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.layout = "gb";
  services.xserver.xkbVariant = "";
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
  hardware.nvidia.modesetting.enable = true;

  # BSPWM settings
  services.xserver.windowManager.bspwm.enable = true;

  # Steam settings
  # Not used on Desktop
  #programs.steam = {
  #   enable = true;
  #   remotePlay.openFirewall = true;
  #   dedicatedServer.openFirewall = true;
  #};

  # XDG portals and system packages
  xdg.portal.enable = true;

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    git
    lazygit
    kitty
    zsh
    fzf
    thefuck
    gh
    awscli
    clang
    docker-compose
    nodePackages.pyright
    python311Packages.black
    python311Packages.virtualenv
    python311Packages.ruff-lsp
    python3Packages.django
    nil
    rnix-lsp
    ripgrep
    #floorp
    discord
    vscode
    spotify
    dropbox
    keepassxc
    #steam
    #steam-run
    rofi
    flameshot
    neofetch
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
    nodejs
    statix
    deadnix
    alejandra
    stylua
    lua-language-server
    gdu
  ];

  # NixOS services (enable only what you need)
  services.openssh.enable = true;
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # System state version
  system.stateVersion = "23.11";
}
