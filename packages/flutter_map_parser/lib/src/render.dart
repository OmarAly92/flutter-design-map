import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class RenderResult {
  const RenderResult({
    required this.outPath,
    required this.routeCount,
    required this.captureCount,
  });

  final String outPath;
  final int routeCount;
  final int captureCount;
}

/// Renders a dependency-free HTML contact map for capture review and sharing.
RenderResult renderStaticMap({
  required String projectRoot,
  String workingDirName = '.flutter-map',
  String? outPath,
}) {
  final String root = p.normalize(p.absolute(projectRoot));
  final String work = p.join(root, workingDirName);
  final File graphFile = File(p.join(work, 'graph.json'));
  if (!graphFile.existsSync()) {
    throw StateError('Missing $workingDirName/graph.json under $root.');
  }
  final Map<String, Object?> graph =
      jsonDecode(graphFile.readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> statuses = _readJsonMap(
    p.join(work, 'capture-status.json'),
  );
  final List<Map<String, Object?>> routes =
      ((graph['routes'] as List<Object?>?) ?? <Object?>[])
          .whereType<Map>()
          .map((Map raw) => Map<String, Object?>.from(raw))
          .toList();
  final List<Map<String, Object?>> edges =
      ((graph['edges'] as List<Object?>?) ?? <Object?>[])
          .whereType<Map>()
          .map((Map raw) => Map<String, Object?>.from(raw))
          .toList();
  final Directory screens = Directory(p.join(work, 'screens'));
  final Map<String, File> screenFiles = <String, File>{};
  if (screens.existsSync()) {
    for (final File file in screens.listSync().whereType<File>()) {
      if (RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false)
          .hasMatch(file.path)) {
        screenFiles[p.basename(file.path)] = file;
      }
    }
  }

  int captureCount = 0;
  final StringBuffer cards = StringBuffer();
  for (final Map<String, Object?> route in routes) {
    final String id = route['id']?.toString() ?? '';
    final String slug = route['slug']?.toString() ?? id;
    final Map<String, Object?> status = Map<String, Object?>.from(
      statuses[id] as Map? ?? <String, Object?>{},
    );
    final File? base = _baseCapture(screenFiles, slug);
    if (base != null) {
      captureCount++;
    }
    final List<File> states = screenFiles.entries
        .where(
            (MapEntry<String, File> entry) => entry.key.startsWith('$slug--'))
        .map((MapEntry<String, File> entry) => entry.value)
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
    captureCount += states.length;
    cards.writeln('<article class="screen">');
    cards.writeln('<div class="phone">${_imageOrPlaceholder(base)}</div>');
    cards.writeln('<h2>${_html(route['urlPath']?.toString() ?? id)}</h2>');
    cards.writeln('<code>${_html(id)}</code>');
    final String verdict =
        status['status']?.toString() ?? (base == null ? 'missing' : 'ok');
    cards.writeln('<span class="status $verdict">${_html(verdict)}</span>');
    if (status['note'] != null) {
      cards.writeln('<p>${_html(status['note'].toString())}</p>');
    }
    if (states.isNotEmpty) {
      cards.writeln(
          '<details><summary>${states.length} runtime state(s)</summary><div class="states">');
      for (final File state in states) {
        cards.writeln(
            '<figure>${_imageOrPlaceholder(state)}<figcaption>${_html(p.basenameWithoutExtension(state.path).substring(slug.length + 2))}</figcaption></figure>');
      }
      cards.writeln('</div></details>');
    }
    cards.writeln('</article>');
  }

  final StringBuffer edgeRows = StringBuffer();
  for (final Map<String, Object?> edge in edges) {
    edgeRows.writeln(
      '<li><code>${_html(edge['from']?.toString() ?? '')}</code> '
      '→ <code>${_html(edge['to']?.toString() ?? 'unresolved')}</code> '
      '<span>${_html(edge['raw']?.toString() ?? '')}</span></li>',
    );
  }
  final String appName = p.basename(root);
  final String html = '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_html(appName)} · app map</title><style>
:root{color-scheme:dark;font:14px Inter,ui-sans-serif,system-ui;background:#090b10;color:#f3f4f6}*{box-sizing:border-box}body{margin:0;padding:28px;background:radial-gradient(circle at 50% 0,#182039 0,transparent 35%),#090b10}header{max-width:1440px;margin:auto auto 24px}h1{margin:0 0 8px}.sub{color:#9ca3af}.grid{max-width:1440px;margin:auto;display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:24px}.screen{padding:14px;border:1px solid #ffffff18;border-radius:18px;background:#11141ccc;box-shadow:0 12px 35px #0008}.phone{aspect-ratio:402/874;border:5px solid #252a36;border-radius:25px;overflow:hidden;background:#171b25;display:grid;place-items:center}.phone img{width:100%;height:100%;object-fit:cover}.missing-art{color:#6b7280}.screen h2{font-size:13px;margin:12px 0 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.screen code{font-size:10px;color:#a5b4fc}.status{float:right;padding:3px 7px;border-radius:99px;background:#ffffff0d;font-size:10px}.status.ok{color:#67e8f9}.status.missing,.status.error-boundary,.status.not-found{color:#fda4af}.screen p{font-size:11px;color:#9ca3af}.states{display:flex;gap:8px;overflow:auto;margin-top:8px}.states figure{min-width:100px;margin:0}.states figcaption{font-size:9px;color:#9ca3af}.edges{max-width:1440px;margin:36px auto;padding:20px;border:1px solid #ffffff18;border-radius:18px;background:#11141c}.edges li{margin:8px 0;color:#9ca3af}.edges span{margin-left:8px}summary{cursor:pointer;color:#67e8f9;margin-top:10px}
</style></head><body><header><h1>${_html(appName)}</h1><div class="sub">${routes.length} screens · $captureCount captures · ${edges.length} edges · generated ${_html(DateTime.now().toUtc().toIso8601String())}</div></header><main class="grid">$cards</main><section class="edges"><h2>Transitions</h2><ul>$edgeRows</ul></section></body></html>''';
  final String output = p.normalize(
    p.absolute(outPath ?? p.join(work, 'map.html')),
  );
  File(output)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(html);
  return RenderResult(
    outPath: output,
    routeCount: routes.length,
    captureCount: captureCount,
  );
}

Map<String, Object?> _readJsonMap(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    return <String, Object?>{};
  }
  final Object? decoded = jsonDecode(file.readAsStringSync());
  return decoded is Map
      ? Map<String, Object?>.from(decoded)
      : <String, Object?>{};
}

File? _baseCapture(Map<String, File> files, String slug) {
  for (final MapEntry<String, File> entry in files.entries) {
    if (p.basenameWithoutExtension(entry.key) == slug) {
      return entry.value;
    }
  }
  return null;
}

String _imageOrPlaceholder(File? file) {
  if (file == null) {
    return '<span class="missing-art">no capture</span>';
  }
  final String ext = p.extension(file.path).toLowerCase();
  final String mime = ext == '.jpg' || ext == '.jpeg'
      ? 'image/jpeg'
      : ext == '.webp'
          ? 'image/webp'
          : 'image/png';
  return '<img alt="" src="data:$mime;base64,${base64Encode(file.readAsBytesSync())}">';
}

String _html(String value) => const HtmlEscape().convert(value);
