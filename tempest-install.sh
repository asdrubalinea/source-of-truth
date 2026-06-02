#!/bin/sh
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes run 'github:nix-community/disko/latest#disko-install' -- --flake '.#tempest' --write-efi-boot-entries --disk main /dev/disk/by-id/usb-SanDisk_Portable_SSD_323532353952343031333638-0:0
