import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/local/download_db.dart';
import '../data/models/song.dart';
import '../data/models/playlist.dart';
import 'settings_provider.dart';
import 'auth_provider.dart';
import '../services/stream_extractor.dart';

// ── Download State ──────────────────────────────────────────────────────────

class DownloadProgress {
  final String videoId;
  final double progress; // 0.0 to 1.0
  final bool isComplete;
  final String? error;

  const DownloadProgress({
    required this.videoId,
    this.progress = 0.0,
    this.isComplete = false,
    this.error,
  });
}

class DownloadState {
  final Map<String, DownloadProgress> activeDownloads;
  final int downloadedCount;
  final int totalSizeBytes;

  const DownloadState({
    this.activeDownloads = const {},
    this.downloadedCount = 0,
    this.totalSizeBytes = 0,
  });

  DownloadState copyWith({
    Map<String, DownloadProgress>? activeDownloads,
    int? downloadedCount,
    int? totalSizeBytes,
  }) {
    return DownloadState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
    );
  }
}

// ── Download Provider ───────────────────────────────────────────────────────

class DownloadNotifier extends Notifier<DownloadState> {
  final _db = DownloadDb.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  DownloadState build() {
    Future.microtask(() async {
      await _initPersistentStorage();
      await _refreshCounts();
    });
    return const DownloadState();
  }

  Future<void> _initPersistentStorage() async {
    try {
      final settings = ref.read(settingsProvider);
      if (settings.persistentStorage) {
        if (await ph.Permission.storage.request().isGranted) {
          final publicDir = await _getPublicDownloadDir();
          await DownloadDb.setCustomPath(publicDir.path);
        }
      } else {
        await DownloadDb.setCustomPath(null);
      }
    } catch (e) {
      debugPrint('[Download] Init persistent storage error: $e');
    }
  }

