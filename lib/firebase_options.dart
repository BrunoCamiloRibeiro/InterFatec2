import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCzLEzx6_MAtebRQ-Vv0j27y26NCX2scL0',
    authDomain: 'trans-saude.firebaseapp.com',
    projectId: 'trans-saude',
    storageBucket: 'trans-saude.firebasestorage.app',
    messagingSenderId: '221136277930',
    appId: '1:221136277930:web:c5676a4ccee86a763c5bd3',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzLEzx6_MAtebRQ-Vv0j27y26NCX2scL0',
    projectId: 'trans-saude',
    storageBucket: 'trans-saude.firebasestorage.app',
    appId: '1:221136277930:web:c5676a4ccee86a763c5bd3',
    messagingSenderId: '221136277930',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCzLEzx6_MAtebRQ-Vv0j27y26NCX2scL0',
    authDomain: 'trans-saude.firebaseapp.com',
    projectId: 'trans-saude',
    storageBucket: 'trans-saude.firebasestorage.app',
    appId: '1:221136277930:web:c5676a4ccee86a763c5bd3',
    messagingSenderId: '221136277930',
  );
}
