import 'package:shared_preferences/shared_preferences.dart';

/// Persistent service to track songs shown to the user.
/// Ensures discovery is always "New" by filtering out recently suggested items.
class SeenSongsService {
  static const _key = 'megit_seen_video_ids';
  static const _maxItems = 1000; // Track last 1000 seen songs

  /// Marks a list of video IDs as "Seen".
  static Future<void> markAsSeen(List<String> videoIds) async {
    if (videoIds.isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_key) ?? [];
    
    // Create a set for uniqueness
    final nextSeen = <String>{...videoIds, ...seen};
    
    // Cap size to keep storage light but effective
    final list = nextSeen.take(_maxItems).toList();
    await prefs.setStringList(_key, list);
  }

  /// Returns a set of all video IDs suggested in recent sessions.
  static Future<Set<String>> getSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  /// Clears the history (e.g. on manual refresh).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
