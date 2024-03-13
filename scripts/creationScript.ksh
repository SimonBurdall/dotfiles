#!/bin/ksh
echo -e "\n[*] Installing fonts..."
[[ ! -d "$FDIR" ]] && mkdir -p "$FDIR"
cp -rf $DIR/fonts/* "$FDIR"

rm -rf fonts

for dir in */; do
    mv "config/$dir" ~/.config/
done

mv configuration.nix /etc/nixos/

sudo nixos-rebuild switch

mv bashrc ~/.bashrc
source ~/.bashrc

git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
nvim
