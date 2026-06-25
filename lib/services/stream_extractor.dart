import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:async';

/// Cache entry for resolved stream URLs.
class _StreamCacheEntry {
  final String url;
  final DateTime expiry;
  _StreamCacheEntry(this.url, this.expiry);
  bool get isExpired => DateTime.now().isAfter(expiry);
}

/// Client-side audio stream extractor using latest youtube_explode_dart.
class StreamExtractor {
  static final YoutubeExplode _yt = YoutubeExplode();
  
  /// Session-level cache for resolved stream URLs (Problem 1 & Task 1 Fix)
  static final Map<String, _StreamCacheEntry> _urlCache = {};

  /// Gets an audio stream URL for a given videoId.
  /// Executes on a background isolate to keep UI smooth (Task 2 Fix).
  static Future<String> getAudioStreamUrl(String videoId, {String quality = 'automatic'}) async {
    // 1. Check Cache (must happen on the calling/main isolate — see note below)
    final cacheKey = '$videoId:$quality';
    final cached = _urlCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      debugPrint('[StreamExtractor] Cache hit for $videoId ($quality)');
      return cached.url;
    }

    // 2. Run extraction on a background isolate (Task 2) so the JS-deciphering
    // work doesn't block the UI thread. NOTE: compute()/Isolate.run spawns a
    // fresh isolate with its OWN copy of static state — writing to _urlCache
    // *inside* _extractInternal would silently write to that throwaway
    // isolate's copy and never be visible here. So the cache is written here,
    // on the main isolate, using the value returned back from the isolate.
    final url = await compute((_) => _extractInternal(videoId, quality), null);
    _urlCache[cacheKey] = _StreamCacheEntry(url, DateTime.now().add(const Duration(hours: 1)));
    return url;
  }

  static Future<String> _extractInternal(String videoId, String quality) async {
    // The sequence of clients to try, paired with an explicit label.
    // (client.runtimeType is NOT useful here — tv/androidVr/ios/safari are all
    // instances of the same YoutubeApiClient class, so it always printed the
    // same string. Logs below now show which one actually ran.)
    final clients = [
      // Prioritize androidVr as it often bypasses throttling and 403s better 
      // than the standard 'tv' client in many regions.
      ('androidVr', YoutubeApiClient.androidVr),
      ('android', YoutubeApiClient.android),
      ('tv', YoutubeApiClient.tv),
      ('ios', YoutubeApiClient.ios),
      ('safari', YoutubeApiClient.safari),
    ];

    Exception? lastError;
    for (final (label, client) in clients) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(videoId, ytClients: [client]);

        final audioStreams = manifest.audioOnly.toList();
        if (audioStreams.isEmpty) {
          debugPrint('[StreamExtractor] ⚠️ Client $label returned no audio streams for $videoId');
          continue;
        }

        audioStreams.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));

        AudioOnlyStreamInfo chosen;
        if (quality == 'low') {
          chosen = audioStreams.last;
        } else if (quality == 'normal') {
          chosen = audioStreams[(audioStreams.length / 2).floor()];
        } else {
          chosen = audioStreams.first;
        }

        final url = chosen.url.toString();
        
        debugPrint('[StreamExtractor] ✅ $videoId success via $label (${chosen.bitrate})');
        return url;
      } catch (e) {
        debugPrint('[StreamExtractor] ❌ Client $label failed for $videoId: $e');
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastError ?? Exception('All client types failed to extract stream for $videoId');
  }

  static void dispose() {
    _yt.close();
    _urlCache.clear();
  }
}
