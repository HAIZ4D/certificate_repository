import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'logger_service.dart';
import '../models/notification_model.dart';
import '../config/app_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  LoggerService.debug('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;

  Future<void> initialize() async {
    try {
      if (kIsWeb) {
        LoggerService.debug('Initializing notifications for web platform');
        await _initializeWeb();
      } else {
        LoggerService.debug('Initializing notifications for mobile platform');
        await _initializeMobile();
      }

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await _initializeLocalNotifications();
      await _setupMessageHandlers();
      await _requestPermissions();
      
      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        LoggerService.info('FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
      }

      _tokenRefreshSubscription = _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        LoggerService.info('FCM Token refreshed');
      });

      LoggerService.info('NotificationService initialized successfully');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to initialize NotificationService', 
                         error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _initializeWeb() async {
    // Web Push Notification Configuration
    // Note: In production, replace with your actual VAPID key from Firebase Console
    // Get VAPID key: https://console.firebase.google.com/project/your-project/settings/cloudmessaging
    const vapidKey = String.fromEnvironment('VAPID_KEY', 
      defaultValue: 'DEFAULT_VAPID_KEY_FOR_DEVELOPMENT_ONLY');
    
    try {
      if (vapidKey != 'DEFAULT_VAPID_KEY_FOR_DEVELOPMENT_ONLY' && vapidKey.isNotEmpty) {
        _fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
        LoggerService.info('Web FCM token obtained with VAPID key');
      } else {
        // Development mode - use default token generation
        _fcmToken = await _firebaseMessaging.getToken();
        LoggerService.info('Web FCM token obtained without VAPID key (development mode)');
      }
      
      if (_fcmToken != null) {
        LoggerService.info('Web FCM token: ${_fcmToken!.substring(0, 20)}...');
        await _saveFCMTokenToUser();
      }
    } catch (e) {
      LoggerService.error('Failed to get web FCM token', error: e);
      // Fallback to basic token generation
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        LoggerService.info('Fallback web FCM token obtained');
      } catch (fallbackError) {
        LoggerService.error('Fallback web FCM token generation failed', error: fallbackError);
      }
    }
  }

  Future<void> _initializeMobile() async {
    _fcmToken = await _firebaseMessaging.getToken();
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    LoggerService.debug('Received foreground message: ${message.messageId}');
    
    if (message.notification != null && !kIsWeb) {
      _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        data: message.data,
      );
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    LoggerService.debug('Message opened app: ${message.messageId}');
  }

  void _onNotificationTapped(NotificationResponse response) {
    LoggerService.debug('Notification tapped: ${response.payload}');
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      LoggerService.debug('Web notification permission: ${settings.authorizationStatus}');
      return;
    }

    final notificationStatus = await Permission.notification.request();
    LoggerService.debug('Notification permission status: $notificationStatus');

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    LoggerService.debug('FCM permission status: ${settings.authorizationStatus}');
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int id = 0,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Default notification channel',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: data?.toString(),
    );
  }

  Future<void> sendCertificateIssuedNotification({
    required String recipientEmail,
    required String certificateTitle,
    required String issuerName,
    required String verificationCode,
  }) async {
    try {
      const title = 'New Certificate Issued';
      final body = 'You have received a new certificate: $certificateTitle from $issuerName';
      
      // Find recipient user ID by email
      final userQuery = await FirebaseFirestore.instance
          .collection(AppConfig.usersCollection)
          .where('email', isEqualTo: recipientEmail)
          .limit(1)
          .get();
      
      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;
        
        // Create notification in Firestore
        await createNotification(
          userId: userId,
          title: title,
          message: body,
          type: 'certificate_issued',
          data: {
            'certificateTitle': certificateTitle,
            'issuerName': issuerName,
            'verificationCode': verificationCode,
          },
        );
      }
      
      await _showLocalNotification(
        title: title,
        body: body,
        data: {
          'type': 'certificate_issued',
          'recipientEmail': recipientEmail,
          'certificateTitle': certificateTitle,
          'issuerName': issuerName,
          'verificationCode': verificationCode,
        },
      );

      LoggerService.info('Certificate notification sent to $recipientEmail');
    } catch (e) {
      LoggerService.error('Failed to send certificate notification', error: e);
    }
  }

  Future<void> sendDocumentStatusNotification({
    required String userId,
    required String documentName,
    required String status,
    String? reviewComments,
  }) async {
    try {
      const title = 'Document Status Update';
      final body = 'Your document "$documentName" has been $status';
      
      // Create notification in Firestore
      await createNotification(
        userId: userId,
        title: title,
        message: body,
        type: 'document_status',
        data: {
          'documentName': documentName,
          'status': status,
          'reviewComments': reviewComments,
        },
      );
      
      await _showLocalNotification(
        title: title,
        body: body,
        data: {
          'type': 'document_status',
          'userId': userId,
          'documentName': documentName,
          'status': status,
          'reviewComments': reviewComments,
        },
      );

      LoggerService.info('Document status notification sent to $userId');
    } catch (e) {
      LoggerService.error('Failed to send document status notification', error: e);
    }
  }

  Future<void> sendSystemNotification({
    required String title,
    required String message,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _showLocalNotification(
        title: title,
        body: message,
        data: {
          'type': 'system',
          'userId': userId,
          ...?additionalData,
        },
      );

      LoggerService.info('System notification sent: $title');
    } catch (e) {
      LoggerService.error('Failed to send system notification', error: e);
    }
  }

  String? get fcmToken => _fcmToken;

  // Get user notifications stream from Firestore with enhanced error handling
  Stream<List<NotificationModel>> getUserNotifications(String userId) {
    try {
      // Check if user is authenticated
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        LoggerService.warning('❌ User not authenticated or user ID mismatch for notifications');
        return Stream.value([]);
      }

      LoggerService.info('📱 Loading notifications for user: $userId');

      return FirebaseFirestore.instance
          .collection(AppConfig.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .handleError((error) {
            LoggerService.error('❌ Failed to load notifications stream', error: error);
            return <QuerySnapshot<Map<String, dynamic>>>[];
          })
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => NotificationModel.fromFirestore(doc))
                  .toList();
            } catch (e) {
              LoggerService.error('❌ Failed to parse notification documents', error: e);
              return <NotificationModel>[];
            }
          });
    } catch (e) {
      LoggerService.error('❌ Failed to create user notifications stream', error: e);
      return Stream.value([]);
    }
  }

  // Mark notification as read with enhanced error handling
  Future<void> markAsRead(String notificationId) async {
    try {
      // Check authentication
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        LoggerService.warning('❌ User not authenticated, cannot mark notification as read');
        return;
      }

      LoggerService.info('📖 Marking notification as read: $notificationId');

      await FirebaseFirestore.instance
          .collection(AppConfig.notificationsCollection)
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('✅ Notification marked as read successfully');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('⚠️ Permission denied when marking notification as read. This is expected for some users.');
      } else {
        LoggerService.error('❌ Failed to mark notification as read', error: e);
      }
    }
  }

  // Create notification with enhanced error handling and authentication checks
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Check if current user has permission to create notifications
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        LoggerService.warning('❌ User not authenticated, cannot create notification');
        return;
      }

      LoggerService.info('📝 Creating notification for user: $userId');

      // Validate input parameters
      if (userId.isEmpty || title.isEmpty || message.isEmpty) {
        LoggerService.warning('⚠️ Invalid notification parameters provided');
        return;
      }

      await FirebaseFirestore.instance
          .collection(AppConfig.notificationsCollection)
          .add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser.uid,
      });
      
      LoggerService.info('✅ Notification created successfully in Firestore');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('⚠️ Permission denied when creating notification. Using local notification instead.');
        // Fallback to local notification only
        await _showLocalNotification(
          title: title,
          body: message,
          data: {
            'type': type,
            'userId': userId,
            ...?data,
          },
        );
      } else {
        LoggerService.error('❌ Failed to create notification in Firestore', error: e);
      }
    }
  }

  // Send CA approval notification with enhanced error handling
  Future<void> sendCAApprovalNotification({
    required String userId,
    required String status,
    String? comments,
  }) async {
    try {
      final title = status == 'approved' ? 'CA Application Approved' : 'CA Application Rejected';
      final body = status == 'approved' 
          ? 'Your Certificate Authority application has been approved!'
          : 'Your Certificate Authority application has been rejected.';
      
      LoggerService.info('📬 Sending CA approval notification to user: $userId');

      // Try to create notification in Firestore
      await createNotification(
        userId: userId,
        title: title,
        message: body,
        type: 'ca_approval',
        data: {
          'status': status,
          'comments': comments,
        },
      );
      
      // Always show local notification as backup
      await _showLocalNotification(
        title: title,
        body: body,
        data: {
          'type': 'ca_approval',
          'userId': userId,
          'status': status,
          'comments': comments,
        },
      );

      LoggerService.info('✅ CA approval notification sent successfully');
    } catch (e) {
      LoggerService.error('❌ Failed to send CA approval notification', error: e);
    }
  }

  // Send account status notification with enhanced error handling
  Future<void> sendAccountStatusNotification({
    required String userId,
    required String status,
    String? reason,
  }) async {
    try {
      const title = 'Account Status Update';
      final body = 'Your account status has been updated to: $status';
      
      LoggerService.info('📬 Sending account status notification to user: $userId');

      // Try to create notification in Firestore (may fail due to permissions)
      try {
        await createNotification(
          userId: userId,
          title: title,
          message: body,
          type: 'account_status',
          data: {
            'status': status,
            'reason': reason,
          },
        );
      } catch (e) {
        LoggerService.warning('⚠️ Could not save account status notification to Firestore', error: e);
      }

      // Always show local notification
      await _showLocalNotification(
        title: title,
        body: body,
        data: {
          'type': 'account_status',
          'userId': userId,
          'status': status,
          'reason': reason,
        },
      );

      LoggerService.info('✅ Account status notification sent successfully');
    } catch (e) {
      LoggerService.error('❌ Failed to send account status notification', error: e);
    }
  }

  // Save FCM token with enhanced error handling
  Future<void> _saveFCMTokenToUser() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        LoggerService.warning('❌ No authenticated user, cannot save FCM token');
        return;
      }

      if (_fcmToken == null) {
        LoggerService.warning('❌ No FCM token available to save');
        return;
      }

      LoggerService.info('💾 Saving FCM token for user: ${currentUser.uid}');

      await FirebaseFirestore.instance
          .collection(AppConfig.usersCollection)
          .doc(currentUser.uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      
      LoggerService.info('✅ FCM token saved successfully');
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('⚠️ Permission denied when saving FCM token. User document may not exist yet.');
      } else if (e.toString().contains('not-found')) {
        LoggerService.warning('⚠️ User document not found when saving FCM token. Will be created later.');
      } else {
        LoggerService.error('❌ Failed to save FCM token', error: e);
      }
    }
  }

  // Enhanced method to get notification count for a user
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        LoggerService.warning('❌ User not authenticated for notification count');
        return 0;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection(AppConfig.notificationsCollection)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('⚠️ Permission denied when getting notification count');
      } else {
        LoggerService.error('❌ Failed to get unread notification count', error: e);
      }
      return 0;
    }
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _messageSubscription?.cancel();
    LoggerService.debug('NotificationService disposed');
  }
} 
