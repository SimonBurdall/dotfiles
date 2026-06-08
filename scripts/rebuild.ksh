#!/usr/bin/env bash
set -e
pushd ~/dotfiles/nixos/ > /dev/null

host=$(hostname)

# Edit, format the whole repo, then show everything about to be committed
"${EDITOR:-nvim}" configuration.nix
alejandra ~/dotfiles > /dev/null
git diff -U0

# Build + switch via the flake; log output, surface errors on failure
echo "Rebuilding ${host}..."
sudo nixos-rebuild switch --flake ~/dotfiles#${host} &>nixos-switch.log \
  || (grep --color error nixos-switch.log && false)

# Prime a labelled commit, ready to push
label="$(date +%Y%m%d)-$(shuf -i 100000-999999 -n 1)-${host}"
if git diff --quiet && git diff --cached --quiet; then
  echo "No changes to commit."
else
  echo "Priming commit: ${label}"
  git commit -am "$label"
fi

popd > /dev/null
echo "Done. Review, then 'git push' when happy."
