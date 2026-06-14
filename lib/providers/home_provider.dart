import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/home_section.dart';
import '../data/models/song.dart';
import '../data/api/music_api.dart';
import 'playlist_provider.dart';
import 'audio_provider.dart';

class HomeState {
  final List<HomeSection> sections;
  final bool loading;
  final bool error;

  const HomeState({
    this.sections = const [],
    this.loading = true,
    this.error = false,
  });

  HomeState copyWith({
    List<HomeSection>? sections,
    bool? loading,
    bool? error,
  }) {
    return HomeState(
      sections: sections ?? this.sections,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class HomeNotifier extends Notifier<HomeState> {
  final _musicApi = MusicApi();

  @override
  HomeState build() {
    return const HomeState();
  }

  Future<void> loadHome({bool forceRefresh = false}) async {
    if (!forceRefresh && state.sections.isNotEmpty) {
      return; // Use cached data
    }

    state = state.copyWith(loading: true, error: false);

    try {
      // 1. Fetch standard home feed
      final sections = await _musicApi.getHome();

      // 2. Add personalized "Suggested for You" section
      try {
        final personalized = await _getPersonalizedSection();
        if (personalized != null) {
          // Insert at second position for high visibility
          sections.insert(min(1, sections.length), personalized);
        }
      } catch (e) {
        debugPrint('[HomeProvider] Personalization failed: $e');
      }

      state = state.copyWith(
        sections: sections,
        loading: false,
        error: false,
      );
    } catch (e) {
      debugPrint('[HomeProvider] Failed to load home feed: $e');
      state = state.copyWith(loading: false, error: true);
    }
  }

  Future<HomeSection?> _getPersonalizedSection() async {
    final history = ref.read(audioProvider).history;
    final playlists = ref.read(playlistProvider).playlists;
    
    // Collect seeds: last 2 songs from history + 2 random from Liked Songs
    final seeds = <Song>[];
    if (history.isNotEmpty) seeds.addAll(history.take(2));
    
    final likedPl = playlists.where((p) => p.name == 'Liked Songs').firstOrNull;
    if (likedPl != null && likedPl.songs.isNotEmpty) {
      final pool = List<Song>.from(likedPl.songs)..shuffle();
      seeds.addAll(pool.take(2));
    }

    if (seeds.isEmpty) return null;

    // Fetch related tracks for the seeds
    final results = await Future.wait(
      seeds.take(3).map((s) => _musicApi.getRelated(s.videoId))
    );

    final flatList = results.expand((x) => x).toList();
    if (flatList.isEmpty) return null;

    // Remove duplicates
    final seen = <String>{};
    final unique = <Song>[];
    for (final s in flatList) {
      if (!seen.contains(s.videoId)) {
        seen.add(s.videoId);
        unique.add(s);
      }
    }
    
    unique.shuffle();

    return HomeSection(
      title: 'Suggested for You',
      items: unique.take(20).toList(),
    );
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);
