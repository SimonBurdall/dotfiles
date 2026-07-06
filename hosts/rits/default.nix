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
  boot.kernelParams = ["nvidia_drm.fbdev=1"];

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

  hardware.graphics.extraPackages = with pkgs; [nvidia-vaapi-driver];

  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    settings = {
      capture = "kms";
      encoder = "nvenc";
    };
    package = with pkgs;
      (sunshine.override {
        cudaSupport = true;
        cudaPackages = cudaPackages;
      }).overrideAttrs (old: {
        nativeBuildInputs =
          old.nativeBuildInputs
          ++ [
            cudaPackages.cuda_nvcc
            (lib.getDev cudaPackages.cuda_cudart)
          ];
        cmakeFlags =
          old.cmakeFlags
          ++ [
            "-DCMAKE_CUDA_COMPILER=${lib.getExe cudaPackages.cuda_nvcc}"
          ];
      });
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = [(pkgs.blender.override {cudaSupport = true;})];
}
