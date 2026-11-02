# Examples

Start with [installation](../docs/getting-started.md) to configure the flake input and overlay, then copy the chosen example
into the consuming configuration, preserving its relative paths.

| Example | Includes |
| --- | --- |
| [Home Manager](home-manager/default.nix) | A compiled example plugin and generated settings, as a Home Manager module. |
| [Custom plugin set](plugin-set/default.nix) | A local extension, shared dependency lock, settings and a role launcher. |

Both use `pi-bolt-nix.overlays.default` on the package set passed to them.

## See a real configuration

These two examples are self-contained. Larger working setups live in the repositories that build what they package:

- [`pi-extensions`](https://github.com/Shrub24/pi-extensions) — one Nix package per plugin, dependencies and patches included.
  Take them by package name; see [packaging plugins](../docs/guides/plugins.md#consume-a-plugin-that-ships-its-own-package).
- [`nix-dotfiles` `pkgs/pi-plugins`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-plugins) — a packaging catalogue
  with a committed plugin lock and an update script, as described in [npm dependencies](../docs/guides/dependencies.md#recommended-shape).
  Its [`pkgs/pi-bolt`](https://github.com/Shrub24/nix-dotfiles/tree/main/pkgs/pi-bolt) shows role launchers over one payload.

Both are consumer configurations, not required layouts; the guides state the contracts they satisfy.

## Home Manager

Import `./home-manager` as a Home Manager module. It selects the built-in example plugin and renders settings using `select`.
The user configuration still owns `home.username`, `home.homeDirectory` and `home.stateVersion`.

```nix
modules = [ ./examples/home-manager ];
```

## Custom plugin set

With `plugin-set/` beside the Nix file that imports it:

```nix
let
  example = import ./plugin-set {
    inherit pkgs;
    agentDir = "/home/me/.pi/roles/greeting";
  };
in
{
  package = example.package;
  settings = example.settings;
}
```

The example packages a local extension, uses a standalone npm lock and adds `pi-bolt-greeting`. Create the agent directory and
write its settings before using that launcher. `/greet` displays a YAML greeting. The directory is configurable; no activation
or credential/session sharing policy is imposed.

Regenerate its lock from the repository root:

```sh
nix run .#pi-bolt.updatePluginLock -- -o examples/plugin-set/plugins.lock.json \
  examples/plugin-set/greeting/package.json
```

`checks.<system>.docs-examples` evaluates both examples without building their executables. The custom plugin's compiled
command is also suitable for the existing offline RPC `get_commands` inspection when changing its runtime behaviour.
