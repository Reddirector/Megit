import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../widgets/song_cards.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/thumbnail_utils.dart';
import '../../data/models/song.dart';
import '../../data/models/home_section.dart';
import '../../providers/audio_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/home_provider.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/song_action_sheet.dart';
import '../../widgets/playing_bars.dart';

/// Home screen — Optimized with Slivers for 60FPS performance.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).loadHome();
    });
  }

  Future<void> _loadHome() async {
    await ref.read(homeProvider.notifier).loadHome(forceRefresh: true);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _greetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return LucideIcons.sunrise;
    if (hour < 18) return LucideIcons.sun;
    return LucideIcons.moon;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final playlistState = ref.watch(playlistProvider);
    final playlists = playlistState.playlists;
    final audio = ref.watch(audioProvider);
    final homeState = ref.watch(homeProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final firstName = (auth.displayName ?? 'Member').split(' ').first;
    final isTablet = AppTheme.isTablet(context);
    final horizontalPad = isTablet ? 32.0 : 20.0;

    final recentPlaylists = playlists.where((p) {
      final songs = (p.songs as List<dynamic>?) ?? [];
      return songs.isNotEmpty;
    }).take(isTablet ? 8 : 6).toList();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative background halos ──
          Positioned(
            top: -120, left: -80,
            child: IgnorePointer(
              child: Container(
                width: 320, height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.haloGradient(accent)),
              ),
            ),
          ),
          Positioned(
            top: -60, right: -100,
            child: IgnorePointer(
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.haloGradient(AppColors.computeSecondary(accent))),
              ),
            ),
          ),

          // ── Scrollable Content ──
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: accent,
              backgroundColor: AppColors.backgroundElevated,
              onRefresh: _loadHome,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(horizontalPad, 12, horizontalPad, 28),
                      child: _buildHeader(firstName, accent, context),
                    ),
                  ),

                  // 2. Quick action chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(left: horizontalPad, bottom: 24),
                      child: _buildQuickChips(context, accent),
                    ),
                  ),

                  // 3. Recent Playlists Section
                  if (recentPlaylists.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                        child: const _SectionTitle(title: 'Jump back in', icon: LucideIcons.history),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isTablet ? 3 : 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 64,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _RecentPlaylistCard(playlist: recentPlaylists[i], audio: audio),
                          childCount: recentPlaylists.length,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],

                  // 4. Curated Sections
                  if (homeState.loading && homeState.sections.isEmpty)
                    const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                  else if (homeState.error && homeState.sections.isEmpty)
                    SliverToBoxAdapter(child: _buildErrorState())
                  else if (homeState.sections.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState())
                  else
                    for (final section in homeState.sections)
                      if (section.items.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 32),
                          sliver: SliverToBoxAdapter(
                            child: _HomeSectionWidget(section: section, audio: audio),
                          ),
                        ),

                  // Bottom padding for mini player
                  const SliverToBoxAdapter(child: SizedBox(height: 160)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String firstName, Color accent, BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_greetingIcon(), size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(_greeting(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.1)),
                ],
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.accentGradient(accent).createShader(bounds),
                child: Text(firstName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.8)),
              ),
            ],
          ),
        ),
        _CircleButton(icon: LucideIcons.bell, onTap: () {}),
        const SizedBox(width: 10),
        _CircleButton(icon: LucideIcons.settings, onTap: () => context.push('/settings')),
      ],
    );
  }

  Widget _buildQuickChips(BuildContext context, Color accent) {
    final chips = [
      (LucideIcons.heart, 'Liked', () => context.push('/playlist/__liked__')),
      (LucideIcons.download, 'Downloads', () => context.push('/downloads')),
      (LucideIcons.history, 'Recent', () => context.push('/library')),
      (LucideIcons.sparkles, 'For You', () {}),
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (icon, label, action) = chips[i];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: action,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.glassBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
              child: const Icon(LucideIcons.radio, size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('No content yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('Pull to refresh', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _loadHome, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(LucideIcons.wifi_off, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text("Couldn't load music feed", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            FilledButton.tonal(onPressed: _loadHome, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ── Internal Section Widget (Problem 3 & Task 3 Fix) ──
class _HomeSectionWidget extends ConsumerWidget {
  final HomeSection section;
  final AudioState audio;
  const _HomeSectionWidget({required this.section, required this.audio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: section.title),
        const SizedBox(height: 16),
        MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true, // Limited to exactly 6 items, so low risk
          physics: const NeverScrollableScrollPhysics(),
          addAutomaticKeepAlives: true,
          addRepaintBoundaries: true,
          itemCount: math.min(section.items.length, 6), // Static 6-item preview
          itemBuilder: (context, i) {
            final song = section.items[i];
            final isPlaying = song.isPlayable
                ? audio.currentSong?.videoId == song.videoId
                : audio.contextPlaylistId == (song.playlistId ?? song.browseId ?? song.id);
            
            final h = (150 + (i % 4) * 25).toDouble();
            
            return MasonrySongCard(
              song: song,
              height: h,
              isPlaying: isPlaying,
              onTap: () {
                if (song.isPlayable) {
                  ref.read(audioProvider.notifier).playSong(song, clearQueue: true);
                } else {
                  final id = song.playlistId ?? song.browseId ?? song.id;
                  if (id.isNotEmpty) {
                    if (song.type == 'ARTIST') context.push('/artist/$id');
                    else context.push('/playlist/$id');
                  }
                }
              },
              onLongPress: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => SongActionSheet(song: song),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _RecentPlaylistCard extends StatelessWidget {
  final dynamic playlist;
  final AudioState audio;
  const _RecentPlaylistCard({required this.playlist, required this.audio});

  @override
  Widget build(BuildContext context) {
    final songs = (playlist.songs as List<dynamic>?) ?? [];
    final thumb = songs.isNotEmpty ? ThumbnailUtils.getHighRes((songs.first as dynamic).thumbnail ?? '', size: 200) : '';
    final isPlayingThis = audio.contextPlaylistId == playlist.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/playlist/${playlist.id}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.surface,
            border: Border.all(color: isPlayingThis ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4) : AppColors.glassBorder, width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                child: SizedBox(
                  width: 62, height: 62,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Hero(
                          tag: 'pl-thumb-${playlist.id}',
                          child: songs.length >= 4
                              ? _QuadCover(songs: songs.take(4).map((s) => s as Song).toList())
                              : (thumb.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: thumb, fit: BoxFit.cover,
                                      memCacheWidth: 150, memCacheHeight: 150, // Task 4
                                      errorWidget: (_, __, ___) => Container(color: AppColors.surface))
                                  : Container(color: AppColors.surface)),
                        ),
                      ),
                      if (isPlayingThis)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(child: PlayingBars(color: Theme.of(context).colorScheme.primary, height: 18, isPaused: !audio.isPlaying)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text('${songs.length} tracks', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuadCover extends StatelessWidget {
  final List<Song> songs;
  const _QuadCover({required this.songs});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: songs.map((s) {
        final url = ThumbnailUtils.getHighRes(s.thumbnail, size: 120);
        return url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url, fit: BoxFit.cover,
                memCacheWidth: 100, memCacheHeight: 100, // Task 4
                errorWidget: (_, __, ___) => Container(color: AppColors.surface))
            : Container(color: AppColors.surface);
      }).toList(),
    );
  }
}

// ── Re-used UI Components ──

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onTap;
  const _SectionTitle({required this.title, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
          ),
          if (onTap != null) Icon(LucideIcons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.glassBorder, width: 1)),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
