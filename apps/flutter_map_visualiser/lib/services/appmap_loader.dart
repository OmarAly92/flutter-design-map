import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart';

import '../models/appmap_bundle.dart';

/// Loads a v2 `.appmap` zip from raw bytes.
class AppMapLoader {
  const AppMapLoader();

  AppMapBundle loadBytes(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final Map<String, Uint8List> files = <String, Uint8List>{};
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final String name = file.name.replaceFirst(RegExp(r'^/+'), '');
      files[name] = Uint8List.fromList(file.content as List<int>);
    }
    final Uint8List? manifestBytes = files['manifest.json'];
    final Uint8List? mapBytes = files['map.json'];
    if (manifestBytes == null || mapBytes == null) {
      throw const FormatException(
        'Invalid .appmap: missing manifest.json or map.json',
      );
    }
    final Map<String, Object?> manifestJson =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
    final Map<String, Object?> mapJson =
        jsonDecode(utf8.decode(mapBytes)) as Map<String, Object?>;
    final AppMapManifest manifest = AppMapManifest.fromJson(manifestJson);
    if (manifest.formatVersion != 1 && manifest.formatVersion != 2) {
      throw FormatException(
        'Unsupported formatVersion ${manifest.formatVersion}',
      );
    }
    final List<AppMapNode> nodes =
        ((mapJson['nodes'] as List<Object?>?) ?? <Object?>[])
            .whereType<Map>()
            .map(
              (Map raw) => AppMapNode.fromJson(Map<String, Object?>.from(raw)),
            )
            .toList();
    final List<AppMapEdge> edges =
        ((mapJson['edges'] as List<Object?>?) ?? <Object?>[])
            .whereType<Map>()
            .map(
              (Map raw) => AppMapEdge.fromJson(Map<String, Object?>.from(raw)),
            )
            .toList();
    final Map<String, Uint8List> screenshots = <String, Uint8List>{};
    for (final MapEntry<String, Uint8List> entry in files.entries) {
      if (entry.key.startsWith('screens/')) {
        screenshots[entry.key] = entry.value;
      }
    }
    final List<AppMapFlow> flows = _loadFlows(
      files,
      mapJson,
      manifest.formatVersion,
    );
    return AppMapBundle(
      manifest: manifest,
      nodes: nodes,
      edges: edges,
      flows: flows,
      screenshots: screenshots,
    );
  }

  List<AppMapFlow> _loadFlows(
    Map<String, Uint8List> files,
    Map<String, Object?> mapJson,
    int formatVersion,
  ) {
    if (formatVersion >= 2) {
      final List<AppMapFlow> flows = <AppMapFlow>[];
      for (final String name in files.keys) {
        if (!RegExp(r'^flows/.+\.yaml$').hasMatch(name)) {
          continue;
        }
        final String flowName = name.substring(
          'flows/'.length,
          name.length - '.yaml'.length,
        );
        try {
          final Map<String, Object?> meta = _readMeta(
            files['flows/$flowName.meta.json'],
          );
          flows.add(
            _argentFlowToInternal(flowName, utf8.decode(files[name]!), meta),
          );
        } catch (_) {
          // Skip malformed flows; the rest of the map still loads.
        }
      }
      flows.sort((AppMapFlow a, AppMapFlow b) => a.name.compareTo(b.name));
      return flows;
    }
    return ((mapJson['flows'] as List<Object?>?) ?? <Object?>[])
        .whereType<Map>()
        .map((Map raw) => _legacyFlow(Map<String, Object?>.from(raw)))
        .toList();
  }

  Map<String, Object?> _readMeta(Uint8List? bytes) {
    if (bytes == null) {
      return <String, Object?>{};
    }
    final Object? decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is Map) {
      return Map<String, Object?>.from(decoded);
    }
    return <String, Object?>{};
  }

  AppMapFlow _argentFlowToInternal(
    String name,
    String yamlText,
    Map<String, Object?> meta,
  ) {
    final Object? doc = loadYaml(yamlText);
    final Map<dynamic, dynamic> root = doc is Map ? doc : <dynamic, dynamic>{};
    final List<dynamic> rawSteps =
        (root['steps'] as List<dynamic>?) ?? <dynamic>[];
    final Map<String, Object?> metaSteps = Map<String, Object?>.from(
      meta['steps'] as Map? ?? <String, Object?>{},
    );
    final List<FlowStep> steps = <FlowStep>[];
    for (int i = 0; i < rawSteps.length; i++) {
      final Object? raw = rawSteps[i];
      final Map<String, Object?> stepMeta = Map<String, Object?>.from(
        metaSteps['$i'] as Map? ?? <String, Object?>{},
      );
      if (raw is! Map) {
        steps.add(
          FlowStep(action: raw.toString(), note: stepMeta['note'] as String?),
        );
        continue;
      }
      final Map<String, Object?> map = Map<String, Object?>.from(raw);
      final String? key = map.keys.isEmpty ? null : map.keys.first.toString();
      if (key == 'tool' && map['tool'] == 'open-url') {
        final Map<String, Object?> args = Map<String, Object?>.from(
          map['args'] as Map? ?? <String, Object?>{},
        );
        steps.add(
          FlowStep(
            action: 'open_url',
            url: args['url'] as String?,
            note: stepMeta['note'] as String?,
            screen: stepMeta['screen'] as String?,
          ),
        );
      } else if (key == 'tool' && map['tool'] == 'gesture-swipe') {
        final Map<String, Object?> args = Map<String, Object?>.from(
          map['args'] as Map? ?? <String, Object?>{},
        );
        steps.add(
          FlowStep(
            action: 'swipe',
            from: <double>[
              (args['fromX'] as num?)?.toDouble() ?? 0,
              (args['fromY'] as num?)?.toDouble() ?? 0,
            ],
            to: <double>[
              (args['toX'] as num?)?.toDouble() ?? 0,
              (args['toY'] as num?)?.toDouble() ?? 0,
            ],
            screen: stepMeta['screen'] as String?,
            note: stepMeta['note'] as String?,
          ),
        );
      } else if (key == 'wait') {
        final num ms = (map['wait'] as num?) ?? 1000;
        steps.add(FlowStep(action: 'wait', seconds: ms / 1000));
      } else if (key == 'tap' || key == 'long-press') {
        final Object? val = map[key];
        final List<double>? point = _tapPoint(val);
        steps.add(
          FlowStep(
            action: 'tap',
            coordinate: point ?? _numList(stepMeta['coordinate']),
            target: stepMeta['target'] as String? ?? _selectorLabel(val),
            screen: stepMeta['screen'] as String?,
            note: stepMeta['note'] as String?,
          ),
        );
      } else if (key == 'type') {
        final Map<String, Object?> val = Map<String, Object?>.from(
          map['type'] as Map? ?? <String, Object?>{},
        );
        steps.add(
          FlowStep(
            action: 'type',
            text: val['text'] as String?,
            target: _selectorLabel(val['into']),
            screen: stepMeta['screen'] as String?,
          ),
        );
      } else if (key == 'launch') {
        steps.add(FlowStep(action: 'launch', text: map['launch']?.toString()));
      } else {
        steps.add(
          FlowStep(
            action: key ?? 'unknown',
            note: stepMeta['note'] as String?,
            screen: stepMeta['screen'] as String?,
          ),
        );
      }
      final String? capture = stepMeta['capture'] as String?;
      if (capture != null && capture.isNotEmpty) {
        steps.add(FlowStep(action: 'screenshot', capture: capture));
      }
    }
    return AppMapFlow(
      name: name,
      title: meta['title'] as String? ?? name,
      route: meta['route'] as String?,
      device: meta['device'] as String?,
      result: meta['result'] as String?,
      pointSize: const <double>[1, 1],
      steps: steps,
    );
  }

  AppMapFlow _legacyFlow(Map<String, Object?> json) {
    final List<Object?> rawSteps =
        (json['steps'] as List<Object?>?) ?? <Object?>[];
    return AppMapFlow(
      name: json['name'] as String? ?? 'flow',
      title: json['title'] as String? ?? json['name'] as String? ?? 'flow',
      route: json['route'] as String?,
      device: json['device'] as String?,
      result: json['result'] as String?,
      pointSize: _numList(json['pointSize']) ?? const <double>[1, 1],
      steps: rawSteps.whereType<Map>().map((Map raw) {
        final Map<String, Object?> map = Map<String, Object?>.from(raw);
        return FlowStep(
          action: map['action'] as String? ?? 'unknown',
          url: map['url'] as String?,
          target: map['target'] as String?,
          screen: map['screen'] as String?,
          note: map['note'] as String?,
          capture: map['file'] as String? ?? map['capture'] as String?,
          coordinate: _numList(map['coordinate']),
          from: _numList(map['from']),
          to: _numList(map['to']),
          text: map['text'] as String?,
          seconds: (map['seconds'] as num?)?.toDouble(),
        );
      }).toList(),
    );
  }

  List<double>? _tapPoint(Object? val) {
    if (val is Map) {
      final Map<String, Object?> map = Map<String, Object?>.from(val);
      if (map['x'] is num && map['y'] is num) {
        return <double>[
          (map['x'] as num).toDouble(),
          (map['y'] as num).toDouble(),
        ];
      }
      if (map['on'] is Map) {
        return _tapPoint(map['on']);
      }
    }
    return null;
  }

  List<double>? _numList(Object? value) {
    if (value is! List) {
      return null;
    }
    return value.whereType<num>().map((num n) => n.toDouble()).toList();
  }

  String? _selectorLabel(Object? sel) {
    if (sel is String) {
      return sel;
    }
    if (sel is Map) {
      final Map<String, Object?> map = Map<String, Object?>.from(sel);
      if (map['x'] is num) {
        return null;
      }
      return map['text'] as String? ??
          map['id'] as String? ??
          map['role'] as String?;
    }
    return null;
  }
}
