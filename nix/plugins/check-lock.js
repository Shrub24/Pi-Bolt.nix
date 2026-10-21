// Fails, naming each one, when a plugin's declared "dependencies" are not what its entry in pluginLock was generated from: a pin
// moved and the lock was not regenerated. Usage: node check-lock.js <pluginLock> <folder holding <plugin>/package.json>
// A plugin without an entry in the lock is not checked here: check-dependencies.js checks what is staged for it.
const fs = require("node:fs");
const path = require("node:path");

const [lockFile, membersDir] = process.argv.slice(2);
const lock = JSON.parse(fs.readFileSync(lockFile, "utf8"));

const problems = [];
for (const name of fs.readdirSync(membersDir)) {
	const declared = JSON.parse(fs.readFileSync(path.join(membersDir, name, "package.json"), "utf8")).dependencies ?? {};
	const locked = lock.packages[`pbplugins/${name}`]?.dependencies ?? {};
	for (const dependency of new Set([...Object.keys(declared), ...Object.keys(locked)])) {
		if (declared[dependency] !== locked[dependency]) {
			problems.push(
				`${name}: ${dependency} is ${declared[dependency] ?? "not declared"} in its package.json, ${locked[dependency] ?? "not"} in the lock`,
			);
		}
	}
}

if (problems.length > 0) {
	console.error(`pi-bolt: pluginLock is stale: a plugin's dependencies changed:\n  ${problems.join("\n  ")}\nregenerate it with update-plugin-lock`);
	process.exit(1);
}
