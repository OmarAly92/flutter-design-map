# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs.

Phase 1 ships a **GoRouter / go_router_builder AST parser** that emits the same working `graph.json` contract used by expo-map (`nodes`/`routes`, `edges`, scheme, state hints).

## Quick start

```bash
cd packages/flutter_map_parser
dart pub get
dart test
dart run bin/parse_routes.dart ../../fixtures/demo_go_router
# → fixtures/demo_go_router/.flutter-map/graph.json

dart run bin/parse_routes.dart ../../fixtures/demo_go_router_builder
```

## Layout

- `packages/flutter_map_parser` — Dart CLI + library (`analyzer`-based)
- `fixtures/demo_go_router` — imperative `GoRouter` fixture
- `fixtures/demo_go_router_builder` — `@TypedGoRoute` fixture

## Status

- [x] Imperative `GoRouter` / `GoRoute` tree parse
- [x] `go_router_builder` `@TypedGoRoute` / nested typed routes
- [x] `context.go` / `push` / `goNamed` + `Route().go(context)` edge extraction
- [x] Material bottom-sheet / dialog hints
- [x] Android / iOS deep-link scheme
- [ ] AutoRoute
- [ ] Exploration / pack / visualiser skill
