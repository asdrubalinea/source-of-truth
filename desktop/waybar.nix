{ config, pkgs, ... }:

let
  waybarConfigMainBar = {
    layer = "top";
    position = "top";
    height = 40;
    # output = [ "DP-3" ];
    margin-top = 15;
    margin-left = 50;
    margin-right = 50;
    # modules-left = [ "custom/spotify" ];

    modules-center = [
      "cpu"
      "memory"
      # "disk"
      # "disk#nvme" "disk#ssd"
    ];

    modules-right = [ "clock" ];

    # "custom/spotify".exec = "/home/bailey/.config/waybar/scripts/mediaplayer.py --player spotify";
    # "custom/spotify".format = "<span color='#689d6a'> 󰝚</span> {}";
    # "custom/spotify".return-type = "json";
    "cpu".format = " <span color='#cc241d'> </span>{usage}%";
    "cpu".tooltip = false;
    "memory".format = "<span color='#d79921'></span> {}%";
    "disk".path = "/";
    "disk".interval = 30;
    "disk".format = "<span color='#98971a'>󰋊</span> {free}";
    "disk".unit = "GB";
    "disk#nvme".path = "/nvme";
    "disk#nvme".interval = 30;
    "disk#nvme".format = "<span color='#458588'>󰋊</span> {free}";
    "disk#nvme".unit = "GB";
    "disk#ssd".path = "/ssd";
    "disk#ssd".interval = 30;
    "disk#ssd".format = "<span color='#b16286'>󰋊</span> {free}";
    "disk#ssd".unit = "GB";
    "clock".format = "{:%B %d, %Y - %I:%M} <span color='#689d6a'> </span>";
    "clock".tooltip-format = "<big>{:%Y %B}</big>\n<tt><big>{calendar}</big></tt>";
  };

  waybarConfigMonitorBar = {
    height = 26;
    # output = [ "DP-4" ];
    spacing = 20;
    margin-top = 5;
    margin-left = 30;
    margin-right = 30;
    modules-left = [ "clock" ];
    modules-center = [ "tray" ];
    modules-right = [ "network#down" "network#up" ];
    "clock".format = " {:%I:%M}";
    "network#down".interval = 1;
    "network#down".interface = "wlo1";
    "network#down".format-wifi = "<span color='#cc241d'></span> {bandwidthDownBytes}";
    "network#up".interval = 1;
    "network#up".interface = "wlo1";
    "network#up".format-wifi = "<span color='#458588'></span> {bandwidthUpBytes} ";
  };

in
{
  programs.waybar = {
    enable = true;
    settings = [
      waybarConfigMainBar
      # waybarConfigMonitorBar
    ];
    style = ''
      * {
        font-family: JetBrainsMono Nerd Font;
        font-size: 16px;
      }

      window#waybar {
        background: rgba(24,26,27,0.8);
        border: 2px solid rgba(89, 89, 89, 0.67);
        border-radius: 5px;
      }

      .modules-right {
        padding-right: 5px;
      }

      .module-left {
        padding-left: 5px;
      }

      #cpu {
        padding-left: 1em;
        padding-right: 1em;
      }

      #memory {
        padding-right: 1em;
      }

      #disk {
        padding-right: 1em;
      }
    '';
  };
}
