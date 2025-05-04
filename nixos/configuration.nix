{
  config,
  pkgs,
  ...
}: {
  imports = [./hardware-configuration.nix];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

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

  fileSystems."/home/si/3-minilla" = {
    device = "truenas.local:/mnt/minilla";
    fsType = "nfs";
    options = [
      "defaults"
      "rw"
      "nolock"
    ];
  };

  fileSystems."/home/si/4-spacezilla" = {
    device = "truenas.local:/mnt/spacezilla";
    fsType = "nfs";
    options = [
      "defaults"
      "rw"
      "nolock"
    ];
  };

  services.rpcbind.enable = true;

  # User account
  users.users.si = {
    isNormalUser = true;
    description = "Simon";
    extraGroups = ["networkmanager" "wheel" "video" "plugdev" "input"];
    packages = with pkgs; [
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enhanced graphics support for VR
  hardware.graphics = {
    enable = true;
    enable32Bit = true; # Important for Steam
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Hardware settings
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    nvidiaPersistenced = true;
  };

  hardware.opengl = {
    enable = true;
    driSupport32Bit = true; # Important for Steam
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

  # Enable Monado OpenXR runtime
  services.monado.enable = true;

  # USB rules
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

  # BSPWM settings
  services.xserver.windowManager.bspwm.enable = true;

  # Enhanced Steam configuration
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # XDG portals and system packages
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };

  virtualisation.docker.enable = true;
  services.nfs.server.enable = true;

  environment.systemPackages = with pkgs; [
    # Programming Languages and Dev Tools
    alejandra
    awscli
    clang
    cargo
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
    python312Packages.django
    ruff-lsp
    rustc
    python312Packages.virtualenv
    statix
    stylua

    # VR-related packages
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

    # Software
    ardour
    blender
    brave
    calibre
    discord
    floorp
    freecad
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
    orca-slicer
    pocket-casts
    rpi-imager
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
    xclip
    zip
    zsh
    immich-go

    nvtop
    pciutils
  ];

  services.gnome.core-utilities.enable = false;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
  ];

  environment.sessionVariables = {
    # VR-specific environment variables
    "STEAM_EXTRA_COMPAT_TOOLS_PATHS" = "\${HOME}/.steam/root/compatibilitytools.d";
    "VK_ICD_FILENAMES" = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
  };

  # NixOS services (enable only what you need)
  services.openssh.enable = true;
  # Open ports for Oculus Link
  networking.firewall.allowedTCPPorts = [9943 9944];
  networking.firewall.allowedUDPPorts = [9943 9944];
  # For SteamVR
  security.polkit.enable = true;
  # networking.firewall.enable = false;

  # System state version
  system.stateVersion = "24.05";
}
