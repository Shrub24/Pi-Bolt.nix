# The remote control background service as a systemd user unit, opt-in: Pi-Bolt's `pi-bolt service install` writes this unit
# itself, which a Nix-managed home cannot allow (the file is a store link, so the write fails). Written here instead, the unit
# moves with the package, and `pi-bolt service status|pair|logs` still find it by name.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pi-bolt-remote-control;
  template = import ../remote-control-unit.nix;
in
{
  options.services.pi-bolt-remote-control = {
    enable = lib.mkEnableOption "the Pi-Bolt remote control background service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pi-bolt;
      defaultText = lib.literalExpression "pkgs.pi-bolt";
      description = "The Pi-Bolt package whose launcher runs the service.";
    };

    launcher = lib.mkOption {
      type = lib.types.str;
      default = "pi-bolt";
      description = ''
        Launcher to run. The service serves the agent directory that launcher sets, so a role's launcher serves that role.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.pi-bolt-remote-control = {
      Unit = {
        Description = template.description;
        After = template.after;
        Wants = template.after;
      };

      Service = {
        Type = template.type;
        ExecStart = "${cfg.package}/bin/${cfg.launcher} service run";
        WorkingDirectory = "%h";
        Restart = template.restart;
        RestartSec = "${toString template.restartSec}s";
      };

      Install.WantedBy = template.wantedBy;
    };
  };
}
