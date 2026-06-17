# ─────────────────────────────────────────────────────────────────────────
# PLACEHOLDER — replace this on the laptop before building .#mori
#
# This file is machine-specific (disk UUIDs, partition layout, detected
# kernel modules) and CANNOT be shared from rits. On the freshly-installed
# laptop, generate the real one:
#
#   During install:   sudo nixos-generate-config --root /mnt
#   After install:    sudo nixos-generate-config
#
# Then copy the generated /etc/nixos/hardware-configuration.nix over THIS
# file and commit it:
#
#   cp /etc/nixos/hardware-configuration.nix ~/dotfiles/hosts/mori/hardware-configuration.nix
#
# Until you do, `nixos-rebuild ... .#mori` will fail with a "no root file
# system" error. That is expected and is step one of the recovery runbook.
# ─────────────────────────────────────────────────────────────────────────
{...}: {
  # Intentionally empty. Replace with the generated file from the laptop.
}
