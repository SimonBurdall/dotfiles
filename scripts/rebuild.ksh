#!/usr/bin/env bash
set -e

cfg=~/dotfiles
host=$(hostname)
files=("$cfg/nixos/common.nix" "$cfg/nixos/home.nix" "$cfg/hosts/$host/default.nix")

# ── styling ──────────────────────────────────────────────
reset=$'\e[0m'; dim=$'\e[2m'; ok=$'\e[1;32m'; warn=$'\e[1;33m'; err=$'\e[1;31m'
_accent() {                                   # pywal color4 for headers
  local hex; hex=$(sed -n '5p' "$HOME/.cache/wal/colors" 2>/dev/null)
  if [[ "$hex" =~ ^#([0-9A-Fa-f]{6})$ ]]; then
    printf '\e[1;38;2;%d;%d;%dm' \
      "$((16#${BASH_REMATCH[1]:0:2}))" "$((16#${BASH_REMATCH[1]:2:2}))" "$((16#${BASH_REMATCH[1]:4:2}))"
  else printf '\e[1m'; fi
}
acc=$(_accent)
step() { printf '\n%s▸ %s%s\n' "$acc" "$1" "$reset"; }
good() { printf '  %s✓%s %s\n' "$ok" "$reset" "$1"; }
skip() { printf '  %s•%s %s%s%s\n' "$dim" "$reset" "$dim" "$1" "$reset"; }

pushd "$cfg/nixos/" > /dev/null

step "Sync"
if git fetch --quiet 2>/dev/null; then
  git pull --rebase --autostash --quiet
  good "up to date with origin"
else
  skip "offline — skipped"
fi

case "$1" in
  -e|edit) "${EDITOR:-nvim}" "${files[@]}" ;;
  -d|dir)  "${EDITOR:-nvim}" "$cfg" ;;
  -n|none) : ;;
  *)       "${EDITOR:-nvim}" common.nix ;;
esac

step "Format"
if alejandra "$cfg" > /dev/null 2>&1; then good "alejandra clean"
else printf '  %s⚠%s alejandra reported issues\n' "$warn" "$reset"; fi

step "Changes"
if git diff --quiet && git diff --cached --quiet; then
  skip "none"
else
  git --no-pager diff --stat | sed 's/^/  /'
fi

step "Rebuild ${host}"
if sudo nixos-rebuild switch --flake "$cfg#${host}" &> nixos-switch.log; then
  good "switched"
else
  printf '  %s✗ rebuild failed%s\n' "$err" "$reset"
  grep --color=always -i error nixos-switch.log | head -20 | sed 's/^/  /'
  popd > /dev/null; exit 1
fi

primed=false
if ! git diff --quiet || ! git diff --cached --quiet; then
  step "Commit"
  read -rp "  Prime a commit? [y/N] " ans
  if [[ "$ans" =~ ^[Yy] ]]; then
    read -rp "  Message: " msg
    msg="${msg:-$(date +%Y%m%d)-$(shuf -i 100000-999999 -n 1)-${host}}"
    git commit -qam "$msg"
    good "committed: $msg"
    primed=true
  else
    skip "left uncommitted"
  fi
fi

popd > /dev/null

if $primed; then
  printf '\n%s✓ done%s — review, then %sgit push%s when happy\n' "$ok" "$reset" "$acc" "$reset"
else
  printf '\n%s✓ done%s\n' "$ok" "$reset"
fi
