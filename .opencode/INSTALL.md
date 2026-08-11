# Installing Flutter Map for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- The Dart SDK on `PATH` (the skill runs the parser CLIs in
  `packages/flutter_map_parser`)

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or project-level):

```json
{
  "plugin": ["flutter-map@git+https://github.com/OmarAly92/flutter-design-map.git"]
}
```

Restart OpenCode. The plugin registers the `skills/` directory, so OpenCode's
native `skill` tool can discover `flutter-design-map-skills`.

Verify by asking OpenCode to list its skills.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load flutter-design-map-skills
```

Nothing is force-loaded, and `SKILL.md` sets `disable-model-invocation: true`,
so `flutter-design-map-skills` enters context only when you load it explicitly.
Note that this flag is honoured by Claude Code; OpenCode may still surface the
skill to the model from its `description`, so treat explicit loading as the
intended path rather than a guarantee.

## Updating

OpenCode installs through a git-backed package spec. Some OpenCode/Bun versions
pin the resolved git dependency, so a restart may not pick up the newest commit.
If updates do not appear, clear OpenCode's package cache or reinstall the plugin.

To pin a specific version:

```json
{
  "plugin": ["flutter-map@git+https://github.com/OmarAly92/flutter-design-map.git#v0.2.0"]
}
```
