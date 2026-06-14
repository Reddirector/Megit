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
  final bool isSpotify;
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
    required this.isSpotify,
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
      isSpotify: isSpotify,
      errorMessage: errorMessage ?? this.errorMessage,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  double get progress =>
      totalSongs > 0 ? processedSongs / totalSongs : 0.0;

  bool get isDone => status == 'done' || status == 'error';
}

// ── Import Notifier ──────────────────────────────────────────────────────────

class ImportNotifier extends StateNotifier<Map<String, ImportTask>> {
  final Ref _ref;
  final _spotifyApi = SpotifyApi();
  final _ytMusicApi = YtMusicApi();
  final _musicApi = MusicApi();
  final _db = FirebaseFirestore.instance;

  ImportNotifier(this._ref) : super({});

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startImport(String url) async {
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final isSpotify = url.contains('spotify.com');
    final isYtMusic = url.contains('music.youtube.com') ||
        url.contains('youtube.com/playlist') ||
        url.contains('youtube.com/watch') ||
        _extractYtmBrowseId(url) != null;

    if (!isSpotify && !isYtMusic) {
      // Register task with error immediately
      _upsert(taskId, (t) => ImportTask(
        id: taskId,
        url: url,
        name: 'Playlist Import',
        isSpotify: false,
        status: 'error',
        errorMessage: 'Unsupported URL. Please use a Spotify or YouTube Music link.',
      ));
      return;
    }

    // Register task immediately so UI reacts
    _upsert(taskId, (t) => ImportTask(
      id: taskId,
      url: url,
      name: isSpotify ? 'Spotify Playlist' : 'YouTube Music Playlist',
      isSpotify: isSpotify,
      status: 'fetching',
    ));

    // Run import in background (don't await in UI)
    unawaited(
      isSpotify
          ? _importSpotify(taskId, url)
          : _importYtMusic(taskId, url),
    );
  }

  void dismissTask(String taskId) {
    final newState = Map<String, ImportTask>.from(state);
    newState.remove(taskId);
    state = newState;
  }

  // ── Spotify Import ─────────────────────────────────────────────────────────

  Future<void> _importSpotify(String taskId, String url) async {
    try {
      // 1. Extract playlist ID
      final playlistId = _spotifyApi.extractPlaylistId(url);
      if (playlistId == null) {
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Invalid Spotify URL. Copy the share link from the Spotify app.',
        ));
        return;
      }

