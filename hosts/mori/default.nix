{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../nixos/common.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "mori";

  ## GPU ----
  # modesetting + mesa (already provided by common.nix) covers most Intel/AMD
  # laptops out of the box. Adjust to match the actual laptop:
  #
  #   Intel:  uncomment the intel-media-driver line below.
  #   AMD:    usually nothing extra needed (mesa amdgpu is the default).
  #   NVIDIA Optimus: copy the hardware.nvidia block from hosts/rits/default.nix
  #           and add a hardware.nvidia.prime { } section with the PCI bus IDs
  #           from `lspci | grep -E "VGA|3D"`.
  services.xserver.videoDrivers = lib.mkDefault ["modesetting"];
  # hardware.graphics.extraPackages = with pkgs; [intel-media-driver];

  ## Laptop niceties (uncomment what you want) ----
  # services.libinput.enable = true;        # touchpad
  # services.logind.lidSwitch = "suspend";
  # powerManagement.enable = true;
  # services.tlp.enable = true;             # battery tuning

  # NOTE: the truenas NFS mounts come from common.nix with nofail + automount,
  # so they appear when you are on the home network and are silently skipped
  # when you are not. Nothing to do here.
}
