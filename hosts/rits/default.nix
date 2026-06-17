{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../nixos/common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "rits";

  ## NVIDIA (RTX 4070 Ti Super) ----
  boot.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  services.xserver.videoDrivers = ["nvidia"];

  # Never blank the desktop (handy for the always-on ultrawide).
  services.xserver.serverFlagsSection = ''
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    powerManagement.enable = true;
    forceFullCompositionPipeline = true;
    nvidiaPersistenced = true;
  };

  # Appended to the generic list in common.nix.
  hardware.graphics.extraPackages = with pkgs; [nvidia-vaapi-driver];

  ## VR and game streaming (desktop host only) ----
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
  };
}
