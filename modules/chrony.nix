{
  config,
  lib,
  pkgs,
  ...
}: {
  # chrony in place of systemd-timesyncd (the module mkForce-disables it).
  # Imported by tempest and orchid; each persists /var/lib/chrony in its
  # system/persistence.nix (drift file, RTC trim file, NTS cookies).
  #
  # timesyncd is SNTP: it trusts one server at a time, has no filtering, and
  # polled a single pool member ~27 ms away every 34 min (on tempest it sat at
  # +19 ms offset, 14 ms jitter). chrony combines several sources and models
  # the oscillator's frequency between polls.
  #
  # Measured from orchid on 2026-10-22 (chronyd -Q, min round-trip delay):
  # every stratum 1 below put that clock 5-7 ms behind, which timesyncd never
  # saw. The error bound for a source is half its round-trip delay, and every
  # path shares the same Canaries uplink, so any asymmetry on that link biases
  # all of them together. Without a local reference (a GPS PPS input, which
  # neither host has), low single-digit ms accuracy is as good as it gets.
  # Precision, meaning stability from one moment to the next, is much better.
  #
  # Mostly NTS-authenticated sources. hora.roa.es (the navy observatory that
  # keeps Spain's legal time, ~40 ms) and ntp.i2t.ehu.eus (~40 ms) are the
  # closest stratum 1s but serve no NTS, so they are unauthenticated. Under
  # chrony's default `authselectmode mix` they are only used alongside the
  # authenticated majority, not instead of it. NTS matters more on tempest,
  # which roams untrusted networks. No Google or other leap-smearing servers:
  # mixing smeared and true UTC wrecks the leap-second day.
  #
  # Neither NIC (orchid's RTL8125, tempest's MT7925) has a PTP hardware clock,
  # so `hwtimestamp` is not possible. chrony still takes kernel software
  # timestamps (the "K K" in measurements.log), which keep scheduling latency
  # out of the measurement.
  options.time.chronyMaxpoll = lib.mkOption {
    type = lib.types.nullOr (lib.types.ints.between (-6) 24);
    default = null;
    description = ''
      Cap on chrony's poll interval, as log2 seconds, for every server. null
      keeps chrony's default backoff to 1024 s (2^10).
    '';
  };

  config.services.chrony = {
    enable = true;
    # Per-server options are set below in extraConfig.
    servers = [];
    extraConfig = let
      # xleave: interleaved mode, which uses the server's real transmit
      # timestamp when the server supports it and falls back otherwise.
      maxpoll = config.time.chronyMaxpoll;
      opts = "iburst xleave" + lib.optionalString (maxpoll != null) " maxpoll ${toString maxpoll}";
    in ''
      server time.cloudflare.com ${opts} nts
      server nts.netnod.se ${opts} nts
      server gbg1.nts.netnod.se ${opts} nts
      server ptbtime1.ptb.de ${opts} nts
      server ptbtime2.ptb.de ${opts} nts
      server ntppool1.time.nl ${opts} nts
      server ntppool2.time.nl ${opts} nts
      server hora.roa.es ${opts}
      server ntp.i2t.ehu.eus ${opts}

      # NTS cookies and keys, so a restart skips the NTS-KE handshake.
      ntsdumpdir /var/lib/chrony

      # Never steer the clock on the word of one server.
      minsources 2

      # Leap seconds from tzdata, not just from servers' leap bits.
      leapseclist ${pkgs.tzdata}/share/zoneinfo/leap-seconds.list
    '';
  };
}
