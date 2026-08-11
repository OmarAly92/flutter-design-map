# Contributing

## Where things live

- `skills/flutter-design-map-skills/SKILL.md` — the agent workflow. Single source of truth;
  every harness manifest just points at `./skills/`.
- `packages/flutter_map_parser/` — the Dart parser, explore-plan generator,
  renderer, and `.appmap` packer the skill drives.
- `apps/flutter_map_visualiser/` — the Flutter web visualiser.
- `docs/appmap-format.md` — the `.appmap` + Argent flow contract.
- Manifests (`.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`,
  `.kimi-plugin/`, `.agents/`, `.opencode/`, `.pi/`, `gemini-extension.json`)
  — distribution only. See [`AGENTS.md`](./AGENTS.md).

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

Then commit, tag `vX.Y.Z`, and push with `--follow-tags`.
