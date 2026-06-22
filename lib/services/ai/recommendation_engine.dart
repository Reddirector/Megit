import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/song.dart';
import '../../data/models/home_section.dart';
import '../../data/api/music_api.dart';
import 'package:flutter/foundation.dart';
import 'seen_songs_service.dart';

/// Megit AI Recommendation Engine.
class RecommendationEngine {
  final String uid;
  final MusicApi _musicApi = MusicApi();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  RecommendationEngine(this.uid);

  // getPersonalizedHome() runs 3 Firestore queries plus up to 10 parallel
  // external API calls and scores hundreds of candidates — it's expensive.
  // It's called both once from the home screen and (with cooldown/attempt
  // guards) from section_detail_screen's "load more". Cache the result per
  // user for a short window so back-to-back calls reuse it instead of
  // re-running the whole pipeline.
  static final Map<String, _CachedRecommendations> _cache = {};
  static const Duration _cacheTtl = Duration(minutes: 3);

  /// Generates highly diverse home sections with strict deduplication.
  Future<List<HomeSection>> getPersonalizedHome() async {
    final cached = _cache[uid];
    if (cached != null && DateTime.now().isBefore(cached.expiry)) {
      return cached.sections;
    }
    try {
      final profile = await _buildTasteProfile();
      if (profile.seeds.isEmpty) return [];

      // Get persistent seen history
      final seenIds = await SeenSongsService.getSeenIds();

      // Fetch a massive candidate pool (Problem 1 Fix)
      final candidates = await _fetchCandidates(profile.seeds, seenIds, profile.librarySongs);

      // Score, Rank & Deduplicate
      final sections = _generateSections(candidates, profile, seenIds);
      
      // Mark as seen for session logic
      final allShowedIds = sections.expand((s) => s.items.map((song) => song.videoId)).toList();
      await SeenSongsService.markAsSeen(allShowedIds);

      _cache[uid] = _CachedRecommendations(sections, DateTime.now().add(_cacheTtl));
      return sections;
    } catch (e) {
      debugPrint('[AI Engine] Recommendation failed: $e');
      return [];
    }
  }

  /// Extracts user preferences from Firestore.
  Future<_TasteProfile> _buildTasteProfile() async {
    // 1. Top Songs & History (Problem 1 Fix: 30 history seeds)
    final historySnap = await _db.collection('users').doc(uid).collection('history')
        .orderBy('playedAt', descending: true).limit(30).get();
    
    final topSongsSnap = await _db.collection('users').doc(uid).collection('songStats')
        .orderBy('playCount', descending: true).limit(30).get();

    // 2. All Playlist tracks (Problem 1 Fix)
    final playlistsSnap = await _db.collection('playlists')
        .where('members', arrayContains: uid).get();
    
    final List<Song> librarySongs = [];
    for (var doc in playlistsSnap.docs) {
      final data = doc.data();
      final songs = (data['songs'] as List? ?? []).map((s) => Song.fromJson(s)).toList();
      librarySongs.addAll(songs);
    }

    final List<Song> seeds = [];
    final Map<String, int> artistAffinity = {};

    // Use History as primary seeds
    seeds.addAll(historySnap.docs.map((d) => Song.fromJson(d.data())));
    
    // Add unique tracks from playlists as seeds
    for (var s in librarySongs) {
      if (!seeds.any((seed) => seed.videoId == s.videoId) && seeds.length < 150) {
        seeds.add(s);
      }
      final artist = s.artist.toLowerCase();
      artistAffinity[artist] = (artistAffinity[artist] ?? 0) + 1;
    }

    // Mix in top songs
    for (var doc in topSongsSnap.docs) {
      final song = Song.fromJson(doc.data());
      if (!seeds.any((s) => s.videoId == song.videoId) && seeds.length < 200) {
        seeds.add(song);
      }
    }

    final Set<String> recentIds = historySnap.docs.map((d) => d.id).toSet();

    return _TasteProfile(
      seeds: seeds,
      artistAffinity: artistAffinity,
      recentIds: recentIds,
      librarySongs: librarySongs,
    );
  }

