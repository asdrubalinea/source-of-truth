#!/bin/sh
nix run 'github:nix-community/disko/latest#disko-install' -- --write-efi-boot-entries --flake '.#tempest' --disk main /dev/vda
