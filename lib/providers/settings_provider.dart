import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Settings State ──────────────────────────────────────────────────────────

class SettingsState {
  final String streamingQuality; // 'automatic', 'low', 'normal', 'high'
  final String downloadQuality;
  final int crossfadeDuration; // 0-12 seconds
  final bool dataSaverMode;
  final Color accentColor;

  const SettingsState({
    this.streamingQuality = 'high',
    this.downloadQuality = 'high',
    this.crossfadeDuration = 9,
    this.dataSaverMode = false,
    this.accentColor = const Color(0xFF9D4EDD),
  });

  SettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeDuration,
    bool? dataSaverMode,
    Color? accentColor,
  }) {
    return SettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

// ── Settings Provider ───────────────────────────────────────────────────────

/// Settings stored entirely in SharedPreferences — no backend required.
/// Each setting is saved immediately on change and restored on app launch.
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Load from disk asynchronously after first build
    Future.microtask(_loadFromDisk);
    return const SettingsState();
  }

  // ── Load ──

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      streamingQuality: _toFrontend(prefs.getString('megit_streaming_quality') ?? 'high'),
      downloadQuality: _toFrontend(prefs.getString('megit_download_quality') ?? 'high'),
      crossfadeDuration: prefs.getInt('megit_crossfade') ?? 9,
      dataSaverMode: prefs.getBool('megit_data_saver') ?? false,
      accentColor: Color(prefs.getInt('megit_accent_color_int') ?? 0xFF9D4EDD),
    );
  }

  // ── Setters (each saves immediately) ──

  void setStreamingQuality(String quality) {
    state = state.copyWith(streamingQuality: quality);
    _save();
  }

  void setDownloadQuality(String quality) {
    state = state.copyWith(downloadQuality: quality);
    _save();
  }

  void setCrossfade(int seconds) {
    state = state.copyWith(crossfadeDuration: seconds.clamp(0, 12));
    _save();
  }

  void setDataSaver(bool enabled) {
    state = state.copyWith(dataSaverMode: enabled);
    _save();
  }

  void setAccentColor(Color color) {
    state = state.copyWith(accentColor: color);
    _save();
  }

  // ── Persist ──

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('megit_streaming_quality', _toBackend(state.streamingQuality));
    await prefs.setString('megit_download_quality', _toBackend(state.downloadQuality));
    await prefs.setInt('megit_crossfade', state.crossfadeDuration);
    await prefs.setBool('megit_data_saver', state.dataSaverMode);
    await prefs.setInt('megit_accent_color_int', state.accentColor.toARGB32());
  }

  // ── Quality string mapping ──

  static String _toBackend(String q) => switch (q) {
    'automatic' => 'auto',
    'normal' => 'medium',
    _ => q,
  };

  static String _toFrontend(String q) => switch (q) {
    'auto' => 'automatic',
    'medium' => 'normal',
    _ => q,
  };
}

// ── Provider Registration ───────────────────────────────────────────────────

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
