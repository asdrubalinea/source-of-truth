#!/bin/sh

nix --experimental-features 'nix-command flakes' flake update
