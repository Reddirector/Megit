import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUDMSkKB-_hL9bl45P5BxVEVXDrS7C4_8',
    appId: '1:360258546308:android:5d34ef95c27d79e80af0d1',
    messagingSenderId: '360258546308',
    projectId: 'megit-by-ap',
    storageBucket: 'megit-by-ap.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUDMSkKB-_hL9bl45P5BxVEVXDrS7C4_8',
    appId: '1:360258546308:ios:5d34ef95c27d79e80af0d1', // Placeholder based on Android, might need correction if iOS is used
    messagingSenderId: '360258546308',
    projectId: 'megit-by-ap',
    storageBucket: 'megit-by-ap.firebasestorage.app',
    iosBundleId: 'com.aditya.megit',
  );
}
