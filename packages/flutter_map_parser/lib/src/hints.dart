import 'dart:io';

import 'package:flutter_map_parser/src/model.dart';
import 'package:path/path.dart' as p;

/// Extracts Flutter state hints (sheets / dialogs / modals) from a Dart file.
List<StateHint> extractStateHints(String filePath) {
  final File file = File(filePath);
  if (!file.existsSync()) {
    return <StateHint>[];
  }
  return extractStateHintsFromSource(file.readAsStringSync());
}

List<StateHint> extractStateHintsFromSource(String source) {
  final List<StateHint> hints = <StateHint>[];
  if (source.contains('showModalBottomSheet') ||
      source.contains('showBottomSheet') ||
      source.contains('DraggableScrollableSheet')) {
    hints.add(
      StateHint(
        type: 'bottom-sheet',
        lib: 'material',
        snapPoints: _extractSnapPoints(source),
      ),
    );
  }
  const List<(String, String)> sheetPackages = <(String, String)>[
    ('package:wolt_modal_sheet', 'wolt_modal_sheet'),
    ('package:modal_bottom_sheet', 'modal_bottom_sheet'),
    ('package:sheet/', 'sheet'),
  ];
  for (final (String importNeedle, String libName) in sheetPackages) {
    if (source.contains(importNeedle)) {
      hints.add(
        StateHint(
          type: 'bottom-sheet',
          lib: libName,
          snapPoints: _extractSnapPoints(source),
        ),
      );
    }
  }
  if (source.contains('showDialog') ||
      source.contains('AlertDialog') ||
      source.contains('showCupertinoDialog')) {
    hints.add(const StateHint(type: 'dialog'));
  }
  if (source.contains('showGeneralDialog')) {
    hints.add(const StateHint(type: 'modal'));
  }
  return _dedupeHints(hints);
}

List<String>? _extractSnapPoints(String source) {
  final List<String> points = <String>[];
  final RegExpMatch? list = RegExp(
    r'snapPoints\s*[:=][^\[]*\[([^\]]+)\]',
    multiLine: true,
  ).firstMatch(source);
  if (list != null) {
    points.addAll(
      list
          .group(1)!
          .split(',')
          .map((String value) =>
              value.trim().replaceAll(RegExp(r'''["'`]'''), ''))
          .where((String value) => value.isNotEmpty),
    );
  }
  for (final RegExpMatch match in RegExp(
    r'(?:initial|min|max)ChildSize\s*:\s*(0?\.\d+|1(?:\.0+)?)',
  ).allMatches(source)) {
    final double? fraction = double.tryParse(match.group(1)!);
    if (fraction != null) {
      final String point = '${(fraction * 100).round()}%';
      if (!points.contains(point)) {
        points.add(point);
      }
    }
  }
  return points.isEmpty ? null : points;
}

void applyHintsToRoutes({
  required List<RouteNode> routes,
  required String projectRoot,
}) {
  for (final RouteNode route in routes) {
    final String absolutePath =
        p.isAbsolute(route.file) ? route.file : p.join(projectRoot, route.file);
    final List<StateHint> hints = extractStateHints(absolutePath);
    route.stateHints
      ..clear()
      ..addAll(hints);
    if (route.presentation != null &&
        route.presentation!.toLowerCase().contains('modal')) {
      route.stateHints.add(
        StateHint(
          type: 'router-modal',
          presentation: route.presentation,
        ),
      );
    }
  }
}

List<StateHint> _dedupeHints(List<StateHint> hints) {
  final Set<String> seen = <String>{};
  final List<StateHint> unique = <StateHint>[];
  for (final StateHint hint in hints) {
    final String key = '${hint.type}|${hint.lib}|${hint.presentation}';
    if (seen.add(key)) {
      unique.add(hint);
    }
  }
  return unique;
}
