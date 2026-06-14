import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
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

/// Home screen — Megit's premium dashboard.
/// Features a hero greeting, recent playlists grid, and curated music sections.
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

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Decorative halo background (top-left) ──
          Positioned(
            top: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.haloGradient(accent),
                ),
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.haloGradient(
                    AppColors.computeSecondary(accent),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: accent,
              backgroundColor: AppColors.backgroundElevated,
              onRefresh: _loadHome,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPad,
                  vertical: 12,
                ),
                children: [
                  _buildHeader(firstName, accent, context),
                  const SizedBox(height: 28),

                  // ── Quick action chips ──
                  _buildQuickChips(context, accent),
                  const SizedBox(height: 24),

                  // ── Recent Playlists ──
                  if (playlists.where((p) => ((p.songs as List<dynamic>?) ?? []).isNotEmpty).isNotEmpty) ...[
                    _SectionTitle(
                      title: 'Jump back in',
                      icon: LucideIcons.history,
                    ),
                    const SizedBox(height: 14),
                    _buildRecentPlaylistsGrid(playlists, audio, isTablet),
                    const SizedBox(height: 28),
                  ],

                  // ── Music Sections ──
                  if (homeState.loading && homeState.sections.isEmpty) ...[
                    _buildSkeleton(),
                    _buildSkeleton(),
                    _buildSkeleton(),
                  ] else if (homeState.error && homeState.sections.isEmpty) ...[
                    _buildErrorState(),
                  ] else if (homeState.sections.isEmpty) ...[
                    _buildEmptyState(),
                  ] else ...[
                    for (final section in homeState.sections)
                      if (section.items.isNotEmpty)
                        _buildSection(section, audio, isTablet),
                  ],

                  // Bottom padding for mini player + nav
                  const SizedBox(height: 160),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──
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
                  Icon(_greetingIcon(),
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.accentGradient(accent)
                    .createShader(bounds),
                child: Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Profile / notification button
        _CircleButton(
          icon: LucideIcons.bell,
          onTap: () {},
        ),
        const SizedBox(width: 10),
        _CircleButton(
          icon: LucideIcons.settings,
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }

  // ── Quick chips ──
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
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: const Icon(LucideIcons.radio,
                  size: 36, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('No content yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 6),
            const Text('Pull to refresh',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadHome,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Playlists Grid ──
  Widget _buildRecentPlaylistsGrid(List<dynamic> playlists, AudioState audio, bool isTablet) {
    final items = playlists.where((pl) {
      final songs = (pl.songs as List<dynamic>?) ?? [];
      return songs.isNotEmpty;
    }).take(isTablet ? 8 : 6).toList();

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 64,
      ),
      itemBuilder: (context, i) {
        final pl = items[i];
        final songs = (pl.songs as List<dynamic>?) ?? [];
        final thumb = songs.isNotEmpty
            ? ThumbnailUtils.getHighRes((songs.first as dynamic).thumbnail ?? '', size: 200)
            : '';
        final isPlayingThis = audio.contextPlaylistId == pl.id;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/playlist/${pl.id}'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.surface,
                border: Border.all(
                  color: isPlayingThis
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                      : AppColors.glassBorder,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    child: SizedBox(
                      width: 62,
                      height: 62,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Hero(
                              tag: 'pl-thumb-${pl.id}',
                              child: songs.length >= 4
                                  ? _buildQuadArt(songs.take(4).toList())
                                  : (thumb.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: thumb,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => _artPlaceholder())
                                      : _artPlaceholder()),
                            ),
                          ),
                          if (isPlayingThis)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black54,
                                child: Center(
                                  child: PlayingBars(
                                    color: Theme.of(context).colorScheme.primary,
                                    height: 18,
                                    isPaused: !audio.isPlaying,
                                  ),
                                ),
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
                        Text(
                          pl.name ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${songs.length} tracks',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuadArt(List<dynamic> songs) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: songs.map((s) {
        final url = ThumbnailUtils.getHighRes(s.thumbnail, size: 120);
        return url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _artPlaceholder())
            : _artPlaceholder();
      }).toList(),
    );
  }

  Widget _artPlaceholder() => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(LucideIcons.music,
              size: 20, color: AppColors.textTertiary),
        ),
      );

  // ── Horizontal Song Section ──
  Widget _buildSection(HomeSection section, AudioState audio, bool isTablet) {
    final cardSize = isTablet ? 160.0 : 140.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: section.title),
          const SizedBox(height: 14),
          SizedBox(
            height: cardSize + 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                final song = section.items[i];
                final isPlaying = song.isPlayable
                    ? audio.currentSong?.videoId == song.videoId
                    : audio.contextPlaylistId == (song.playlistId ?? song.browseId ?? song.id);
                return _SongCard(
                  song: song,
                  size: cardSize,
                  isPlaying: isPlaying,
                  isPaused: !audio.isPlaying,
                  onTap: () => _handlePlay(song),
                  onLongPress: () => _showMenu(song),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handlePlay(Song song) {
    if (song.isPlayable) {
      ref.read(audioProvider.notifier).playSong(song, clearQueue: true);
    } else {
      final id = song.playlistId ?? song.browseId ?? song.id;
      if (id.isNotEmpty) {
        if (song.type == 'ARTIST') {
          context.push('/artist/$id');
        } else {
          context.push('/playlist/$id');
        }
      }
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

  // ── Skeleton ──
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonLoader(width: 140, height: 18, borderRadius: 6),
          const SizedBox(height: 14),
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, __) => const SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(width: 140, height: 140, borderRadius: 14),
                    SizedBox(height: 10),
                    SkeletonLoader(width: 110, height: 12, borderRadius: 4),
                    SizedBox(height: 6),
                    SkeletonLoader(width: 72, height: 10, borderRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Icon(LucideIcons.wifi_off,
                size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text("Couldn't load music feed",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: _loadHome,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Title ──
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionTitle({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ── Premium round button ──
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

// ── Song Card ──
class _SongCard extends StatelessWidget {
  final Song song;
  final double size;
  final bool isPlaying;
  final bool isPaused;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SongCard({
    required this.song,
    required this.size,
    required this.isPlaying,
    required this.isPaused,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = ThumbnailUtils.getHighRes(song.thumbnail, size: 400);
    final accent = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: size,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Hero(
                      tag: song.type == 'ARTIST' 
                          ? 'artist-thumb-${song.browseId ?? song.id}'
                          : song.isPlayable 
                              ? 'thumb-${song.videoId.isNotEmpty ? song.videoId : song.id}'
                              : 'pl-thumb-${song.playlistId ?? song.browseId ?? song.id}',
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: thumb.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.surface),
                                errorWidget: (_, __, ___) =>
                                    Container(color: AppColors.surface))
                            : Container(color: AppColors.surface),
                      ),
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: PlayingBars(
                                color: accent, height: 24, isPaused: isPaused),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isPlaying ? accent : AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
