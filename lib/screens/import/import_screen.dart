import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/import_provider.dart';
import '../../widgets/glass_container.dart';

/// Import Playlist screen — consolidated into a single, clean link-based experience.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlC = TextEditingController();
  String _selectedSource = 'spotify'; // Default platform
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
            url.contains('youtube.com/playlist') ||
            url.contains('music.apple.com') ||
            url.contains('tunemymusic.com'));
  }

  void _startImport() {
    final url = _urlC.text.trim();
    if (url.isEmpty || !_isValidUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paste a valid Spotify, Apple Music, or YouTube Music URL.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ref.read(importProvider.notifier).startImport(url);
    _urlC.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import started — progress shown below.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickAndImportCSV() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        ref.read(importProvider.notifier).startCSVImport(file);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV import started — progress shown below.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[Import] File picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() => _urlC.text = data!.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final importsMap = ref.watch(importProvider);
    final activeImports = importsMap.values.toList()
      ..sort((a, b) {
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),

            const SizedBox(height: 24),

            // ── Platform cards ──
            Row(
              children: [
                _PlatformCard(
                  label: 'Spotify',
                  color: const Color(0xFF1DB954),
                  icon: 'assets/spotify.logo.png',
                  isSelected: _selectedSource == 'spotify',
                  onTap: () => setState(() => _selectedSource = 'spotify'),
                ),
                const SizedBox(width: 8),
                _PlatformCard(
                  label: 'YT Music',
                  color: const Color(0xFFFF0000),
                  icon: 'assets/ytmusic.logo.png',
                  isSelected: _selectedSource == 'ytmusic',
                  onTap: () => setState(() => _selectedSource = 'ytmusic'),
                ),
                const SizedBox(width: 8),
                _PlatformCard(
                  label: 'Apple',
                  color: const Color(0xFFFC3C44),
                  isSelected: _selectedSource == 'apple',
                  onTap: () => setState(() => _selectedSource = 'apple'),
                  iconWidget: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Apple_Music_logo.svg/1200px-Apple_Music_logo.svg.png',
                      width: 28, height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(LucideIcons.apple, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _PlatformCard(
                  label: 'Tune',
                  color: const Color(0xFF9D4EDD),
                  isSelected: _selectedSource == 'tunemymusic',
                  onTap: () => setState(() => _selectedSource = 'tunemymusic'),
                  iconWidget: const Icon(LucideIcons.radio, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 8),
                _PlatformCard(
                  label: 'CSV',
                  color: const Color(0xFF217346),
                  isSelected: _selectedSource == 'csv',
                  onTap: () => setState(() => _selectedSource = 'csv'),
                  iconWidget: const Icon(LucideIcons.file_spreadsheet, color: Colors.white, size: 24),
                ),
              ],
            ),

            const SizedBox(height: 24),

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
                      const Text('How to import', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InstructionStep(
                    num: '1', 
                    text: _selectedSource == 'tunemymusic' 
                      ? 'Create a share link on TuneMyMusic.com for your playlist.'
                      : _selectedSource == 'csv'
                        ? 'Export your playlist as a .csv file from any service.'
                        : 'Open your playlist in Spotify, YT Music, or Apple Music.'
                  ),
                  const SizedBox(height: 8),
                  _InstructionStep(
                    num: '2', 
                    text: _selectedSource == 'csv'
                      ? 'Tap "Upload CSV File" and select your file.'
                      : 'Tap Share and Copy the link.'
                  ),
                  const SizedBox(height: 8),
                  _InstructionStep(
                    num: '3', 
                    text: _selectedSource == 'csv'
                      ? 'Megit will match each track from the file to YT Music.'
                      : 'Paste the link below to sync the entire collection.'
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── URL Input or CSV Upload ──
            if (_selectedSource == 'csv')
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _pickAndImportCSV,
                  icon: const Icon(LucideIcons.upload, size: 18),
                  label: const Text('Upload CSV File', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            else ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _isInputFocused ? accent.withValues(alpha: 0.6) : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Icon(LucideIcons.link, size: 16, color: AppColors.textSecondary),
                    ),
                    Expanded(
                      child: Focus(
                        onFocusChange: (v) => setState(() => _isInputFocused = v),
                        child: TextField(
                          controller: _urlC,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Paste playlist or song URL…',
                            hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onSubmitted: (_) => _startImport(),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pasteFromClipboard,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surfaceHover, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Paste', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Import Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _startImport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.download, size: 18),
                      SizedBox(width: 10),
                      Text('Import Collection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],

            // ── Import Activity ──
            if (activeImports.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('Import Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ...activeImports.map((task) => _ImportTaskCard(
                    task: task,
                    accent: accent,
                    onDismiss: () => ref.read(importProvider.notifier).dismissTask(task.id),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final String label;
  final Color color;
  final String? icon;
  final Widget? iconWidget;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.label,
    required this.color,
    this.icon,
    this.iconWidget,
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
          height: 72,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? color.withValues(alpha: 0.7) : Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconWidget != null) iconWidget!
              else ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(icon!, width: 26, height: 26,
                    errorBuilder: (_, __, ___) => Icon(LucideIcons.music_2, color: color, size: 24)),
              ),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? color : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

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
          width: 18, height: 18,
          margin: const EdgeInsets.only(top: 1, right: 10),
          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
          child: Center(child: Text(num, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
        ),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.4))),
      ],
    );
  }
}

class _ImportTaskCard extends StatelessWidget {
  final ImportTask task;
  final Color accent;
  final VoidCallback onDismiss;

  const _ImportTaskCard({required this.task, required this.accent, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final statusColor = task.status == 'done' ? AppColors.success : (task.status == 'error' ? AppColors.danger : accent);
    final statusIcon = task.status == 'done' ? LucideIcons.circle_check : (task.status == 'error' ? LucideIcons.circle_x : LucideIcons.refresh_cw);

    String platformName = task.platform.toUpperCase();
    if (task.platform == 'tunemymusic') platformName = 'TUNE MY MUSIC';

    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(platformName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary)),
                  ],
                ),
              ),
              if (task.isDone)
                IconButton(onPressed: onDismiss, icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textSecondary)),
            ],
          ),
          if (!task.isDone) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: task.totalSongs > 0 ? task.progress : null, backgroundColor: AppColors.surfaceHover, valueColor: AlwaysStoppedAnimation<Color>(accent), minHeight: 4),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            task.status == 'error' ? task.errorMessage ?? 'Import failed' : (task.status == 'done' ? 'Successfully synced to library' : 'Syncing collection… ${task.processedSongs}/${task.totalSongs}'),
            style: TextStyle(fontSize: 12, color: task.status == 'error' ? AppColors.danger : Colors.white60),
          ),
        ],
      ),
    );
  }
}
