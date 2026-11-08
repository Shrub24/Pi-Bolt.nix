# Reports whether the unit we write still matches the one the pinned Pi-Bolt generates (nix/remote-control-unit.nix).
#
# Upstream builds the unit text in TypeScript and ships no unit file, so this runs its generator with the runtime's Bun and
# compares the fields both sides share. It never fails: an upstream release that changes its template is something to look at,
# not a reason to block a build, so it prints a warning annotation and exits 0.
{
  lib,
  writeShellApplication,
  runtime,
  source,
}:
let
  template = import ./remote-control-unit.nix;
  # The release the source is pinned to; the compile refuses a mismatch, so it labels the comparison.
  version = (import ./runtime-data.nix).version;
  expect = {
    inherit (template)
      description
      type
      restart
      wantedBy
      ;
    after = lib.concatStringsSep " " template.after;
    restartSec = toString template.restartSec;
  };
in
writeShellApplication {
  name = "check-systemd-unit";

  text = ''
    actual="$(${runtime}/bun run ${./check-systemd-unit.ts} "${source}/packages/coding-agent/src/remote-control/service-files.ts")"

    # The value of key $2 in section $1 of the generated unit.
    field() {
      printf '%s\n' "$actual" | awk -v section="[$1]" -v key="$2" '
        $0 == section { inside = 1; next }
        /^\[/ { inside = 0 }
        inside && index($0, key "=") == 1 { sub("^" key "=", ""); print; exit }
      '
    }

    # systemd's duration forms are interchangeable: compare seconds, not spelling.
    seconds() {
      local value="$1"
      case "$value" in
        *min) echo $(( ''${value%min} * 60 )) ;;
        *s) echo "''${value%s}" ;;
        *) echo "$value" ;;
      esac
    }

    drift=""
    check() {
      local label="$1" expected="$2" got="$3"
      [ "$expected" = "$got" ] && return 0
      drift+="  $label: expected '$expected', Pi-Bolt generates '$got'"$'\n'
    }

    check Description ${lib.escapeShellArg expect.description} "$(field Unit Description)"
    check After ${lib.escapeShellArg expect.after} "$(field Unit After)"
    check Type ${lib.escapeShellArg expect.type} "$(field Service Type)"
    check Restart ${lib.escapeShellArg expect.restart} "$(field Service Restart)"
    check RestartSec "${expect.restartSec}" "$(seconds "$(field Service RestartSec)")"
    check WantedBy ${lib.escapeShellArg expect.wantedBy} "$(field Install WantedBy)"

    if [ -z "$drift" ]; then
      echo "systemd unit: matches Pi-Bolt ${version}'s template"
      exit 0
    fi

    echo "::warning title=Pi-Bolt systemd unit drift::nix/remote-control-unit.nix no longer matches the template Pi-Bolt ${version} generates"
    printf '%s' "$drift"
    echo "Upstream builds this unit in packages/coding-agent/src/remote-control/service-files.ts; compare it with nix/remote-control-unit.nix."
    exit 0
  '';

  meta.description = "Compare nix/remote-control-unit.nix with the unit the pinned Pi-Bolt generates";
}
