# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs.

Phase 1 ships a **GoRouter AST parser** that emits the same working `graph.json` contract used by expo-map (`nodes`/`routes`, `edges`, scheme, state hints).

## Quick start

```bash
cd packages/flutter_map_parser
dart pub get
dart test
dart run bin/parse_routes.dart ../../fixtures/demo_go_router
# → fixtures/demo_go_router/.flutter-map/graph.json
```

## Layout

- `packages/flutter_map_parser` — Dart CLI + library (`analyzer`-based)
- `fixtures/demo_go_router` — minimal GoRouter app (4 routes, nested params, sheet hint, `demomap` scheme)

## Status

- [x] Imperative `GoRouter` / `GoRoute` tree parse
- [x] `context.go` / `push` / `goNamed` edge extraction
- [x] Material bottom-sheet / dialog hints
- [x] Android / iOS deep-link scheme
- [ ] `go_router_builder` annotations
- [ ] AutoRoute
- [ ] Exploration / pack / visualiser skill
