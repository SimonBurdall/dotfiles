#!/usr/bin/env bash

for dir in */; do
    mv "config/$dir" ~/.config/
done

cp configuration.nix /etc/nixos/

sudo nixos-rebuild switch

cp bashrc ~/.bashrc
source ~/.bashrc

git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
rm -rf ~/.config/nvim/.git
nvim
