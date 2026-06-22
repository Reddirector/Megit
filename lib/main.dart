import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:just_audio/just_audio.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/audio_provider.dart';
import 'services/audio_handler.dart';
import 'package:permission_handler/permission_handler.dart';

/// Global key for showing snack bars from anywhere (e.g. Providers)
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parallelize independent initializations for faster cold start (Task 5).
  // Each helper has its own try/catch and a guaranteed, correctly-typed
  // fallback value, so Future.wait never has to reconcile mismatched types
  // across branches (returning `null` from catchError on a non-nullable
  // Future<FirebaseApp> can throw a runtime type error the moment Firebase
  // init actually fails — exactly when you don't want a crash).
  final results = await Future.wait([
    _initFirebase(),
    _initNotificationPermission(),
    _initAudioServiceSafely(),
  ]);

  final audioHandler = results[2] as MegitAudioHandler;

  // Immersive dark status bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Inject the initialized audio handler so providers can access it.
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const MegitApp(),
    ),
  );
}

Future<FirebaseApp?> _initFirebase() async {
  try {
    return await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 15));
  } catch (e) {
    debugPrint('[Megit] Firebase initialization failed: $e');
    return null;
  }
}

Future<PermissionStatus> _initNotificationPermission() async {
  try {
    return await Permission.notification.request().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('[Megit] Notification permission failed: $e');
    return PermissionStatus.denied;
  }
}

Future<MegitAudioHandler> _initAudioServiceSafely() async {
  try {
    return await initAudioService().timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint('[Megit] AudioService init failed: $e');
    return MegitAudioHandler(AudioPlayer());
  }
}

class MegitApp extends ConsumerStatefulWidget {
  const MegitApp({super.key});

  @override
  ConsumerState<MegitApp> createState() => _MegitAppState();
}

class _MegitAppState extends ConsumerState<MegitApp> {
  bool _audioInitialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize the audio engine with the audio handler singleton.
    // Using addPostFrameCallback to ensure ProviderScope is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_audioInitialized) {
        final handler = ref.read(audioHandlerProvider);
        ref.read(audioProvider.notifier).initialize(handler);
        _audioInitialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state — gates the UI until auth resolves
    final auth = ref.watch(authProvider);

    // Watch accent color from settings
    final settings = ref.watch(settingsProvider);
    final accentColor = settings.accentColor;

    // Trigger initial settings load from disk on auth
    ref.listen(authProvider, (_, __) {
      // Nothing needed here — settings load from disk automatically on startup.
    });

    // Show loading while Firebase auth resolves
    if (auth.loading) {
      return MaterialApp(
        key: const ValueKey('loading-app'),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(accentColor: accentColor),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'Megit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(accentColor: accentColor),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

