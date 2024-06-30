#!/usr/bin/env bash

## Nixos Configuration
# Copy config into local and rebuild.
cp ../nixos/configuration.nix /etc/nixos/
sudo nixos-rebuild switch

# Copy all config directories in local.
for dir in */; do
    cp -r "../config/$dir" ~/.config/
done

# Copy alias to local.
cp ../bashrc ~/.bashrc
source ~/.bashrc

# Build the file structure.
./create_directories.sh

# Setup AstroNvim.
git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
rm -rf ~/.config/nvim/.git
nvim
