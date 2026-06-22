import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/home_section.dart';
import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/lyrics.dart';
import '../local/download_db.dart';
import '../../services/ytmusic_api.dart';
import '../../services/stream_extractor.dart';
import '../../services/ytmusic_parser.dart';
import 'package:dio/dio.dart';

/// Music API service — now acts as a bridge to the client-side YtMusicApi.
class MusicApi {
  final YtMusicApi _api = YtMusicApi();

  /// Get home feed sections.
  Future<List<HomeSection>> getHome() async {
    return _api.getHome();
  }

  /// Get authenticated library playlists.
  Future<List<Playlist>> getLibraryPlaylists(String accessToken) async {
    return _api.getLibraryPlaylists(accessToken);
  }

  /// Search YouTube Music.
  /// [type]: 'songs' | 'albums' | 'playlists' | 'artists' | 'all'
  Future<Map<String, dynamic>> searchAll(String query) async {
    final results = await Future.wait([
      _api.search(query, type: 'song'),
      _api.search(query, type: 'album'),
      _api.search(query, type: 'playlist'),
      _api.search(query, type: 'artist'),
    ]);
    return {
      'songs': results[0],
      'albums': results[1],
      'playlists': results[2],
      'artists': results[3],
    };
  }

  /// Search songs only.
  Future<List<Song>> searchSongs(String query) async {
    return _api.search(query, type: 'song');
  }

  /// Get autocomplete suggestions.
  /// Get autocomplete suggestions.
  Future<List<String>> getSuggestions(String query) async {
    return _api.getSearchSuggestions(query);
  }

  /// Get artist page.
  Future<Artist> getArtist(String browseId) async {
    return _api.getArtist(browseId);
  }

  /// Get a YT Music playlist/album.
  /// Returns a tuple of (Playlist, continuationToken)
  Future<(Playlist, String?)> getPlaylistBatch(String id, {String? continuation}) async {
    try {
      final Map<String, dynamic> data;
      if (continuation != null) {
        data = await _api.getRawContinuation(continuation);
      } else {
        data = await _api.getRawBrowse(id);
      }

      final playlist = YtMusicParser.parsePlaylist(data, id);
      final nextContinuation = YtMusicParser.extractPlaylistContinuation(data);
      
      return (playlist, nextContinuation);
    } catch (e) {
      debugPrint('Error fetching playlist batch: $e');
      rethrow;
    }
  }

  /// Get Recommendations / Related songs.
  Future<List<Song>> getRelated(String videoId) async {
    return _api.getRelated(videoId);
  }

  /// Resolve artist name to browseId.
  Future<String?> resolveArtist(String name) async {
    final results = await _api.search(name, type: 'artist');
    if (results.isNotEmpty) return results.first.browseId;
    return null;
  }

  /// Resolve album name to browseId.
  Future<String?> resolveAlbum(String name) async {
    final results = await _api.search(name, type: 'album');
    if (results.isNotEmpty) return results.first.browseId;
    return null;
  }

  /// Get a YT Music playlist/album.
  /// If full=true, fetches up to 1000 songs using pagination continuations.
  Future<Playlist> getPlaylist(String id, {bool full = false}) async {
    if (!full) return _api.getPlaylist(id);

    try {
      final rawBrowse = await _api.getRawBrowse(id);
      Playlist playlist = YtMusicParser.parsePlaylist(rawBrowse, id);
      String? continuation = YtMusicParser.extractPlaylistContinuation(rawBrowse);
      int maxPages = 15; // Cap at ~1500 songs
      
      while (continuation != null && maxPages > 0) {
        final contData = await _api.getRawContinuation(continuation);
        // We use parsePlaylist here but need to ensure it doesn't reset the title/thumbnail
        final contPlaylist = YtMusicParser.parsePlaylist(contData, id);
        
        if (contPlaylist.songs.isEmpty) break;
        
        final combinedSongs = List<Song>.from(playlist.songs)..addAll(contPlaylist.songs);
        playlist = playlist.copyWith(songs: combinedSongs);
        
        // CRITICAL: Must extract from the NEWLY fetched page data
        continuation = YtMusicParser.extractPlaylistContinuation(contData);
        maxPages--;
      }
      return playlist;
    } catch (e) {
      debugPrint('Error fetching full playlist: $e');
      // Fallback
      return _api.getPlaylist(id);
    }
  }

  /// Get raw stream URL asynchronously using client-side extraction.
  Future<String> extractStreamUrl(String videoId) async {
    return StreamExtractor.getAudioStreamUrl(videoId);
  }

