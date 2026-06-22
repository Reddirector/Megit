import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/song.dart';
import '../data/api/spotify_api.dart';
import '../services/ytmusic_api.dart';
import '../data/api/music_api.dart';
import '../data/models/playlist.dart';
import 'auth_provider.dart';
import '../services/apple_music/apple_music_api.dart';
import '../services/tune_my_music_api.dart';
import '../services/csv_parser_service.dart';
import 'dart:io';

// ── Import Task Model ────────────────────────────────────────────────────────

class ImportTask {
  final String id;
  final String url;
  final String name;
  final int totalSongs;
  final int processedSongs;
  final int matchedSongs;
  // 'fetching' | 'matching' | 'saving' | 'done' | 'error'
  final String status;
  final String platform; // 'spotify' | 'ytmusic' | 'apple' | 'tunemymusic' | 'csv'
  final String? errorMessage;
  final String? playlistId; // Firestore ID after save

  ImportTask({
    required this.id,
    required this.url,
    required this.name,
    this.totalSongs = 0,
    this.processedSongs = 0,
    this.matchedSongs = 0,
    this.status = 'fetching',
    required this.platform,
    this.errorMessage,
    this.playlistId,
  });

  ImportTask copyWith({
    String? name,
    int? totalSongs,
    int? processedSongs,
    int? matchedSongs,
    String? status,
    String? errorMessage,
    String? playlistId,
  }) {
    return ImportTask(
      id: id,
      url: url,
      name: name ?? this.name,
      totalSongs: totalSongs ?? this.totalSongs,
      processedSongs: processedSongs ?? this.processedSongs,
      matchedSongs: matchedSongs ?? this.matchedSongs,
      status: status ?? this.status,
      platform: platform,
      errorMessage: errorMessage ?? this.errorMessage,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  double get progress =>
      totalSongs > 0 ? processedSongs / totalSongs : 0.0;

  bool get isDone => status == 'done' || status == 'error';
  bool get isSpotify => platform == 'spotify';
  bool get isApple => platform == 'apple';
  bool get isTMM => platform == 'tunemymusic';
  bool get isCSV => platform == 'csv';
}

// ── Import Notifier ──────────────────────────────────────────────────────────

class ImportNotifier extends StateNotifier<Map<String, ImportTask>> {
  final Ref _ref;
  final _spotifyApi = SpotifyApi();
  final _ytMusicApi = YtMusicApi();
  final _musicApi = MusicApi();
  final _appleMusicApi = AppleMusicApi();
  final _tmmApi = TuneMyMusicApi();
  final _db = FirebaseFirestore.instance;

  // New library sync state
  List<Playlist>? _fetchedLibrary;
  bool _isFetchingLibrary = false;
  String? _libraryError;

  ImportNotifier(this._ref) : super({});

  List<Playlist>? get fetchedLibrary => _fetchedLibrary;
  bool get isFetchingLibrary => _isFetchingLibrary;
  String? get libraryError => _libraryError;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startImport(String url) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    debugPrint('[Import] Starting import for URL: $url');

    final isSpotify = url.contains('spotify.com');
    final isApple = url.contains('music.apple.com');
    final isTMM = url.contains('tunemymusic.com/share');
    final isYtMusic = url.contains('music.youtube.com') ||
        url.contains('youtube.com/playlist') ||
        url.contains('youtube.com/watch') ||
        _extractYtmBrowseId(url) != null;

    String platform = 'ytmusic';
    if (isSpotify) platform = 'spotify';
    if (isApple) platform = 'apple';
    if (isTMM) platform = 'tunemymusic';
    
    debugPrint('[Import] Detected platform: $platform');

    if (!isSpotify && !isYtMusic && !isApple && !isTMM) {
      debugPrint('[Import] Unsupported URL format');
      _upsert(taskId, (t) => ImportTask(
        id: taskId,
        url: url,
        name: 'Playlist Import',
        platform: 'unknown',
        status: 'error',
        errorMessage: 'Unsupported URL. Please use Spotify, Apple, YT Music, or TuneMyMusic.',
      ));
      return;
    }

    _upsert(taskId, (t) => ImportTask(
      id: taskId,
      url: url,
      name: isSpotify ? 'Spotify Playlist' : (isApple ? 'Apple Music Playlist' : (isTMM ? 'Shared Playlist' : 'YouTube Music Playlist')),
      platform: platform,
      status: 'fetching',
    ));

    // Run import in background
    if (isSpotify) {
      unawaited(_importSpotify(taskId, url));
    } else if (isApple) {
      unawaited(_importAppleMusic(taskId, url));
    } else if (isTMM) {
      unawaited(_importTMM(taskId, url));
    } else {
      unawaited(_importYtMusic(taskId, url));
    }
  }

  Future<void> startCSVImport(File file) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final fileName = file.path.split('/').last;
    
    _upsert(taskId, (t) => ImportTask(
      id: taskId,
      url: 'file://${file.path}',
      name: fileName,
      platform: 'csv',
      status: 'fetching',
    ));

    unawaited(_importCSV(taskId, file));
  }

