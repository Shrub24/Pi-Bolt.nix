# The part of the remote control unit that mirrors Pi-Bolt's own template: what nix/modules/remote-control.nix writes and what
# nix/check-systemd-unit.nix compares against the unit the pinned source generates. Upstream has no unit file to read (it builds
# the text in packages/coding-agent/src/remote-control/service-files.ts), so this is the shared truth for both sides here.
{
  description = "Pi-Bolt remote control (serves paired phones)";
  after = [ "network-online.target" ];
  type = "simple";
  restart = "on-failure";
  # Seconds; the unit writes it as systemd's duration form.
  restartSec = 5;
  wantedBy = [ "default.target" ];
}
