import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/models/playlist.dart';
import '../data/models/song.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/thumbnail_utils.dart';

class PlaylistCover extends StatelessWidget {
  final Playlist playlist;
  final double size;
  final double borderRadius;

  const PlaylistCover({
    super.key,
    required this.playlist,
    required this.size,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildCoverContent(),
      ),
    );
  }

  Widget _buildCoverContent() {
    // 1. Custom Image (Base64). Stored as raw base64 (no data: URL prefix) —
    // see ThumbnailPickerModal, the only place that writes this field.
    if (playlist.customThumbnail != null && playlist.customThumbnail!.isNotEmpty) {
      try {
        final bytes = base64Decode(playlist.customThumbnail!);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }

    // 2. Custom Color + Name Initial
    if (playlist.customColor != null && playlist.customColor!.isNotEmpty) {
      final color = Color(int.parse(playlist.customColor!.replaceFirst('#', '0xFF'), radix: 16));
      return Container(
        color: color,
        child: Center(
          child: Text(
            playlist.name.isNotEmpty ? playlist.name[0].toUpperCase() : 'P',
            style: TextStyle(
              fontSize: size * 0.4,
              fontWeight: FontWeight.w900,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    // 3. Quad Cover (4 most recent songs)
    if (playlist.songs.length >= 4 && playlist.type == 'MEGIT') {
      return _buildQuadArt(playlist.songs.take(4).toList());
    }

    // 4. Original Thumbnail (YTM or single song)
    final thumb = playlist.thumbnail ?? (playlist.songs.isNotEmpty ? playlist.songs.first.thumbnail : '');
    if (thumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ThumbnailUtils.getHighRes(thumb, size: (size * 2).toInt()),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppColors.backgroundElevated),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }

    return _placeholder();
  }

  Widget _buildQuadArt(List<Song> songs) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: songs.map((s) {
        final url = ThumbnailUtils.getHighRes(s.thumbnail, size: (size).toInt());
        return url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder())
            : _placeholder();
      }).toList(),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.backgroundElevated,
        child: Center(
          child: Icon(Icons.music_note_rounded, size: size * 0.4, color: AppColors.textTertiary),
        ),
      );
}
