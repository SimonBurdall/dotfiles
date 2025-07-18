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
  boot.kernelModules = ["uinput"];

  networking.hostName = "rits";
  # networking.hostName = "mori";
  networking.networkmanager.enable = true;

  system.autoUpgrade.enable = true;
  system.autoUpgrade.allowReboot = true;
  system.stateVersion = "25.05";

  # ALVR will handle these ports automatically with the module
  #networking.firewall.allowedTCPPorts = [9943 9944];
  #networking.firewall.allowedUDPPorts = [9943 9944];
  #networking.firewall.enable = true;

  # Updated firewall configuration for ALVR + Sunshine
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [9943 9944 47984 47989 47990 48010 8008 8009 8010 8443];
    allowedUDPPorts = [9943 9944];
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
    extraGroups = ["networkmanager" "wheel" "video" "plugdev" "input" "usb"];
    packages = with pkgs; [
      # User-specific packages can be added here
    ];
  };

  # OpenComposite configuration to bypass SteamVR
  system.userActivationScripts.opencomposite = ''
    mkdir -p ~/.config/openvr
    cat > ~/.config/openvr/openvrpaths.vrpath << EOF
    {
      "runtime" : [ "${pkgs.opencomposite}/lib/opencomposite" ],
      "version" : 1
    }
    EOF
  '';

  # Create groups if they don't exist
  users.groups.plugdev = {};
  users.groups.usb = {};

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

    serverFlagsSection = ''
      Option "BlankTime" "0"
      Option "StandbyTime" "0"
      Option "SuspendTime" "0"
      Option "OffTime" "0"
    '';
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
    jack.enable = true;
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

  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
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

    # Add Sunshine input device rules
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

  #---------------------------------------------------------------------
  # Virtualization and Containerization
  virtualisation.docker.enable = true;

  #---------------------------------------------------------------------
  # VR Configuration - ALVR Module
  programs.alvr = {
    enable = true;
    openFirewall = true; # This automatically handles ports 9943-9944 TCP/UDP
  };

  # OpenVR/SteamVR udev rules
  services.udev.packages = with pkgs; [openxr-loader];

  # SteamVR permissions fix and bypass setup
  systemd.user.services.steamvr-setup-bypass = {
    description = "Bypass SteamVR setup requirements";
    wantedBy = ["graphical-session.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "steamvr-setup" ''
        # Create all necessary directories
        mkdir -p ~/.local/share/Steam/steamapps/common/SteamVR/{bin/linux64,drivers,resources}
        mkdir -p ~/.local/share/Steam/config
        mkdir -p ~/.openvr/drivers

        # Create a dummy vrserver executable to bypass checks
        touch ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrserver
        chmod +x ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrserver

        # Create vrpathreg dummy
        echo '#!/bin/sh' > ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg.sh
        echo 'exit 0' >> ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg.sh
        chmod +x ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg.sh

        # Link system libraries
        ln -sf ${pkgs.glibc}/lib/libc.so.6 ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/libc.so.6 || true
        ln -sf ${pkgs.gcc.cc.lib}/lib/libstdc++.so.6 ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/libstdc++.so.6 || true

        # Create SteamVR manifest
        cat > ~/.local/share/Steam/steamapps/common/SteamVR/steamvr.vrsettings << 'EOF'
        {
          "driver_alvr_server": {
            "enable": true
          },
          "steamvr": {
            "activateMultipleDrivers": true,
            "requireHmd": false,
            "forcedDriver": "",
            "forcedHmd": ""
          }
        }
        EOF
      '';
    };
  };

  # Create SteamVR config directory with proper settings
  system.userActivationScripts.steamvr-config = ''
    mkdir -p ~/.local/share/Steam/config
    mkdir -p ~/.openvr
    mkdir -p ~/.local/share/Steam/steamapps/common/SteamVR/drivers
    mkdir -p ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64

    # Create symlinks for SteamVR runtime
    ln -sf ${pkgs.steam}/bin/steam-runtime ~/.local/share/Steam/ubuntu12_32/steam-runtime || true

    # Create default SteamVR settings to bypass setup
    if [ ! -f ~/.local/share/Steam/config/steamvr.vrsettings ]; then
      cat > ~/.local/share/Steam/config/steamvr.vrsettings << 'EOF'
    {
      "steamvr" : {
        "requireHmd" : false,
        "forcedDriver" : "null",
        "forcedHmd" : "",
        "displayDebug" : false,
        "debugProcessPipe" : "",
        "enableHomeApp" : false,
        "showMirrorView" : false,
        "autolaunchSteamVROnButtonPress" : false
      },
      "driver_null" : {
        "enable" : true
      },
      "driver_alvr_server" : {
        "enable" : true,
        "pathServerFolder" : ""
      }
    }
    EOF
    fi

    # Create vrpathreg script workaround
    cat > ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg.sh << 'EOF'
    #!/bin/sh
    # Dummy vrpathreg to prevent SteamVR setup errors
    exit 0
    EOF
    chmod +x ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrpathreg.sh || true
  '';

  #---------------------------------------------------------------------
  # Gaming and Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    # Enable Steam hardware support
    gamescopeSession.enable = true;
  };

  # Hardware support for Steam
  hardware.steam-hardware.enable = true;

  # Steam-specific packages for runtime compatibility
  programs.steam.package = pkgs.steam.override {
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

  #---------------------------------------------------------------------
  # Package Management
  nixpkgs.config.allowUnfree = true;

  nixpkgs.config.permittedInsecurePackages = [
    "electron-27.3.11"
    "electron-33.4.11"
  ];

  #---------------------------------------------------------------------
  # Environment Variables for VR
  environment.sessionVariables = {
    # Help Steam find the correct runtime
    STEAM_RUNTIME_PREFER_HOST_LIBRARIES = "0";
    # Use system libraries when possible
    STEAM_RUNTIME = "1";
    # OpenXR runtime selection (for Monado)
    XR_RUNTIME_JSON = "${pkgs.monado}/share/openxr/1/openxr_monado.json";
    # Disable SteamVR home to reduce overhead
    STEAMVR_DISABLE_HOMEVR = "1";
  };

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
    # alvr is now handled by the programs.alvr module
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
    # SteamVR runtime dependencies
    libusb1
    libv4l
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
