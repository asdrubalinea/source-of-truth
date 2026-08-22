{...}: {
  # Everything else (doas/sudo-rs, passwordless wheel) is modules/security.nix.
  # Only the keepEnv rule is host-local: it is not applied on the desktops.
  security.doas.extraRules = [
    {
      users = ["irene"];
      keepEnv = true;
      noPass = true;
    }
  ];
}
