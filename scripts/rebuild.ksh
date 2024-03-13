#!/usr/bin/env bash
set -e
pushd ~/1-vault/1-code/2-snippets/dotfiles/nixos/
$EDITOR configuration.nix
alejandra . >/dev/null
git diff -U0 *.nix
echo "NixOS Rebuilding..."
echo "Nixos: Copying config"
sudo cp configuration.nix /etc/nixos/
echo "Nixos: nixos-switch"
sudo nixos-rebuild switch &>nixos-switch.log || (cat nixos-switch.log | grep --color error && false)
echo "Nixos: Generating version nummber"
today=$(date +%Y%m%d)
randomNumber=$(shuf -i 100000-999999 -n 1)
new_label="${today}-${randomNumber}-${HOSTNAME}" 
git commit -am "$new_label"
popd
echo "Nixos: Finished."