  /// Retrieves candidate tracks from YouTube Music's "Related" API.
  Future<List<Song>> _fetchCandidates(List<Song> seeds, Set<String> persistentSeenIds, List<Song> librarySongs) async {
    final List<Song> pool = [];
    final Set<String> seenInThisRun = {};
    final Set<String> libraryIds = librarySongs.map((s) => s.videoId).toSet();

    // Requirement: Sample 10 seeds per refresh and fetch related tracks.
    final randomSeeds = List<Song>.from(seeds)..shuffle();
    final subset = randomSeeds.take(10).toList();

    final results = await Future.wait(
      subset.map((s) => _musicApi.getRelated(s.videoId).timeout(const Duration(seconds: 15), onTimeout: () => []))
    );

    for (var list in results) {
      for (var song in list) {
        // Strict Filter: Skip anything seen recently OR already in library OR already added to this pool
        if (!seenInThisRun.contains(song.videoId) && 
            !persistentSeenIds.contains(song.videoId) &&
            !libraryIds.contains(song.videoId)) {
          seenInThisRun.add(song.videoId);
          pool.add(song);
        }
      }
    }

    // Requirement: Keep 100-200 unique candidates
    pool.shuffle();
    return pool;
  }

  /// Scores candidates and segments them into Spotify-style sections.
  List<HomeSection> _generateSections(List<Song> candidates, _TasteProfile profile, Set<String> seenIds) {
    final scored = candidates.map((s) {
      double score = 0;
      
      final affinity = profile.artistAffinity[s.artist.toLowerCase()];
      if (affinity != null) {
        score += min(affinity * 2.0, 15.0);
      }

      if (profile.recentIds.contains(s.videoId)) {
        score -= 20.0; // High penalty for recently played
      }

      // High entropy for discovery
      score += Random().nextDouble() * 10.0;

      return _ScoredSong(s, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    final sorted = scored.map((ss) => ss.song).toList();

    final sections = <HomeSection>[];
    final Set<String> crossSectionSeen = {};

    // 1. "Daily Mix" (Target a lot for deep discovery)
    final mix = sorted.where((s) => 
      profile.artistAffinity.containsKey(s.artist.toLowerCase()) && 
      !crossSectionSeen.contains(s.videoId)
    ).take(150).toList();
    for (var s in mix) crossSectionSeen.add(s.videoId);
    if (mix.length >= 4) sections.add(HomeSection(title: 'Your Daily Mix', items: mix));

    // 2. "Discovery for You" (Target a lot)
    final discovery = sorted.where((s) => 
      !profile.artistAffinity.containsKey(s.artist.toLowerCase()) && 
      !crossSectionSeen.contains(s.videoId)
    ).take(150).toList();
    for (var s in discovery) crossSectionSeen.add(s.videoId);
    if (discovery.isNotEmpty) sections.add(HomeSection(title: 'Discovery for You', items: discovery));

    // 3. "Trending Around You" (Rest of the pool)
    final trending = sorted.where((s) => !crossSectionSeen.contains(s.videoId)).take(150).toList();
    if (trending.isNotEmpty) sections.add(HomeSection(title: 'Trending Around You', items: trending));

    return sections;
  }
}

class _TasteProfile {
  final List<Song> seeds;
  final Map<String, int> artistAffinity;
  final Set<String> recentIds;
  final List<Song> librarySongs;
  _TasteProfile({required this.seeds, required this.artistAffinity, required this.recentIds, required this.librarySongs});
}

class _CachedRecommendations {
  final List<HomeSection> sections;
  final DateTime expiry;
  _CachedRecommendations(this.sections, this.expiry);
}

class _ScoredSong {
  final Song song;
  final double score;
  _ScoredSong(this.song, this.score);
}
