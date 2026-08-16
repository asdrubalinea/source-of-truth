{ ... }:
# The niri compositor layer of the ember rice: the scrolling-tiling window
# manager, its bindings, its window rules, and the two things that exist only to
# work around what niri lacks (an emulated scratchpad, and a sticky-PiP follower).
# Gated on `rices.ember.niri.enable`; the furniture it sits under is one level up.
#
# `./system.nix` is the NixOS half and is imported by the host, not from here —
# standalone Home Manager cannot reach NixOS options. See ADR 0004.
{
  imports = [
    ./niri.nix
    ./pip-follow.nix
    ./marquee.nix
  ];
}
