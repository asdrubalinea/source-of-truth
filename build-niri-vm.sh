#!/usr/bin/env bash

# Build niri-test VM configuration script
# This script builds a VM with the niri rice configuration for testing

set -euo pipefail

echo "Building niri-test VM configuration..."
echo "This will create a VM image with the niri rice configuration for testing purposes."

# Build the VM image
echo "Building VM image..."
nix build '.#nixosConfigurations.niri-test.config.system.build.vm' --print-build-logs

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "Build successful!"
    echo "VM image built at: result/bin/run-niri-test-vm"
    echo ""
    echo "To run the VM:"
    echo "  ./result/bin/run-niri-test-vm"
    echo ""
    echo "VM specs:"
    echo "  - Host: niri-test"
    echo "  - Desktop: niri window manager"
    echo "  - Rice: niri rice configuration"
    echo "  - Storage: ZFS with impermanence"
    echo "  - Login: irene (password from passwords.nix)"
    echo ""
    echo "The VM will boot into the niri desktop environment."
    echo "Use Ctrl+Alt+G to release mouse from VM."
else
    echo "Build failed!"
    exit 1
fi