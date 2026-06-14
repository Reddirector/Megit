import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/thumbnail_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/stats_provider.dart';
import '../../data/api/music_api.dart';
import '../../data/models/song.dart';
import '../../widgets/glass_container.dart';
import '../../core/constants/app_constants.dart';

/// Profile screen — Redesigned for a sharp, smooth experience.
/// Edit name/picture, detailed listening stats, and personalized sections.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameC = TextEditingController();
  final _picker = ImagePicker();

  // Stats
  String _activeTimeframe = 'week';
  final _musicApi = MusicApi();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
      ref.listenManual(authProvider, (prev, next) {
        if ((prev?.user == null || prev?.isLoggedIn == false) && next.isLoggedIn) {
          _loadStats();
        }
      });
    });
  }

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _loadStats({bool force = false}) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) return;
    ref.read(statsProvider.notifier).loadStats(_activeTimeframe, force: force);
  }

  Future<void> _handleFullRefresh() async {
    await Future.wait([
       ref.read(authProvider.notifier).refreshProfile(),
       ref.read(statsProvider.notifier).loadStats(_activeTimeframe, force: true),
    ]);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        
        await ref.read(authProvider.notifier).updateUserProfile(photoURL: base64Image);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Profile picture updated successfully!')),
           );
        }
      }
    } catch (e) {
      debugPrint('[Profile] Image pick error: $e');
    }
  }

  Future<void> _goToArtist(Map<String, dynamic> a) async {
    final name = a['artist'] ?? a['name'] ?? '';
    if (name.isEmpty) return;
    try {
      final browseId = a['browseId'] ?? a['id'];
      if (browseId != null && browseId.toString().isNotEmpty) {
        context.push('/artist/$browseId');
        return;
      }
      final bid = await _musicApi.resolveArtist(name);
      if (mounted) {
        if (bid != null) {
          context.push('/artist/$bid');
        } else {
          context.push('/search?q=${Uri.encodeComponent(name)}');
        }
      }
    } catch (_) {
      if (mounted) context.push('/search?q=${Uri.encodeComponent(name)}');
    }
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '0m';
    final minutes = ms ~/ 60000;
    final hours = minutes ~/ 60;
    if (hours > 0) return '${hours}h ${minutes % 60}m';
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final stats = ref.watch(statsProvider);
    final accent = Theme.of(context).colorScheme.primary;
    final secondary = AppColors.computeSecondary(accent);

    if (!auth.isLoggedIn) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Not logged in',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayName = auth.displayName ?? 'Megit User';
    final email = auth.user?.email ?? '';
    final initials = auth.initials;

    return Scaffold(
      extendBody: true,
      body: SafeArea(bottom: false,
        child: RefreshIndicator(
          color: accent,
          backgroundColor: const Color(0xFF121212),
          onRefresh: _handleFullRefresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 200),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [accent, secondary]),
                        boxShadow: [
                          BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 24, spreadRadius: -4),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: ClipOval(
                            child: auth.photoURL != null && auth.photoURL!.isNotEmpty
                                ? (auth.photoURL!.startsWith('data:image')
                                    ? Image.memory(
                                        base64Decode(auth.photoURL!.split(',')[1]),
                                        fit: BoxFit.cover,
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: auth.photoURL!,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => _initialsWidget(initials),
                                        errorWidget: (_, __, ___) => _initialsWidget(initials),
                                      ))
                                : _initialsWidget(initials),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: const Icon(LucideIcons.camera, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              Center(
                child: Text(displayName,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(email,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showEditProfileDialog(context, displayName),
                      icon: const Icon(LucideIcons.pencil, size: 14),
                      label: const Text('Edit Name'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(LucideIcons.log_out, size: 14),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger.withOpacity(0.15),
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              const Text('Listening Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              
              GlassContainer(
                borderRadius: 12,
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: ['day', 'week', 'month', 'year'].map((tf) {
                    final isActive = _activeTimeframe == tf;
                    final label = tf[0].toUpperCase() + tf.substring(1);
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _activeTimeframe = tf;
                          _loadStats(force: true);
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isActive ? accent.withOpacity(0.25) : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                                    color: isActive ? accent : AppColors.textSecondary)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _StatCard(
                      title: 'LISTENING TIME',
                      value: _formatTime(stats.totalMs),
                      subtitle: _activeTimeframe == 'day' ? 'Today' : 'This ${_activeTimeframe}',
                      icon: LucideIcons.clock,
                      accent: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _StatCard(
                      title: 'DAILY AVG',
                      value: stats.dailyAvgMinutes > 0 ? '${stats.dailyAvgMinutes}m' : '—',
                      subtitle: 'Per day',
                      icon: LucideIcons.trending_up,
                      accent: accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _StatCard(
                title: 'LIFETIME LISTENING',
                value: _formatTime(stats.lifetimeMs),
                subtitle: 'Total time listened on Megit',
                icon: LucideIcons.headphones,
                accent: accent,
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Icon(LucideIcons.circle_play, size: 18, color: accent),
                  const SizedBox(width: 8),
                  const Text('Your Top Songs',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              stats.topSongs.isEmpty
                  ? const _EmptyStats(msg: 'Listening history will appear here.')
                  : SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stats.topSongs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final s = stats.topSongs[i];
                          final thumb = ThumbnailUtils.getHighRes(
                              s['thumbnail'] ?? s['cover'] ?? '', size: 300);
                          return GestureDetector(
                            onTap: () {
                              try {
                                final songObj = Song.fromJson(s);
                                ref.read(audioProvider.notifier).playSong(songObj, clearQueue: true);
                              } catch (_) {}
                            },
                            child: SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: thumb.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                                          : Container(color: AppColors.surface),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(s['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  Text(s['artist'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text('#${i + 1} • ${s['playCount'] ?? 0} plays',
                                      style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Icon(LucideIcons.mic_vocal, size: 18, color: accent),
                  const SizedBox(width: 8),
                  const Text('Your Top Artists',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              stats.topArtists.isEmpty
                  ? const _EmptyStats(msg: 'Your favorite artists will appear here.')
                  : SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stats.topArtists.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final a = stats.topArtists[i];
                          final name = a['artist'] ?? a['name'] ?? 'Unknown';
                          final thumb = ThumbnailUtils.getHighRes(
                              a['thumbnail'] ?? a['cover'] ?? '', size: 300);
                          return GestureDetector(
                            onTap: () => _goToArtist(a),
                            child: SizedBox(
                              width: 140,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(70), 
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: thumb.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                                          : _artistPlaceholder(name.isNotEmpty ? name[0] : '?', accent),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                  Center(
                                    child: Text(_formatTime((a['totalSeconds'] ?? 0) * 1000),
                                        style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 48),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [accent, secondary]),
                        boxShadow: [
                          BoxShadow(color: accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Icon(LucideIcons.audio_waveform, size: 30, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('MEGIT',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 8)),
                    const SizedBox(height: 4),
                    const Text('Premium sound. Effortless flow.',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text('Version $kAppVersion',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initialsWidget(String initials) {
    return Center(
      child: Text(initials,
          style: const TextStyle(
              fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }

  Widget _artistPlaceholder(String initial, Color accent) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Text(initial.toUpperCase(),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accent)),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName) {
    _nameC.text = currentName;
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0D0D0D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: AppColors.glassBorder)),
              title: const Text('Edit Name', style: TextStyle(fontWeight: FontWeight.w800)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('DISPLAY NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textTertiary, letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameC,
                    autofocus: true,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      filled: true, fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final name = _nameC.text.trim();
                    if (name.isNotEmpty) {
                      setStateDialog(() => isSaving = true);
                      await ref.read(authProvider.notifier).updateUserProfile(displayName: name);
                      if (ctx.mounted) {
                        setStateDialog(() => isSaving = false);
                        ctx.pop();
                      }
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _StatCard({
    required this.title, required this.value, required this.subtitle, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                      color: accent, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  final String msg;
  const _EmptyStats({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
