import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AppleMusicTrackData {
  final String title;
  final String artist;
  final String album;
  final String thumbnail;
  
  AppleMusicTrackData({
    required this.title,
    required this.artist,
    required this.album,
    required this.thumbnail,
  });
}

class AppleMusicPlaylistData {
  final String name;
  final List<AppleMusicTrackData> tracks;
  AppleMusicPlaylistData({required this.name, required this.tracks});
}

class AppleMusicApi {
  final Dio _dio = Dio();

  /// Extracts playlist ID and region from music.apple.com/...
  Map<String, String>? extractInfo(String url) {
    // Example: https://music.apple.com/us/playlist/vibe-check/pl.u-38oWWvWFZoYByX
    final regex = RegExp(r'music\.apple\.com/([a-z]{2})/playlist/[^/]+/(pl\.[a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return {
        'region': match.group(1)!,
        'id': match.group(2)!,
      };
    }
    return null;
  }

  /// Fetches Apple Music playlist data via public web endpoint scraping/API
  Future<AppleMusicPlaylistData> getPlaylist(String region, String playlistId) async {
    try {
      final response = await _dio.get(
        'https://music.apple.com/$region/playlist/$playlistId',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200) {
        final html = response.data.toString();
        
        // 1. Extract Playlist Name
        final nameRegex = RegExp(r'<title>(.*?) on Apple Music</title>');
        final nameMatch = nameRegex.firstMatch(html);
        final name = nameMatch?.group(1) ?? 'Apple Music Playlist';

        // 2. Extract Track Data from JSON-LD or script tags
        // Apple Music usually embeds a JSON with track data
        final List<AppleMusicTrackData> tracks = [];
        
        // Attempt to find the "data" JSON in the script tags
        final dataRegex = RegExp(r'id="serialized-server-data"[^>]*>(.*?)</script>');
        final dataMatch = dataRegex.firstMatch(html);
        
        if (dataMatch != null) {
          // This is complex to parse directly, let's use a simpler regex for items if possible
          // or fallback to meta tags for a basic set.
          // For a robust implementation, we'd parse the full JSON.
          debugPrint('Apple Music data found, parsing...');
        }

        // Fallback: Basic metadata scraping for public tracks
        final trackRegex = RegExp(r'{"type":"songs","id":"[^"]+","attributes":{"name":"([^"]+)","artistName":"([^"]+)","albumName":"([^"]+)"');
        final matches = trackRegex.allMatches(html);

        for (final m in matches) {
          tracks.add(AppleMusicTrackData(
            title: m.group(1) ?? 'Unknown',
            artist: m.group(2) ?? 'Unknown',
            album: m.group(3) ?? '',
            thumbnail: '', // High-res thumbs require more parsing
          ));
        }

        if (tracks.isEmpty) {
          // Second fallback: simple title/artist scrape
          final songListRegex = RegExp(r'class="songs-list-row__song-name">([^<]+)</div>.*?class="songs-list-row__by-line">.*?>(.*?)</a>', dotAll: true);
          final listMatches = songListRegex.allMatches(html);
          for (final m in listMatches) {
             tracks.add(AppleMusicTrackData(
                title: m.group(1)!.trim(),
                artist: m.group(2)!.trim(),
                album: '',
                thumbnail: '',
             ));
          }
        }

        return AppleMusicPlaylistData(name: name, tracks: tracks);
      }
    } catch (e) {
      debugPrint('Failed to fetch Apple Music playlist: $e');
    }
    throw Exception('Could not fetch Apple Music playlist. Ensure it is public.');
  }
}
