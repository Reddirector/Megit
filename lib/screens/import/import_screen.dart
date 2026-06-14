import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/import_provider.dart';
import '../../widgets/glass_container.dart';

/// Import Playlist screen — redesigned with real-time progress tracking.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlC = TextEditingController();
  String _selectedSource = 'auto'; // 'auto' | 'spotify' | 'ytmusic'
  bool _isInputFocused = false;

  @override
  void dispose() {
    _urlC.dispose();
    super.dispose();
  }

  bool _isValidUrl(String url) {
    return url.startsWith('http') &&
        (url.contains('spotify.com') ||
            url.contains('music.youtube.com') ||
            url.contains('youtube.com/playlist'));
  }

  void _startImport() {
    final url = _urlC.text.trim();
    if (url.isEmpty || !_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a valid Spotify or YouTube Music playlist URL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ref.read(importProvider.notifier).startImport(url);
    _urlC.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import started — check progress below.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _urlC.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final imports = ref.watch(importProvider);
    final activeImports = imports.values.toList()
      ..sort((a, b) {
        // Done tasks go to bottom
        if (a.isDone && !b.isDone) return 1;
        if (!a.isDone && b.isDone) return -1;
        return b.id.compareTo(a.id);
      });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            // ── Header ──
            Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(LucideIcons.arrow_left, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                const Text('Import Playlist',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),

            const SizedBox(height: 24),

            // ── Platform cards ──
            Row(
              children: [
                _PlatformCard(
                  label: 'Spotify',
                  color: const Color(0xFF9D4EDD),
                  icon: 'assets/spotify.logo.png',
                  isSelected: _selectedSource == 'spotify',
                  onTap: () => setState(
                      () => _selectedSource = _selectedSource == 'spotify'
                          ? 'auto'
                          : 'spotify'),
                ),
                const SizedBox(width: 12),
                _PlatformCard(
                  label: 'YT Music',
                  color: const Color(0xFFFF0000),
                  icon: 'assets/ytmusic.logo.png',
                  isSelected: _selectedSource == 'ytmusic',
                  onTap: () => setState(
                      () => _selectedSource == 'ytmusic'
                          ? _selectedSource = 'auto'
                          : _selectedSource = 'ytmusic'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Instructions ──
            GlassContainer(
              borderRadius: 14,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.info, size: 16, color: accent),
                      const SizedBox(width: 8),
                      const Text('How to import',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _InstructionStep(
                    num: '1',
                    text: _selectedSource == 'spotify'
                        ? 'Open a playlist in Spotify → tap ⋯ → Share → Copy link'
                        : _selectedSource == 'ytmusic'
                            ? 'Open a playlist in YouTube Music → tap ⋮ → Share → Copy link'
                            : 'Open a public playlist in Spotify or YouTube Music and tap Share → Copy link',
                  ),
                  const SizedBox(height: 6),
                  const _InstructionStep(
                      num: '2', text: 'Paste the link below and tap Import'),
                  const SizedBox(height: 6),
                  const _InstructionStep(
                    num: '3',
                    text:
                        'Megit matches each track and saves the playlist to your library',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── URL Input ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isInputFocused
                      ? accent.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14),
                    child: Icon(LucideIcons.link, size: 16,
                        color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: Focus(
                      onFocusChange: (v) =>
                          setState(() => _isInputFocused = v),
                      child: TextField(
                        controller: _urlC,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText:
                              'Paste playlist URL here…',
                          hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onSubmitted: (_) => _startImport(),
                      ),
                    ),
                  ),
                  // Paste button
                  GestureDetector(
                    onTap: _pasteFromClipboard,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Paste',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Import Button ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _startImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.download, size: 16),
                    SizedBox(width: 8),
                    Text('Import Playlist',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),

            // ── Active & Completed Imports ──
            if (activeImports.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Import Activity',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...activeImports.map((task) => _ImportTaskCard(
                    task: task,
                    accent: accent,
                    onDismiss: () =>
                        ref.read(importProvider.notifier).dismissTask(task.id),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Platform Card ─────────────────────────────────────────────────────────────

class _PlatformCard extends StatelessWidget {
  final String label;
  final Color color;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 68,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(icon, width: 28, height: 28,
                    errorBuilder: (_, __, ___) =>
                        Icon(LucideIcons.music_2, color: color, size: 24)),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppColors.textPrimary)),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.circle_check, size: 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Instruction Step ──────────────────────────────────────────────────────────

class _InstructionStep extends StatelessWidget {
  final String num;
  final String text;

  const _InstructionStep({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1, right: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceStrong,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        ),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5)),
        ),
      ],
    );
  }
}

// ── Import Task Card ──────────────────────────────────────────────────────────

class _ImportTaskCard extends StatelessWidget {
  final ImportTask task;
  final Color accent;
  final VoidCallback onDismiss;

  const _ImportTaskCard({
    required this.task,
    required this.accent,
    required this.onDismiss,
  });

  Color get _statusColor {
    return switch (task.status) {
      'done' => AppColors.success,
      'error' => AppColors.danger,
      _ => accent,
    };
  }

  IconData get _statusIcon {
    return switch (task.status) {
      'done' => LucideIcons.circle_check_big,
      'error' => LucideIcons.circle_x,
      _ => task.isSpotify ? LucideIcons.music : LucideIcons.play,
    };
  }

  String get _statusLabel {
    return switch (task.status) {
      'fetching' => 'Fetching playlist…',
      'matching' =>
        'Matching songs… ${task.processedSongs}/${task.totalSongs}',
      'saving' => 'Saving to library…',
      'done' =>
        '${task.matchedSongs} songs saved${task.totalSongs > 0 && task.matchedSongs < task.totalSongs ? ' (${task.totalSongs - task.matchedSongs} skipped)' : ''}',
      'error' => task.errorMessage ?? 'Import failed',
      _ => task.status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Platform icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon, size: 18, color: _statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.isSpotify ? 'Spotify' : 'YouTube Music',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Dismiss button for done/error tasks
              if (task.isDone)
                GestureDetector(
                  onTap: onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(LucideIcons.x,
                        size: 16, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),

          // Progress bar (for active imports)
          if (!task.isDone && task.totalSongs > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress,
                backgroundColor: AppColors.surfaceHover,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 4,
              ),
            ),
          ] else if (!task.isDone) ...[
            // Indeterminate for fetching state
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: AppColors.surfaceHover,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 4,
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Status text
          Text(
            _statusLabel,
            style: TextStyle(
                fontSize: 12,
                color: task.status == 'error'
                    ? AppColors.danger
                    : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
