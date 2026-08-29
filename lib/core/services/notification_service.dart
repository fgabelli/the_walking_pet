import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_router.dart';

class NotificationService with WidgetsBindingObserver {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// One-time token migration after account transfer.
  /// Deletes old FCM token and forces a fresh registration.
  static const _tokenMigrationKey = 'fcm_token_migrated_v2';

  Future<void> _migrateTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tokenMigrationKey) == true) return;

    print('[FCM] Running one-time token migration...');
    try {
      // 1. Delete old FCM token from Firebase servers
      await _firebaseMessaging.deleteToken();
      print('[FCM] Old token deleted');

      // 2. Clear tokens in Firestore
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmTokens': [],
          'tokenStatus': 'migrating',
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Small delay to let Firebase process the deletion
      await Future.delayed(const Duration(seconds: 2));

      // 4. Mark migration as done
      await prefs.setBool(_tokenMigrationKey, true);
      print('[FCM] Token migration complete — will get fresh token now');
    } catch (e) {
      print('[FCM] Token migration error: $e');
      // Mark as done anyway to avoid infinite loops
      await prefs.setBool(_tokenMigrationKey, true);
    }
  }

  Future<void> initialize() async {
    // Inizializza fusi orari per le notifiche programmate (es. reminder passeggiate)
    tz.initializeTimeZones();
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    // Register observer to handle lifecycle changes (resuming resets app icon badge)
    WidgetsBinding.instance.addObserver(this);

    // 1. Initialize Local Notifications immediately so it's ready for early calls like resetBadge()
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(payload);
            final type = data['type'] ?? 'generic';
            NotificationRouter.navigate(type, data);
          } catch (e) {
            print("Error parsing local notification payload: $e");
          }
        }
      },
    );

    // 0. Reset iOS badge count on app launch
    if (Platform.isIOS) {
      await _firebaseMessaging.setAutoInitEnabled(true);
      // Clear badge when app opens
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(badge: true);
    }
    // Reset badge count to 0 and clear all local notifications
    await _localNotifications.cancelAll();
    // Reset the iOS app icon badge to 0
    await resetBadge();
    if (Platform.isIOS) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: false, // Don't increment badge in foreground
        sound: true,
      );
    }

     // Create High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id from Manifest
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', 
      importance: Importance.max,
    );

    const AndroidNotificationChannel vaccinationChannel = AndroidNotificationChannel(
      'vaccination_channel',
      'Promemoria Vaccinazioni',
      description: 'Notifiche per richiami e scadenze vaccinali',
      importance: Importance.high,
    );
    
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.createNotificationChannel(vaccinationChannel);

    // 2. Request Permission (Firebase)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // 3. Migrate token if needed (one-time after account transfer)
      await _migrateTokenIfNeeded();

      // 3.1 Get and Save Token
      await updateToken();

      // [CRITICAL FIX] 3.5 Listen for Auth Changes to save token when user logs in
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          print('User logged in, updating FCM token...');
          updateToken();
        }
      });

      // 4. Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((token) {
        _saveTokenToDatabase(token);
      });

      // 5. Foreground Message Handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // If notification exists, show it locally (foreground)
        if (notification != null) {
          _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: android?.smallIcon,
                  importance: Importance.max,
                  priority: Priority.high,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              payload: jsonEncode({
                ...message.data,
                'title': notification.title,
                'body': notification.body,
              }),
          );
        }
      });

      // 5.5 Gestione click su notifica push quando l'app è in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print("Push notification clicked: ${message.data}");
        final type = message.data['type'] ?? 'generic';
        NotificationRouter.navigate(type, message.data);
      });

      // Gestione click su notifica push che avvia l'app da spenta
      _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          print("App launched from terminated state via push: ${message.data}");
          final type = message.data['type'] ?? 'generic';
          Future.delayed(const Duration(milliseconds: 1000), () {
            NotificationRouter.navigate(type, message.data);
          });
        }
      });
      
      // 6. iOS Foreground Presentation Options
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: false, // Don't increment badge in foreground
        sound: true,
      );

      // 7. Schedule Daily Walk Reminders
      await _scheduleWalkReminders();
    } else {
      print('User declined or has not accepted permission');
    }
  }

  Future<void> _scheduleWalkReminders() async {
    // Cancella prima i vecchi reminder (ID 1001 e 1002) per evitare duplicati
    await _localNotifications.cancel(1001);
    await _localNotifications.cancel(1002);

    final now = tz.TZDateTime.now(tz.local);
    
    // Mattina: 08:30
    var scheduledMorning = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30);
    if (scheduledMorning.isBefore(now)) {
      scheduledMorning = scheduledMorning.add(const Duration(days: 1));
    }
    
    // Sera: 18:30
    var scheduledEvening = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 30);
    if (scheduledEvening.isBefore(now)) {
      scheduledEvening = scheduledEvening.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel',
        'Promemoria Passeggiate',
        channelDescription: 'Notifiche per ricordarti di portare fuori il pet',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _localNotifications.zonedSchedule(
        1001,
        '🐾 Ora della passeggiata!',
        'Traccia il percorso su DOGZN: creeremo un piano di salute su misura per età, taglia e peso del tuo pet!',
        scheduledMorning,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      await _localNotifications.zonedSchedule(
        1002,
        '🐾 Passeggiata serale!',
        'Esci con il tuo pet e usa il tracking! Raggiungi i suoi obiettivi di salute in base a peso ed età.',
        scheduledEvening,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      print('Errore nella programmazione dei promemoria passeggiata: $e');
    }
  }

  Future<void> scheduleVaccinationReminder({
    required String healthRecordId,
    required String petName,
    required String vaccineName,
    required DateTime nextDueDate,
  }) async {
    final baseId = healthRecordId.hashCode.abs();
    final reminderId = baseId % 100000000;
    final dueId = (baseId + 1) % 100000000;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'vaccination_channel',
        'Promemoria Vaccinazioni',
        channelDescription: 'Notifiche per richiami e scadenze vaccinali',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      // 7 days before
      final reminderDate = nextDueDate.subtract(const Duration(days: 7));
      if (reminderDate.isAfter(DateTime.now())) {
        final tzReminderDate = tz.TZDateTime.from(reminderDate, tz.local);
        await _localNotifications.zonedSchedule(
          reminderId,
          '💉 Richiamo in arrivo',
          'Richiamo $vaccineName per $petName tra 7 giorni',
          tzReminderDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      // On due date
      if (nextDueDate.isAfter(DateTime.now())) {
        final tzDueDate = tz.TZDateTime.from(nextDueDate, tz.local);
        await _localNotifications.zonedSchedule(
          dueId,
          '💉 Richiamo vaccinale oggi!',
          'Oggi scade il richiamo $vaccineName per $petName!',
          tzDueDate,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      print('Errore nella programmazione del promemoria vaccinale: $e');
    }
  }

  Future<void> cancelVaccinationReminder(String healthRecordId) async {
    final baseId = healthRecordId.hashCode.abs();
    final reminderId = baseId % 100000000;
    final dueId = (baseId + 1) % 100000000;
    await _localNotifications.cancel(reminderId);
    await _localNotifications.cancel(dueId);
  }

  Future<void> updateToken() async {
    final userId = _auth.currentUser?.uid;
    try {
      // [FIX] iOS: ensure APNs token is available before requesting FCM token.
      // Without this, getToken() returns null on iOS cold start/reinstall.
      if (Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          // APNs registration may not be ready yet — retry after delay
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }
        if (apnsToken == null) {
          // Last attempt with longer delay
          await Future.delayed(const Duration(seconds: 5));
          apnsToken = await _firebaseMessaging.getAPNSToken();
        }
        if (apnsToken == null) {
          print('[FCM] APNs token still null after retries — cannot get FCM token');
          if (userId != null) {
            await _firestore.collection('users').doc(userId).set({
              'tokenStatus': 'apns_unavailable',
              'tokenUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          return;
        }
        print('[FCM] APNs token obtained successfully');
      }

      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
        if (userId != null) {
          // Save token with platform diagnostics
          final diagnostics = <String, dynamic>{
            'tokenStatus': 'success',
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
            'tokenPlatform': Platform.isIOS ? 'ios' : 'android',
          };
          // Save APNs token for iOS debugging
          if (Platform.isIOS) {
            final apns = await _firebaseMessaging.getAPNSToken();
            if (apns != null) {
              diagnostics['apnsTokenPrefix'] = apns.substring(0, apns.length > 20 ? 20 : apns.length);
              diagnostics['apnsTokenLength'] = apns.length;
            }
          }
          await _firestore.collection('users').doc(userId).set(
            diagnostics, SetOptions(merge: true));
        }
      } else {
        print('[FCM] getToken() returned null');
        if (userId != null) {
          await _firestore.collection('users').doc(userId).set({
            'tokenStatus': 'null_token',
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('[FCM] Error getting FCM token: $e');
      if (userId != null) {
        try {
          await _firestore.collection('users').doc(userId).set({
            'tokenStatus': 'error: ${e.toString()}',
            'tokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
    }
  }

  Future<void> _saveTokenToDatabase(String token) async {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // [FIX] Use set(merge:true) instead of update() so it works even
      // for newly registered users whose Firestore document doesn't exist yet.
      await _firestore.collection('users').doc(userId).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      print('[FCM] Error saving FCM token: $e');
    }
  }
  
  // Clean up token on logout
  Future<void> deleteToken() async {
     try {
       String? token = await _firebaseMessaging.getToken();
       String? userId = _auth.currentUser?.uid;
       if (userId != null && token != null) {
         await _firestore.collection('users').doc(userId).update({
           'fcmTokens': FieldValue.arrayRemove([token]),
         });
       }
     } catch (_) {}
  }

  /// Resets the iOS app icon badge count to 0.
  /// Call this when the app opens, when notifications are viewed,
  /// or when all notifications are marked as read.
  Future<void> resetBadge() async {
    if (Platform.isIOS) {
      // Show a silent notification with badgeNumber: 0 to reset the iOS badge
      await _localNotifications.show(
        999999,
        null,
        null,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            badgeNumber: 0,
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
          ),
        ),
      );
      await _localNotifications.cancel(999999);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[FCM] App resumed, resetting badge...');
      resetBadge();
    }
  }

  /// Sends a "Radar Ping" (Abbaio) to invisible users
  /// Since we cannot send FCM directly from client securely, we write a temporary
  /// 'radar_pings' document that a Cloud Function should listen to and fan-out.
  Future<void> sendRadarPing({
    required List<String> targetIds, 
    required String senderName,
    required String petSummary, // e.g., "Jack Russell"
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) return;

    try {
       await _firestore.collection('radar_pings').add({
         'senderId': senderId,
         'senderName': senderName,
         'petSummary': petSummary,
         'targetIds': targetIds,
         'timestamp': FieldValue.serverTimestamp(),
         // Status field for the backend to process
         'status': 'pending', 
       });
       print('Radar ping sent to ${targetIds.length} users');
    } catch (e) {
      print('Error sending radar ping: $e');
      rethrow;
    }
  }

  /// Shows a local notification for proximity alerts (danger zones, SOS)
  /// Triggered when the user physically enters the radius of an active alert.
  Future<void> showProximityAlert({
    required String title,
    required String body,
    String? alertId,
  }) async {
    await _localNotifications.show(
      alertId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'This channel is used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
