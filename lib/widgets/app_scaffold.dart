import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../screens/offline/offline_screen.dart';
import 'mini_player.dart';
import '../providers/update_provider.dart';
import '../providers/audio_provider.dart';
import 'whale_background.dart';

/// App scaffold — Megit's persistent shell.
/// Features a floating glass mini-player + premium pill-shaped bottom nav
/// with an animated selection indicator.
class AppScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  bool _isOffline = false;
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  @override
  void initState() {
    super.initState();

    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() => _isOffline = result.every((r) => r == ConnectivityResult.none));
      }
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() => _isOffline = result.every((r) => r == ConnectivityResult.none));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final updateState = ref.read(updateNotifierProvider);
      if (updateState.value?.isUpdateAvailable == true) {
        _showUpdateDialog(updateState.value!);
      } else {
        ref.listenManual<AsyncValue<AppUpdateInfo?>>(
          updateNotifierProvider,
          (previous, next) {
            if (next.value?.isUpdateAvailable == true) {
              _showUpdateDialog(next.value!);
            }
          },
        );
      }
    });
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    if (!mounted) return;
    final accent = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0E13),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: AppTheme.accentGradient(accent),
                        boxShadow: AppTheme.accentGlow(accent),
                      ),
                      child: const Icon(
                        LucideIcons.cloud_download,
                        color: Colors.black,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Update Available',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Megit v${info.latestVersion} is ready. Upgrade now for the latest features and improvements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          launchUrl(Uri.parse(info.downloadUrl),
                              mode: LaunchMode.externalApplication);
                        },
                        icon: const Icon(LucideIcons.download, size: 18),
                        label: const Text('Download Update'),
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

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  void _navigateToIndex(int index) {
    const routes = ['/', '/search', '/library', '/profile'];
    context.go(routes[index]);
  }

  static int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location == '/') return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/library')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);
    final location = GoRouterState.of(context).uri.toString();
    final hasSong = ref.watch(audioProvider.select((a) => a.currentSong != null));

    final isOfflinePlaylist = location.startsWith('/playlist/__pl__') ||
        location.startsWith('/playlist/__downloads__');
    if (_isOffline && !location.startsWith('/downloads') && !isOfflinePlaylist) {
      return const OfflineScreen();
    }

    return Scaffold(
      extendBody: true,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          
          final index = _currentIndex(context);
          if (details.primaryVelocity! < -500) {
            // Swipe Left -> Go Right
            if (index < 3) {
              _navigateToIndex(index + 1);
            }
          } else if (details.primaryVelocity! > 500) {
            // Swipe Right -> Go Left
            if (index > 0) {
              _navigateToIndex(index - 1);
            }
          }
        },
        child: widget.child,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Floating Mini Player ──
              if (hasSong)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      // RepaintBoundary isolates the mini-player repaints
                      // (which happen every 250ms on position updates) from
                      // the rest of the scaffold, preventing full-screen
                      // jank on low-end devices.
                      child: const RepaintBoundary(child: MiniPlayer()),
                    ),
                  ),
                ),

              // ── Premium Pill Bottom Nav ──
              _PremiumBottomNav(currentIndex: currentIndex),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  const _PremiumBottomNav({required this.currentIndex});

  static const _items = [
    _NavItemData(icon: LucideIcons.house, label: 'Home', route: '/'),
    _NavItemData(icon: LucideIcons.search, label: 'Search', route: '/search'),
    _NavItemData(icon: LucideIcons.library, label: 'Library', route: '/library'),
    _NavItemData(icon: LucideIcons.user, label: 'Profile', route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: WhaleNavBarWrapper(
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xCC0B0E13).withOpacity(0.4),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Animated selection indicator (slides between items)
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      -1.0 + (currentIndex * 2.0 / (_items.length - 1)),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / _items.length,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent.withValues(alpha: 0.22),
                                AppColors.computeSecondary(accent).withValues(alpha: 0.12),
                              ],
                            ),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Items
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Expanded(
                        child: _NavItem(
                          icon: item.icon,
                          label: item.label,
                          isActive: i == currentIndex,
                          onTap: () => context.go(item.route),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final String route;
  const _NavItemData({required this.icon, required this.label, required this.route});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = isActive ? accent : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.1,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
