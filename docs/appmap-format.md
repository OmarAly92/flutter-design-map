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

## Commands

```bash
cd packages/flutter_map_parser
dart run bin/parse_routes.dart ../../fixtures/demo_go_router
dart run bin/pack_map.dart ../../fixtures/demo_go_router

# or both:
dart run bin/flutter_map.dart ../../fixtures/demo_go_router
```

See upstream docs: https://github.com/aleqsio/expo-map/blob/main/docs/appmap-format.md
