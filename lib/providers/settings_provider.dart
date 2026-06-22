import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

// ── Settings State ──────────────────────────────────────────────────────────

enum LayoutMode { list, grid, masonry }

class SettingsState {
  final String streamingQuality;
  final String downloadQuality;
  final int crossfadeDuration;
  final bool dataSaverMode;
  final Color accentColor;
  final bool persistentStorage;
  
  // Library view preferences
  final LayoutMode libraryLayoutMode;
  final String librarySortKey;
  final String librarySortOrder;
  
  // Downloads view preferences
  final LayoutMode downloadsLayoutMode;
  final String downloadsSortKey;
  final String downloadsSortOrder;

  // General Playlist/Section Layout
  final LayoutMode playlistLayoutMode;

  const SettingsState({
    this.streamingQuality = 'high',
    this.downloadQuality = 'high',
    this.crossfadeDuration = 9,
    this.dataSaverMode = false,
    this.accentColor = const Color(0xFF9D4EDD),
    this.persistentStorage = false,
    this.libraryLayoutMode = LayoutMode.masonry,
    this.librarySortKey = 'recent',
    this.librarySortOrder = 'desc',
    this.downloadsLayoutMode = LayoutMode.masonry,
    this.downloadsSortKey = 'recent',
    this.downloadsSortOrder = 'desc',
    this.playlistLayoutMode = LayoutMode.masonry,
  });

  SettingsState copyWith({
    String? streamingQuality,
    String? downloadQuality,
    int? crossfadeDuration,
    bool? dataSaverMode,
    Color? accentColor,
    bool? persistentStorage,
    LayoutMode? libraryLayoutMode,
    String? librarySortKey,
    String? librarySortOrder,
    LayoutMode? downloadsLayoutMode,
    String? downloadsSortKey,
    String? downloadsSortOrder,
    LayoutMode? playlistLayoutMode,
  }) {
    return SettingsState(
      streamingQuality: streamingQuality ?? this.streamingQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      dataSaverMode: dataSaverMode ?? this.dataSaverMode,
      accentColor: accentColor ?? this.accentColor,
      persistentStorage: persistentStorage ?? this.persistentStorage,
      libraryLayoutMode: libraryLayoutMode ?? this.libraryLayoutMode,
      librarySortKey: librarySortKey ?? this.librarySortKey,
      librarySortOrder: librarySortOrder ?? this.librarySortOrder,
      downloadsLayoutMode: downloadsLayoutMode ?? this.downloadsLayoutMode,
      downloadsSortKey: downloadsSortKey ?? this.downloadsSortKey,
      downloadsSortOrder: downloadsSortOrder ?? this.downloadsSortOrder,
      playlistLayoutMode: playlistLayoutMode ?? this.playlistLayoutMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'streamingQuality': streamingQuality,
        'downloadQuality': downloadQuality,
        'crossfadeDuration': crossfadeDuration,
        'dataSaverMode': dataSaverMode,
        'accentColor': accentColor.toARGB32(),
        'persistentStorage': persistentStorage,
        'libraryLayoutMode': libraryLayoutMode.index,
        'librarySortKey': librarySortKey,
        'librarySortOrder': librarySortOrder,
        'downloadsLayoutMode': downloadsLayoutMode.index,
        'downloadsSortKey': downloadsSortKey,
        'downloadsSortOrder': downloadsSortOrder,
        'playlistLayoutMode': playlistLayoutMode.index,
      };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
        streamingQuality: json['streamingQuality'] ?? 'high',
        downloadQuality: json['downloadQuality'] ?? 'high',
        crossfadeDuration: json['crossfadeDuration'] ?? 9,
        dataSaverMode: json['dataSaverMode'] ?? false,
        accentColor: Color(json['accentColor'] ?? 0xFF9D4EDD),
        persistentStorage: json['persistentStorage'] ?? false,
        libraryLayoutMode: LayoutMode.values[(json['libraryLayoutMode'] ?? 2).clamp(0, 2)],
        librarySortKey: json['librarySortKey'] ?? 'recent',
        librarySortOrder: json['librarySortOrder'] ?? 'desc',
        downloadsLayoutMode: LayoutMode.values[(json['downloadsLayoutMode'] ?? 2).clamp(0, 2)],
        downloadsSortKey: json['downloadsSortKey'] ?? 'recent',
        downloadsSortOrder: json['downloadsSortOrder'] ?? 'desc',
        playlistLayoutMode: LayoutMode.values[(json['playlistLayoutMode'] ?? 2).clamp(0, 2)],
      );
}

class SettingsNotifier extends Notifier<SettingsState> {
  final _db = FirebaseFirestore.instance;

  @override
  SettingsState build() {
    // 1. Load from disk asynchronously
    Future.microtask(_loadFromDisk);

    // 2. Optimized cloud sync - fetch only once on login and use local cache
    ref.listen(authProvider, (previous, next) {
      if (next.user != null && previous?.user?.uid != next.user!.uid) {
        // Run sync in microtask to not block UI during startup
        Future.microtask(() => _syncFromFirestore(next.user!.uid));
      }
      if (previous?.user != null && next.user == null) {
        reset();
      }
    });

    return const SettingsState();
  }

