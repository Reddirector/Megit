import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/thumbnail_utils.dart';
import '../providers/audio_provider.dart';
import '../providers/playlist_provider.dart';

/// Premium mini player — Megit signature design.
/// Features layered glass + albumart blur background, clean controls,
/// and a subtle progress bar at the bottom.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use select() to only rebuild when the relevant fields change —
    // this prevents rebuilds from queue/history changes, etc.
    final song = ref.watch(audioProvider.select((a) => a.currentSong));
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(audioProvider.select((a) => a.isPlaying));
    final progress = ref.watch(audioProvider.select((a) => a.progress));
    final duration = ref.watch(audioProvider.select((a) => a.duration));

    final accent = Theme.of(context).colorScheme.primary;
    final thumb = ThumbnailUtils.getHighRes(song.thumbnail, size: 300);
    final progressPercent = duration.inMilliseconds > 0
        ? (progress.inMilliseconds / duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    final _ = ref.watch(playlistProvider);
    final isLiked = ref.read(playlistProvider.notifier).isLiked(song.videoId);

    return GestureDetector(
      onTap: () => context.push('/player'),
      child: SizedBox(
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: album art blurred background ──
            if (thumb.isNotEmpty)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    memCacheWidth: 200, // Task 4: Fix thumbnail memory usage
                    memCacheHeight: 200,
                  ),
                ),
              ),

            // ── Layer 2: darkening + accent tint ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.80),
                      Colors.black.withValues(alpha: 0.65),
                      accent.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),

            // ── Layer 3: blur for glass effect ──
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: const SizedBox(),
              ),
            ),

            // ── Layer 4: hairline border ──
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            // ── Layer 5: content ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  // ── Cover art ──
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: thumb.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                memCacheWidth: 150, // Task 4
                                memCacheHeight: 150,
                                errorWidget: (_, __, ___) =>
                                    Container(color: AppColors.surface),
                              )
                            : Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  LucideIcons.music,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ── Title + Artist ──
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 18,
                          child: ClipRect(
                            child: ShaderMask(
                              shaderCallback: (rect) => const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0.0, 0.05, 0.95, 1.0],
                              ).createShader(rect),
                              blendMode: BlendMode.dstIn,
                              child: _MarqueeText(
                                text: song.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // ── Like ──
                  _IconBtn(
                    icon: isLiked ? LucideIcons.heart : LucideIcons.heart,
                    color: isLiked ? accent : Colors.white,
                    filled: isLiked,
                    onTap: () => ref
                        .read(playlistProvider.notifier)
                        .toggleLike(song),
                  ),
                  const SizedBox(width: 4),

                  // ── Play/Pause (premium pill) ──
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(audioProvider.notifier).togglePlay(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.white.withValues(alpha: 0.85)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: ref.watch(audioProvider.select((a) => a.isLoading))
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(accent),
                                ),
                              )
                            : Icon(
                                isPlaying
                                    ? LucideIcons.pause
                                    : LucideIcons.play,
                                size: 20,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Next ──
                  _IconBtn(
                    icon: LucideIcons.skip_forward,
                    color: Colors.white,
                    onTap: () => ref.read(audioProvider.notifier).playNext(),
                  ),
                ],
              ),
            ),

            // ── Progress bar at bottom ──
            Positioned(
              bottom: 0,
              left: 12,
              right: 12,
              child: SizedBox(
                height: 2.5,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progressPercent,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              AppColors.computeSecondary(accent),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.6),
                              blurRadius: 8,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

// ── Marquee Text (auto-scrolling for long titles) ──
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late final ScrollController _controller;
  late AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  void _startScroll() {
    if (!mounted) return;
    if (_controller.hasClients && _controller.position.maxScrollExtent > 0) {
      _animation.repeat();
      _animation.addListener(() {
        if (_controller.hasClients) {
          _controller
              .jumpTo(_animation.value * _controller.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _animation.reset();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = widget.text.trim().split(RegExp(r'\s+')).length;

    if (wordCount <= 2) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 40),
          Text(widget.text, style: widget.style),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
