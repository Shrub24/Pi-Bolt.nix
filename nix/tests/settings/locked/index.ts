import { format } from "date-fns";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// A plugin whose only dependency comes from the set's lock: its own tree has none, so a shared settings file has to point at
// the payload's runtime view for stock Pi to load it.
export default function settingsLocked(pi: ExtensionAPI) {
	pi.registerCommand("settings-locked", {
		description: `Locked ${format(new Date(Date.UTC(2000, 0, 1)), "yyyy")}`,
		handler: async () => {},
	});
}
