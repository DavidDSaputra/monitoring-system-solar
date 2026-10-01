import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/push_firebase_config.dart';

enum PushNotificationAvailability {
  unavailable,
  disabled,
  requesting,
  enabled,
  denied,
  error,
}

class PushNotificationState {
  final PushNotificationAvailability availability;
  final String message;

  const PushNotificationState(this.availability, this.message);

  bool get isEnabled => availability == PushNotificationAvailability.enabled;
  bool get isBusy => availability == PushNotificationAvailability.requesting;
  bool get canToggle =>
      availability != PushNotificationAvailability.unavailable;
}

class PushNavigationRequest {
  final String type;
  final String source;
  final String plantCode;
  final String plantName;
  final String event;
  final String status;
  final String tab;

  const PushNavigationRequest({
    required this.type,
    required this.source,
    required this.plantCode,
    required this.plantName,
    required this.event,
    required this.status,
    required this.tab,
  });

  bool get showAlarm => tab == 'alarm' || event == 'issue';

  static PushNavigationRequest? fromData(Map<dynamic, dynamic> data) {
    String value(String key) => data[key]?.toString().trim() ?? '';

    final type = value('type').toLowerCase();
    final source = value('source').toLowerCase();
    final plantCode = value('plantCode');
    if (!{'plant_status', 'device_status', 'alarm'}.contains(type) ||
        !{'solis', 'huawei', 'growatt'}.contains(source) ||
        plantCode.isEmpty) {
      return null;
    }

    return PushNavigationRequest(
      type: type,
      source: source,
      plantCode: plantCode,
      plantName: value('plantName').isEmpty
          ? 'Plant SolarView'
          : value('plantName'),
      event: value('event').toLowerCase(),
      status: value('status').toLowerCase(),
      tab: value('tab').toLowerCase(),
    );
  }
}

typedef PushNavigationHandler = bool Function(PushNavigationRequest request);

@pragma('vm:entry-point')
Future<void> solarViewFirebaseBackgroundHandler(RemoteMessage message) async {
  final options = PushFirebaseConfig.currentPlatform;
  if (options == null) return;
  await Firebase.initializeApp(options: options);
}

class PushNotificationService {
  PushNotificationService._();

  static const _enabledStorageKey = 'solarview.push.enabled';
  static const _channelId = 'solar_alerts_quiet';
  static const _channelName = 'SolarView alerts';
  static const _channelDescription =
      'Peringatan plant, inverter, datalogger, dan gangguan produksi.';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final ValueNotifier<PushNotificationState> status = ValueNotifier(
    PushNotificationState(
      PushFirebaseConfig.isConfigured
          ? PushNotificationAvailability.disabled
          : PushNotificationAvailability.unavailable,
      PushFirebaseConfig.isConfigured
          ? 'Belum diaktifkan'
          : 'Firebase belum dikonfigurasi',
    ),
  );

  static bool _initialized = false;
  static PushNavigationHandler? _navigationHandler;
  static PushNavigationRequest? _pendingNavigationRequest;
  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _messageSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;

  static Future<void> initialize() async {
    if (_initialized) return;
    final options = PushFirebaseConfig.currentPlatform;
    if (options == null) {
      status.value = const PushNotificationState(
        PushNotificationAvailability.unavailable,
        'Firebase belum dikonfigurasi',
      );
      return;
    }

    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(solarViewFirebaseBackgroundHandler);
      await _initializeLocalNotifications();
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: defaultTargetPlatform == TargetPlatform.iOS,
            badge: true,
            sound: false,
          );

      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) => FirebaseMessaging.instance.subscribeToTopic(
          PushFirebaseConfig.topic,
        ),
      );
      _initialized = true;

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _queueNavigation(initialMessage.data);
      }

      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchPayload != null) {
        _queueEncodedNavigation(launchPayload);
      }

      final enabled = await _storage.read(key: _enabledStorageKey) == 'true';
      if (enabled) {
        await _activate(requestPermission: false);
      } else {
        status.value = const PushNotificationState(
          PushNotificationAvailability.disabled,
          'Belum diaktifkan',
        );
      }
    } catch (error) {
      debugPrint('Push notification initialization failed: $error');
      status.value = PushNotificationState(
        PushNotificationAvailability.error,
        'Inisialisasi gagal. Silakan coba lagi.',
      );
    }
  }

  static Future<bool> enable() async {
    if (!_initialized) await initialize();
    if (!_initialized) return false;
    return _activate(requestPermission: true);
  }

  static Future<bool> _activate({required bool requestPermission}) async {
    status.value = const PushNotificationState(
      PushNotificationAvailability.requesting,
      'Meminta izin notifikasi...',
    );

    try {
      NotificationSettings settings;
      if (requestPermission) {
        settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      } else {
        settings = await FirebaseMessaging.instance.getNotificationSettings();
      }

      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        await _storage.write(key: _enabledStorageKey, value: 'false');
        status.value = const PushNotificationState(
          PushNotificationAvailability.denied,
          'Izin notifikasi ditolak',
        );
        return false;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        throw StateError('Token FCM tidak tersedia');
      }
      await FirebaseMessaging.instance.subscribeToTopic(
        PushFirebaseConfig.topic,
      );
      await _storage.write(key: _enabledStorageKey, value: 'true');
      status.value = const PushNotificationState(
        PushNotificationAvailability.enabled,
        'Aktif untuk alarm plant dan perangkat',
      );
      return true;
    } catch (error) {
      debugPrint('Push notification activation failed: $error');
      status.value = PushNotificationState(
        PushNotificationAvailability.error,
        'Aktivasi gagal. Periksa koneksi lalu coba lagi.',
      );
      return false;
    }
  }

  static Future<void> disable() async {
    if (_initialized) {
      try {
        await FirebaseMessaging.instance.unsubscribeFromTopic(
          PushFirebaseConfig.topic,
        );
      } catch (_) {
        // Preference must still be disabled if Firebase is temporarily offline.
      }
    }
    await _storage.write(key: _enabledStorageKey, value: 'false');
    status.value = const PushNotificationState(
      PushNotificationAvailability.disabled,
      'Dinonaktifkan',
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_solarview'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _queueEncodedNavigation(payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final source = message.data['source']?.toString() ?? 'solarview';
    final plantCode = message.data['plantCode']?.toString() ?? 'alerts';
    final notificationId = '$source:$plantCode'.hashCode & 0x7fffffff;
    await _localNotifications.show(
      id: notificationId,
      title: title ?? 'SolarView',
      body: body,
      payload: jsonEncode(message.data),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_stat_solarview',
          groupKey: 'solarview_alerts',
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  static void registerNavigationHandler(PushNavigationHandler handler) {
    _navigationHandler = handler;
    resumePendingNavigation();
  }

  static void resumePendingNavigation() {
    final request = _pendingNavigationRequest;
    final handler = _navigationHandler;
    if (request == null || handler == null) return;
    if (handler(request)) {
      _pendingNavigationRequest = null;
    }
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    _queueNavigation(message.data);
  }

  static void _queueEncodedNavigation(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) _queueNavigation(decoded);
    } catch (_) {
      // Ignore notification payloads that are not SolarView navigation data.
    }
  }

  static void _queueNavigation(Map<dynamic, dynamic> data) {
    final request = PushNavigationRequest.fromData(data);
    if (request == null) return;
    _pendingNavigationRequest = request;
    resumePendingNavigation();
  }

  static Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
