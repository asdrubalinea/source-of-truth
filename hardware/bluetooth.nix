{ ... }: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
      };

      # bluetoothd's policy plugin re-dials any device whose link drops, which
      # is exactly wrong for earbuds: disconnecting to hand them to the phone
      # just makes the laptop page them again. 0 = an explicit disconnect
      # stays disconnected until something asks for a connection.
      Policy = {
        ReconnectAttempts = 0;
      };
    };
  };

  services.blueman.enable = true;
}
