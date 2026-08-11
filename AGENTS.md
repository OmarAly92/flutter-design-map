# flutter-design-map — repo guide

This repository is two things at once:

1. **A toolchain** — the Dart parser/packer in `packages/flutter_map_parser` and
   the Flutter web visualiser in `apps/flutter_map_visualiser`. See
   [`CLAUDE.md`](./CLAUDE.md) for the code architecture, commands, and the data
   contracts that hold the pieces together.
2. **A distribution wrapper** — manifests that ship `skills/flutter-design-map-skills/SKILL.md`
   to Claude Code and Codex, plus a universal symlink installer for anything
   else that reads `SKILL.md` files. That part is documented below.

## Single source of truth

All skill content lives in `skills/`:

- `skills/flutter-design-map-skills/SKILL.md` — the full mapping workflow: static parse,
  explore plan, simulator sweep, runtime-state capture, flow recording, packing.

Never duplicate skill text elsewhere. Every harness manifest just points at
`./skills/`. Edit the `SKILL.md`; the manifests do not change.

## The skill is not self-contained

Unlike a pure-markdown conventions skill, `flutter-design-map-skills` shells out to the Dart
CLIs in `packages/flutter_map_parser`. That constrains distribution:

- Every plugin manifest ships the **whole repo**, not just `skills/`, so the
  parser travels with the skill.
- `install.sh` **symlinks** (never copies) `skills/flutter-design-map-skills` into the target
  skills dir, and runs `dart pub get` for the parser.
- `SKILL.md` resolves `$PARSER` at runtime: `${CLAUDE_PLUGIN_ROOT}` /
  `${PLUGIN_ROOT}` first, then its own directory resolved with `pwd -P` and
  walked up two levels, then a fresh clone as the fallback.
- `SKILL.md` then runs `dart pub get` in `$PARSER` unconditionally. A plugin
  install copies the source but no `.dart_tool/`, and `dart run <abs-path>`
  does **not** resolve dependencies implicitly — without this step the very
  first CLI call dies on `Couldn't resolve the package 'args'`. `install.sh`
  does the same fetch at install time; the plugin path has no such hook, so
  the skill has to do it itself.

If you move `packages/flutter_map_parser` or restructure `skills/`, update the
resolution block at the top of `SKILL.md` in the same change.

## How each harness finds the skill

| Harness | Entry point | Can the model start it on its own? |
| --- | --- | --- |
| Claude Code | `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` (skills auto-discovered) | No — `disable-model-invocation` blocks it; `/flutter-design-map-skills` only |
| Codex | `.codex-plugin/plugin.json` (`"skills": "./skills/"`) + `.agents/plugins/marketplace.json` | No |
| Any other agent | `install.sh` symlinks `skills/*` into `~/.claude/skills/` | No |

**Explicit invocation only, by design.** The sibling `flutter-knowledge` repo
injects its conventions into every session with a `pubspec.yaml`, which is right
for always-on conventions. `flutter-design-map-skills` is the opposite shape: a
long, heavy, side-effectful workflow that boots a simulator, sweeps every route,
and writes screenshots. So it goes one step further than merely not being
forced — `SKILL.md` sets `disable-model-invocation: true`, which removes it from
the model's invocable-skill list entirely. The only way in is the user typing
`/flutter-design-map-skills`. Do not add a `SessionStart` hook, and do not drop
that flag, without a reason that survives those arguments.

Two consequences worth knowing:

- The `description` no longer drives triggering, so it is written to describe
  what the skill *does*, not when to reach for it. Keep it that way.
- `disable-model-invocation` is a Claude Code feature. Codex reads the same
  frontmatter but may ignore the flag and still offer the skill from its
  `description` — the flag is a hard guarantee only on Claude Code, and a
  statement of intent anywhere else.

Only Claude Code and Codex are packaged. Manifests for Cursor, Kimi, OpenCode,
Pi, and Gemini were removed deliberately — the universal `install.sh` covers
any other agent that reads `SKILL.md` files. Gemini in particular is a poor fit:
it has no on-demand skill mechanism, so its context file always loads, which
directly contradicts this skill's explicit-invocation-only design.

## Adding a skill

1. Create `skills/<name>/SKILL.md` with `name` + `description` frontmatter.
2. No manifest changes needed — every harness points at the whole `skills/` dir.
3. Bump the version (see below) and push.

## Releasing a new version

Run `./bump-version.sh <x.y.z>` — it rewrites the version string in every
manifest and `version.json` at once. Then commit, tag `vX.Y.Z`, and push.
Consumers update by pulling the repo / re-running their harness's update step.
