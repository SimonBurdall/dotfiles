{
  config,
  pkgs,
  ...
}: {
  imports = [./hardware-configuration.nix];

  ## Boot and System ----
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = ["uinput"];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.core.netdev_max_backlog" = 5000;

    "net.ipv4.tcp_low_latency" = 1;
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_window_scaling" = 1;
  };

  networking.hostName = "rits";
  # networking.hostName = "mori";
  networking.networkmanager.enable = true;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
  system.stateVersion = "25.11";

  # Firewall configuration for Sunshine
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [47984 47989 47990 48010 8008 8009 8010 8443];
    allowedUDPPortRanges = [
      {
        from = 47998;
        to = 48000;
      } # Sunshine
      {
        from = 32768;
        to = 61000;
      } # Chromecast streaming
    ];
  };

  ## Localization ----
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
  };
  console.keyMap = "uk";

  ## User Management ----
  users.users.si = {
    isNormalUser = true;
    description = "Simon";
    extraGroups = ["networkmanager" "wheel" "video" "plugdev" "input" "usb"];
    packages = with pkgs; [
    ];
  };

  # Create groups if they don't exist
  users.groups.plugdev = {};
  users.groups.usb = {};

  ## Display, Desktop Environment, and Window Manager ----
  services.xserver = {
    enable = true;
    windowManager.bspwm.enable = true;
    xkb.layout = "gb";
    xkb.variant = "";
    videoDrivers = ["nvidia"];

    serverFlagsSection = ''
      Option "BlankTime" "0"
      Option "StandbyTime" "0"
      Option "SuspendTime" "0"
      Option "OffTime" "0"
    '';
  };

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  ## Fonts ----
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.symbols-only
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
  ];

  fonts.fontDir.enable = true;
  fonts.fontconfig.enable = true;

  ## Hardware and Graphics ----
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    nvidiaPersistenced = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libva-vdpau-driver
      libvdpau-va-gl
      vulkan-loader
      vulkan-validation-layers
      nvidia-vaapi-driver
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      vulkan-loader
    ];
  };

  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  ## Audio ----
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  ## File Systems and Network Shares ----
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

  ## System Services ----
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

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  services.udev.extraRules = ''
    # Meta Quest USB detection (for ADB/sideloading)
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", GROUP="plugdev", TAG+="uaccess"

    # Sunshine input device rules
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="input"
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  ## Virtualization and Containerization ----
  virtualisation.docker.enable = true;

  ## Gaming and Steam ----
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
  };

  hardware.steam-hardware.enable = true;

  programs.steam.package = pkgs.steam.override {
    extraProfile = ''
      unset TZ
      export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
    '';
    extraPkgs = pkgs:
      with pkgs; [
        libgdiplus
        libusb1
        libv4l
        pipewire
      ];
    extraLibraries = pkgs:
      with pkgs; [
        libusb1
        libv4l
      ];
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
    defaultRuntime = true;
  };

  ## Package Management ----
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
    "electron-33.4.11"
    "electron-36.9.5"
  ];

  ## System Packages ----
  environment.systemPackages = with pkgs; [
    # Development Tools
    act
    alejandra
    android-studio
    awscli
    clang
    clippy
    deadnix
    docker
    docker-compose
    gcc
    gh
    git
    lazygit
    lua-language-server
    neovim
    nodePackages.nodejs
    nodePackages.npm
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.yarn
    openssl
    openssl.dev
    pkg-config
    postgresql
    pyright
    python312
    python312Packages.black
    python312Packages.django
    python312Packages.pip
    python312Packages.virtualenv
    ruff
    rust-analyzer
    rustc
    rustfmt
    rustup
    sqlite
    statix
    stylua
    tailwindcss
    trunk

    # Utilities
    android-tools
    dbeaver-bin
    clamav
    keymapp
    scrcpy
    vulkan-tools
    vulkan-loader
    vulkan-validation-layers
    libva
    libva-utils
    libusb1
    libv4l
    lsfg-vk
    lsfg-vk-ui
    zlib

    # Creative Software
    blender
    blockbench
    freecad
    gimp
    godot_4
    inkscape
    obs-studio
    orca-slicer
    reaper
    scribus

    # Media and Entertainment
    brave
    floorp-bin
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
    prismlauncher
    moonlight-qt
    gamemode

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
    picom
    playerctl
    polybar
    pywal
    ripgrep
    rofi
    solaar
    sxhkd
    unzip
    wireplumber
    zip
    xclip

    # Monitoring Tools
    pciutils
  ];
}
