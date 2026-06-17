{
  inputs,
  pkgs,
  ...
}: let
  astalPkgs = inputs.astal.packages.${pkgs.system};
in {
  imports = [inputs.ags.homeManagerModules.default];

  home.username = "si";
  home.homeDirectory = "/home/si";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.ags = {
    enable = true;
    extraPackages = [
      astalPkgs.io
      astalPkgs.astal4
      astalPkgs.battery
      astalPkgs.wireplumber
      astalPkgs.network
      astalPkgs.bluetooth
      astalPkgs.mpris
      astalPkgs.notifd
      astalPkgs.tray
      astalPkgs.hyprland
    ];
  };

  home.packages = with pkgs; [
    dart-sass
  ];
}
