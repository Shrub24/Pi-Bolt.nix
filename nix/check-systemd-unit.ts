// Prints the systemd user unit the pinned Pi-Bolt generates, for a spec that stands in for ours: the drift check compares the
// fields nix/modules/remote-control.nix writes against them. Upstream generates the unit from code and ships no unit file, so
// this is the only way to read its shape without inferring it.
//
// Usage: <bun> check-systemd-unit.ts <service-files.ts in the Pi-Bolt source>

const [, , modulePath] = process.argv;
if (!modulePath) {
	console.error("usage: check-systemd-unit.ts <service-files.ts>");
	process.exit(2);
}

const { systemdUserUnit } = await import(modulePath);

process.stdout.write(
	systemdUserUnit({
		program: ["/pi-bolt/bin/pi-bolt", "service", "run"],
		env: { PATH: "/usr/bin" },
		home: "/home/user",
		stderrPath: "/home/user/.pi/agent/remote-control/service.err.log",
	}),
);
