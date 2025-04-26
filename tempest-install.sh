#!/bin/sh
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#tempest' --disk main /dev/vda
