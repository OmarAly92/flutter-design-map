# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs.

Phase 1 ships a **multi-mode route AST parser** (GoRouter, go_router_builder, AutoRoute) that emits the same working `graph.json` contract used by expo-map.

## Quick start

```bash
cd packages/flutter_map_parser
dart pub get
dart test
dart run bin/parse_routes.dart ../../fixtures/demo_go_router
dart run bin/parse_routes.dart ../../fixtures/demo_go_router_builder
dart run bin/parse_routes.dart ../../fixtures/demo_auto_route
```

## Layout

- `packages/flutter_map_parser` — Dart CLI + library (`analyzer`-based)
- `fixtures/demo_go_router` — imperative `GoRouter` fixture
- `fixtures/demo_go_router_builder` — `@TypedGoRoute` fixture
- `fixtures/demo_auto_route` — `@AutoRouterConfig` fixture

## Status

- [x] Imperative `GoRouter` / `GoRoute` tree parse
- [x] `go_router_builder` `@TypedGoRoute` / nested typed routes
- [x] AutoRoute `@AutoRouterConfig` + `AutoRoute(page: X.page)`
- [x] `context.go` / typed `.go` / `context.router.push` edge extraction
- [x] Material bottom-sheet / dialog hints
- [x] Android / iOS deep-link scheme
- [ ] Exploration / pack / visualiser skill
