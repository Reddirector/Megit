import 'package:flutter/material.dart';

/// Megit color palette — Refined Black, White, and Purple design language.
/// Redesigned for a sharp, smooth, and visually appealing experience.
class AppColors {
  AppColors._();

  // ── Core Backgrounds ──
  /// Pure black background for maximum contrast.
  static const Color background = Color(0xFF000000);

  /// Secondary background — slightly elevated.
  static const Color backgroundElevated = Color(0xFF0A0A0A);

  /// Tertiary background — for selected / hover states.
  static const Color backgroundTertiary = Color(0xFF121212);

  // ── Surfaces ──
  static const Color surface = Color(0x14FFFFFF);       // rgba(255,255,255,0.08)
  static const Color surfaceHover = Color(0x1FFFFFFF);  // rgba(255,255,255,0.12)
  static const Color surfaceStrong = Color(0x29FFFFFF); // rgba(255,255,255,0.16)

  // ── Text ──
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF717171);
  static const Color textMuted = Color(0xFF4D4D4D);

  // ── Status ──
  static const Color danger = Color(0xFFFF4D4D);
  static const Color success = Color(0xFFBB86FC); // Using light purple for success to match theme
  static const Color warning = Color(0xFFFFB74D);

  // ── Default accents (Black + White + Purple) ──
  /// Primary accent — Vibrant Purple.
  static const Color accentPrimary = Color(0xFF9D4EDD);

  /// Secondary accent — Deeper Purple.
  static const Color accentSecondary = Color(0xFF5A189A);

  /// Tertiary accent — Electric Purple.
  static const Color accentTertiary = Color(0xFFE0AAFF);

  // ── Glass / Blur ──
  static const Color glassBackground = Color(0x99000000); // 60% opacity
  static const Color glassBackgroundStrong = Color(0xCC000000); // 80% opacity
  static const Color glassBorder = Color(0x1FFFFFFF);     // ~12% white
  static const Color glassBorderStrong = Color(0x33FFFFFF); // ~20% white
  static const Color glassFallback = Color(0xEB000000);

  // ── Premium gradients ──
  /// Subtle hero gradient — deep purple to black.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A0B2E),
      Color(0xFF000000),
    ],
  );

  /// Premium card gradient — softly tinted with purple.
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1A9D4EDD), // Very subtle purple
      Color(0x05FFFFFF),
    ],
  );

  /// Compute a harmonious secondary color from a primary accent.
  /// Adjusted for Purple theme.
  static Color computeSecondary(Color primary) {
    final HSLColor hsl = HSLColor.fromColor(primary);
    return HSLColor.fromAHSL(
      1.0,
      (hsl.hue - 15) % 360,
      (hsl.saturation * 0.8).clamp(0.0, 1.0),
      (hsl.lightness * 0.7).clamp(0.15, 0.85),
    ).toColor();
  }

  /// Build a 2-stop accent gradient from a primary color.
  static LinearGradient accentGradient(Color primary) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primary, computeSecondary(primary)],
    );
  }

  /// Build a subtle radial halo gradient (for backgrounds behind art).
  static RadialGradient haloGradient(Color color) {
    return RadialGradient(
      colors: [
        color.withValues(alpha: 0.30),
        color.withValues(alpha: 0.05),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    );
  }
}
