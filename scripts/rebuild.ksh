#!/usr/bin/env bash
set -e

cfg=~/dotfiles
host=$(hostname)
files=("$cfg/nixos/configuration.nix" "$cfg/nixos/home.nix")

pushd "$cfg/nixos/" > /dev/null

case "$1" in
    -e|edit) "${EDITOR:-nvim}" "${files[@]}" ;; 
    -d|dir)  "${EDITOR:-nvim}" "$cfg" ;;     
    -n|none) : ;;                              
    *)       "${EDITOR:-nvim}" configuration.nix ;;
esac

alejandra "$cfg" > /dev/null
git diff -U0

echo "Rebuilding ${host}..."
sudo nixos-rebuild switch --flake "$cfg#${host}" &> nixos-switch.log \
  || (grep --color error nixos-switch.log && false)

if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to commit."
else
  label="$(date +%Y%m%d)-$(shuf -i 100000-999999 -n 1)-${host}"
  echo "Priming commit: ${label}"
  git commit -am "$label"
fi

popd > /dev/null
echo "Done. Review, then 'git push' when happy."
