/**
 * Flutter Map plugin for OpenCode.ai
 *
 * Registers this repo's skills/ directory with OpenCode so skills/flutter-map/SKILL.md
 * is discovered via its description-based trigger. Unlike a conventions skill,
 * flutter-map is a heavy on-demand workflow (it boots a simulator, sweeps every
 * route, and captures screenshots), so nothing is force-injected into the system
 * prompt — the agent loads it only when the user actually asks for a map.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, '../../skills');

export const FlutterMapPlugin = async () => {
  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(skillsDir)) {
        config.skills.paths.push(skillsDir);
      }
    },
  };
};
