// A plugin whose npm dependencies come from the set's lock, not from a node_modules of its own. date-fns is one Pi does not have;
// yaml is one it has at another version, so the plugin's copy is its own. The model id carries both.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import format from "date-fns/format";
import yamlPackage from "yaml/package.json";

export default function lockdep(pi: ExtensionAPI) {
	pi.registerProvider("pi-bolt-lock", {
		baseUrl: "http://127.0.0.1:9",
		apiKey: "none",
		api: "openai-completions",
		models: [
			{
				id: `lock-${format(new Date(Date.UTC(2000, 5, 15, 12)), "yyyy")}-yaml-${yamlPackage.version}`,
				name: "Pi-Bolt Nix lock check",
				reasoning: false,
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 1000,
				maxTokens: 100,
			},
		],
	});
}
