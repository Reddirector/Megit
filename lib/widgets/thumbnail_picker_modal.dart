import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_lucide/flutter_lucide.dart';
import '../data/models/playlist.dart';
import '../providers/playlist_provider.dart';
import '../core/theme/app_colors.dart';
import 'glass_container.dart';

class ThumbnailPickerModal extends ConsumerStatefulWidget {
  final Playlist playlist;

  const ThumbnailPickerModal({super.key, required this.playlist});

  @override
  ConsumerState<ThumbnailPickerModal> createState() => _ThumbnailPickerModalState();
}

class _ThumbnailPickerModalState extends ConsumerState<ThumbnailPickerModal> {
  final _textController = TextEditingController();
  String _selectedColor = '#14B89A'; // Default Megit Emerald
  bool _isSaving = false;

  final List<String> _presetColors = [
    '#14B89A', // Emerald
    '#E5B355', // Gold
    '#9D4EDD', // Purple
    '#FF4D4D', // Red
    '#4D94FF', // Blue
    '#FF9F43', // Orange
    '#212121', // Dark Gray
    '#FFFFFF', // White
  ];

  @override
  void initState() {
    super.initState();
    _textController.text = widget.playlist.customText ?? '';
    _selectedColor = widget.playlist.customColor ?? '#14B89A';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Thumbnail',
          toolbarColor: AppColors.background,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Thumbnail',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _isSaving = true);

    try {
      final bytes = await File(croppedFile.path).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode image');

      // Resize to 400x400 to keep Firestore doc size small
      final resized = img.copyResize(image, width: 400, height: 400);
      final encoded = base64Encode(img.encodeJpg(resized, quality: 75));

      await ref.read(playlistProvider.notifier).updatePlaylist(
        widget.playlist.id,
        {
          'customThumbnail': encoded,
          'customColor': null,
          'customText': null,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving custom thumbnail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save image')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveColorText() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(playlistProvider.notifier).updatePlaylist(
        widget.playlist.id,
        {
          'customThumbnail': null,
          'customColor': _selectedColor,
          'customText': _textController.text.trim().isEmpty ? null : _textController.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error saving color/text: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeCustom() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(playlistProvider.notifier).updatePlaylist(
        widget.playlist.id,
        {
          'customThumbnail': null,
          'customColor': null,
          'customText': null,
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error removing custom thumbnail: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassContainer(
      borderRadius: 24,
      blur: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Edit Thumbnail',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          
          // Options
          ListTile(
            leading: const Icon(LucideIcons.image),
            title: const Text('Choose from Gallery'),
            onTap: _isSaving ? null : _pickFromGallery,
          ),
          const Divider(color: AppColors.glassBorder),
          
          // Color & Text Section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solid Color & Text',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final hex = _presetColors[i];
                      final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                      final isSelected = _selectedColor == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = hex),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(LucideIcons.check, size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Text (optional)',
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveColorText,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.background,
                    ),
                    child: const Text('Save Color & Text'),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(color: AppColors.glassBorder),
          ListTile(
            leading: const Icon(LucideIcons.trash_2, color: AppColors.danger),
            title: const Text('Remove Custom Thumbnail', style: TextStyle(color: AppColors.danger)),
            onTap: _isSaving ? null : _removeCustom,
          ),
          const SizedBox(height: 16),
          if (_isSaving)
            const CircularProgressIndicator()
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}
