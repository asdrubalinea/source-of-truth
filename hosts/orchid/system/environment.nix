{ inputs, pkgs, ... }:
{
  environment.systemPackages =
    with pkgs;
    [
      neovim
      git
      helix
      swtpm
      tpm2-tools
      git-crypt
      ntfs3g

      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
    ]
    ++ [
      # inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

  environment.variables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  programs = {
    fish.enable = true;
    mosh.enable = true;
    steam.enable = true;

    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # For VSCode support
    nix-ld.enable = true;

    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    };
  };
}
