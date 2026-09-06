# Everything about an ocelot that is not known when its image is built. One
# image serves every ocelot (docs/adr/0013), so the individual's name, the
# project it is of, and its ssh host key all arrive at boot in the launcher's
# staging directory at /host — not on the kernel command line, which cannot
# carry a path with a space in it without quoting games.
#
# Layout of /host, written by scripts/ocelot.sh:
#   conf/name                        this ocelot's name
#   conf/project                     the project's absolute path on tempest
#   conf/ssh_host_ed25519_key{,.pub} generated on tempest, already in known_hosts
#   conf/creds                       the staged credential entries, one per line
#   project/                         the project directory itself
#   creds/<entry>                    one per agent credential dir or file,
#                                    at the same relative path it has under $HOME
#                                    (so an entry may be nested)
{pkgs, ...}: {
  systemd.services.ocelot-runtime = {
    description = "Apply this ocelot's runtime identity";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target" "host.mount"];
    requires = ["host.mount"];
    # sshd needs the host key in place; home-manager and docker both want the
    # home and its credential binds finished before they touch it.
    before = [
      # sshd-keygen is what would otherwise generate a *different* host key than
      # the one tempest already put in known_hosts; it skips a key that is
      # already there, so this only has to win the race.
      "sshd-keygen.service"
      "sshd.service"
      "docker.service"
      "home-manager-irene.service"
    ];
    path = with pkgs; [util-linux coreutils findutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      # Identity. The hostname is what the shell prompt and every log line show,
      # and it is the one place an ocelot says which one it is. Written straight
      # to the kernel — /etc/hostname is a store symlink (networking.hostName is
      # set, so it has to be something) and hostnamectl needs a bus this early in
      # the boot; gethostname(2) is what the prompt and the journal read anyway.
      if [ -r /host/conf/name ]; then
        printf '%s' "ocelot-$(cat /host/conf/name)" >/proc/sys/kernel/hostname
      fi

      # ssh host key. Copied rather than used in place: sshd is strict about a
      # host key's mode and owner, and everything on a virtiofs share is irene
      # 0600 at best (docs/adr/0013 — unprivileged virtiofsd does no uid mapping).
      if [ -r /host/conf/ssh_host_ed25519_key ]; then
        install -m 0600 -o root -g root \
          /host/conf/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key
        install -m 0644 -o root -g root \
          /host/conf/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_ed25519_key.pub
      fi

      # The project, at the same absolute path it has on tempest, so a path
      # copied between the two means the same file. /host/project is already the
      # right directory; this only puts it where the project expects to be.
      if [ -r /host/conf/project ]; then
        project="$(cat /host/conf/project)"
        case "$project" in
          /*)
            mkdir -p "$project"
            mountpoint -q "$project" || mount --bind /host/project "$project"
            ;;
          *)
            echo "ocelot: refusing to mount project at non-absolute path '$project'" >&2
            exit 1
            ;;
        esac
      fi

      # Agent credentials, bound into the guest home at their usual names.
      # Bind-mounted and not symlinked on purpose: a tool that writes its config
      # by rename(2) would replace a symlink and silently stop writing through to
      # the host. The list lives in scripts/ocelot.sh — whatever it staged is
      # what gets bound, so there is one place to add to.
      #
      # Read from conf/creds rather than walked out of the share. An entry may be
      # nested (.config/opencode), and a `find -maxdepth 1` over /host/creds sees
      # only `.config` — which would bind the staging directory's .config over the
      # guest's whole ~/.config and bury the home-manager-generated zellij, fish
      # and helix configs under it.
      if [ -r /host/conf/creds ]; then
        while read -r entry; do
          [ -n "$entry" ] || continue
          target="/home/irene/$entry"
          mountpoint -q "$target" && continue
          parent="$(dirname "$target")"
          mkdir -p "$parent"
          chown irene:users "$parent"
          if [ -d "/host/creds/$entry" ]; then
            mkdir -p "$target"
          else
            [ -e "$target" ] || : >"$target"
          fi
          chown irene:users "$target"
          mount --bind "/host/creds/$entry" "$target"
        done </host/conf/creds
      fi
    '';
  };
}
