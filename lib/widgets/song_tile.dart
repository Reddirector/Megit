import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/thumbnail_utils.dart';
import '../core/utils/formatters.dart';
import '../data/models/song.dart';
import 'playing_bars.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../providers/audio_provider.dart';

/// Premium song list tile — Spotify-inspired refined row.
/// Features high-contrast typography and smooth UI states.
class SongTile extends ConsumerWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isPlaying;
  final bool showDuration;
  final int? index;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.isPlaying = false,
    this.showDuration = false,
    this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbUrl = ThumbnailUtils.getHighRes(song.thumbnail, size: 200);
    final accent = Theme.of(context).colorScheme.primary;
    final audio = ref.watch(audioProvider);
    final downloads = ref.watch(downloadProvider);
    final isDownloading = downloads.activeDownloads.containsKey(song.videoId);
    final downloadProgress =
        isDownloading ? downloads.activeDownloads[song.videoId]!.progress : 0.0;

    return Opacity(
      opacity: song.isAutoAdded ? 0.7 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // ── Thumbnail (Sharp corners, High-quality) ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: thumbUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                memCacheWidth: 150, // Task 4: Fix thumbnail memory usage
                                memCacheHeight: 150,
                                placeholder: (_, __) =>
                                    Container(color: AppColors.surface),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.surface,
                                  child: const Icon(
                                    LucideIcons.music,
                                    color: AppColors.textTertiary,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.surface,
                                child: const Icon(
                                  LucideIcons.music,
                                  color: AppColors.textTertiary,
                                  size: 20,
                                ),
                              ),
                        if (isDownloading)
                          Positioned.fill(
                            child: Container(
                              alignment: Alignment.bottomCenter,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                              ),
                              child: FractionallySizedBox(
                                heightFactor: downloadProgress.clamp(0.0, 1.0),
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  color: accent.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        if (isPlaying)
                          Container(
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Center(
                              child: PlayingBars(
                                  color: accent,
                                  height: 20,
                                  isPaused: !audio.isPlaying),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ── Title + Artist ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isPlaying ? accent : AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist + (song.isAutoAdded ? ' • auto-added' : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                if (showDuration && song.duration > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      formatDuration(song.duration),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
