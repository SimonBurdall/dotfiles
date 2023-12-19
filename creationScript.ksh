#!/bin/ksh
for dir in */; do
    mv "$dir" ~/.config/
done
mv configuration.nix /etc/nixos/
mv bashrc ~/.bashrc
source ~/.bashrc
