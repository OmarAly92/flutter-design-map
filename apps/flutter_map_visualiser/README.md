# Flutter AppMap visualizer

Interactive Flutter web viewer for producer-neutral `.appmap` bundles. It opens a bundled demo on startup; use **Open .appmap** to inspect another map entirely in the browser.

## Run

```bash
flutter pub get
flutter run -d chrome
```

## Features

- layered route graph with crossing reduction, pan/zoom controls, and draggable minimap
- static transitions plus dashed agent-observed and active-flow synthetic edges
- selectable transition details with source expressions, observing flows, and recorded trigger positions
- flow playback with follow camera, keyboard scrubbing, tap/swipe overlays, and state captures
- navigation/deep-link/neighbour modes and replay-command copying
- v1 inline-flow and v2 Argent YAML bundle loading

The viewer never uploads the selected bundle.
