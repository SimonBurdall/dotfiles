#!/usr/bin/env bash
set -e

cfg=~/dotfiles
host=$(hostname)
files=("$cfg/nixos/configuration.nix" "$cfg/nixos/home.nix")

pushd "$cfg/nixos/" > /dev/null

# Pick what to edit. Bare `reb` edits configuration.nix, as before.
# `:cq` out of the editor aborts the whole rebuild (thanks to set -e).
case "$1" in
    -e|edit) "${EDITOR:-nvim}" "${files[@]}" ;;   # both, side by side
    -d|dir)  "${EDITOR:-nvim}" "$cfg/nixos" ;;     # tree / netrw / oil
    -n|none) : ;;                                  # skip edit, just rebuild
    *)       "${EDITOR:-nvim}" configuration.nix ;;
esac

# Format the whole repo, then show exactly what's about to change
alejandra "$cfg" > /dev/null
git diff -U0

echo "Rebuilding ${host}..."
sudo nixos-rebuild switch --flake "$cfg#${host}" &> nixos-switch.log \
  || (grep --color error nixos-switch.log && false)

# Prime a labelled commit, ready to push
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to commit."
else
  label="$(date +%Y%m%d)-$(shuf -i 100000-999999 -n 1)-${host}"
  echo "Priming commit: ${label}"
  git commit -am "$label"
fi

popd > /dev/null
echo "Done. Review, then 'git push' when happy."
