import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/thumbnail_utils.dart';
import '../../data/api/music_api.dart';
import '../../data/models/artist.dart';
import '../../data/models/song.dart';
import '../../providers/audio_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/song_action_sheet.dart';
import '../../widgets/playing_bars.dart';

/// Artist screen — Spotify-inspired immersive redesign.
/// HD Dynamic Banner, Floating Play Button, Circular Artist Art, Verified Badge.
class ArtistScreen extends ConsumerStatefulWidget {
  final String browseId;
  const ArtistScreen({super.key, required this.browseId});

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  final _musicApi = MusicApi();
  Artist? _artist;
  bool _loading = true;
  bool _error = false;
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _loadArtist();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset;
    final newOpacity = (offset / 180).clamp(0.0, 1.0);
    if (newOpacity != _headerOpacity) {
      setState(() => _headerOpacity = newOpacity);
    }
  }

  @override
  void didUpdateWidget(covariant ArtistScreen old) {
    super.didUpdateWidget(old);
    if (old.browseId != widget.browseId) _loadArtist();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadArtist() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = false; });
    try {
      final artist = await _musicApi.getArtist(widget.browseId);
      if (mounted) setState(() { _artist = artist; _loading = false; });
    } catch (e) {
      debugPrint('[ArtistScreen] Load error: $e');
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  void _playAll() {
    if (_artist == null || _artist!.topSongs.isEmpty) return;
    final notifier = ref.read(audioProvider.notifier);
    notifier.playSong(_artist!.topSongs.first, clearQueue: true);
    if (_artist!.topSongs.length > 1) {
      notifier.replaceQueue(_artist!.topSongs.sublist(1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final accent = Theme.of(context).colorScheme.primary;

    if (_loading) return _buildLoading(context);
    if (_error || _artist == null) return _buildError(context);

    final artist = _artist!;
    final heroThumb = ThumbnailUtils.getHighRes(artist.thumbnail, size: 1200);

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Immersive Scroll Content ──
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Spotify-Style Flexible Header ──
              SliverAppBar(
                expandedHeight: 360,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.background,
                elevation: 0,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Ultra-HD Banner
                      Hero(
                        tag: 'artist-thumb-${widget.browseId}',
                        child: CachedNetworkImage(
                          imageUrl: heroThumb,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: AppColors.backgroundElevated),
                        ),
                      ),
                      // Gradient for Spotify aesthetic
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                              AppColors.background,
                            ],
                            stops: const [0.0, 0.4, 0.8, 1.0],
                          ),
                        ),
                      ),
                      // Artist Info Overlay
                      Positioned(
                        left: 20, right: 20, bottom: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.badge_check, size: 16, color: Color(0xFF4D96FF)),
                                const SizedBox(width: 6),
                                const Text('Verified Artist', 
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.0)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(artist.name,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 44, fontWeight: FontWeight.w900,
                                    color: Colors.white, letterSpacing: -1.5, height: 1.1)),
                            if (artist.subscribers.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text('${artist.subscribers} monthly listeners',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.white70,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Action Bar ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    children: [
                      // Big Play Button (Spotify Signature)
                      GestureDetector(
                        onTap: _playAll,
                        child: Container(
                          width: 54, height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.accentGradient(accent),
                            boxShadow: AppTheme.accentGlow(accent),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Shuffle Button
                      _OutlinedActionButton(
                        icon: LucideIcons.shuffle,
                        isActive: audio.isShuffled,
                        onTap: () {
                          ref.read(audioProvider.notifier).toggleShuffle();
                          _playAll();
                        },
                      ),
                      const SizedBox(width: 14),
                      // Follow Button
                      _OutlinedActionButton(
                        icon: LucideIcons.heart,
                        onTap: () {},
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.ellipsis, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),

              // ── Body Sections ──
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Popular Songs Header
                    const Text('Popular', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 16),
                    
                    ...artist.topSongs.take(5).toList().asMap().entries.map(
                      (entry) => _buildSongRow(entry.key, entry.value, audio, accent),
                    ),

                    const SizedBox(height: 32),

                    // Albums Header
                    if (artist.albums.isNotEmpty) ...[
                      const Text('Discography', style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 16),
                    ],
                  ]),
                ),
              ),

              // Albums Grid
              if (artist.albums.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildAlbumCard(artist.albums[i]),
                      childCount: artist.albums.length,
                    ),
                  ),
                ),

              // Singles Section
              if (artist.singles.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: const Text('Singles & EPs', style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _buildAlbumCard(artist.singles[i]),
                      childCount: artist.singles.length,
                    ),
                  ),
                ),
              ],

              // About Section
              if (artist.description.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const Text('About', style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const SizedBox(height: 16),
                        GlassContainer(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(20),
                          child: Text(artist.description,
                              maxLines: 8,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textSecondary,
                                  height: 1.6, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ),

          // ── Pinned Navigation Header ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: Opacity(
              opacity: _headerOpacity,
              child: Container(
                height: MediaQuery.of(context).padding.top + 56,
                decoration: const BoxDecoration(color: AppColors.background),
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(LucideIcons.chevron_left, size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(artist.name, 
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ── Always-visible Back Button (when header is transparent) ──
          if (_headerOpacity < 0.5)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(LucideIcons.chevron_left, size: 30, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black26),
              ),
            ),
        ],
      ),
    );
  }

  // ── Song Row ──
  Widget _buildSongRow(int index, Song song, AudioState audio, Color accent) {
    final isPlaying = audio.currentSong?.videoId == song.videoId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.read(audioProvider.notifier).playSong(song, clearQueue: true),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: 24,
                child: Text('${index + 1}',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: isPlaying ? accent : AppColors.textTertiary)),
              ),
              const SizedBox(width: 12),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 48, height: 48,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: ThumbnailUtils.getHighRes(song.thumbnail, size: 200),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: AppColors.backgroundElevated),
                      ),
                      if (isPlaying)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: PlayingBars(color: accent, height: 18, isPaused: !audio.isPlaying),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: isPlaying ? accent : AppColors.textPrimary, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(song.album.isNotEmpty ? song.album : 'Single',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              // Menu
              IconButton(
                icon: const Icon(LucideIcons.ellipsis_vertical, size: 18, color: AppColors.textTertiary),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => SongActionSheet(song: song),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Album Card ──
  Widget _buildAlbumCard(ArtistAlbum album) {
    return GestureDetector(
      onTap: () => context.push('/playlist/${album.browseId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: ThumbnailUtils.getHighRes(album.thumbnail, size: 500),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.backgroundElevated),
                  ),
                  Positioned(
                    right: 8, bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                      child: const Icon(LucideIcons.disc, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(album.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 2),
          Text(album.year.isNotEmpty ? album.year : 'Album',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  Widget _buildError(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circle_alert, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            const Text("Failed to load artist profile", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => _loadArtist(), child: const Text('Retry')),
            TextButton(onPressed: () => context.pop(), child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  const _OutlinedActionButton({required this.icon, required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isActive ? accent : AppColors.glassBorder, width: 1.5),
          color: isActive ? accent.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Icon(icon, size: 20, color: isActive ? accent : Colors.white),
      ),
    );
  }
}