  // ── CSV Import ─────────────────────────────────────────────────────────────

  Future<void> _importCSV(String taskId, File file) async {
    try {
      debugPrint('[Import] Parsing CSV file: ${file.path}');
      final csvData = await CSVParserService.parseFile(file);

      debugPrint('[Import] CSV Parse success: ${csvData.name}, ${csvData.tracks.length} tracks');
      _upsert(taskId, (t) => t.copyWith(
        name: csvData.name,
        totalSongs: csvData.tracks.length,
        status: 'matching',
      ));

      final matchedSongs = <Song>[];
      for (int i = 0; i < csvData.tracks.length; i++) {
        final track = csvData.tracks[i];
        try {
          final query = '${track.artist} ${track.title}'.trim();
          final results = await _ytMusicApi.search(query, type: 'song').timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            matchedSongs.add(results.first);
          }
        } catch (e) {
          debugPrint('[Import] CSV Match error at index $i: $e');
        }
        
        _upsert(taskId, (t) => t.copyWith(
          processedSongs: i + 1,
          matchedSongs: matchedSongs.length,
        ));
        if (i % 5 == 4) await Future.delayed(const Duration(milliseconds: 300));
      }

      if (matchedSongs.isEmpty) {
        debugPrint('[Import] CSV Matching failed — 0 songs matched');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'No songs matched on YT Music.'));
        return;
      }

      debugPrint('[Import] CSV Saving playlist: ${matchedSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: '${csvData.name} (CSV)',
        songs: matchedSongs,
        thumbnail: matchedSongs.first.thumbnail,
      );

      _upsert(taskId, (t) => t.copyWith(status: 'done', playlistId: firestoreId));
    } catch (e) {
      debugPrint('[Import] CSV Critical failure: $e');
      _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'CSV import failed: ${e.toString().replaceAll('Exception: ', '')}'));
    }
  }

  // ── Tune My Music Import ────────────────────────────────────────────────────

  Future<void> _importTMM(String taskId, String url) async {
    try {
      final shareId = _tmmApi.extractId(url);
      if (shareId == null) {
        debugPrint('[Import] TMM ID extraction failed');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'Invalid TuneMyMusic URL.'));
        return;
      }

      debugPrint('[Import] Fetching TMM share metadata for: $shareId');
      _upsert(taskId, (t) => t.copyWith(status: 'fetching', name: 'Fetching Shared playlist…'));
      final tmmData = await _tmmApi.getPlaylist(shareId);

      debugPrint('[Import] TMM Scrape success: ${tmmData.name}, ${tmmData.tracks.length} tracks');
      _upsert(taskId, (t) => t.copyWith(
        name: tmmData.name,
        totalSongs: tmmData.tracks.length,
        status: 'matching',
      ));

      final matchedSongs = <Song>[];
      for (int i = 0; i < tmmData.tracks.length; i++) {
        final track = tmmData.tracks[i];
        try {
          final query = '${track.artist} ${track.title}'.trim();
          final results = await _ytMusicApi.search(query, type: 'song').timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            matchedSongs.add(results.first);
          }
        } catch (e) {
          debugPrint('[Import] TMM Match error at index $i: $e');
        }
        
        _upsert(taskId, (t) => t.copyWith(
          processedSongs: i + 1,
          matchedSongs: matchedSongs.length,
        ));
        if (i % 5 == 4) await Future.delayed(const Duration(milliseconds: 300));
      }

      if (matchedSongs.isEmpty) {
        debugPrint('[Import] TMM Matching failed — 0 songs matched');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'No songs matched on YT Music.'));
        return;
      }

      debugPrint('[Import] TMM Saving playlist: ${matchedSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: '${tmmData.name} (Shared)',
        songs: matchedSongs,
        thumbnail: matchedSongs.first.thumbnail,
      );

      _upsert(taskId, (t) => t.copyWith(status: 'done', playlistId: firestoreId));
    } catch (e) {
      debugPrint('[Import] TMM Critical failure: $e');
      _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'TuneMyMusic import failed: $e'));
    }
  }

  Future<void> fetchLibrary(String platform) async {
    _isFetchingLibrary = true;
    _libraryError = null;
    _fetchedLibrary = null;
    state = {...state}; // Trigger rebuild

    try {
      if (platform == 'ytmusic') {
        final auth = _ref.read(authProvider.notifier);
        final token = await auth.ensureYoutubeAccess();
        if (token == null) throw Exception('Google sync cancelled.');
        _fetchedLibrary = await _musicApi.getLibraryPlaylists(token);
      } else if (platform == 'spotify') {
         _libraryError = 'Spotify library sync requires direct login (coming soon).';
      } else if (platform == 'apple') {
         _libraryError = 'Apple Music library sync is coming soon.';
      }
    } catch (e) {
      _libraryError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isFetchingLibrary = false;
      state = {...state};
    }
  }

  void clearLibrary() {
    _fetchedLibrary = null;
    _libraryError = null;
    state = {...state};
  }

  Future<void> importSelected(List<Playlist> selected) async {
    for (final pl in selected) {
      final url = 'https://music.youtube.com/playlist?list=${pl.id.replaceFirst('VL', '')}';
      startImport(url);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void dismissTask(String taskId) {
    final newState = Map<String, ImportTask>.from(state);
    newState.remove(taskId);
    state = newState;
  }

  // ── Apple Music Import ──────────────────────────────────────────────────────

  Future<void> _importAppleMusic(String taskId, String url) async {
    try {
      final info = _appleMusicApi.extractInfo(url);
      if (info == null) {
        debugPrint('[Import] Apple Music info extraction failed');
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Invalid Apple Music URL.',
        ));
        return;
      }

      debugPrint('[Import] Fetching Apple Music metadata for: ${info['id']}');
      _upsert(taskId, (t) => t.copyWith(status: 'fetching', name: 'Fetching Apple Music playlist…'));
      final appleData = await _appleMusicApi.getPlaylist(info['region']!, info['id']!);

      debugPrint('[Import] Apple Scrape success: ${appleData.name}, ${appleData.tracks.length} tracks');
      _upsert(taskId, (t) => t.copyWith(
        name: appleData.name,
        totalSongs: appleData.tracks.length,
        status: 'matching',
      ));

      final matchedSongs = <Song>[];
      for (int i = 0; i < appleData.tracks.length; i++) {
        final track = appleData.tracks[i];
        try {
          final query = '${track.artist} ${track.title}'.trim();
          final results = await _ytMusicApi.search(query, type: 'song').timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            matchedSongs.add(results.first);
          }
        } catch (e) {
          debugPrint('[Import] Apple Match error at index $i: $e');
        }
        
        _upsert(taskId, (t) => t.copyWith(
          processedSongs: i + 1,
          matchedSongs: matchedSongs.length,
        ));
        if (i % 5 == 4) await Future.delayed(const Duration(milliseconds: 300));
      }

      if (matchedSongs.isEmpty) {
        debugPrint('[Import] Apple Matching failed — 0 songs matched');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'No songs matched on YT Music.'));
        return;
      }

      debugPrint('[Import] Apple Saving playlist: ${matchedSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: '${appleData.name} (Apple)',
        songs: matchedSongs,
        thumbnail: matchedSongs.first.thumbnail,
      );

      _upsert(taskId, (t) => t.copyWith(status: 'done', playlistId: firestoreId));
    } catch (e) {
      debugPrint('[Import] Apple Critical failure: $e');
      _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'Apple Music import failed: $e'));
    }
  }

  // ── Spotify Import ─────────────────────────────────────────────────────────

  Future<void> _importSpotify(String taskId, String url) async {
    try {
      final playlistId = _spotifyApi.extractPlaylistId(url);
      if (playlistId == null) {
        debugPrint('[Import] Spotify ID extraction failed');
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Invalid Spotify URL.',
        ));
        return;
      }

      debugPrint('[Import] Fetching Spotify metadata for: $playlistId');
      _upsert(taskId, (t) => t.copyWith(status: 'fetching', name: 'Fetching Spotify playlist…'));
      SpotifyPlaylistData spotifyData;
      try {
        spotifyData = await _spotifyApi.getPlaylist(playlistId).timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('[Import] Spotify Fetch error: $e');
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Could not fetch Spotify metadata: $e',
        ));
        return;
      }

      debugPrint('[Import] Spotify Scrape success: ${spotifyData.name}, ${spotifyData.tracks.length} tracks');
      _upsert(taskId, (t) => t.copyWith(
        name: spotifyData.name,
        totalSongs: spotifyData.tracks.length,
        status: 'matching',
      ));

      final matchedSongs = <Song>[];
      for (int i = 0; i < spotifyData.tracks.length; i++) {
        final track = spotifyData.tracks[i];
        try {
          final query = '${track.artist} ${track.title}'.trim();
          final results = await _ytMusicApi.search(query, type: 'song')
              .timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            final best = results.first;
            final song = best.thumbnail.isNotEmpty ? best : best.copyWith(thumbnail: track.thumbnail);
            matchedSongs.add(song);
          }
        } catch (e) {
          debugPrint('[Import] Spotify Match error at index $i: $e');
        }
        _upsert(taskId, (t) => t.copyWith(
          processedSongs: i + 1,
          matchedSongs: matchedSongs.length,
        ));
        if (i % 5 == 4) await Future.delayed(const Duration(milliseconds: 300));
      }

      if (matchedSongs.isEmpty) {
        debugPrint('[Import] Spotify Matching failed — 0 songs matched');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'No songs matched on YT Music.'));
        return;
      }

      debugPrint('[Import] Spotify Saving playlist: ${matchedSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: '${spotifyData.name} (Spotify)',
        songs: matchedSongs,
        thumbnail: matchedSongs.first.thumbnail,
      );

      _upsert(taskId, (t) => t.copyWith(status: 'done', playlistId: firestoreId));
    } catch (e) {
      debugPrint('[Import] Spotify Critical failure: $e');
      _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'Spotify import failed: $e'));
    }
  }

  // ── YT Music Import ────────────────────────────────────────────────────────

  Future<void> _importYtMusic(String taskId, String url) async {
    try {
      final browseId = _extractYtmBrowseId(url);
      if (browseId == null) {
        debugPrint('[Import] YT Music ID extraction failed');
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Invalid YouTube Music URL.',
        ));
        return;
      }

      debugPrint('[Import] Fetching YT Music metadata for: $browseId');
      _upsert(taskId, (t) => t.copyWith(status: 'fetching', name: 'Fetching YT Music playlist…'));
      final (firstPlaylist, initialToken) = await _musicApi.getPlaylistBatch(browseId);
      
      var allSongs = firstPlaylist.songs.where((s) => s.isPlayable).toList();
      var currentToken = initialToken;
      
      debugPrint('[Import] YT Music First Batch: ${firstPlaylist.name}, ${allSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(
        name: firstPlaylist.name,
        totalSongs: allSongs.length,
        processedSongs: allSongs.length,
        matchedSongs: allSongs.length,
      ));

      int pageCount = 1;
      while (currentToken != null && pageCount < 15) {
        debugPrint('[Import] Fetching YT Music batch $pageCount');
        _upsert(taskId, (t) => t.copyWith(status: 'fetching'));
        final (nextPlaylist, nextToken) = await _musicApi.getPlaylistBatch(browseId, continuation: currentToken);
        final nextSongs = nextPlaylist.songs.where((s) => s.isPlayable).toList();
        if (nextSongs.isEmpty) break;
        allSongs.addAll(nextSongs);
        currentToken = nextToken;
        pageCount++;
        _upsert(taskId, (t) => t.copyWith(processedSongs: allSongs.length, matchedSongs: allSongs.length, totalSongs: allSongs.length));
      }

      if (allSongs.isEmpty) {
        debugPrint('[Import] YT Music Fetch failed — 0 songs found');
        _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'Playlist is empty or private.'));
        return;
      }

      debugPrint('[Import] YT Music Saving playlist: ${allSongs.length} songs');
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: firstPlaylist.name,
        songs: allSongs,
        thumbnail: firstPlaylist.thumbnail ?? (allSongs.isNotEmpty ? allSongs.first.thumbnail : ''),
      );

      _upsert(taskId, (t) => t.copyWith(status: 'done', playlistId: firestoreId));
    } catch (e) {
      debugPrint('[Import] YT Music Critical failure: $e');
      _upsert(taskId, (t) => t.copyWith(status: 'error', errorMessage: 'Import failed: $e'));
    }
  }

  // ── Firestore save ─────────────────────────────────────────────────────────

  Future<String?> _savePlaylist({
    required String name,
    required List<Song> songs,
    String? thumbnail,
  }) async {
    try {
      final auth = _ref.read(authProvider);
      if (auth.user == null) throw Exception('Not logged in');
      final capped = songs.length > 3500 ? songs.sublist(0, 3500) : songs;
      final docRef = await _db.collection('playlists').add({
        'name': name,
        'createdBy': auth.user!.uid,
        'ownerName': auth.displayName ?? 'Megit User',
        'members': [auth.user!.uid],
        'thumbnail': thumbnail ?? '',
        'songs': capped.map((s) => <String, dynamic>{
          ...s.toJson(),
          'addedByUid': auth.user!.uid,
          'addedByName': auth.displayName ?? 'Megit User',
        }).toList(),
        'visibility': 'Public',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _extractYtmBrowseId(String url) {
    final listRegex = RegExp(r'[?&]list=([A-Za-z0-9_-]+)');
    final listMatch = listRegex.firstMatch(url);
    if (listMatch != null) {
      final id = listMatch.group(1)!;
      if (id.startsWith('PL') || id.startsWith('RD') || id.startsWith('OL') || id.startsWith('LL')) {
        return id.startsWith('VL') ? id : 'VL$id';
      }
      return id;
    }
    final browseRegex = RegExp(r'/browse/([A-Za-z0-9_-]+)');
    final browseMatch = browseRegex.firstMatch(url);
    if (browseMatch != null) return browseMatch.group(1);
    return null;
  }

  void _upsert(String taskId, ImportTask Function(ImportTask) update) {
    final existing = state[taskId];
    final next = existing != null ? update(existing) : update(ImportTask(id: taskId, url: '', name: '', platform: 'unknown'));
    state = {...state, taskId: next};
  }

  // ── Auto Import ────────────────────────────────────────────────────────────

  Future<void> startAutoImport({int limit = 5}) async {
    final auth = _ref.read(authProvider);
    final token = auth.accessToken;
    if (token == null) return;
    try {
      final playlists = await _musicApi.getLibraryPlaylists(token);
      final toImport = playlists.take(limit).toList();
      for (final pl in toImport) {
        final url = 'https://music.youtube.com/playlist?list=${pl.id.replaceFirst('VL', '')}';
        await startImport(url);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}
  }

  Future<List<Playlist>> fetchUserPlaylists() async {
    final auth = _ref.read(authProvider);
    final token = auth.accessToken;
    if (token == null) return [];
    try {
      return await _musicApi.getLibraryPlaylists(token);
    } catch (_) {
      return [];
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final importProvider =
    StateNotifierProvider<ImportNotifier, Map<String, ImportTask>>((ref) {
  return ImportNotifier(ref);
});
