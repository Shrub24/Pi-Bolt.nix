// Fails, naming each one, when a package a compiled plugin declares in "dependencies" is not staged, or is staged at a version
// outside the declared range. Usage: node check-dependencies.js <semver module> <host node_modules> <spec.json>
// spec: [{ name, dir, skip }] — the plugin, its staged folder, and the declared packages that are staged plugins (not checked).
// A package resolves as Node resolves it: the plugin's own node_modules first, then the host's. The packages Pi provides
// (@earendil-works/pi-* and typebox) are not checked: Pi routes a plugin's imports of them to its own copy whatever range the plugin
// declares, at run time and in a compiled build alike, and staging leaves the plugin's copy out.
const fs = require("node:fs");
const path = require("node:path");

const [semverPath, hostModules, specFile] = process.argv.slice(2);
const semver = require(semverPath);

const readJson = (file) => {
	try {
		return JSON.parse(fs.readFileSync(file, "utf8"));
	} catch {
		return undefined;
	}
};

const providedByPi = (dependency) => dependency === "typebox" || dependency.startsWith("@earendil-works/pi-");

const problems = [];
for (const { name, dir, skip } of readJson(specFile)) {
	const declared = readJson(path.join(dir, "package.json"))?.dependencies ?? {};
	for (const [dependency, range] of Object.entries(declared)) {
		// Only version ranges are comparable: a git, file or tarball specifier names its own source.
		if (skip.includes(dependency) || providedByPi(dependency) || semver.validRange(range) === null) continue;
		const staged =
			readJson(path.join(dir, "node_modules", dependency, "package.json")) ??
			readJson(path.join(hostModules, dependency, "package.json"));
		if (staged === undefined) {
			problems.push(`${name}: ${dependency} ${range} is declared but not staged`);
		} else if (!semver.satisfies(staged.version, range, { includePrerelease: true })) {
			problems.push(`${name}: ${dependency} ${range} is declared, ${staged.version} is staged`);
		}
	}
}

if (problems.length > 0) {
	console.error(`pi-bolt: a plugin's dependencies are not what it declares:\n  ${problems.join("\n  ")}`);
	process.exit(1);
}
