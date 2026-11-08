---
title: Remote control service
---

# Remote control service

Pi-Bolt can serve paired phones from a background service, so they reach this computer with no terminal open. What it does
belongs upstream: [background service](https://github.com/opensec-git/Pi-Bolt/blob/pi-bolt/packages/coding-agent/docs/remote-control.md#background-service).

Enable it from the Home Manager module this flake ships:

```nix
{
  imports = [ inputs.pi-bolt-nix.homeManagerModules.remote-control ];

  services.pi-bolt-remote-control = {
    enable = true;
    package = payload;   # the compiled package, if you build one
    launcher = "pi-bolt"; # or a role's launcher
  };
}
```

| Option | Default | Meaning |
| --- | --- | --- |
| `enable` | `false` | Write the unit and start it with your session. |
| `package` | `pkgs.pi-bolt` | The package whose launcher runs the service. |
| `launcher` | `"pi-bolt"` | Which launcher runs it. A launcher sets the agent directory, so this picks the configuration the phones see. |

`pi-bolt service status`, `pair` and `logs` work unchanged: they read the same unit file and ask `systemctl --user`.

## Reaching a phone

The service listens on every interface at one port (`remoteControl.port`, else 48123), so how a phone gets to it is a network
choice, not a Pi-Bolt one:

| Path | What it needs |
| --- | --- |
| Same network | Nothing. The addresses are listed as `local`. |
| A VPN you already run (Tailscale, WireGuard) | Nothing here: a `100.64.0.0/10` address is listed as `tailscale`, any other as `local`. |
| Cloudflare tunnel, no account | `cloudflared` on the launcher's `PATH`, and `remoteControl.service.tunnel = "quick"`. The hostname is random and changes when the tunnel restarts; connected phones get the new one. |
| Cloudflare tunnel on your hostname | `remoteControl.service.tunnel = { name = "..."; hostname = "..."; }`, after `cloudflared tunnel create` and the DNS route. |

The default is `"quick"`, so a phone can connect from anywhere once `cloudflared` is installed; with no `cloudflared` the
service logs it and serves the first two paths. Traffic is end-to-end encrypted (Noise), so the tunnel operator relays
ciphertext. On NixOS the firewall still has to allow the port, or trust the interface:

```nix
networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 48123 ];
```

## Before you enable it

- **Do not also run `pi-bolt service install`.** It writes the same unit file itself, which fails with `EACCES` over this
  module's store link. Declare the unit, or use `service install`, not both.
- **Lingering**, if the service must outlive your last session: `users.users.<name>.linger = true` on NixOS, or
  `loginctl enable-linger`. Home Manager cannot set it.
- **The tunnel** is a setting, not a flag: `remoteControl.service.tunnel` (`"off"` serves the local network and Tailscale
  only). It defaults to `remoteControl.tunnel`, which is a quick tunnel and needs `cloudflared` on the launcher's `PATH` —
  `extraPackages = [ pkgs.cloudflared ]` on the package. Without it the service logs that and serves the local network.
- **A second role** is a second unit with its own name, running that role's launcher; `pi-bolt service status` reports on
  `pi-bolt-remote-control` only, so use `systemctl --user status` for the others:

  ```nix
  systemd.user.services.pi-bolt-remote-control-orchestrator = {
    Unit.Description = "Pi-Bolt remote control (orchestrator)";
    Unit.After = [ "network-online.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${payload}/bin/pi-bolt-orchestrator service run";
      WorkingDirectory = "%h";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "default.target" ];
  };
  ```

## The unit is checked against Pi-Bolt's own

Pi-Bolt generates this unit in TypeScript and ships no unit file, so this flake writes its own and compares the two:

```sh
nix run .#checkSystemdUnit
```

It runs the generator from the pinned release and reports any field that no longer matches `nix/remote-control-unit.nix`. It
never fails — a template change upstream is worth a look, not a broken build — so CI runs it as a warning.
