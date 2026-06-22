import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TMMTrackData {
  final String title;
  final String artist;
  
  TMMTrackData({required this.title, required this.artist});
}

class TMMPlaylistData {
  final String name;
  final List<TMMTrackData> tracks;
  TMMPlaylistData({required this.name, required this.tracks});
}

class TuneMyMusicApi {
  final Dio _dio = Dio();

  /// Extracts ID from tunemymusic.com/share/[ID]
  String? extractId(String url) {
    final regex = RegExp(r'tunemymusic\.com/share/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Fetches playlist data by scraping the public share page.
  Future<TMMPlaylistData> getPlaylist(String shareId) async {
    try {
      final response = await _dio.get(
        'https://www.tunemymusic.com/share/$shareId',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data.toString();
        
        // 1. Extract Playlist Name
        final nameRegex = RegExp(r'<h1[^>]*>(.*?)</h1>');
        final nameMatch = nameRegex.firstMatch(html);
        final name = nameMatch?.group(1)?.trim() ?? 'Shared Playlist';

        // 2. Extract Tracks
        // TMM usually lists tracks in a clear structure. 
        // We'll search for the song-row-title and artist patterns.
        final List<TMMTrackData> tracks = [];
        
        // Pattern for track titles and artists in the HTML table/list
        // Note: TMM's HTML structure might change, but typically track info is in text.
        final trackRegex = RegExp(r'<div class="song-title">([^<]+)</div>.*?<div class="song-artist">([^<]+)</div>', dotAll: true);
        final matches = trackRegex.allMatches(html);

        for (final m in matches) {
          tracks.add(TMMTrackData(
            title: m.group(1)!.trim(),
            artist: m.group(2)!.trim(),
          ));
        }

        if (tracks.isEmpty) {
          // Fallback: search for any text that looks like "Title - Artist" if the specific classes fail
          final fallbackRegex = RegExp(r'<li>\s*(.*?)\s+-\s+(.*?)\s*</li>');
          final fallbackMatches = fallbackRegex.allMatches(html);
          for (final m in fallbackMatches) {
             tracks.add(TMMTrackData(
                title: m.group(1)!.trim(),
                artist: m.group(2)!.trim(),
             ));
          }
        }

        return TMMPlaylistData(name: name, tracks: tracks);
      }
    } catch (e) {
      debugPrint('[TMM] Error scraping playlist: $e');
    }
    throw Exception('Could not fetch Tune My Music playlist. Ensure the link is public.');
  }
}
