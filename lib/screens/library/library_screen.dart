import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../widgets/song_cards.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/import_provider.dart';
import '../../providers/download_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/playing_bars.dart';
import '../../widgets/playlist_thumbnail.dart';
import '../../widgets/thumbnail_picker_modal.dart';
import '../../core/utils/thumbnail_utils.dart';

/// Library screen — port of Library.jsx.
/// Shows user playlists with sort, grid/list toggle, FAB for create/import.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _showSortDropdown = false;
  bool _showAddOptions = false;
  bool _showCreateModal = false;
  final _createController = TextEditingController();

  // For rename/delete modals
  Playlist? _editingPlaylist;
  bool _showRenameModal = false;
  bool _showDeleteModal = false;
  final _renameController = TextEditingController();

  // For edit-songs modal (buffered save)
  bool _showEditSongsModal = false;
  Playlist? _editSongsPlaylist;
  List<Song> _editSongsList = [];

  @override
  void dispose() {
    _createController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistState = ref.watch(playlistProvider);
    final playlists = playlistState.playlists;
    final accent = Theme.of(context).colorScheme.primary;

    final settings = ref.watch(settingsProvider);
    final layoutMode = settings.libraryLayoutMode;
    final sortKey = settings.librarySortKey;
    final sortOrder = settings.librarySortOrder;

    // Sort
    final sorted = _sortPlaylists(playlists, sortKey, sortOrder);

    // ── Listen for Import results (Toasts) ──
    ref.listen<Map<String, ImportTask>>(importProvider, (previous, next) {
      for (final entry in next.entries) {
        final taskId = entry.key;
        final task = entry.value;
        final prevTask = previous?[taskId];

        if (task.status == 'done' && (prevTask == null || prevTask.status != 'done')) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.circle_check, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Imported "${task.name}" successfully!')),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          // Auto-dismiss task so it doesn't show up again
          Future.delayed(const Duration(milliseconds: 500), () {
            ref.read(importProvider.notifier).dismissTask(taskId);
          });
        } else if (task.status == 'error' && (prevTask == null || prevTask.status != 'error')) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.circle_x, color: Colors.white, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Import failed: ${task.errorMessage ?? "Empty playlist or private"}')),
                ],
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            ref.read(importProvider.notifier).dismissTask(taskId);
          });
        }
      }
    });

    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Library',
                              style: Theme.of(context).textTheme.headlineLarge),
                          Row(
                            children: [
                              // Sort button
                              _SortButton(
                                sortKey: sortKey,
                                sortOrder: sortOrder,
                                onTap: () => setState(() =>
                                    _showSortDropdown = !_showSortDropdown),
                              ),
                              const SizedBox(width: 8),
                              // Downloads button
                              GestureDetector(
                                onTap: () => context.push('/downloads'),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(LucideIcons.download,
                                      size: 18, color: AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Layout Selector
                              const SizedBox(width: 4),
                              Consumer(
                                builder: (context, ref, _) {
                                  final mode = ref.watch(settingsProvider.select((s) => s.libraryLayoutMode));
                                  return LayoutSelector(
                                    currentMode: mode,
                                    onModeChanged: (m) => ref.read(settingsProvider.notifier).setLibraryLayoutMode(m),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Playlist list ──
                Expanded(
                  child: sorted.isEmpty
                      ? _buildEmptyState()
                      : _buildLibraryContent(sorted),
                ),
              ],
            ),

            // ── FAB ──
            Positioned(
              bottom: 160, right: 20,
              child: GestureDetector(
                onTap: () => setState(() => _showAddOptions = !_showAddOptions),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accent, AppColors.computeSecondary(accent)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: _showAddOptions ? 0.125 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: const Icon(LucideIcons.plus, size: 20, color: Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(width: 6),
                      const Text('Add',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF))),
                    ],
                  ),
                ),
              ),
            ),

            // ── Add Options overlay ──
            if (_showAddOptions) _buildAddOptions(accent),

            // ── Create Modal ──
            if (_showCreateModal) Positioned.fill(child: _buildCreateModal(accent)),

            // ── Rename Modal ──
            if (_showRenameModal) Positioned.fill(child: _buildRenameModal(accent)),

            // ── Delete Modal ──
            if (_showDeleteModal) Positioned.fill(child: _buildDeleteModal(accent)),

            // ── Edit Songs Modal ──
            if (_showEditSongsModal) Positioned.fill(child: _buildEditSongsModal(accent)),

            // ── Sort Dropdown Overlay ──
            if (_showSortDropdown)
              Positioned(
                top: 60,
                right: 20,
                child: GlassContainer(
                  borderRadius: 12,
                  child: SizedBox(
                    width: 170,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SortOption(
                          label: 'Recently Added', isActive: sortKey == 'recent',
                          sortOrder: sortOrder,
                          onTap: () => _handleSort('recent', sortKey, sortOrder),
                        ),
                        _SortOption(
                          label: 'Alphabetical', isActive: sortKey == 'alpha',
                          sortOrder: sortOrder,
                          onTap: () => _handleSort('alpha', sortKey, sortOrder),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Playlist> _sortPlaylists(List<Playlist> playlists, String sortKey, String sortOrder) {
    final filtered = playlists.where((pl) {
      return pl.songs.isNotEmpty;
    }).toList();

    filtered.sort((a, b) {
      if (sortKey == 'alpha') {
        final cmp = a.name.compareTo(b.name);
        return sortOrder == 'desc' ? cmp : -cmp;
      } else {
        final timeA = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final timeB = b.createdAt?.millisecondsSinceEpoch ?? 0;
        final cmp = timeB - timeA;
        return sortOrder == 'asc' ? cmp : -cmp;
      }
    });
    return filtered;
  }

  void _handleSort(String key, String currentKey, String currentOrder) {
    String nextOrder = 'desc';
    if (currentKey == key) {
      nextOrder = currentOrder == 'asc' ? 'desc' : 'asc';
    }
    ref.read(settingsProvider.notifier).setLibrarySort(key, nextOrder);
    setState(() => _showSortDropdown = false);
  }

  Widget _buildLibraryContent(List<Playlist> playlists) {
    final mode = ref.watch(settingsProvider.select((s) => s.libraryLayoutMode));

    if (mode == LayoutMode.list) return _buildListView(playlists);
    if (mode == LayoutMode.grid) return _buildGridView(playlists);

    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: playlists.length,
      addRepaintBoundaries: true,
      addAutomaticKeepAlives: true,
      itemBuilder: (context, i) {
        final pl = playlists[i];
        final h = (180 + (i % 3) * 40).toDouble();
        return _MasonryPlaylistCard(
          key: ValueKey('pl-masonry-${pl.id}'), // Stable key to prevent flickering
          playlist: pl,
          height: h,
          onTap: () => context.push('/playlist/${pl.id}'),
          onLongPress: () => _showPlaylistMenu(pl),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Your library is empty.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('Tap "Add" to start your first Megit.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildListView(List<Playlist> playlists) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140),
      itemCount: playlists.length,
      itemBuilder: (context, i) => _PlaylistListTile(
        playlist: playlists[i],
        onTap: () => context.push('/playlist/${playlists[i].id}'),
        onLongPress: () => _showPlaylistMenu(playlists[i]),
        onMenu: () => _showPlaylistMenu(playlists[i]),
      ),
    );
  }

  Widget _buildGridView(List<Playlist> playlists) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, childAspectRatio: 0.75,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, i) => _PlaylistGridCard(
        playlist: playlists[i],
        onTap: () => context.push('/playlist/${playlists[i].id}'),
        onLongPress: () => _showPlaylistMenu(playlists[i]),
        onMenu: () => _showPlaylistMenu(playlists[i]),
      ),
    );
  }

  void _showPlaylistMenu(Playlist pl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GlassContainer(
        borderRadius: 24, blur: 24,
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final notifier = ref.read(audioProvider.notifier);
                      final shuffledSongs = List<Song>.from(pl.songs)..shuffle();
                      if (shuffledSongs.isNotEmpty) {
                         await notifier.playSong(shuffledSongs.first, 
                            clearQueue: true, contextPlaylistId: pl.id);
                         notifier.replaceQueue(shuffledSongs.sublist(1));
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.shuffle, size: 17), SizedBox(width: 14),
                        Text('Shuffle Play', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      final data = 'https://music.youtube.com/playlist?list=${pl.id}';
                      await Clipboard.setData(ClipboardData(text: data));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Playlist link copied to clipboard')),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.copy, size: 17), SizedBox(width: 14),
                        Text('Copy Link', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(downloadProvider.notifier).downloadPlaylist(pl);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Download started')),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.download, size: 17), SizedBox(width: 14),
                        Text('Download All', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _showThumbnailPicker(pl);
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.image, size: 17), SizedBox(width: 14),
                        Text('Edit Thumbnail', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      if (pl.name == 'Liked Songs') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot rename the Liked Songs playlist.')),
                        );
                      } else {
                        _renameController.text = pl.name;
                        setState(() { _editingPlaylist = pl; _showRenameModal = true; });
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.pencil, size: 17), SizedBox(width: 14),
                        Text('Rename', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      // Open edit songs modal with buffered copy
                      final songs = (pl.songs as List<dynamic>)
                          .map((s) => s is Song ? s : Song.fromJson(s as Map<String, dynamic>))
                          .toList();
                      setState(() {
                        _editSongsPlaylist = pl;
                        _editSongsList = List<Song>.from(songs);
                        _showEditSongsModal = true;
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.list_music, size: 17), SizedBox(width: 14),
                        Text('Edit Songs', style: TextStyle(fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      if (pl.name == 'Liked Songs') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cannot delete the Liked Songs playlist.')),
                        );
                      } else {
                        setState(() { _editingPlaylist = pl; _showDeleteModal = true; });
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(children: [
                        Icon(LucideIcons.trash_2, size: 17, color: AppColors.danger),
                        SizedBox(width: 14),
                        Text('Delete', style: TextStyle(fontSize: 15, color: AppColors.danger)),
                      ]),
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

  void _showThumbnailPicker(Playlist pl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ThumbnailPickerModal(playlist: pl),
    );
  }

  Widget _buildEditSongsModal(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showEditSongsModal = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close on card tap
            child: GlassContainer(
              borderRadius: 24, blur: 24,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Edit Songs',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                '${_editSongsList.length} song${_editSongsList.length != 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _showEditSongsModal = false),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.background),
                                onPressed: () async {
                                  if (_editSongsPlaylist != null) {
                                    final songMaps = _editSongsList
                                        .map((s) => s.toJson())
                                        .toList();
                                    await ref.read(playlistProvider.notifier).updatePlaylist(
                                      _editSongsPlaylist!.id,
                                      {'songs': songMaps},
                                    );
                                  }
                                  if (mounted) {
                                    setState(() => _showEditSongsModal = false);
                                  }
                                },
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    // Song list - Optimized for lazy loading (Task 3 Fix)
                    Expanded(
                      child: _editSongsList.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No songs in this playlist.',
                                  style: TextStyle(color: AppColors.textSecondary)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _editSongsList.length,
                              itemBuilder: (context, i) {
                                final song = _editSongsList[i];
                                final thumb = ThumbnailUtils.getHighRes(song.thumbnail, size: 120);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Row(
                                    children: [
                                      // Thumbnail
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                          width: 40, height: 40,
                                          child: thumb.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: thumb, fit: BoxFit.cover,
                                                  memCacheWidth: 120, memCacheHeight: 120, // Task 4
                                                  errorWidget: (_, __, ___) =>
                                                      Container(color: AppColors.surface))
                                              : Container(color: AppColors.surface),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Song info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(song.title,
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 14, fontWeight: FontWeight.w600)),
                                            Text(song.artist,
                                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      // Remove button
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _editSongsList.removeAt(i);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.danger.withValues(alpha: 0.15),
                                          ),
                                          child: const Icon(LucideIcons.x,
                                              size: 16, color: AppColors.danger),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddOptions(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showAddOptions = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GlassContainer(
            borderRadius: 24, blur: 24,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add to Library',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Choose how you want to expand your Megit',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 20),


                _AddOptionItem(
                  iconWidget: const Icon(LucideIcons.cloud_download, size: 20, color: Colors.white),
                  label: 'Import Playlist or Song',
                  subtitle: 'Spotify, YT Music, or Apple Music',
                  onTap: () {
                    setState(() => _showAddOptions = false);
                    context.push('/import');
                  },
                ),
                const SizedBox(height: 10),
                _AddOptionItem(
                  iconWidget: const Icon(LucideIcons.list_plus, size: 20, color: Colors.white),
                  label: 'Create New Playlist',
                  subtitle: 'Build your own collection',
                  onTap: () {
                    setState(() {
                      _showAddOptions = false;
                      _showCreateModal = true;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _showAddOptions = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateModal(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showCreateModal = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GlassContainer(
            borderRadius: 24, blur: 24,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('New Playlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('What should we call your new playlist?',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _createController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'e.g. Midnight Rides',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showCreateModal = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.background),
                      onPressed: () {
                        final name = _createController.text.trim();
                        if (name.isNotEmpty) {
                          ref.read(playlistProvider.notifier).createPlaylist(name: name);
                          _createController.clear();
                          setState(() => _showCreateModal = false);
                        }
                      },
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRenameModal(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showRenameModal = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GlassContainer(
            borderRadius: 24, blur: 24,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Rename Playlist',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Enter a new name for your playlist.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: _renameController, autofocus: true,
                  decoration: InputDecoration(
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showRenameModal = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: AppColors.background),
                      onPressed: () async {
                        final name = _renameController.text.trim();
                        if (name.isNotEmpty && _editingPlaylist != null) {
                          await ref.read(playlistProvider.notifier)
                              .updatePlaylist(_editingPlaylist!.id, {'name': name});
                          setState(() => _showRenameModal = false);
                        }
                      },
                      child: const Text('Rename'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteModal(Color accent) {
    return GestureDetector(
      onTap: () => setState(() => _showDeleteModal = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: GlassContainer(
            borderRadius: 24, blur: 24,
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.trash_2, size: 32, color: AppColors.danger),
                const SizedBox(height: 12),
                const Text('Delete Playlist?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${_editingPlaylist?.name}"? This playlist will be lost forever.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showDeleteModal = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: AppColors.background),
                      onPressed: () async {
                        if (_editingPlaylist != null) {
                          await ref.read(playlistProvider.notifier)
                              .deletePlaylist(_editingPlaylist!.id);
                          setState(() => _showDeleteModal = false);
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ──

class _SortButton extends StatelessWidget {
  final String sortKey;
  final String sortOrder;
  final VoidCallback onTap;

  const _SortButton({
    required this.sortKey, required this.sortOrder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = sortKey == 'alpha' ? 'A-Z' : 'Recent';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.arrow_up_down, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            Icon(sortOrder == 'asc' ? LucideIcons.arrow_up : LucideIcons.arrow_down,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label; final bool isActive; final String sortOrder; final VoidCallback onTap;
  const _SortOption({
    required this.label, required this.isActive, required this.sortOrder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(
                fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Theme.of(context).colorScheme.primary : AppColors.textPrimary)),
            if (isActive)
              Icon(sortOrder == 'asc' ? LucideIcons.arrow_up : LucideIcons.arrow_down,
                  size: 14, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListTile extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onMenu;

  const _PlaylistListTile({
    required this.playlist, required this.onTap, this.onLongPress, required this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final songs = playlist.songs;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // Cover
              PlaylistThumbnail(
                playlist: playlist,
                width: 54, height: 54,
                borderRadius: 8,
                isCurrentContext: audio.contextPlaylistId == playlist.id,
                isPaused: !audio.isPlaying,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${songs.length} Songs',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              // More button
              GestureDetector(
                onTap: onMenu,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(LucideIcons.ellipsis_vertical, size: 18, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// [DELETE] _QuadCover class here

class _PlaylistGridCard extends ConsumerWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onMenu;
  const _PlaylistGridCard({required this.playlist, required this.onTap, this.onLongPress, required this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final songs = playlist.songs;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PlaylistThumbnail(
              playlist: playlist,
              borderRadius: 12,
              isGrid: true,
              isCurrentContext: audio.contextPlaylistId == playlist.id,
              isPaused: !audio.isPlaying,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${songs.length} Songs',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onMenu,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 4),
                  child: Icon(LucideIcons.ellipsis_vertical, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddOptionItem extends StatelessWidget {
  final Widget? iconWidget;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _AddOptionItem({
    this.iconWidget, required this.label,
    required this.subtitle, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        borderRadius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.surface,
              ),
              child: Center(
                child: iconWidget ?? const Icon(LucideIcons.plus, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasonryPlaylistCard extends ConsumerWidget {
  final Playlist playlist;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MasonryPlaylistCard({super.key, required this.playlist, required this.height, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioProvider);
    final isPlayingThis = audio.contextPlaylistId == playlist.id;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface, // Prevent transparent flicker
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PlaylistThumbnail(
                  playlist: playlist,
                  borderRadius: 0, // Fill the card
                  isGrid: true,
                ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                if (isPlayingThis)
                  Container(
                    color: Colors.black.withValues(alpha: 0.2),
                    child: Center(
                      child: PlayingBars(
                        color: Theme.of(context).colorScheme.primary,
                        height: 24,
                        isPaused: !audio.isPlaying,
                      ),
                    ),
                  ),
                // Text info
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlist.songs.length} tracks',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
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
