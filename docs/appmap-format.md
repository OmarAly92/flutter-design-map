# .appmap bundle format (v2)

Copied contract from [expo-map](https://github.com/aleqsio/expo-map) — producer-agnostic.
`flutter-map` writes the same zip so the existing visualiser can load Flutter apps.

Working directory (append-friendly):

```
.flutter-map/
  graph.json              # from parse_routes
  capture-status.json     # optional, from exploration
  screens/*.png           # optional screenshots
  flows/*.yaml            # optional argent flows
  flows/*.meta.json
```

Packed bundle:

```
<app>-<date>.appmap       (zip)
├── manifest.json
├── map.json
├── screens/
└── flows/
```

## `manifest.json`

```json
{
  "formatVersion": 2,
  "flowFormat": "argent",
  "generator": "flutter-map/0.1",
  "app": {
    "name": "example",
    "scheme": "example",
    "platform": "ios-simulator",
    "device": "iPhone 17 Pro",
    "mode": "go_router"
  },
  "generatedAt": "2026-08-10T00:00:00Z"
}
```

Viewers accept format versions 1 and 2, ignore unknown fields, and reject every other version.

## `map.json`

`nodes` contain stable route IDs, URL patterns, source files, layout groups, parameters, presentations, runtime-state hints, and capture verdicts. State screenshots use `screens/<slug>--<state>.<ext>`. `edges` contain `from`, nullable `to`, the original source expression in `raw`, and normalized `target`. Version 2 keeps `flows` empty because replay files are stored under `flows/`.

Capture statuses are `ok`, `empty-state`, `not-found`, `error-boundary`, `loading`, `auth-wall`, or `missing`. `needsNavigation` means a bare deep link is insufficient and the recorded navigation flow is authoritative.

## Argent flows

Each flow is a runnable `<name>.yaml` plus `<name>.meta.json`. The sidecar carries the route ID, device, title, and sparse per-YAML-step metadata:

```json
{
  "formatVersion": 2,
  "name": "nav-settings",
  "route": "settings",
  "steps": {
    "2": {
      "target": "Settings tab",
      "screen": "settings",
      "capture": "settings.png"
    }
  }
}
```

Coordinates are normalized 0–1. Navigating taps/swipes require `screen`; screenshot captures attach to the step after which they were taken. Flows replay with `npx @swmansion/argent flow run .flutter-map/flows/<name>.yaml`.

## Commands

```bash
cd packages/flutter_map_parser
dart run bin/parse_routes.dart ../../fixtures/demo_go_router
dart run bin/pack_map.dart ../../fixtures/demo_go_router
dart run bin/render_map.dart ../../fixtures/demo_go_router

# migrate v1 JSON flows when needed:
dart run bin/convert_flows.dart ../../fixtures/demo_go_router --delete-v1

# or both:
dart run bin/flutter_map.dart ../../fixtures/demo_go_router
```

See upstream docs: https://github.com/aleqsio/expo-map/blob/main/docs/appmap-format.md
