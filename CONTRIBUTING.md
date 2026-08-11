# Contributing

## Where things live

- `skills/flutter-design-map-skills/SKILL.md` — the agent workflow. Single source of truth;
  every harness manifest just points at `./skills/`.
- `packages/flutter_map_parser/` — the Dart parser, explore-plan generator,
  renderer, and `.appmap` packer the skill drives.
- `apps/flutter_map_visualiser/` — the Flutter web visualiser.
- `docs/appmap-format.md` — the `.appmap` + Argent flow contract.
- Manifests (`.claude-plugin/`, `.codex-plugin/`, `.agents/`) — distribution
  only, for Claude Code and Codex. See [`AGENTS.md`](./AGENTS.md).

[`CLAUDE.md`](./CLAUDE.md) covers the code architecture and the invariants worth
knowing before you change the parser or the visualiser.

## Before you push

```bash
cd packages/flutter_map_parser && dart pub get && dart test && dart analyze
```

```bash
cd apps/flutter_map_visualiser && flutter pub get && flutter test
```

## Keep the surfaces in sync

CLI flags, output filenames, capture statuses, and the flow/sidecar schema
appear in code **and** in `skills/flutter-design-map-skills/SKILL.md`, `docs/appmap-format.md`,
and `README.md`. A change to any of them is incomplete until those three match —
the skill is executed literally by an agent, so a stale command there is a real
bug.

## Releasing

```bash
./bump-version.sh <x.y.z>
```

Then commit and push:

```bash
git commit -am "Release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push --follow-tags
```

The tag must be annotated (`-a`). `--follow-tags` pushes annotated tags only, so
a lightweight `git tag vX.Y.Z` silently stays local while the branch goes up.
