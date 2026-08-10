# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs and `.appmap` bundles.

## Pipeline

```
parse_routes  →  .flutter-map/graph.json
(+ optional screens/flows from exploration)
pack_map      →  *.appmap   (visualiser-ready zip)
```

## Quick start

```bash
cd packages/flutter_map_parser
dart pub get
dart test

# parse + pack in one step
dart run bin/flutter_map.dart ../../fixtures/demo_go_router
```

## Routing modes

| Mode | Detection | Fixture |
|------|-----------|---------|
| GoRouter | `GoRouter(` | `fixtures/demo_go_router` |
| go_router_builder | `@TypedGoRoute` | `fixtures/demo_go_router_builder` |
| AutoRoute | `@AutoRouterConfig` | `fixtures/demo_auto_route` |

## Status

- [x] Imperative GoRouter parse
- [x] go_router_builder TypedGoRoute parse
- [x] AutoRoute parse
- [x] Edge + state-hint + scheme extraction
- [x] Pack `.flutter-map` → v2 `.appmap`
- [ ] Simulator / device exploration skill (screenshots + argent flows)
