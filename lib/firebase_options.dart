// GENERATED-LIKE FILE (manually written). Replace the values with your Firebase project config.
// To generate this file automatically, run: flutterfire configure
// This placeholder keeps the code compile-ready across mobile and web.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDg7QFpJ-O9YSp7w_4sN6uOlAZ89WYV8EA',
    appId: '1:458713583940:web:eb2a02ce9949dd4903c711',
    messagingSenderId: '458713583940',
    projectId: 'grammatica-68829',
    authDomain: 'grammatica-68829.firebaseapp.com',
    databaseURL: 'https://grammatica-68829-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'grammatica-68829.firebasestorage.app',
  );

  // TODO: Replace all below configs with your Firebase project settings.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD_wcr5QUTJz8Wy0p7nf348Jr6znxkhzMs',
    appId: '1:458713583940:android:a97bae985c314d3e03c711',
    messagingSenderId: '458713583940',
    projectId: 'grammatica-68829',
    databaseURL: 'https://grammatica-68829-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'grammatica-68829.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.grammatica',
  );

  static const FirebaseOptions macos = ios;
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_WIN_API_KEY',
    appId: 'YOUR_WIN_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.firebaseio.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
  static const FirebaseOptions linux = windows;
}