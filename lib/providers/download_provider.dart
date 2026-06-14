import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/local/download_db.dart';
import '../data/models/song.dart';
import '../data/models/playlist.dart';
import 'settings_provider.dart';
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

  @override
  DownloadState build() {
    Future.microtask(() => _refreshCounts());
    return const DownloadState();
  }

  Future<void> _refreshCounts() async {
    final count = await _db.getDownloadCount();
    final size = await _db.getTotalSize();
    state = state.copyWith(downloadedCount: count, totalSizeBytes: size);
  }

  Future<bool> isDownloaded(String videoId) => _db.isDownloaded(videoId);
  Future<String?> getFilePath(String videoId) => _db.getFilePath(videoId);
  
  // Re-add missing methods for playlist_screen compatibility
  Future<List<Song>> getAllDownloadedSongs() => _db.getAllTracks();
  Future<List<Playlist>> getAllOfflinePlaylists() => _db.getAllOfflinePlaylists();
  Future<void> deleteDownload(String videoId) => removeDownload(videoId);
  Future<void> updateOfflinePlaylistSongs(String pid, List<String> ids) => _db.updateOfflinePlaylistSongs(pid, ids);
  Future<void> clearAll() async {
     final songs = await _db.getAllTracks();
     for (final s in songs) {
        await removeDownload(s.videoId);
     }
  }
  Future<void> renameOfflinePlaylist(String pid, String name) => _db.renameOfflinePlaylist(pid, name);
  Future<void> deleteOfflinePlaylist(String pid) => _db.deleteOfflinePlaylist(pid);

  Future<void> downloadSong(Song song, {Playlist? contextPlaylist}) async {
    final videoId = song.videoId;
    if (videoId.isEmpty) return;
    if (await _db.isDownloaded(videoId)) return;
    if (state.activeDownloads.containsKey(videoId)) return;

    _updateProgress(videoId, 0.0);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory(p.join(appDir.path, 'downloads'));
      if (!await downloadDir.exists()) await downloadDir.create(recursive: true);

      final dlQuality = ref.read(settingsProvider).downloadQuality;
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
          await _db.addTrackToPlaylist('__pl__${contextPlaylist.id}', contextPlaylist.name, videoId);
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