  /// Legacy interface, now throws as URLs must be extracted asynchronously.
  String getStreamUrl(String videoId, {List<String> nextIds = const []}) {
    throw UnimplementedError('Streaming is now direct-to-client asynchronously. Use extractStreamUrl(videoId).');
  }

  /// Get lyrics by song metadata — preferred method.
  Future<Lyrics?> getLyricsBySong(Song song) async {
    try {
      // 1. Check local cache first
      final cached = await DownloadDb.instance.getCachedLyrics(song.videoId);
      if (cached != null) {
        return Lyrics.fromJson(cached);
      }

      final dio = Dio();
      
      // Clean YouTube-specific tags from title (e.g. "Song (Official Audio)", "Song [Music Video]")
      final cleanTitle = song.title.replaceAll(RegExp(r'\s*[\(\[](official|music video|lyric|audio|video|feat\.|ft\.).*?[\)\]]', caseSensitive: false), '').trim();
      
      final trackName = Uri.encodeComponent(cleanTitle);
      final artistName = Uri.encodeComponent(song.artist);
      final q = Uri.encodeComponent('$cleanTitle ${song.artist}');
      final duration = song.duration; // It's already in seconds!

      // Try exact match first
      // Do NOT include album_name as YouTube Music album metadata often differs from LRCLIB/Spotify metadata
      String url = 'https://lrclib.net/api/get?track_name=$trackName&artist_name=$artistName';
      if (duration > 0) url += '&duration=$duration';

      final res = await dio.get(url,
          options: Options(
            headers: {'User-Agent': 'Megit Music App v1.0'},
            validateStatus: (status) => status != null && status < 500,
          ));

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final syncedLyrics = data['syncedLyrics'] as String?;
        final plainLyrics = data['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          // Parse synced lyrics format: [mm:ss.xx] text
          final lines = <SyncedLine>[];
          for (final line in syncedLyrics.split('\n')) {
            final match = RegExp(r'\[(\d+):(\d+\.\d+)\]\s*(.*)').firstMatch(line);
            if (match != null) {
              final minutes = int.parse(match.group(1)!);
              final seconds = double.parse(match.group(2)!);
              final text = match.group(3) ?? '';
              lines.add(SyncedLine(
                timestamp: minutes * 60.0 + seconds,
                text: text,
              ));
            }
          }
          if (lines.isNotEmpty) {
            return Lyrics(
              syncedLines: lines,
              plainText: plainLyrics,
              source: 'lrclib',
              isSynced: true,
            );
          }
        }

        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          return Lyrics(
            plainText: plainLyrics,
            source: 'lrclib',
            isSynced: false,
          );
        }
      }

      // Fallback: search endpoint
      final searchRes = await dio.get(
        'https://lrclib.net/api/search?q=$q',
        options: Options(
          headers: {'User-Agent': 'Megit Music App v1.0'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (searchRes.statusCode == 200 && searchRes.data is List && (searchRes.data as List).isNotEmpty) {
        final first = (searchRes.data as List).first as Map<String, dynamic>;
        final syncedLyrics = first['syncedLyrics'] as String?;
        final plainLyrics = first['plainLyrics'] as String?;

        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          final lines = <SyncedLine>[];
          for (final line in syncedLyrics.split('\n')) {
            final match = RegExp(r'\[(\d+):(\d+\.\d+)\]\s*(.*)').firstMatch(line);
            if (match != null) {
              final minutes = int.parse(match.group(1)!);
              final seconds = double.parse(match.group(2)!);
              lines.add(SyncedLine(timestamp: minutes * 60.0 + seconds, text: match.group(3) ?? ''));
            }
          }
          if (lines.isNotEmpty) {
            return Lyrics(syncedLines: lines, plainText: plainLyrics, source: 'lrclib', isSynced: true);
          }
        }

        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          return Lyrics(plainText: plainLyrics, source: 'lrclib', isSynced: false);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Get watch-next / radio queue.
  Future<List<Song>> getWatchNext(String videoId) async {
    return _api.getWatchNext(videoId);
  }

  /// Get recommendations.
  Future<List<Song>> getRecommendations(String videoId) async {
    return _api.getWatchNext(videoId); // Fallback to watchNext for recommendations
  }

  /// Search for an album by query.
  Future<String?> searchAlbum(String query) async {
    final results = await _api.search(query, type: 'album');
    if (results.isNotEmpty) return results.first.browseId;
    return null;
  }
}

