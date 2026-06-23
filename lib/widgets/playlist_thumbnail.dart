import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/playlist.dart';
import '../data/models/song.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/thumbnail_utils.dart';
import 'playing_bars.dart';

class PlaylistThumbnail extends StatelessWidget {
  final Playlist playlist;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isGrid;
  final bool isCurrentContext;
  final bool isPaused;

  const PlaylistThumbnail({
    super.key,
    required this.playlist,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.isGrid = false,
    this.isCurrentContext = false,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: _buildThumbnailContent(context)),
            if (isCurrentContext)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: PlayingBars(
                      color: Theme.of(context).colorScheme.primary,
                      height: isGrid ? 24 : 16,
                      isPaused: isPaused,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailContent(BuildContext context) {
    // 1. Custom Image (Base64)
    if (playlist.customThumbnail != null && playlist.customThumbnail!.isNotEmpty) {
      try {
        final bytes = base64Decode(playlist.customThumbnail!);
        return Image.memory(
          bytes, 
          fit: BoxFit.cover,
          gaplessPlayback: true, // Prevent flicker on update
          key: ValueKey('custom-thumb-${playlist.id}-${bytes.length}'), 
        );
      } catch (e) {
        debugPrint('Error decoding custom thumbnail: $e');
      }
    }

    // 2. Custom Color & Text
    if (playlist.customColor != null && playlist.customColor!.isNotEmpty) {
      final color = _parseColor(playlist.customColor!);
      return Container(
        color: color,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              playlist.customText ?? playlist.name.substring(0, 1).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getContrastingColor(color),
                fontSize: isGrid ? 24 : 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    // 3. Fallback to default logic
    final songs = playlist.songs;
    if (songs.length >= 4) {
      return _QuadCover(songs: songs.take(4).toList());
    } else if (songs.isNotEmpty) {
      final thumb = ThumbnailUtils.getHighRes(songs.first.thumbnail, size: isGrid ? 400 : 200);
      return thumb.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: thumb,
              fit: BoxFit.cover,
              memCacheWidth: isGrid ? 300 : 150, // Task 4: Fix thumbnail memory usage
              memCacheHeight: isGrid ? 300 : 150,
              errorWidget: (_, __, ___) => Container(color: AppColors.surface),
            )
          : Container(color: AppColors.surface);
    }

    // 4. Empty state placeholder
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.music_note, color: AppColors.textSecondary),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.surface;
    }
  }

  Color _getContrastingColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class _QuadCover extends StatelessWidget {
  final List<Song> songs;
  const _QuadCover({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItem(songs[0])),
              Expanded(child: _buildItem(songs[1])),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildItem(songs[2])),
              Expanded(child: _buildItem(songs[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItem(Song s) {
    final url = ThumbnailUtils.getHighRes(s.thumbnail, size: 120);
    if (url.isEmpty) return Container(color: AppColors.surface);
    return CachedNetworkImage(
      key: ValueKey('quad-item-${s.videoId}'), // Stable key
      imageUrl: url, 
      fit: BoxFit.cover,
      memCacheWidth: 120,
      memCacheHeight: 120,
      fadeOutDuration: Duration.zero,
      fadeInDuration: const Duration(milliseconds: 200),
      errorWidget: (_, __, ___) => Container(color: AppColors.surface),
    );
  }
}