  Future<Directory> _getPublicDownloadDir() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/Download/Megit');
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }
    if (!await baseDir.exists()) await baseDir.create(recursive: true);
    return baseDir;
  }

  Future<void> _refreshCounts() async {
    final count = await _db.getDownloadCount();
    final size = await _db.getTotalSize();
    state = state.copyWith(downloadedCount: count, totalSizeBytes: size);
  }

  Future<bool> isDownloaded(String videoId) => _db.isDownloaded(videoId);
  Future<String?> getFilePath(String videoId) => _db.getFilePath(videoId);
  
  Future<List<Song>> getAllDownloadedSongs() => _db.getAllTracks();
  Future<List<Playlist>> getAllOfflinePlaylists() => _db.getAllOfflinePlaylists();
  Future<void> deleteDownload(String videoId) => removeDownload(videoId);
  
  Future<void> clearAll() async {
     final songs = await _db.getAllTracks();
     for (final s in songs) {
        await removeDownload(s.videoId);
     }
  }

  Future<void> deleteOfflinePlaylist(String pid) async {
    try {
      await _db.deleteOfflinePlaylist(pid);
      final auth = ref.read(authProvider);
      if (auth.user != null) {
        await _firestore.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').doc(pid).delete();
      }
    } catch (e) {
      debugPrint('[Download] Delete offline playlist error: $e');
    }
  }

  Future<void> renameOfflinePlaylist(String pid, String name) async {
    await _db.renameOfflinePlaylist(pid, name);
    final lists = await _db.getAllOfflinePlaylists();
    final pl = lists.where((p) => p.id == pid).firstOrNull;
    if (pl != null) {
      _syncOfflinePlaylist(pl);
    }
  }

  Future<void> updateOfflinePlaylistSongs(String pid, List<String> ids) async {
    await _db.updateOfflinePlaylistSongs(pid, ids);
    final lists = await _db.getAllOfflinePlaylists();
    final pl = lists.where((p) => p.id == pid).firstOrNull;
    if (pl != null && pl.songs.isNotEmpty) {
      _syncOfflinePlaylist(pl);
    } else {
       deleteOfflinePlaylist(pid);
    }
  }

  Future<void> _syncOfflinePlaylist(Playlist playlist) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    try {
      await _firestore.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').doc(playlist.id).set({
        'name': playlist.name,
        'songs': playlist.songs.map((s) => s.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'type': 'OFFLINE_PLAYLIST',
      });
    } catch (e) {
      debugPrint('[Download] Sync offline error: $e');
    }
  }

  Future<void> downloadSong(Song song, {Playlist? contextPlaylist}) async {
    final videoId = song.videoId;
    if (videoId.isEmpty) return;
    if (await _db.isDownloaded(videoId)) return;
    if (state.activeDownloads.containsKey(videoId)) return;

    _updateProgress(videoId, 0.0);

    try {
      final settings = ref.read(settingsProvider);
      final Directory downloadDir;
      if (settings.persistentStorage) {
         downloadDir = await _getPublicDownloadDir();
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory(p.join(appDir.path, 'downloads'));
      }
      if (!await downloadDir.exists()) await downloadDir.create(recursive: true);

      final dlQuality = settings.downloadQuality;
      String? directUrl;
      String ext = 'm4a';
      
      try {
        directUrl = await StreamExtractor.getAudioStreamUrl(videoId, quality: dlQuality)
            .timeout(const Duration(seconds: 20));
        if (directUrl.contains('audio%2Fwebm')) ext = 'webm';
      } catch (e) {
        debugPrint('[Download] Client extraction failed: $e');
        _failDownload(videoId, 'Extraction failed');
        return;
      }

      final tempPath = p.join(downloadDir.path, '$videoId.tmp');
      final finalPath = p.join(downloadDir.path, '$videoId.$ext');

      await Dio().download(directUrl, tempPath, onReceiveProgress: (received, total) {
        if (total != -1) _updateProgress(videoId, received / total);
      });

      final file = File(tempPath);
      if (await file.exists()) {
        await file.rename(finalPath);
        await _db.saveTrack(
          videoId: song.videoId,
          title: song.title,
          artist: song.artist,
          album: song.album,
          thumbnail: song.thumbnail,
          duration: song.duration,
          filePath: finalPath,
          fileSize: await File(finalPath).length(),
        );
        
        if (contextPlaylist != null) {
          final pid = contextPlaylist.id.startsWith('__pl__') ? contextPlaylist.id : '__pl__${contextPlaylist.id}';
          await _db.addTrackToPlaylist(pid, contextPlaylist.name, videoId);
          
          final lists = await _db.getAllOfflinePlaylists();
          final updatedPl = lists.where((p) => p.id == pid).firstOrNull;
          if (updatedPl != null) {
            _syncOfflinePlaylist(updatedPl);
          }
        }
        _completeDownload(videoId);
        _refreshCounts();
      }
    } catch (e) {
      _failDownload(videoId, e.toString());
    }
  }

  Future<void> downloadPlaylist(Playlist playlist) async {
    for (final song in playlist.songs) {
      unawaited(downloadSong(song, contextPlaylist: playlist));
    }
  }

  Future<void> removeDownload(String videoId) async {
    final path = await _db.getFilePath(videoId);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await _db.deleteTrack(videoId);
    _refreshCounts();
  }

  void _updateProgress(String videoId, double progress) {
    final active = Map<String, DownloadProgress>.from(state.activeDownloads);
    active[videoId] = DownloadProgress(videoId: videoId, progress: progress);
    state = state.copyWith(activeDownloads: active);
  }

  void _completeDownload(String videoId) {
    final active = Map<String, DownloadProgress>.from(state.activeDownloads);
    active.remove(videoId);
    state = state.copyWith(activeDownloads: active);
  }

  void _failDownload(String videoId, String error) {
    final active = Map<String, DownloadProgress>.from(state.activeDownloads);
    active[videoId] = DownloadProgress(videoId: videoId, error: error);
    state = state.copyWith(activeDownloads: active);
    Future.delayed(const Duration(seconds: 5), () => _completeDownload(videoId));
  }
}

final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);
