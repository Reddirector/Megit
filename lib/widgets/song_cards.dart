import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../core/theme/app_colors.dart';
import '../data/models/song.dart';
import '../providers/settings_provider.dart';
import 'glass_container.dart';

class LayoutSelector extends StatelessWidget {
  final LayoutMode currentMode;
  final ValueChanged<LayoutMode> onModeChanged;

  const LayoutSelector({super.key, required this.currentMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LayoutMode>(
      initialValue: currentMode,
      icon: const Icon(LucideIcons.layout_panel_left, size: 20, color: AppColors.textSecondary),
      onSelected: onModeChanged,
      color: AppColors.backgroundElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: LayoutMode.list, child: Row(children: [Icon(LucideIcons.list, size: 16), SizedBox(width: 10), Text('List')])),
        const PopupMenuItem(value: LayoutMode.grid, child: Row(children: [Icon(LucideIcons.layout_grid, size: 16), SizedBox(width: 10), Text('Grid')])),
        const PopupMenuItem(value: LayoutMode.masonry, child: Row(children: [Icon(LucideIcons.columns_2, size: 16), SizedBox(width: 10), Text('Masonry')])),
      ],
    );
  }
}

class GridSongCard extends StatelessWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const GridSongCard({super.key, required this.song, required this.isPlaying, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: song.thumbnail, 
                    fit: BoxFit.cover,
                    memCacheWidth: 300, // Task 4: Fix thumbnail memory usage
                    memCacheHeight: 300,
                    errorWidget: (_, __, ___) => Container(color: AppColors.surface)
                  ),
                  if (isPlaying) Container(color: Colors.black45, child: const Center(child: Icon(Icons.play_arrow, color: Colors.white))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class MasonrySongCard extends StatelessWidget {
  final Song song;
  final double height;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MasonrySongCard({super.key, required this.song, required this.height, required this.isPlaying, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Seamless cropping to fill the box
                CachedNetworkImage(
                  imageUrl: song.thumbnail, 
                  fit: BoxFit.cover, 
                  memCacheWidth: 400, // Optimize memory usage
                  memCacheHeight: 400,
                  placeholder: (_, __) => Container(color: AppColors.backgroundElevated),
                  errorWidget: (_, __, ___) => Container(color: AppColors.surface)
                ),
                // Dynamic gradient overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
                if (isPlaying) 
                  Container(
                    color: Colors.black.withValues(alpha: 0.3), 
                    child: const Center(child: Icon(Icons.volume_up, color: Colors.white, size: 24))
                  ),
                // Text info positioned at bottom
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title, 
                          maxLines: 2, 
                          overflow: TextOverflow.ellipsis, 
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.7), fontWeight: FontWeight.w600)
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
