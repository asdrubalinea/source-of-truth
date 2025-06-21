#!/usr/bin/env bash

set -euo pipefail

sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes run 'github:nix-community/disko/latest#disko-install' -- --flake '.#vm' --write-efi-boot-entries --disk main /dev/vda

