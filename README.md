# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs and `.appmap` bundles.

## Pipeline

```
parse_routes      →  .flutter-map/graph.json
prepare_explore   →  explore-plan.json + deeplink flows + capture-status
(agent skill)     →  screenshots + nav/state flows on simulator/emulator
pack_map          →  *.appmap
```

## Quick start

```bash
cd packages/flutter_map_parser
dart pub get
dart test

# parse + pack (static, no simulator)
dart run bin/flutter_map.dart ../../fixtures/demo_go_router

# parse + prepare deep-link explore stubs
dart run bin/prepare_explore.dart ../../fixtures/demo_go_router
```

## Skill

Install for agents:

```bash
ln -s "$(pwd)/skills/flutter-map" ~/.cursor/skills/flutter-map
# or ~/.claude/skills/flutter-map
```

Then run `/flutter-map` in a Flutter app. See `skills/flutter-map/SKILL.md`.

## Routing modes

| Mode | Detection | Fixture |
|------|-----------|---------|
| GoRouter | `GoRouter(` | `fixtures/demo_go_router` |
| go_router_builder | `@TypedGoRoute` | `fixtures/demo_go_router_builder` |
| AutoRoute | `@AutoRouterConfig` | `fixtures/demo_auto_route` |
| Navigator 1.0 | `MaterialApp`/`CupertinoApp` + `routes` / `onGenerateRoute` | `fixtures/demo_navigator` |
| Navigator 2.0 | `MaterialApp.router` / `RouterDelegate` + `pages:` | `fixtures/demo_navigator_2` |

## Status

- [x] Imperative GoRouter parse
- [x] go_router_builder TypedGoRoute parse
- [x] AutoRoute parse
- [x] Navigator 1.0 named routes + onGenerateRoute parse
- [x] Navigator 2.0 RouterDelegate pages parse
- [x] Edge + state-hint + scheme extraction
- [x] Pack `.flutter-map` → v2 `.appmap`
- [x] Explore prepare (deep-link flows + plan)
- [x] Agent skill for live simulator/emulator sweep
