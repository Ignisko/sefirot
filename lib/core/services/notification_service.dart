import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Initialize Firebase Messaging and request permissions for iOS/Web.
  Future<void> initialize() async {
    try {
      // 1. Request permissions for iOS and Web
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[NotificationService] User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[NotificationService] User granted provisional permission');
      } else {
        debugPrint('[NotificationService] User declined or has not accepted permission');
      }

      // 2. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Foreground message received: ${message.notification?.title}');
        // Note: You can use flutter_local_notifications here to show a heads-up notification.
      });

      // 3. Get the token (optional, but useful for targeting specific users)
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('[NotificationService] FCM Token: $token');
        // Note: In a real app, you would save this token to the user's Firestore document.
      }
    } catch (e) {
      debugPrint('[NotificationService] Error initializing: $e');
    }
  }
}
