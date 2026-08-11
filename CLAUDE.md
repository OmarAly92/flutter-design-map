# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A toolchain that turns a Flutter app into a visual navigation map. Three deliverables live side by side and share one data contract:

- `packages/flutter_map_parser/` — pure Dart CLI/library: static route parsing, explore-plan generation, `.appmap` packing, static HTML rendering, legacy flow migration.
- `skills/flutter-design-map-skills/SKILL.md` — the agent skill that orchestrates the live phases (boot simulator, deep-link sweep, capture states, record flows) around those CLIs.
- `apps/flutter_map_visualiser/` — Flutter web app that loads a packed `.appmap` and renders the graph, flows, and captures.

The `.appmap` format is copied from [expo-map](https://github.com/aleqsio/expo-map) and is producer-neutral; `docs/appmap-format.md` is the authoritative contract.

## Commands

Parser (run from `packages/flutter_map_parser` — tests resolve fixtures relative to `Directory.current`):

```bash
cd packages/flutter_map_parser && dart pub get && dart test
```

```bash
cd packages/flutter_map_parser && dart test test/parse_demo_fixture_test.dart -n 'parses demo fixture'
```

```bash
cd packages/flutter_map_parser && dart analyze
```

Pipeline CLIs (each takes a project root, defaults to cwd):

```bash
dart run bin/parse_routes.dart <project>      # -> .flutter-map/graph.json
dart run bin/prepare_explore.dart <project>   # -> explore-plan.json, capture-status.json, flows/deeplink-*.yaml
dart run bin/pack_map.dart <project>          # -> .flutter-map/<app>-<date>.appmap
dart run bin/render_map.dart <project>        # -> .flutter-map/map.html (dependency-free review page)
dart run bin/convert_flows.dart <project> --delete-v1
dart run bin/flutter_map.dart <project>       # parse + render + pack in one shot
```

Visualiser:

```bash
cd apps/flutter_map_visualiser && flutter pub get && flutter test
```

```bash
cd apps/flutter_map_visualiser && flutter run -d chrome
```

Deployed to Render from `render.yaml` → `apps/flutter_map_visualiser/Dockerfile` (`flutter build web --release` behind nginx, health check `/healthz`).

## Parser architecture

`parseProject()` in `lib/src/parse.dart` is the single entry point and fixes the phase order:

1. `detect.dart` picks one `RoutingMode` by scanning `pubspec.yaml` + every `lib/**.dart`. Precedence is deliberate and order-sensitive: go_router_builder → go_router → auto_route → navigator → navigator_2. A project can trip several detectors; only the first wins.
2. One `modes/*.dart` parser runs and returns a mode-specific `*ParseResult` (`routes`, `layouts`, `routerFile`, plus `stackEdges` for navigator_2). Each mode parser walks the analyzer AST (`package:analyzer`, `parseString`) and is responsible for producing `RouteNode`s with stable `id`, `urlPath`, `slug`, and `params`. If a mode is detected but yields zero routes, it throws rather than degrading.
3. Shared post-passes run identically for every mode: `hints.dart` (source-text sniffing for sheets/dialogs/modals), `edges.dart` (navigation call extraction), `scheme.dart` (deep-link scheme from AndroidManifest → Info.plist → Dart fallback).

`edges.dart` + `path_index.dart` + `const_strings.dart` are the resolution layer: `ProjectPathIndex` pre-indexes every project-wide string constant and static path helper so navigation targets written as `AppPaths.foo`, `Routes.settings.root`, or `'${Routes.tutorials}/$id'` resolve to concrete paths. Generated files (`*.g.dart`, `*.gr.dart`) are skipped everywhere. An `Edge.to` of `null` means unresolved — that is a normal, reported outcome, not a failure.

`from` attribution is heuristic (nearest route declared in the same file); navigation called from shared widgets can be misattributed. Don't "fix" a test that encodes this.

## The slug contract

`RouteNode.slug` is the join key across the whole system and is load-bearing in four places at once:

- `explore.dart` writes `screens/<slug>.png` paths and `flows/deeplink-<slug>.yaml` into the plan.
- The skill captures screenshots at exactly those paths, plus state variants as `<slug>--<state>.png`.
- `pack.dart` matches base captures by exact `<slug>` basename and derives node `capture.states` by prefix-matching `<slug>--`.
- The visualiser resolves screenshots by the `screens/...` paths in `map.json`.

Changing slug generation in any mode parser silently breaks capture matching. Capture statuses are the closed set `ok · empty-state · not-found · error-boundary · loading · auth-wall · missing`; `needsNavigation: true` means the deep link is insufficient and the recorded flow is authoritative.

## Flow format

Flows are runnable Argent YAML plus a `<name>.meta.json` sidecar. The sidecar's `steps` map is sparse and keyed by **0-based YAML step index**; screenshots are sidecar `capture` fields, never YAML steps. A navigating tap/swipe must carry `"screen": "<route id>"` — the visualiser uses exactly that field to derive agent-observed edges. Coordinates are normalized 0–1.

## Visualiser architecture

Everything is parsed client-side; bundles are never uploaded.

`AppMapLoader.loadBytes` (unzip, accept formatVersion 1 or 2) → `AppMapBundle` (`models/appmap_bundle.dart`) → `FlowResolution.fromBundle` (maps each flow step onto a node id by matching `open_url` targets against node `urlPath` patterns, carrying `step.screen` forward) → `buildGraphEdges` (collapses static parser edges per route pair, then adds **observed** edges for recorded hops static analysis missed, plus **synthetic** edges for gaps in the active flow) → `GraphLayout.compute` (layered top-down, isolated nodes in a grid below) → `MapCanvas` / `EdgePainter` / `NodeCard`.

`pages/visualiser_home_page.dart` owns all app state (selection, flow playback step, camera transform, keyboard handling) and passes it down; the widgets are presentational. `theme/visualiser_theme.dart` holds the dark palette mirroring expo-map's visualiser — use its constants rather than inline colors. Node geometry constants (`kNodeWidth`, `kPhoneAspect` = 402/874, etc.) live in `layout/graph_layout.dart` and are shared by the canvas, minimap, and painters.

## Fixtures

`fixtures/demo_*` are minimal apps, one per routing mode, and exist to be parsed as source — they are never built or `pub get`-ed. Parser tests assert exact route/edge counts against them.

Adding or changing a routing mode means touching: `detect.dart` (detection + precedence + `routingModeLabel`), a new `modes/*.dart` returning routes/layouts, the `switch` in `parse.dart`, a fixture under `fixtures/`, tests, and the routing-mode tables in `README.md` and `skills/flutter-design-map-skills/SKILL.md`.

## Distribution

The repo doubles as a multi-harness skill package: `.claude-plugin/`,
`.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.agents/`, `.opencode/`,
`.pi/`, `gemini-extension.json`, `install.sh`, `bump-version.sh`. All of them
point at `./skills/` and ship the whole repo, because the skill shells out to
`packages/flutter_map_parser` — `SKILL.md` resolves that path at runtime from
`${CLAUDE_PLUGIN_ROOT}`, then from its own `pwd -P` directory two levels up.
The skill is explicit-invocation only — `SKILL.md` sets
`disable-model-invocation: true`, so the model cannot start it; the user runs
`/flutter-design-map-skills`. [`AGENTS.md`](AGENTS.md) has the full rationale
and the per-harness table.
Release with `./bump-version.sh <x.y.z>`.

## Keeping the three surfaces in sync

CLI flags, output filenames, capture statuses, and the flow/sidecar schema appear in code **and** in `skills/flutter-design-map-skills/SKILL.md`, `docs/appmap-format.md`, and `README.md`. A change to any of them is incomplete until those three documents match — the skill is executed literally by an agent, so a stale command there is a real bug.

The skill's safety rules are non-negotiable when writing or generating flows: never record credentials (use `{{secret:NAME}}`), never tap destructive controls (delete, purchase, sign out, submit), and never reconstruct a flow after the fact instead of recording each action as it succeeds.
