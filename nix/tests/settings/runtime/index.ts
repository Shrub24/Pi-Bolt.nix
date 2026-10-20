import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function settingsRuntime(pi: ExtensionAPI) {
	pi.registerCommand("settings-runtime", { description: "Run time", handler: async () => {} });
}
