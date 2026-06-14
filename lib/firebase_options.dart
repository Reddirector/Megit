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
    apiKey: 'AIzaSyCm2oL-yNcvlOJhfpPEgYZE2o5rxncc4kk',
    appId: '1:290283449789:android:81cb075a5de663ec2db6d4',
    messagingSenderId: '290283449789',
    projectId: 'megit-2e583',
    storageBucket: 'megit-2e583.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBCiNPoLQCPY7KoG1vMd6R6v7xJklYuazA',
    appId: '1:290283449789:ios:e180fe0c89400f722db6d4',
    messagingSenderId: '290283449789',
    projectId: 'megit-2e583',
    storageBucket: 'megit-2e583.firebasestorage.app',
    iosBundleId: 'com.aditya.megit',
  );
}
