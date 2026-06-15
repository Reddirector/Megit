import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

// ── Settings State ──────────────────────────────────────────────────────────

class SettingsState {
  final String streamingQuality; // 'automatic', 'low', 'normal', 'high'
  final String downloadQuality;
  final int crossfadeDuration; // 0-12 seconds
  final bool dataSaverMode;
  final Color accentColor;
  final bool persistentStorage;
  
  // Library view preferences (synced to cloud)
  final bool libraryGridView;
  final String librarySortKey;
  final String librarySortOrder;
  
  // Downloads view preferences (synced to cloud)
  final bool downloadsGridView;
  final String downloadsSortKey;
  final String downloadsSortOrder;

  const SettingsState({
    this.streamingQuality = 'high',
    this.downloadQuality = 'high',
    this.crossfadeDuration = 9,
    this.dataSaverMode = false,
    this.accentColor = const Color(0xFF9D4EDD),
    this.persistentStorage = false,
    this.libraryGridView = false,
    this.librarySortKey = 'recent',
    this.librarySortOrder = 'desc',
    this.downloadsGridView = false,
    this.downloadsSortKey = 'recent',
    this.downloadsSortOrder = 'desc',
  });

  SettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeDuration,
    bool? dataSaverMode,
    Color? accentColor,
    bool? persistentStorage,
    bool? libraryGridView,
    String? librarySortKey,
    String? librarySortOrder,
    bool? downloadsGridView,
    String? downloadsSortKey,
    String? downloadsSortOrder,
  }) {
    return SettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      accentColor: accentColor ?? this.accentColor,
      persistentStorage: persistentStorage ?? this.persistentStorage,
      libraryGridView: libraryGridView ?? this.libraryGridView,
      librarySortKey: librarySortKey ?? this.librarySortKey,
      librarySortOrder: librarySortOrder ?? this.librarySortOrder,
      downloadsGridView: downloadsGridView ?? this.downloadsGridView,
      downloadsSortKey: downloadsSortKey ?? this.downloadsSortKey,
      downloadsSortOrder: downloadsSortOrder ?? this.downloadsSortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'streamingQuality': streamingQuality,
        'downloadQuality': downloadQuality,
        'crossfadeDuration': crossfadeDuration,
        'dataSaverMode': dataSaverMode,
        'accentColor': accentColor.toARGB32(),
        'persistentStorage': persistentStorage,
        'libraryGridView': libraryGridView,
        'librarySortKey': librarySortKey,
        'librarySortOrder': librarySortOrder,
        'downloadsGridView': downloadsGridView,
        'downloadsSortKey': downloadsSortKey,
        'downloadsSortOrder': downloadsSortOrder,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
        streamingQuality: json['streamingQuality'] ?? 'high',
        downloadQuality: json['downloadQuality'] ?? 'high',
        crossfadeDuration: json['crossfadeDuration'] ?? 9,
        dataSaverMode: json['dataSaverMode'] ?? false,
        accentColor: Color(json['accentColor'] ?? 0xFF9D4EDD),
        persistentStorage: json['persistentStorage'] ?? false,
        libraryGridView: json['libraryGridView'] ?? false,
        librarySortKey: json['librarySortKey'] ?? 'recent',
        librarySortOrder: json['librarySortOrder'] ?? 'desc',
        downloadsGridView: json['downloadsGridView'] ?? false,
        downloadsSortKey: json['downloadsSortKey'] ?? 'recent',
        downloadsSortOrder: json['downloadsSortOrder'] ?? 'desc',
      );
}

// ── Settings Provider ───────────────────────────────────────────────────────

/// Settings stored locally in SharedPreferences AND synced to Firestore for the logged-in user.
class SettingsNotifier extends Notifier<SettingsState> {
  final _db = FirebaseFirestore.instance;