      // 2. Fetch Spotify playlist data
      _upsert(taskId, (t) => t.copyWith(status: 'fetching', name: 'Fetching Spotify playlist…'));
      SpotifyPlaylistData spotifyData;
      try {
        spotifyData = await _spotifyApi.getPlaylist(playlistId)
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Could not fetch Spotify playlist. Make sure it is public.',
        ));
        return;
      }

      _upsert(taskId, (t) => t.copyWith(
        name: spotifyData.name,
        totalSongs: spotifyData.tracks.length,
        status: 'matching',
      ));

      // 3. Match each Spotify track to a YouTube Music video
      final matchedSongs = <Song>[];
      for (int i = 0; i < spotifyData.tracks.length; i++) {
        final track = spotifyData.tracks[i];
        try {
          // Search YTMusic: "artist - title" gives best results
          final query = '${track.artist} ${track.title}'.trim();
          final results = await _ytMusicApi.search(query, type: 'song')
              .timeout(const Duration(seconds: 10));
          if (results.isNotEmpty) {
            // Take the best match (first result)
            final best = results.first;
            // Override thumbnail with Spotify's if YTM didn't return one
            final song = best.thumbnail.isNotEmpty
                ? best
                : best.copyWith(thumbnail: track.thumbnail);
            matchedSongs.add(song);
          }
        } catch (_) {
          // Failed to match this track — skip silently
        }
        _upsert(taskId, (t) => t.copyWith(
          processedSongs: i + 1,
          matchedSongs: matchedSongs.length,
        ));

        // Small delay to avoid rate-limiting YTMusic
        if (i % 5 == 4) await Future.delayed(const Duration(milliseconds: 300));
      }

      if (matchedSongs.isEmpty) {
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'No songs could be matched on YouTube Music.',
        ));
        return;
      }

      // 4. Save as a new Firestore playlist
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: '${spotifyData.name} (Spotify)',
        songs: matchedSongs,
        thumbnail: matchedSongs.first.thumbnail,
      );

      _upsert(taskId, (t) => t.copyWith(
        status: 'done',
        playlistId: firestoreId,
        matchedSongs: matchedSongs.length,
      ));
    } catch (e) {
      debugPrint('[ImportProvider] Spotify import error: $e');
      _upsert(taskId, (t) => t.copyWith(
        status: 'error',
        errorMessage: 'Import failed. Please try again.',
      ));
    }
  }

  Future<void> _importYtMusic(String taskId, String url) async {
    try {
      // 1. Extract browse/playlist ID from URL
      final browseId = _extractYtmBrowseId(url);
      if (browseId == null) {
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Invalid YouTube Music URL. Open a playlist in YT Music and share it.',
        ));
        return;
      }

      _upsert(taskId, (t) => t.copyWith(
        status: 'fetching',
        name: 'Fetching YouTube Music playlist…',
      ));

      // 2. Fetch first batch
      final (firstPlaylist, initialToken) = await _musicApi.getPlaylistBatch(browseId);
      
      var allSongs = firstPlaylist.songs.where((s) => s.isPlayable).toList();
      var currentToken = initialToken;
      
      _upsert(taskId, (t) => t.copyWith(
        name: firstPlaylist.name,
        totalSongs: allSongs.length,
        processedSongs: allSongs.length,
        matchedSongs: allSongs.length,
      ));

      // 3. Continue fetching batches if they exist (Up to 1500 songs)
      int pageCount = 1;
      while (currentToken != null && pageCount < 15) {
        _upsert(taskId, (t) => t.copyWith(status: 'fetching'));
        
        final (nextPlaylist, nextToken) = await _musicApi.getPlaylistBatch(browseId, continuation: currentToken);
        final nextSongs = nextPlaylist.songs.where((s) => s.isPlayable).toList();
        
        if (nextSongs.isEmpty) break;
        
        allSongs.addAll(nextSongs);
        currentToken = nextToken;
        pageCount++;

        _upsert(taskId, (t) => t.copyWith(
          processedSongs: allSongs.length,
          matchedSongs: allSongs.length,
          totalSongs: allSongs.length,
        ));
      }

      if (allSongs.isEmpty) {
        _upsert(taskId, (t) => t.copyWith(
          status: 'error',
          errorMessage: 'Playlist is empty or private. Only public playlists can be imported.',
        ));
        return;
      }

      // 4. Save merged playlist
      _upsert(taskId, (t) => t.copyWith(status: 'saving'));
      final firestoreId = await _savePlaylist(
        name: firstPlaylist.name,
        songs: allSongs,
        thumbnail: firstPlaylist.thumbnail ?? (allSongs.isNotEmpty ? allSongs.first.thumbnail : ''),
      );

      _upsert(taskId, (t) => t.copyWith(
        status: 'done',
        playlistId: firestoreId,
        matchedSongs: allSongs.length,
      ));
    } catch (e) {
      debugPrint('[ImportProvider] YTMusic import error: $e');
      _upsert(taskId, (t) => t.copyWith(
        status: 'error',
        errorMessage: 'Import failed. Check the URL and try again.',
      ));
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
      debugPrint('[ImportProvider] Save error: $e');
      return null;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extract a YouTube Music browseId (PLxxx or MPLAUxxx) or watchPlaylist ID.
  String? _extractYtmBrowseId(String url) {
    // 1. Check for list= parameter (works for music.youtube.com and youtube.com)
    final listRegex = RegExp(r'[?&]list=([A-Za-z0-9_-]+)');
    final listMatch = listRegex.firstMatch(url);
    if (listMatch != null) {
      final id = listMatch.group(1)!;
      // Standard playlists (PL...) or mixes (RD...) need VL prefix for browse endpoint
      if (id.startsWith('PL') || id.startsWith('RD') || id.startsWith('OL') || id.startsWith('LL')) {
        return id.startsWith('VL') ? id : 'VL$id';
      }
      return id;
    }

    // 2. Check for browse/ID path
    final browseRegex = RegExp(r'/browse/([A-Za-z0-9_-]+)');
    final browseMatch = browseRegex.firstMatch(url);
    if (browseMatch != null) return browseMatch.group(1);

    // 3. Fallback: if it's just a raw ID that looks like a playlist
    if (url.startsWith('PL') || url.startsWith('MPLAU') || url.startsWith('VLPL')) {
       if (url.startsWith('PL')) return 'VL$url';
       return url;
    }

    return null;
  }

  void _upsert(String taskId, ImportTask Function(ImportTask) update) {
    final existing = state[taskId];
    final next = existing != null
        ? update(existing)
        : update(ImportTask(
            id: taskId, url: '', name: '', isSpotify: false));
    state = {...state, taskId: next};
  }

  // ── User Library Playlists ─────────────────────────────────────────────────

  Future<List<Playlist>> fetchUserPlaylists() async {
    final auth = _ref.read(authProvider);
    final token = auth.accessToken;
    if (token == null) return [];

    try {
      return await _musicApi.getLibraryPlaylists(token);
    } catch (e) {
      debugPrint('[ImportProvider] Error fetching library playlists: $e');
      return [];
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final importProvider =
    StateNotifierProvider<ImportNotifier, Map<String, ImportTask>>((ref) {
  return ImportNotifier(ref);
});
