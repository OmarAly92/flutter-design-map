import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const skillsDir = resolve(extensionDir, "../..", "skills");

/**
 * Flutter Map extension for Pi.
 *
 * Registers this repo's skills/ directory so Pi discovers skills/flutter-map/SKILL.md
 * via its description-based trigger. Nothing is force-injected into the system
 * prompt: flutter-map is a heavy on-demand workflow (simulator boot, full route
 * sweep, screenshot capture), so it should enter context only when asked for.
 */
export default function flutterMapPiExtension(pi: ExtensionAPI) {
  pi.on("resources_discover", async () => ({
    skillPaths: [skillsDir],
  }));
}
