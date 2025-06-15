{
  config,
  pkgs,
  ...
}: {
  imports = [./hardware-configuration.nix];

  #---------------------------------------------------------------------
  # Boot and System
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "rits";
  # networking.hostName = "mori";
  networking.networkmanager.enable = true;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
  system.stateVersion = "25.05";

  networking.firewall.allowedTCPPorts = [9943 9944];
  networking.firewall.allowedUDPPorts = [9943 9944];
  # networking.firewall.enable = false;

  #---------------------------------------------------------------------
  # Localization
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
  };
  console.keyMap = "uk";

  #---------------------------------------------------------------------
  # User Management
  users.users.si = {
    isNormalUser = true;
    description = "Simon";
    extraGroups = ["networkmanager" "wheel" "video" "plugdev" "input"];
    packages = with pkgs; [
      # User-specific packages can be added here
    ];
  };

  #---------------------------------------------------------------------
  # Display, Desktop Environment, and Window Manager
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    windowManager.bspwm.enable = true;
    xkb.layout = "gb";
    xkb.variant = "";
    videoDrivers = ["nvidia"];
  };

  services.gnome.core-utilities.enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  #---------------------------------------------------------------------
  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.symbols-only
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  #---------------------------------------------------------------------
  # Hardware and Graphics
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    nvidiaPersistenced = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      libvdpau
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      vulkan-loader
      libvdpau
    ];
  };

  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;
  services.monado.enable = true;

  #---------------------------------------------------------------------
  # Audio
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  #---------------------------------------------------------------------
  # Printing
  services.printing.enable = true;

  #---------------------------------------------------------------------
  # File Systems and Network Shares
  fileSystems."/home/si/3-minilla" = {
    device = "truenas.local:/mnt/minilla";
    fsType = "nfs";
    options = ["defaults" "rw" "nolock"];
  };

  fileSystems."/home/si/4-spacezilla" = {
    device = "truenas.local:/mnt/spacezilla";
    fsType = "nfs";
    options = ["defaults" "rw" "nolock"];
  };

  services.rpcbind.enable = true;
  services.nfs.server.enable = true;

  #---------------------------------------------------------------------
  # System Services
  services.openssh.enable = true;
  security.polkit.enable = true;

  systemd.user.services.solaar = {
    enable = true;
    description = "Solaar Logitech Device Manager";
    wantedBy = ["default.target"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };

  services.udev.extraRules = ''
    # Meta Quest USB detection
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0186", MODE="0660", GROUP="plugdev", TAG+="uaccess", SYMLINK+="quest%n"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0082", MODE="0660", GROUP="plugdev", TAG+="uaccess", SYMLINK+="quest%n"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0187", MODE="0660", GROUP="plugdev", TAG+="uaccess", SYMLINK+="quest%n"
    # For the Quest 3 specifically
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ATTR{idProduct}=="0137", MODE="0660", GROUP="plugdev", TAG+="uaccess", SYMLINK+="quest%n"

    # Add rules for Android debugging (useful for ADB)
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", GROUP="plugdev"
  '';

  #---------------------------------------------------------------------
  # Virtualization and Containerization
  virtualisation.docker.enable = true;

  #---------------------------------------------------------------------
  # Gaming and Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  #---------------------------------------------------------------------
  # Package Management
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
    "electron-33.4.11"
  ];

  #---------------------------------------------------------------------
  # System Packages
  environment.systemPackages = with pkgs; [
    # Development Tools
    alejandra
    android-studio
    awscli
    clang
    cargo
    rustc
    deadnix
    docker-compose
    gcc
    gh
    git
    lazygit
    lua-language-server
    neovim
    nodejs
    pyright
    python312
    python312Packages.black
    python312Packages.django
    python312Packages.pip
    python312Packages.virtualenv
    ruff
    statix
    stylua

    # VR and Graphics
    android-tools
    alvr
    scrcpy
    monado
    opencomposite
    wivrn
    vulkan-tools
    vulkan-loader
    vulkan-validation-layers
    libva
    vkBasalt
    sidequest

    # Creative Software
    ardour
    blender
    blockbench
    freecad
    gimp
    godot_4
    inkscape
    obs-studio
    orca-slicer
    scribus

    # Media and Entertainment
    brave
    floorp
    calibre
    discord
    gpu-screen-recorder
    grayjay
    handbrake
    heroic
    keepassxc
    kitty
    maestral
    obsidian
    pocket-casts
    rpi-imager
    spotify
    steam
    steam-run
    strawberry
    thunderbird
    vlc
    vscode
    immich-go

    # Games
    clonehero

    # System and Window Manager Utilities
    bash
    zsh
    betterlockscreen
    bspwm
    calc
    feh
    fastfetch
    flameshot
    fzf
    gdu
    killall
    usbutils
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
    wireplumber
    zip
    xclip

    # Monitoring Tools
    pciutils
  ];
}
