import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function settingsPlugin(pi: ExtensionAPI) {
	pi.registerCommand("settings-compiled", { description: "Compiled", handler: async () => {} });
}
