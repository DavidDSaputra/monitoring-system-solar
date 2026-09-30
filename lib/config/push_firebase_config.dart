import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class PushFirebaseConfig {
  const PushFirebaseConfig._();

  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'com.example.jarwinnMonitoring',
  );
  static const topic = String.fromEnvironment(
    'FIREBASE_PUSH_TOPIC',
    defaultValue: 'solarview-alerts',
  );

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;

    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.android => androidAppId,
      TargetPlatform.iOS => iosAppId,
      _ => '',
    };
    if (projectId.isEmpty ||
        apiKey.isEmpty ||
        messagingSenderId.isEmpty ||
        appId.isEmpty) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? iosBundleId
          : null,
    );
  }

  static bool get isConfigured => currentPlatform != null;
}
