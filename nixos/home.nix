{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  astalPkgs = inputs.astal.packages.x86_64-linux;
in {
  home.stateVersion = "26.05";
  imports = [inputs.ags.homeManagerModules.default];
  programs.home-manager.enable = true;

  home.activation.scaffoldVault = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p $VERBOSE_ARG \
      "$HOME/1-vault/1-code/1-projects" \
      "$HOME/1-vault/1-code/2-snippets" \
      "$HOME/1-vault/1-code/3-archive" \
      "$HOME/1-vault/2-media/1-wallpapers" \
      "$HOME/1-vault/3-permanent" \
      "$HOME/1-vault/4-fleeting" \
      "$HOME/1-vault/5-archive"
  '';

  programs.bash = {
    enable = true;
    shellAliases = {
      "1" = "cd ~/1-vault/";
      "11" = "cd ~/1-vault/1-code/";
      "111" = "cd ~/1-vault/1-code/1-projects/";
      "112" = "cd ~/1-vault/1-code/2-snippets/";
      "113" = "cd ~/1-vault/1-code/3-archive/";
      "12" = "cd ~/1-vault/2-media/";
      "121" = "cd ~/1-vault/2-media/1-wallpapers/";
      "13" = "cd ~/1-vault/3-permanent/";
      "14" = "cd ~/1-vault/4-fleeting/";
      "15" = "cd ~/1-vault/5-archive/";
      "2" = "cd ~/2-syncthing/";
      con = "cd ~/.config";
      dot = "cd ~/dotfiles";
      ang = "ssh anguirus";
      cyd = "ssh cyndaquil";
      kin = "ssh kingghidorah";
      mot = "ssh mothra";
      tan = "ssh -i ~/.ssh/si_personal_vps root@rualmid.xyz";
      l = "ls -alh";
      ll = "ls -l";
      ls = "ls --color=tty";
      v = "nvim";
      sv = "sudo -E nvim";
      alc = "v ~/dotfiles/nixos/home.nix";
      alr = "source ~/.bashrc";
      reb = "~/dotfiles/scripts/rebuild.ksh";
      sdg = "sudo nix-collect-garbage -d";
      reh = "hyprctl keyword monitor DP-1,5120x1440@239.76,0x0,1";
      res = "hyprctl keyword monitor DP-1,2560x1440@120,0x0,1";
      p = "python3";
    };
  };

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

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 16;
  };

  xdg.configFile."bash/wal-prompt.sh".source = ../config/bash/wal-prompt.sh;

  xdg.configFile."ags".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/ags";

  xdg.configFile."kitty".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/kitty";

  xdg.configFile."hypr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/hypr";

  xdg.configFile."swaync".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/swaync";

  xdg.configFile."rofi".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/rofi";

  xdg.configFile."mangohud".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/mangohud";

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/nvim";

  xdg.configFile."zed".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/zed";

  xdg.configFile."hypridle.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/hypridle.conf";

  xdg.configFile."OrcaSlicer/user/default".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/config/OrcaSlicer/user/default";
}
