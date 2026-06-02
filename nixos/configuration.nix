{
  config,
  pkgs,
  ...
}: {
  imports = [./hardware-configuration.nix];

  ## Boot and System ----
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = ["uinput" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"]; # ADDED: nvidia kernel modules required for Hyprland
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
  networking.networkmanager.enable = true;

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    operation = "boot";
  };

  system.stateVersion = "25.11";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [47984 47989 47990 48010 8008 8009 8010 8443 8384 22000];
    allowedUDPPorts = [22000 21027];
    allowedUDPPortRanges = [
      {
        from = 47998;
        to = 48000;
      }
      {
        from = 32768;
        to = 61000;
      }
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
    packages = with pkgs; [];
  };

  users.groups.plugdev = {};
  users.groups.usb = {};

  ## Display, Desktop Environment, and Window Manager ----
  services.xserver = {
    enable = true;
    # REMOVED: windowManager.bspwm.enable — replacing with Hyprland
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

  # CHANGED: gdm -> sddm, defaultSession -> hyprland, kept GNOME as fallback
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland";
  services.desktopManager.gnome.enable = true;
  services.gnome.core-apps.enable = false;

  # ADDED: Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # needed for any X11 apps you still run
  };

  # CHANGED: added hyprland portal, kept gtk portal for GNOME fallback
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland # ADDED
      xdg-desktop-portal-gtk # kept for GNOME
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
    forceFullCompositionPipeline = true; # NOTE: may cause issues under Wayland, remove if you get flickering
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

  services.syncthing = {
    enable = true;
    user = "si";
    group = "users";
    dataDir = "/home/si/2-syncthing";
    configDir = "/home/si/.config/syncthing";
  };

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="input"
    SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ATTR{idProduct}=="df11", MODE="0660", GROUP="plugdev", TAG+="uaccess"
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
    extraPkgs = pkgs: with pkgs; [libgdiplus libusb1 libv4l pipewire];
    extraLibraries = pkgs: with pkgs; [libusb1 libv4l];
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
  };

  ## Package Management ----
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = ["electron-36.9.5"];

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
    nodejs
    typescript
    typescript-language-server
    yarn
    openssl
    openssl.dev
    pkg-config
    postgresql
    pyright
    python313
    python313Packages.black
    python313Packages.django
    python313Packages.pip
    python313Packages.virtualenv
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
    wine
    zlib

    # Creative Software
    (blender.override {cudaSupport = true;})
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
    obsidian
    pocket-casts
    rclone
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
    protonup-qt
    gamemode

    # System and Wayland Utilities
    bash
    zsh
    # REMOVED: bspwm, sxhkd, picom, polybar, rofi, flameshot, xclip, feh
    waybar # ADDED: replaces polybar
    rofi
    dunst
    libnotify
    grim # ADDED: native wayland screenshots
    slurp # ADDED: area selection for grim
    grimblast # ADDED: grim wrapper, nicer ergonomics
    hyprpaper # ADDED: wallpaper daemon
    hyprlock # ADDED: lockscreen
    hypridle # ADDED: idle daemon (triggers hyprlock)
    wl-clipboard # ADDED: replaces xclip
    calc
    fastfetch
    fzf
    gdu
    killall
    usbutils
    mangohud
    networkmanager_dmenu
    nmap
    playerctl
    pywal
    ripgrep
    solaar
    unzip
    wireplumber
    zip

    # Monitoring Tools
    pciutils
  ];
}
