import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/library/library_screen.dart';
import '../../screens/player/player_screen.dart';
import '../../screens/playlist/playlist_screen.dart';
import '../../screens/artist/artist_screen.dart';
import '../../screens/downloads/downloads_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/import/import_screen.dart';
import '../../screens/login/login_screen.dart';
import '../../screens/section/section_detail_screen.dart';
import '../../widgets/app_scaffold.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

/// Global navigator keys for shell route nesting.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration — mirrors React Router config from App.jsx.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.loading) return null;

      final isLoggedIn = authState.isLoggedIn;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isGoingToLogin) {
        return '/login';
      }
      
      if (isLoggedIn && isGoingToLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      // ── Login (no shell) ──
      GoRoute(
        name: 'Login',
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Full-screen player (no bottom nav) ──
      GoRoute(
        name: 'Player',
        parentNavigatorKey: _rootNavigatorKey,
        path: '/player',
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const PlayerScreen(),
            transitionDuration: const Duration(milliseconds: 250),
            reverseTransitionDuration: const Duration(milliseconds: 250),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return ScaleTransition(
                alignment: const Alignment(0.0, 0.85), // Aligns roughly with the mini player position above the nav bar
                scale: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeOutCubic,
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                    reverseCurve: Curves.easeIn,
                  ),
                  child: child,
                ),
              );
            },
          );
        },
      ),

      // ── Main shell (with bottom nav + mini player) ──
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        observers: [
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        builder: (context, state, child) => AppScaffold(child: child),
        routes: [
          GoRoute(
            name: 'Home',
            path: '/',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const HomeScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Library',
            path: '/library',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const LibraryScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Search',
            path: '/search',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: SearchScreen(initialQuery: state.uri.queryParameters['q']),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Profile',
            path: '/profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ProfileScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Settings',
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Downloads',
            path: '/downloads',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const DownloadsScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Playlist',
            path: '/playlist/:id',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: PlaylistScreen(playlistId: state.pathParameters['id']!),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Artist',
            path: '/artist/:id',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: ArtistScreen(browseId: state.pathParameters['id']!),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Import',
            path: '/import',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const ImportScreen(),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            name: 'Section',
            path: '/section/:title',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: SectionDetailScreen(title: state.pathParameters['title']!),
              transitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ],
  );

  ref.listen(authProvider, (_, __) => router.refresh());
  return router;
});

