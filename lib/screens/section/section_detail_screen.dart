import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/song.dart';
import '../../providers/audio_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/song_cards.dart';
import '../../data/models/home_section.dart';
import '../../widgets/song_action_sheet.dart';
import '../../providers/auth_provider.dart';
import '../../services/ai/recommendation_engine.dart';
import 'dart:math' as math;

class SectionDetailScreen extends ConsumerStatefulWidget {
  final String title;
  const SectionDetailScreen({super.key, required this.title});

  @override
  ConsumerState<SectionDetailScreen> createState() => _SectionDetailScreenState();
}

class _SectionDetailScreenState extends ConsumerState<SectionDetailScreen> {
  String _trackFilter = '';
  String _sortKey = 'recent';
  String _sortOrder = 'desc';
  // ignore: unused_field
  bool _showSortDropdown = false;
  
  final List<Song> _extraDiscoverySongs = [];
  final Set<String> _seenIds = {}; // State deduplication
  bool _isLoadingMore = false;

  // --- Loop guards ---
  // getPersonalizedHome() re-runs Firestore queries + several external API
  // calls every time it's called. Without these guards, scrolling near the
  // bottom of this screen re-triggers that expensive pipeline on every scroll
  // notification for as long as the user stays near the bottom, since there
  // was no signal for "no more results" and no cooldown between attempts.
  bool _hasMore = true;
  int _loadMoreAttempts = 0;
  static const int _maxLoadMoreAttempts = 6;
  DateTime? _lastLoadMoreAt;
  static const Duration _loadMoreCooldown = Duration(seconds: 4);

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (_loadMoreAttempts >= _maxLoadMoreAttempts) {
      _hasMore = false;
      return;
    }
    final now = DateTime.now();
    if (_lastLoadMoreAt != null && now.difference(_lastLoadMoreAt!) < _loadMoreCooldown) {
      return; // Debounce: scroll notifications fire far more often than we should re-fetch.
    }
    _lastLoadMoreAt = now;
    _loadMoreAttempts++;

    setState(() => _isLoadingMore = true);

    try {
      final auth = ref.read(authProvider);
      if (auth.user == null) {
        if (mounted) setState(() { _isLoadingMore = false; _hasMore = false; });
        return;
      }
      final ai = RecommendationEngine(auth.user!.uid);
      final more = await ai.getPersonalizedHome();
      final matching = more.firstWhere((s) => s.title == widget.title, orElse: () => const HomeSection(title: '', items: []));

      var newCount = 0;
      if (mounted) {
        setState(() {
          for (final s in matching.items) {
            if (!_seenIds.contains(s.videoId)) {
              _extraDiscoverySongs.add(s);
              _seenIds.add(s.videoId);
              newCount++;
            }
          }
          _isLoadingMore = false;
          // Nothing new came back (we've exhausted the candidate pool for now) —
          // stop trying instead of repeating the same expensive call forever.
          if (newCount == 0) _hasMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial deduplication of base songs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeState = ref.read(homeProvider);
      final baseSection = homeState.sections.firstWhere(
        (s) => s.title == widget.title,
        orElse: () => const HomeSection(title: '', items: []),
      );
      for (final s in baseSection.items) {
        _seenIds.add(s.videoId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final baseSection = homeState.sections.firstWhere(
      (s) => s.title == widget.title,
      orElse: () => HomeSection(title: '', items: []),
    );

    final settings = ref.watch(settingsProvider);
    final layoutMode = settings.playlistLayoutMode;
    final accent = Theme.of(context).colorScheme.primary;
    final audio = ref.watch(audioProvider);

    if (baseSection.title.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allSongs = [...baseSection.items, ..._extraDiscoverySongs];
    var filteredSongs = List<Song>.from(allSongs);
    
    if (_trackFilter.isNotEmpty) {
      filteredSongs = filteredSongs.where((s) => 
        s.title.toLowerCase().contains(_trackFilter.toLowerCase()) || 
        s.artist.toLowerCase().contains(_trackFilter.toLowerCase())
      ).toList();
    }

    // Sort
    if (_sortKey == 'alpha') {
      filteredSongs.sort((a, b) => a.title.compareTo(b.title));
      if (_sortOrder == 'asc') filteredSongs = filteredSongs.reversed.toList();
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.arrow_left, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  LayoutSelector(
                    currentMode: layoutMode,
                    onModeChanged: (m) => ref.read(settingsProvider.notifier).setPlaylistLayoutMode(m),
                  ),
                ],
              ),
            ),

            // ── Search & Filter ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.search, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _trackFilter = v),
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search in this section…',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ──
            Expanded(
              child: _buildContent(filteredSongs, layoutMode, audio, accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<Song> songs, LayoutMode mode, AudioState audio, Color accent) {
    // Show loading indicator if initial pool is still fetching
    if (songs.isEmpty && _isLoadingMore) return const Center(child: CircularProgressIndicator());
    if (songs.isEmpty) return const Center(child: Text('No tracks found', style: TextStyle(color: AppColors.textSecondary)));

    switch (mode) {
      case LayoutMode.list:
        return NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 400) _loadMore();
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: songs.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == songs.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              return SongTile(
                song: songs[i],
                isPlaying: audio.currentSong?.videoId == songs[i].videoId,
                onTap: () {
                  ref.read(audioProvider.notifier).playSong(songs[i], clearQueue: true);
                  ref.read(audioProvider.notifier).replaceQueue(songs.sublist(i + 1));
                },
                onLongPress: () => _showMenu(songs[i]),
              );
            },
          ),
        );
      case LayoutMode.grid:
        return NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 600) _loadMore();
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8,
            ),
            itemCount: songs.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == songs.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              return GridSongCard(
                song: songs[i],
                isPlaying: audio.currentSong?.videoId == songs[i].videoId,
                onTap: () {
                   ref.read(audioProvider.notifier).playSong(songs[i], clearQueue: true);
                   ref.read(audioProvider.notifier).replaceQueue(songs.sublist(i + 1));
                },
                onLongPress: () => _showMenu(songs[i]),
              );
            },
          ),
        );
      case LayoutMode.masonry:
        return NotificationListener<ScrollNotification>(
          onNotification: (sn) {
            if (sn.metrics.pixels >= sn.metrics.maxScrollExtent - 800) _loadMore();
            return false;
          },
          child: MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: songs.length + (_isLoadingMore ? 1 : 0), 
            itemBuilder: (context, i) {
               if (i == songs.length) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
               final song = songs[i];
               final h = (180 + (i % 3) * 40).toDouble();
               
               return MasonrySongCard(
                 song: song,
                 height: h,
                 isPlaying: audio.currentSong?.videoId == song.videoId,
                 onTap: () {
                    ref.read(audioProvider.notifier).playSong(song, clearQueue: true);
                    ref.read(audioProvider.notifier).replaceQueue(songs.sublist(i + 1));
                 },
                 onLongPress: () => _showMenu(song),
               );
            },
          ),
        );
    }
  }

  void _showMenu(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SongActionSheet(song: song),
    );
  }
}
