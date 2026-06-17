{ inputs, pkgs, ... }:
let
  astalPkgs = inputs.astal.packages.${pkgs.system};
in {
  imports = [ inputs.ags.homeManagerModules.default ];

  home.username = "si";
  home.homeDirectory = "/home/si";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.ags = {
    enable = true;
    # Leave configDir unset during development so we edit ~/.config/ags
    # directly and run `ags run` ourselves. We hand it to HM once stable.

    # Astal libraries the shell will use. These provide the GObject
    # introspection typelibs for each subsystem.
    extraPackages = [
      astalPkgs.io
      astalPkgs.astal4        # GTK4
      astalPkgs.battery
      astalPkgs.wireplumber   # audio
      astalPkgs.network
      astalPkgs.bluetooth
      astalPkgs.mpris         # media
      astalPkgs.notifd        # notifications
      astalPkgs.tray
      astalPkgs.hyprland      # workspaces / focused window
    ];
  };

  # Tools the shell shells out to (matching your Waybar click actions)
  home.packages = with pkgs; [
    dart-sass   # AGS compiles scss
  ];
}