  @override
  SettingsState build() {
    // 1. Load from disk asynchronously after first build
    Future.microtask(_loadFromDisk);

    // 2. Listen to auth changes to sync from Firestore and handle logout
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && previous?.user?.uid != next.user!.uid) {
        _syncFromFirestore(next.user!.uid);
      }
      if (previous?.user != null && next.user == null) {
        reset();
      }
    });

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
      persistentStorage: prefs.getBool('megit_persistent_storage') ?? false,
      libraryGridView: prefs.getBool('megit_lib_view_mode_grid') ?? false,
      librarySortKey: prefs.getString('megit_lib_sort_key') ?? 'recent',
      librarySortOrder: prefs.getString('megit_lib_sort_order') ?? 'desc',
      downloadsGridView: prefs.getBool('megit_dl_view_mode_grid') ?? false,
      downloadsSortKey: prefs.getString('megit_dl_sort_key') ?? 'recent',
      downloadsSortOrder: prefs.getString('megit_dl_sort_order') ?? 'desc',
    );
  }

  Future<void> _syncFromFirestore(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).collection('settings').doc('app').get();
      if (doc.exists) {
        final data = doc.data()!;
        state = SettingsState.fromJson(data);
        _saveToDisk(); // Update local cache
      } else {
        // If no cloud settings, upload current local settings
        _saveToFirestore(uid);
      }
    } catch (e) {
      debugPrint('[Settings] Firestore sync error: $e');
    }
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

  void setPersistentStorage(bool enabled) {
    state = state.copyWith(persistentStorage: enabled);
    _save();
  }

  void setLibraryGridView(bool grid) {
    state = state.copyWith(libraryGridView: grid);
    _save();
  }

  void setLibrarySort(String key, String order) {
    state = state.copyWith(librarySortKey: key, librarySortOrder: order);
    _save();
  }

  void setDownloadsGridView(bool grid) {
    state = state.copyWith(downloadsGridView: grid);
    _save();
  }

  void setDownloadsSort(String key, String order) {
    state = state.copyWith(downloadsSortKey: key, downloadsSortOrder: order);
    _save();
  }

  // ── Reset ──

  Future<void> reset() async {
    state = const SettingsState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('megit_streaming_quality');
    await prefs.remove('megit_download_quality');
    await prefs.remove('megit_crossfade');
    await prefs.remove('megit_data_saver');
    await prefs.remove('megit_accent_color_int');
    await prefs.remove('megit_persistent_storage');
    await prefs.remove('megit_lib_view_mode_grid');
    await prefs.remove('megit_lib_sort_key');
    await prefs.remove('megit_lib_sort_order');
    await prefs.remove('megit_dl_view_mode_grid');
    await prefs.remove('megit_dl_sort_key');
    await prefs.remove('megit_dl_sort_order');
  }

  // ── Persist ──

  Future<void> _save() async {
    await _saveToDisk();
    final user = ref.read(authProvider).user;
    if (user != null) {
      await _saveToFirestore(user.uid);
    }
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('megit_streaming_quality', _toBackend(state.streamingQuality));
    await prefs.setString('megit_download_quality', _toBackend(state.downloadQuality));
    await prefs.setInt('megit_crossfade', state.crossfadeDuration);
    await prefs.setBool('megit_data_saver', state.dataSaverMode);
    await prefs.setBool('megit_persistent_storage', state.persistentStorage);
    await prefs.setInt('megit_accent_color_int', state.accentColor.toARGB32());
    await prefs.setBool('megit_lib_view_mode_grid', state.libraryGridView);
    await prefs.setString('megit_lib_sort_key', state.librarySortKey);
    await prefs.setString('megit_lib_sort_order', state.librarySortOrder);
    await prefs.setBool('megit_dl_view_mode_grid', state.downloadsGridView);
    await prefs.setString('megit_dl_sort_key', state.downloadsSortKey);
    await prefs.setString('megit_dl_sort_order', state.downloadsSortOrder);
  }

  Future<void> _saveToFirestore(String uid) async {
    try {
      await _db.collection('users').doc(uid).collection('settings').doc('app').set(
            state.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('[Settings] Firestore save error: $e');
    }
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
