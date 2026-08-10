import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Visual language aligned with expo-map's visualiser.
class VisualiserTheme {
  static const Color bg = Color(0xFF0A0C11);
  static const Color panel = Color(0xB811141C);
  static const Color panelSolid = Color(0xFF11141C);
  static const Color panelBorder = Color(0x14FFFFFF);
  static const Color fg = Color(0xFFE8EAF0);
  static const Color muted = Color(0xFF8B93A7);
  static const Color accent = Color(0xFF818CF8);
  static const Color accentBright = Color(0xFFA5B4FC);
  static const Color cyan = Color(0xFF67E8F9);
  static const Color warn = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF87171);

  static ThemeData build() {
    final TextTheme textTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: fg, displayColor: fg);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        surface: panelSolid,
        primary: accent,
        secondary: cyan,
        onSurface: fg,
        onPrimary: Colors.white,
      ),
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF5A63E8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'ok':
        return accentBright;
      case 'empty-state':
        return muted;
      case 'missing':
      case 'auth-wall':
      case 'loading':
        return warn;
      case 'error-boundary':
      case 'not-found':
        return danger;
      default:
        return muted;
    }
  }

  static int hueForGroup(String group) {
    int h = 0;
    for (final int code in group.codeUnits) {
      h = (h * 31 + code) % 360;
    }
    return h;
  }

  static Color groupColor(String group) {
    final int hue = hueForGroup(group.isEmpty ? 'root' : group);
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.70, 0.62).toColor();
  }
}

class BrokenStatus {
  const BrokenStatus({required this.icon, required this.label});

  final String icon;
  final String label;

  static BrokenStatus? forCapture(String status) {
    switch (status) {
      case 'error-boundary':
        return const BrokenStatus(icon: '⛌', label: 'crashes on deep link');
      case 'not-found':
        return const BrokenStatus(icon: '∅', label: 'params hit nothing real');
      case 'loading':
        return const BrokenStatus(icon: '◌', label: 'stuck loading');
      case 'auth-wall':
        return const BrokenStatus(icon: '🔒', label: 'behind sign-in');
      case 'missing':
        return const BrokenStatus(icon: '⚠', label: 'no capture');
      default:
        return null;
    }
  }
}
