#!/bin/sh
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes run 'github:nix-community/disko/latest#disko-install' -- --flake '.#tempest' --write-efi-boot-entries --disk main /dev/disk/by-id/nvme-Corsair_MP700_PRO_SE_A8WFB416001JKK