  Future<void> _loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      streamingQuality: _toFrontend(prefs.getString('megit_streaming_quality') ?? 'high'),
      downloadQuality: _toFrontend(prefs.getString('megit_download_quality') ?? 'high'),
      crossfadeDuration: prefs.getInt('megit_crossfade') ?? 9,
      dataSaverMode: prefs.getBool('megit_data_saver') ?? false,
      accentColor: Color(prefs.getInt('megit_accent_color_int') ?? 0xFF9D4EDD),
      persistentStorage: prefs.getBool('megit_persistent_storage') ?? false,
      libraryLayoutMode: LayoutMode.values[(prefs.getInt('megit_lib_layout_mode') ?? 2).clamp(0, 2)],
      librarySortKey: prefs.getString('megit_lib_sort_key') ?? 'recent',
      librarySortOrder: prefs.getString('megit_lib_sort_order') ?? 'desc',
      downloadsLayoutMode: LayoutMode.values[(prefs.getInt('megit_dl_layout_mode') ?? 2).clamp(0, 2)],
      downloadsSortKey: prefs.getString('megit_dl_sort_key') ?? 'recent',
      downloadsSortOrder: prefs.getString('megit_dl_sort_order') ?? 'desc',
      playlistLayoutMode: LayoutMode.values[(prefs.getInt('megit_playlist_layout') ?? 2).clamp(0, 2)],
    );
  }

  Future<void> _syncFromFirestore(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).collection('settings').doc('app').get();
      if (doc.exists) {
        state = SettingsState.fromJson(doc.data()!);
        _saveToDisk();
      } else {
        _saveToFirestore(uid);
      }
    } catch (e) {
      debugPrint('[Settings] Firestore sync error: $e');
    }
  }

  void setStreamingQuality(String q) { state = state.copyWith(streamingQuality: q); _save(); }
  void setDownloadQuality(String q) { state = state.copyWith(downloadQuality: q); _save(); }
  void setCrossfade(int s) { state = state.copyWith(crossfadeDuration: s.clamp(0, 12)); _save(); }
  void setDataSaver(bool e) { state = state.copyWith(dataSaverMode: e); _save(); }
  void setAccentColor(Color c) { state = state.copyWith(accentColor: c); _save(); }
  void setPersistentStorage(bool e) { state = state.copyWith(persistentStorage: e); _save(); }
  void setLibraryLayoutMode(LayoutMode m) { state = state.copyWith(libraryLayoutMode: m); _save(); }
  void setLibrarySort(String k, String o) { state = state.copyWith(librarySortKey: k, librarySortOrder: o); _save(); }
  void setDownloadsLayoutMode(LayoutMode m) { state = state.copyWith(downloadsLayoutMode: m); _save(); }
  void setDownloadsSort(String k, String o) { state = state.copyWith(downloadsSortKey: k, downloadsSortOrder: o); _save(); }
  void setPlaylistLayoutMode(LayoutMode m) { state = state.copyWith(playlistLayoutMode: m); _save(); }

  Future<void> reset() async {
    state = const SettingsState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> _save() async {
    await _saveToDisk();
    final user = ref.read(authProvider).user;
    if (user != null) await _saveToFirestore(user.uid);
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('megit_streaming_quality', _toBackend(state.streamingQuality));
    await prefs.setString('megit_download_quality', _toBackend(state.downloadQuality));
    await prefs.setInt('megit_crossfade', state.crossfadeDuration);
    await prefs.setBool('megit_data_saver', state.dataSaverMode);
    await prefs.setBool('megit_persistent_storage', state.persistentStorage);
    await prefs.setInt('megit_accent_color_int', state.accentColor.toARGB32());
    await prefs.setInt('megit_lib_layout_mode', state.libraryLayoutMode.index);
    await prefs.setString('megit_lib_sort_key', state.librarySortKey);
    await prefs.setString('megit_lib_sort_order', state.librarySortOrder);
    await prefs.setInt('megit_dl_layout_mode', state.downloadsLayoutMode.index);
    await prefs.setString('megit_dl_sort_key', state.downloadsSortKey);
    await prefs.setString('megit_dl_sort_order', state.downloadsSortOrder);
    await prefs.setInt('megit_playlist_layout', state.playlistLayoutMode.index);
  }

  Future<void> _saveToFirestore(String uid) async {
    try {
      await _db.collection('users').doc(uid).collection('settings').doc('app').set(state.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Settings] Firestore save error: $e');
    }
  }

  static String _toBackend(String q) => switch (q) { 'automatic' => 'auto', 'normal' => 'medium', _ => q };
  static String _toFrontend(String q) => switch (q) { 'auto' => 'automatic', 'medium' => 'normal', _ => q };
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
