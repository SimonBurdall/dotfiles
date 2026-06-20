#!/usr/bin/env bash
# sddm-wal — sync pywal colours + wallpaper into a writable copy of the
# sddm-astronaut theme.
#
# SDDM runs as the `sddm` user before login and can't read your home or
# ~/.cache/wal, so this copies everything it needs into
# /var/lib/sddm/themes/astronaut-wal (root-owned, world-readable).
#
# Run it WITH SUDO after changing your wallpaper / pywal theme:
#     sudo sddm-wal
#
set -euo pipefail

user="${SUDO_USER:-si}"
wal="/home/$user/.cache/wal"
store="/run/current-system/sw/share/sddm/themes/sddm-astronaut-theme"
dest="/var/lib/sddm/themes/astronaut-wal"
base="Themes/astronaut.conf"          # which embedded theme to build on
conf="$dest/Themes/wal.conf"

[ "$(id -u)" -eq 0 ] || { echo "run me with sudo"; exit 1; }
[ -d "$store" ]      || { echo "sddm-astronaut not installed (no $store)"; exit 1; }
[ -r "$wal/colors.sh" ] || { echo "no pywal colours at $wal"; exit 1; }

# pull in $color0..$color15, $background, $foreground.
# pywal's colors.sh touches things like $FZF_DEFAULT_OPTS that are unset under
# sudo, so relax nounset just for the source.
set +u
# shellcheck disable=SC1090
. "$wal/colors.sh"
set -u
wallpaper="$(cat "$wal/wal")"
ext="${wallpaper##*.}"

# 1. fresh seed from the store. Resolve the /run symlink to the real store dir
#    first, and let cp create $dest (don't pre-mkdir it, or cp -T trips on the
#    symlink-vs-directory mismatch).
src="$(readlink -f "$store")"
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -rL "$src" "$dest"
chmod -R u+w "$dest"

# 2. wallpaper somewhere sddm can actually read
install -Dm644 "$wallpaper" "$dest/Backgrounds/wal.$ext"

# 3. build wal.conf from the base theme, overriding only the keys we theme.
#    (keys that don't exist in this theme version are simply skipped)
cp "$dest/$base" "$conf"
setkey() { sed -i "s|^$1=.*|$1=\"$2\"|" "$conf"; }

setkey Background              "Backgrounds/wal.$ext"
setkey FormPosition           "center"
setkey FullBlur               "true"
setkey PartialBlur            "false"
setkey BlurRadius             "40"

setkey HeaderTextColor        "$color5"
setkey DateTextColor          "$foreground"
setkey TimeTextColor          "$foreground"
setkey PlaceholderTextColor   "$color8"
setkey WarningColor           "$color1"

setkey LoginFieldBackgroundColor    "$color0"
setkey PasswordFieldBackgroundColor "$color0"
setkey LoginFieldTextColor          "$foreground"
setkey PasswordFieldTextColor       "$foreground"
setkey UserIconColor                "$color4"
setkey PasswordIconColor            "$color4"

setkey LoginButtonTextColor          "$background"
setkey LoginButtonBackgroundColor    "$color4"
setkey SystemButtonsIconsColor       "$foreground"
setkey SessionButtonTextColor        "$foreground"
setkey VirtualKeyboardButtonTextColor "$foreground"

setkey DropdownTextColor             "$foreground"
setkey DropdownBackgroundColor       "$background"
setkey DropdownSelectedBackgroundColor "$color4"
setkey HighlightTextColor            "$background"
setkey HighlightBackgroundColor      "$color4"

# 4. point the theme metadata at our generated conf
sed -i "s|^ConfigFile=.*|ConfigFile=Themes/wal.conf|" "$dest/metadata.desktop"

# 5. make the whole thing readable by the sddm user
chown -R root:root "$dest"
chmod -R a+rX "$dest"

echo "SDDM theme updated."
echo "Preview without logging out:"
echo "  sddm-greeter-qt6 --test-mode --theme \"$dest\""
