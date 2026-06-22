import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/home_section.dart';
import '../data/models/song.dart';
import '../data/api/music_api.dart';
import 'playlist_provider.dart';
import 'audio_provider.dart';
import 'auth_provider.dart';
import '../services/ai/recommendation_engine.dart';

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
      // 1. Fetch standard home feed (Retrieval) - Fast path
      final sections = await _musicApi.getHome();
      
      // Update UI immediately with standard sections for fast opening
      state = state.copyWith(sections: sections, loading: false, error: false);

      // 2. Fetch AI-Personalized sections in the background (Ranking & Segmentation)
      Future.microtask(() async {
        try {
          final auth = ref.read(authProvider);
          if (auth.user != null) {
            final ai = RecommendationEngine(auth.user!.uid);
            final personalized = await ai.getPersonalizedHome();
            
            if (personalized.isNotEmpty) {
              final updatedSections = [...personalized, ...sections];
              state = state.copyWith(sections: updatedSections);
            }
          }
        } catch (e) {
          debugPrint('[HomeProvider] AI background personalization failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[HomeProvider] Failed to load home feed: $e');
      state = state.copyWith(loading: false, error: true);
    }
  }
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

