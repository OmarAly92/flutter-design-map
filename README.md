# flutter-map

Flutter producer for [expo-map](https://github.com/aleqsio/expo-map)-compatible navigation graphs and `.appmap` bundles.

## Pipeline

```
parse_routes      →  .flutter-map/graph.json
prepare_explore   →  explore-plan.json + deeplink flows + capture-status
(agent skill)     →  screenshots + nav/state flows on simulator/emulator
pack_map          →  *.appmap
render_map        →  self-contained map.html review/contact sheet
visualiser (web)  →  open *.appmap in-browser
```

## Visualiser (Flutter web)

```bash
cd apps/flutter_map_visualiser
flutter pub get
flutter run -d chrome
```

The bundled demo opens automatically. Open an `.appmap` from `.flutter-map/` (or any expo-map-compatible bundle) to replace it. Pan/zoom the graph, select routes or transitions, inspect static and agent-observed edges, and scrub recorded flows.

![Flutter Map visualiser showing the captured Bluesky navigation graph and an agent flow](docs/images/flutter-map-visualiser.jpg)

*The bundled Bluesky map with its Home route selected, connected navigation
edges, replay controls, and graph minimap.*

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

## Agent skill

The `flutter-map` skill can run the complete mapping workflow for another
Flutter project: parse its routes, prepare deep links, capture screens and
runtime states on a simulator or emulator, record navigation flows, and package
the result as an expo-map-compatible `.appmap` bundle.

### Install

From this repository, link the skill into your agent's skill directory:

```bash
# Codex
mkdir -p ~/.codex/skills
ln -s "$(pwd)/skills/flutter-map" ~/.codex/skills/flutter-map

# Cursor
ln -s "$(pwd)/skills/flutter-map" ~/.cursor/skills/flutter-map

# Claude
ln -s "$(pwd)/skills/flutter-map" ~/.claude/skills/flutter-map
```

Start a new agent task after installation so the skill is discovered.

### Use

Open the Flutter project you want to map, then ask Codex:

```text
Use $flutter-map to create a full navigation map of this app.
```

You can also supply a project path or limit how far the workflow runs:

```text
Use $flutter-map on /path/to/my_flutter_app.
Use $flutter-map --prepare on this app.
Use $flutter-map --static on this app.
```

| Mode | Result |
|------|--------|
| default | Full parse, simulator/emulator capture, flow recording, and packaging |
| `--prepare` | Parse routes and write the exploration plan and deep-link flow stubs, then stop |
| `--static` | Parse and package without launching a simulator; captures are marked missing |

In Cursor or Claude, invoke `/flutter-map` instead.

For the best full capture, boot an iOS Simulator or Android emulator first,
configure a working deep-link scheme, and make safe fixture or test data
available for parameterized and authenticated routes. When native devices are
unavailable, the skill can use its more limited browser-capture fallback.

### Output

All generated files stay inside the mapped Flutter project:

```text
.flutter-map/
├── graph.json
├── explore-plan.json
├── capture-status.json
├── screens/
├── flows/
├── map.html
└── <app-name>-<date>.appmap
```

Open the final `.appmap` with the Flutter visualiser above, or open `map.html`
for a self-contained review. Consider adding `.flutter-map/` to the target
project's `.gitignore`.

See [`skills/flutter-map/SKILL.md`](skills/flutter-map/SKILL.md) for the full
capture procedure and safety rules.

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
- [x] Flutter web `.appmap` visualiser (`apps/flutter_map_visualiser`)
- [x] Observed/synthetic edges, transition trigger pinning, and state-aware playback
- [x] Static self-contained `map.html` review fallback
- [x] Legacy JSON → Argent flow migration
