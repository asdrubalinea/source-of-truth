#!/usr/bin/env bash

set -euo pipefail

sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake '.#vm' --write-efi-boot-entries --disk main /dev/vda