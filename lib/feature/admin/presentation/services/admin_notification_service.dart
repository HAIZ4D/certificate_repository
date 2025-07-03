import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/config/app_config.dart';

class AdminNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send custom notification to specific users
  Future<void> sendCustomNotification({
    required String adminId,
    required List<String> targetUserIds,
    required String title,
    required String message,
    String type = 'admin_custom',
    Map<String, dynamic>? data,
  }) async {
    try {
      // Validate admin permissions
      await _validateAdminPermissions(adminId);

      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();
      
      // Create notifications for each target user
      for (final userId in targetUserIds) {
        final notificationRef = _firestore
            .collection(AppConfig.notificationsCollection)
            .doc();
        
        batch.set(notificationRef, {
          'userId': userId,
          'title': title,
          'message': message,
          'type': type,
          'data': {
            'sentBy': adminId,
            'sentByRole': 'admin',
            ...?data,
          },
          'isRead': false,
          'createdAt': timestamp,
          'updatedAt': timestamp,
        });
      }

      await batch.commit();

      // Log the admin action
      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'custom_notification_sent',
        details: {
          'title': title,
          'targetCount': targetUserIds.length,
          'type': type,
        },
      );

      LoggerService.info('Custom notification sent to ${targetUserIds.length} users by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to send custom notification', error: e);
      rethrow;
    }
  }

  /// Send broadcast notification to all users or specific user type
  Future<void> sendBroadcastNotification({
    required String adminId,
    required String title,
    required String message,
    UserType? targetUserType,
    String type = 'broadcast',
    Map<String, dynamic>? data,
  }) async {
    try {
      // Validate admin permissions for broadcast
      await _validateAdminPermissions(adminId);

      // Get target users
      Query userQuery = _firestore.collection(AppConfig.usersCollection)
          .where('status', isEqualTo: UserStatus.active.name);

      if (targetUserType != null) {
        userQuery = userQuery.where('userType', isEqualTo: targetUserType.name);
      }

      final userSnapshot = await userQuery.get();
      final targetUserIds = userSnapshot.docs.map((doc) => doc.id).toList();

      if (targetUserIds.isEmpty) {
        throw Exception('No target users found for broadcast');
      }

      // Create notifications in batches (Firestore batch limit is 500)
      const batchSize = 400;
      final batches = <WriteBatch>[];
      
      for (int i = 0; i < targetUserIds.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < targetUserIds.length) 
            ? i + batchSize 
            : targetUserIds.length;
        
        for (int j = i; j < endIndex; j++) {
          final notificationRef = _firestore
              .collection(AppConfig.notificationsCollection)
              .doc();
          
          batch.set(notificationRef, {
            'userId': targetUserIds[j],
            'title': title,
            'message': message,
            'type': type,
            'data': {
              'sentBy': adminId,
              'sentByRole': 'admin',
              'isBroadcast': true,
              'targetUserType': targetUserType?.name,
              ...?data,
            },
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        batches.add(batch);
      }

      // Execute all batches
      for (final batch in batches) {
        await batch.commit();
      }

      // Log the broadcast action
      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'broadcast_notification_sent',
        details: {
          'title': title,
          'targetCount': targetUserIds.length,
          'targetUserType': targetUserType?.name ?? 'all',
          'type': type,
        },
      );

      LoggerService.info('Broadcast notification sent to ${targetUserIds.length} users by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to send broadcast notification', error: e);
      rethrow;
    }
  }

  /// Delete a notification (admin only)
  Future<void> deleteNotification(String notificationId, String adminId) async {
    try {
      // Validate admin permissions
      await _validateAdminPermissions(adminId);

      // Get notification details for logging
      final notificationDoc = await _firestore
          .collection(AppConfig.notificationsCollection)
          .doc(notificationId)
          .get();

      if (!notificationDoc.exists) {
        throw Exception('Notification not found');
      }

      final notificationData = notificationDoc.data()!;

      // Delete the notification
      await _firestore
          .collection(AppConfig.notificationsCollection)
          .doc(notificationId)
          .delete();

      // Log the deletion
      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'notification_deleted',
        details: {
          'notificationId': notificationId,
          'originalTitle': notificationData['title'],
          'originalRecipient': notificationData['userId'],
        },
      );

      LoggerService.info('Notification deleted by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to delete notification', error: e);
      rethrow;
    }
  }

  /// Get all system notifications for admin management
  Future<List<NotificationModel>> getAllSystemNotifications({
    String? type,
    bool? isRead,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConfig.notificationsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      LoggerService.error('Failed to get system notifications', error: e);
      return [];
    }
  }

  /// Get notification statistics
  Future<Map<String, dynamic>> getNotificationStatistics() async {
    try {
      // Get total notifications
      final totalSnapshot = await _firestore
          .collection(AppConfig.notificationsCollection)
          .count()
          .get();

      // Get unread notifications
      final unreadSnapshot = await _firestore
          .collection(AppConfig.notificationsCollection)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      // Get notifications by type
      final typeSnapshot = await _firestore
          .collection(AppConfig.notificationsCollection)
          .get();

      final typeDistribution = <String, int>{};
      for (final doc in typeSnapshot.docs) {
        final type = doc.data()['type'] as String? ?? 'unknown';
        typeDistribution[type] = (typeDistribution[type] ?? 0) + 1;
      }

      // Get recent activity (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentSnapshot = await _firestore
          .collection(AppConfig.notificationsCollection)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .count()
          .get();

      final totalCount = totalSnapshot.count ?? 0;
      final unreadCount = unreadSnapshot.count ?? 0;
      final readPercentage = totalCount > 0 
          ? ((totalCount - unreadCount) / totalCount * 100).round()
          : 0;

      return {
        'totalNotifications': totalCount,
        'unreadNotifications': unreadCount,
        'readPercentage': readPercentage,
        'typeDistribution': typeDistribution,
        'recentActivity': recentSnapshot.count ?? 0,
      };
    } catch (e) {
      LoggerService.error('Failed to get notification statistics', error: e);
      return {
        'totalNotifications': 0,
        'unreadNotifications': 0,
        'readPercentage': 0,
        'typeDistribution': <String, int>{},
        'recentActivity': 0,
      };
    }
  }

  /// Schedule notification with real processing
  Future<void> scheduleNotification({
    required String adminId,
    required List<String> targetUserIds,
    required String title,
    required String message,
    required DateTime scheduledTime,
    String type = 'scheduled',
    Map<String, dynamic>? data,
  }) async {
    try {
      // Validate admin permissions
      await _validateAdminPermissions(adminId);

      // Store scheduled notification for future processing
      final scheduledNotificationRef = await _firestore.collection('scheduled_notifications').add({
        'adminId': adminId,
        'targetUserIds': targetUserIds,
        'title': title,
        'message': message,
        'type': type,
        'data': data ?? {},
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Log the action
      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'schedule_notification',
        details: {
          'scheduledNotificationId': scheduledNotificationRef.id,
          'targetUserCount': targetUserIds.length,
          'scheduledTime': scheduledTime.toIso8601String(),
          'title': title,
        },
      );

      // If the scheduled time is within the next 5 minutes, set up immediate processing
      final timeDifference = scheduledTime.difference(DateTime.now());
      if (timeDifference.inMinutes <= 5 && timeDifference.inSeconds > 0) {
        Timer(timeDifference, () async {
          await _processScheduledNotification(scheduledNotificationRef.id);
        });
      }

      LoggerService.info('Notification scheduled for ${scheduledTime.toIso8601String()} by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to schedule notification', error: e);
      rethrow;
    }
  }

  /// Process scheduled notification
  Future<void> _processScheduledNotification(String scheduledNotificationId) async {
    try {
      final doc = await _firestore.collection('scheduled_notifications').doc(scheduledNotificationId).get();
      
      if (!doc.exists) {
        LoggerService.warning('Scheduled notification not found: $scheduledNotificationId');
        return;
      }

      final data = doc.data()!;
      final status = data['status'] as String;

      if (status != 'pending') {
        LoggerService.info('Scheduled notification already processed: $scheduledNotificationId');
        return;
      }

      // Send the notification
      await sendCustomNotification(
        adminId: data['adminId'] as String,
        targetUserIds: List<String>.from(data['targetUserIds']),
        title: data['title'] as String,
        message: data['message'] as String,
        type: data['type'] as String,
        data: Map<String, dynamic>.from(data['data'] ?? {}),
      );

      // Update status
      await _firestore.collection('scheduled_notifications').doc(scheduledNotificationId).update({
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Scheduled notification processed: $scheduledNotificationId');
    } catch (e) {
      LoggerService.error('Failed to process scheduled notification', error: e);
      
      // Update status to failed
      await _firestore.collection('scheduled_notifications').doc(scheduledNotificationId).update({
        'status': 'failed',
        'failedAt': FieldValue.serverTimestamp(),
        'error': e.toString(),
      });
    }
  }

  /// Get scheduled notifications
  Future<List<Map<String, dynamic>>> getScheduledNotifications({
    String? adminId,
    String? status,
  }) async {
    try {
      Query query = _firestore.collection('scheduled_notifications');
      
      if (adminId != null) {
        query = query.where('adminId', isEqualTo: adminId);
      }
      
      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.orderBy('scheduledTime', descending: true).get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to get scheduled notifications', error: e);
      return [];
    }
  }

  /// Cancel scheduled notification
  Future<void> cancelScheduledNotification({
    required String scheduledNotificationId,
    required String adminId,
  }) async {
    try {
      await _validateAdminPermissions(adminId);

      await _firestore.collection('scheduled_notifications').doc(scheduledNotificationId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': adminId,
      });

      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'cancel_scheduled_notification',
        details: {
          'scheduledNotificationId': scheduledNotificationId,
        },
      );

      LoggerService.info('Scheduled notification cancelled: $scheduledNotificationId by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to cancel scheduled notification', error: e);
      rethrow;
    }
  }

  /// Validate admin permissions
  Future<void> _validateAdminPermissions(String adminId) async {
    final userDoc = await _firestore
        .collection(AppConfig.usersCollection)
        .doc(adminId)
        .get();

    if (!userDoc.exists) {
      throw Exception('Admin user not found');
    }

    final userData = userDoc.data()!;
    final userType = userData['userType'] as String?;
    final status = userData['status'] as String?;

    if (userType != UserType.admin.name || status != UserStatus.active.name) {
      throw Exception('Insufficient permissions for notification management');
    }
  }

  /// Log admin notification actions
  Future<void> _logAdminNotificationAction({
    required String adminId,
    required String action,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('admin_notification_logs').add({
        'adminId': adminId,
        'action': action,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Could be populated from context
        'userAgent': null, // Could be populated from context
      });
    } catch (e) {
      LoggerService.warning('Failed to log admin notification action', error: e);
      // Don't throw - logging failure shouldn't stop the main operation
    }
  }

  /// Get notification templates with filtering and categories
  Future<List<Map<String, dynamic>>> getNotificationTemplates({
    String? category,
    bool? isActive,
    String? createdBy,
  }) async {
    try {
      Query query = _firestore.collection('notification_templates');

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (isActive != null) {
        query = query.where('isActive', isEqualTo: isActive);
      }

      if (createdBy != null) {
        query = query.where('createdBy', isEqualTo: createdBy);
      }

      final snapshot = await query.orderBy('name').get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data() as Map<String, dynamic>,
      }).toList();
    } catch (e) {
      LoggerService.error('Failed to get notification templates', error: e);
      return <Map<String, dynamic>>[];
    }
  }

  /// Get template categories
  Future<List<String>> getTemplateCategories() async {
    try {
      final snapshot = await _firestore
          .collection('notification_templates')
          .where('isActive', isEqualTo: true)
          .get();

      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      final sortedCategories = categories.toList()..sort();
      return sortedCategories;
    } catch (e) {
      LoggerService.error('Failed to get template categories', error: e);
      return [];
    }
  }

  /// Update notification template
  Future<void> updateNotificationTemplate({
    required String templateId,
    required String adminId,
    String? name,
    String? title,
    String? message,
    String? category,
    Map<String, dynamic>? variables,
    bool? isActive,
  }) async {
    try {
      await _validateAdminPermissions(adminId);

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminId,
      };

      if (name != null) updateData['name'] = name;
      if (title != null) updateData['title'] = title;
      if (message != null) updateData['message'] = message;
      if (category != null) updateData['category'] = category;
      if (variables != null) updateData['variables'] = variables;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore.collection('notification_templates').doc(templateId).update(updateData);

      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'update_template',
        details: {
          'templateId': templateId,
          'updates': updateData.keys.toList(),
        },
      );

      LoggerService.info('Notification template updated: $templateId by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to update notification template', error: e);
      rethrow;
    }
  }

  /// Delete notification template
  Future<void> deleteNotificationTemplate({
    required String templateId,
    required String adminId,
  }) async {
    try {
      await _validateAdminPermissions(adminId);

      // Soft delete - mark as inactive instead of actual deletion
      await _firestore.collection('notification_templates').doc(templateId).update({
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': adminId,
      });

      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'delete_template',
        details: {
          'templateId': templateId,
        },
      );

      LoggerService.info('Notification template deleted: $templateId by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to delete notification template', error: e);
      rethrow;
    }
  }

  /// Duplicate notification template
  Future<String> duplicateNotificationTemplate({
    required String templateId,
    required String adminId,
    String? newName,
  }) async {
    try {
      await _validateAdminPermissions(adminId);

      // Get original template
      final originalDoc = await _firestore.collection('notification_templates').doc(templateId).get();
      
      if (!originalDoc.exists) {
        throw Exception('Template not found');
      }

      final originalData = originalDoc.data()!;
      
      // Create duplicate
      final duplicateData = Map<String, dynamic>.from(originalData);
      duplicateData['name'] = newName ?? '${originalData['name']} (Copy)';
      duplicateData['createdBy'] = adminId;
      duplicateData['createdAt'] = FieldValue.serverTimestamp();
      duplicateData['updatedAt'] = FieldValue.serverTimestamp();
      duplicateData.remove('deletedAt');
      duplicateData.remove('deletedBy');
      duplicateData['isActive'] = true;

      final newTemplateRef = await _firestore.collection('notification_templates').add(duplicateData);

      await _logAdminNotificationAction(
        adminId: adminId,
        action: 'duplicate_template',
        details: {
          'originalTemplateId': templateId,
          'newTemplateId': newTemplateRef.id,
        },
      );

      LoggerService.info('Notification template duplicated: $templateId -> ${newTemplateRef.id} by admin: $adminId');
      return newTemplateRef.id;
    } catch (e) {
      LoggerService.error('Failed to duplicate notification template', error: e);
      rethrow;
    }
  }

  /// Create notification template
  Future<void> createNotificationTemplate({
    required String adminId,
    required String name,
    required String title,
    required String message,
    required String category,
    Map<String, dynamic>? variables,
  }) async {
    try {
      await _validateAdminPermissions(adminId);

      await _firestore.collection('notification_templates').add({
        'name': name,
        'title': title,
        'message': message,
        'category': category,
        'variables': variables ?? {},
        'createdBy': adminId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      LoggerService.info('Notification template created: $name by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to create notification template', error: e);
      rethrow;
    }
  }

  /// Send notification using template
  Future<void> sendNotificationFromTemplate({
    required String adminId,
    required String templateId,
    required List<String> targetUserIds,
    Map<String, String>? variableValues,
  }) async {
    try {
      // Get template
      final templateDoc = await _firestore
          .collection('notification_templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        throw Exception('Notification template not found');
      }

      final templateData = templateDoc.data()!;
      String title = templateData['title'] as String;
      String message = templateData['message'] as String;

      // Replace variables if provided
      if (variableValues != null) {
        for (final entry in variableValues.entries) {
          title = title.replaceAll('{{${entry.key}}}', entry.value);
          message = message.replaceAll('{{${entry.key}}}', entry.value);
        }
      }

      // Send notification
      await sendCustomNotification(
        adminId: adminId,
        targetUserIds: targetUserIds,
        title: title,
        message: message,
        type: 'template',
        data: {
          'templateId': templateId,
          'templateName': templateData['name'],
        },
      );

      LoggerService.info('Notification sent from template: $templateId by admin: $adminId');
    } catch (e) {
      LoggerService.error('Failed to send notification from template', error: e);
      rethrow;
    }
  }
} 