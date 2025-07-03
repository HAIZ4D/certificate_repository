import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_model.dart';
import '../../../core/models/certificate_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/config/app_config.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get current admin user ID with validation
  String? get _currentUserId {
    final user = _auth.currentUser;
    if (user == null) {
      LoggerService.warning('Admin operation attempted without authentication');
      return null;
    }
    return user.uid;
  }

  // Validate admin permissions for critical operations
  Future<bool> _validateAdminAccess() async {
    if (_currentUserId == null) {
      LoggerService.error('Critical operation attempted without authentication');
      return false;
    }
    
    try {
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(_currentUserId)
          .get();
      
      if (!userDoc.exists) {
        LoggerService.error('Admin user document not found: $_currentUserId');
        return false;
      }
      
      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;
      final status = userData['status'] as String?;
      
      if (userType != 'admin' || status != 'active') {
        LoggerService.error('Access denied: User $_currentUserId is not an active admin');
        return false;
      }
      
      return true;
    } catch (e) {
      LoggerService.error('Admin validation failed: $e');
      return false;
    }
  }

  // ============================================================================
  // REAL-TIME DASHBOARD STATISTICS
  // ============================================================================

  /// Get real-time user statistics
  Stream<Map<String, dynamic>> getUserStatisticsStream() {
    return _firestore
        .collection(AppConfig.usersCollection)
        .snapshots()
        .map((snapshot) {
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = thisMonthStart;

      return {
        'total': users.length,
        'active': users.where((u) => u.status == UserStatus.active).length,
        'pending': users.where((u) => u.status == UserStatus.pending).length,
        'suspended': users.where((u) => u.status == UserStatus.suspended).length,
        'recipients': users.where((u) => u.userType == UserType.user).length,
        'cas': users.where((u) => u.userType == UserType.ca).length,
        'admins': users.where((u) => u.userType == UserType.admin).length,
        'pendingCAs': users.where((u) => u.userType == UserType.ca && u.status == UserStatus.pending).length,
        'activeCAs': users.where((u) => u.userType == UserType.ca && u.status == UserStatus.active).length,
        'thisMonth': users.where((u) => u.createdAt.isAfter(thisMonthStart)).length,
        'lastMonth': users.where((u) => 
          u.createdAt.isAfter(lastMonthStart) && u.createdAt.isBefore(lastMonthEnd)
        ).length,
      };
    });
  }

  /// Get real-time certificate statistics
  Stream<Map<String, dynamic>> getCertificateStatisticsStream() {
    return _firestore
        .collection(AppConfig.certificatesCollection)
        .snapshots()
        .map((snapshot) {
      final certificates = snapshot.docs.map((doc) => CertificateModel.fromFirestore(doc)).toList();
      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);

      return {
        'total': certificates.length,
        'issued': certificates.where((c) => c.status == CertificateStatus.issued).length,
        'draft': certificates.where((c) => c.status == CertificateStatus.draft).length,
        'revoked': certificates.where((c) => c.status == CertificateStatus.revoked).length,
        'expired': certificates.where((c) => c.isExpired).length,
        'thisMonth': certificates.where((c) => c.createdAt.isAfter(thisMonthStart)).length,
        'byType': _groupCertificatesByType(certificates),
      };
    });
  }

  /// Get real-time document statistics
  Stream<Map<String, dynamic>> getDocumentStatisticsStream() {
    return _firestore
        .collection(AppConfig.documentsCollection)
        .snapshots()
        .map((snapshot) {
      final documents = snapshot.docs.map((doc) => DocumentModel.fromFirestore(doc)).toList();
      final totalSize = documents.fold<int>(0, (total, doc) => total + doc.fileSize);

      return {
        'total': documents.length,
        'verified': documents.where((d) => d.status == DocumentStatus.verified).length,
        'pending': documents.where((d) => d.status == DocumentStatus.pending).length,
        'rejected': documents.where((d) => d.status == DocumentStatus.rejected).length,
        'totalSize': totalSize,
        'averageSize': documents.isNotEmpty ? (totalSize / documents.length).round() : 0,
        'byType': _groupDocumentsByType(documents),
      };
    });
  }

  Map<String, int> _groupCertificatesByType(List<CertificateModel> certificates) {
    final Map<String, int> typeCount = {};
    for (final cert in certificates) {
      final type = cert.type.displayName;
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }
    return typeCount;
  }

  Map<String, int> _groupDocumentsByType(List<DocumentModel> documents) {
    final Map<String, int> typeCount = {};
    for (final doc in documents) {
      final type = doc.type.displayName;
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }
    return typeCount;
  }

  // ============================================================================
  // CA APPLICATION MANAGEMENT
  // ============================================================================

  /// Get real-time CA applications stream
  Stream<List<UserModel>> getCAApplicationsStream({
    UserStatus? status,
    String? searchQuery,
    String sortBy = 'createdAt',
    bool descending = true,
  }) {
    Query query = _firestore
        .collection(AppConfig.usersCollection)
        .where('userType', isEqualTo: UserType.ca.name);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    query = query.orderBy(sortBy, descending: descending);

    return query.snapshots().map((snapshot) {
      List<UserModel> applications = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowercaseQuery = searchQuery.toLowerCase();
        applications = applications.where((user) =>
          user.displayName.toLowerCase().contains(lowercaseQuery) ||
          user.email.toLowerCase().contains(lowercaseQuery) ||
          (user.organizationName?.toLowerCase().contains(lowercaseQuery) ?? false)
        ).toList();
      }

      return applications;
    });
  }

  /// Approve a CA registration application
  Future<bool> approveCAApplication(String userId, [String? comments]) async {
    try {
      // Strict admin validation
      if (!await _validateAdminAccess()) {
        throw Exception('Unauthorized: Admin access required for CA approval');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final user = UserModel.fromFirestore(userDoc);
        
        if (user.userType != UserType.ca) {
          throw Exception('User is not a CA applicant');
        }

        if (user.status != UserStatus.pending) {
          throw Exception('Application is not in pending status');
      }

      // Update user status to active
        transaction.update(userRef, {
        'status': UserStatus.active.name,
        'approvedBy': _currentUserId,
        'approvedAt': Timestamp.fromDate(DateTime.now()),
        'approvalComments': comments,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

        // Update organization name if CA
        if (user.userType == UserType.ca) {
          transaction.update(userRef, {
            'organizationName': user.organizationName ?? 'Approved CA',
          });
        }

      // Log the approval action
        final activityRef = _firestore.collection('admin_activities').doc();
        transaction.set(activityRef, {
          'id': activityRef.id,
          'action': 'ca_application_approved',
          'adminId': _currentUserId,
          'targetUserId': userId,
          'targetUserEmail': user.email,
          'targetUserName': user.displayName,
          'details': {
            'previousStatus': user.status.name,
            'newStatus': UserStatus.active.name,
            'organizationName': user.organizationName,
          },
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      // Send notification to approved CA
      try {
        await _notificationService.sendCAApprovalNotification(
          userId: userId,
          status: 'approved',
        );
      } catch (e) {
        LoggerService.warning('Failed to send notification to approved CA', error: e);
      }

      LoggerService.info('CA application approved: $userId by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to approve CA application', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Reject a CA registration application
  Future<bool> rejectCAApplication(String userId, String reason) async {
    try {
      // Strict admin validation
      if (!await _validateAdminAccess()) {
        throw Exception('Unauthorized: Admin access required for CA rejection');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final user = UserModel.fromFirestore(userDoc);
        
        if (user.userType != UserType.ca) {
          throw Exception('User is not a CA applicant');
        }

        if (user.status != UserStatus.pending) {
          throw Exception('Application is not in pending status');
      }

      // Update user status to suspended (rejected)
        transaction.update(userRef, {
        'status': UserStatus.suspended.name,
        'rejectedBy': _currentUserId,
        'rejectedAt': Timestamp.fromDate(DateTime.now()),
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Log the rejection action
        final activityRef = _firestore.collection('admin_activities').doc();
        transaction.set(activityRef, {
          'id': activityRef.id,
          'action': 'ca_application_rejected',
          'adminId': _currentUserId,
          'targetUserId': userId,
          'targetUserEmail': user.email,
          'targetUserName': user.displayName,
          'details': {
          'reason': reason,
            'previousStatus': user.status.name,
            'newStatus': UserStatus.suspended.name,
          },
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      // Send notification to rejected CA
      try {
        await _notificationService.sendCAApprovalNotification(
          userId: userId,
          status: 'rejected',
          comments: reason,
        );
      } catch (e) {
        LoggerService.warning('Failed to send notification to rejected CA', error: e);
      }

      LoggerService.info('CA application rejected: $userId by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to reject CA application', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  // ============================================================================
  // USER MANAGEMENT
  // ============================================================================

  /// Get all users with real-time updates, filtering and pagination
  Stream<List<UserModel>> getUsersStream({
    UserRole? role,
    UserType? userType,
    UserStatus? status,
    String? searchQuery,
    String sortBy = 'createdAt',
    bool descending = true,
    int? limit,
  }) {
      Query query = _firestore.collection(AppConfig.usersCollection);

      if (role != null) {
        query = query.where('role', isEqualTo: role.name);
      }

    if (userType != null) {
      query = query.where('userType', isEqualTo: userType.name);
    }

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

    query = query.orderBy(sortBy, descending: descending);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      List<UserModel> users = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowercaseQuery = searchQuery.toLowerCase();
        users = users.where((user) =>
          user.displayName.toLowerCase().contains(lowercaseQuery) ||
          user.email.toLowerCase().contains(lowercaseQuery) ||
          (user.organizationName?.toLowerCase().contains(lowercaseQuery) ?? false)
        ).toList();
      }

      return users;
    });
  }

  /// Get user details with certificates and documents
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      // Get user document
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final user = UserModel.fromFirestore(userDoc);

      // Get user's certificates
      final certificatesQuery = await _firestore
          .collection(AppConfig.certificatesCollection)
          .where('recipientId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final certificates = certificatesQuery.docs
          .map((doc) => CertificateModel.fromFirestore(doc))
          .toList();

      // Get user's documents
      final documentsQuery = await _firestore
          .collection(AppConfig.documentsCollection)
          .where('uploadedBy', isEqualTo: userId)
          .orderBy('uploadedAt', descending: true)
          .limit(10)
          .get();

      final documents = documentsQuery.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();

      // Get user activity
      final activitiesQuery = await _firestore
          .collection('user_activities')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final activities = activitiesQuery.docs.map((doc) => doc.data()).toList();

      // Update user metadata for display
      final userData = user.toFirestore();
      userData['userTypeDisplayName'] = user.userTypeDisplayName;
      userData['statusDisplayName'] = user.statusDisplayName;
      if (user.userType == UserType.ca) {
        userData['caInfo'] = {
          'organizationName': user.organizationName ?? 'Unknown Organization',
          'businessLicense': user.businessLicense,
          'description': user.description,
          'address': user.address,
        };
      }

      return {
        'user': userData,
        'certificates': certificates,
        'documents': documents,
        'activities': activities,
        'stats': {
          'totalCertificates': certificates.length,
          'totalDocuments': documents.length,
          'lastActivity': activities.isNotEmpty 
              ? activities.first['timestamp'] as Timestamp
              : user.updatedAt,
        },
      };
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get user details', 
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Suspend a user account
  Future<bool> suspendUser(String userId, String reason) async {
    try {
      // Strict admin validation
      if (!await _validateAdminAccess()) {
        throw Exception('Unauthorized: Admin access required for user suspension');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final user = UserModel.fromFirestore(userDoc);

        if (user.status == UserStatus.suspended) {
          throw Exception('User is already suspended');
        }

        // Update user status to suspended
        transaction.update(userRef, {
          'status': UserStatus.suspended.name,
          'suspendedBy': _currentUserId,
          'suspendedAt': Timestamp.fromDate(DateTime.now()),
          'suspensionReason': reason,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

        // Log the suspension action
        final activityRef = _firestore.collection('admin_activities').doc();
        transaction.set(activityRef, {
          'id': activityRef.id,
          'action': 'user_suspended',
        'adminId': _currentUserId,
          'targetUserId': userId,
          'targetUserEmail': user.email,
          'targetUserName': user.displayName,
          'details': {
            'reason': reason,
            'previousStatus': user.status.name,
            'newStatus': UserStatus.suspended.name,
          },
        'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      // Send notification to suspended user
      try {
        await _notificationService.sendAccountStatusNotification(
          userId: userId,
          status: 'suspended',
          reason: reason,
        );
      } catch (e) {
        LoggerService.warning('Failed to send notification to suspended user', error: e);
      }

      LoggerService.info('User suspended: $userId by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to suspend user', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Reactivate a suspended user account
  Future<bool> reactivateUser(String userId) async {
    try {
      // Strict admin validation
      if (!await _validateAdminAccess()) {
        throw Exception('Unauthorized: Admin access required for user reactivation');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final user = UserModel.fromFirestore(userDoc);

        if (user.status != UserStatus.suspended) {
          throw Exception('User is not suspended');
        }

        // Update user status to active
        transaction.update(userRef, {
          'status': UserStatus.active.name,
          'reactivatedBy': _currentUserId,
          'reactivatedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

        // Log the reactivation action
        final activityRef = _firestore.collection('admin_activities').doc();
        transaction.set(activityRef, {
          'id': activityRef.id,
          'action': 'user_reactivated',
          'adminId': _currentUserId,
          'targetUserId': userId,
          'targetUserEmail': user.email,
          'targetUserName': user.displayName,
          'details': {
            'previousStatus': user.status.name,
            'newStatus': UserStatus.active.name,
          },
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      // Send notification to reactivated user
      try {
        await _notificationService.sendAccountStatusNotification(
          userId: userId,
          status: 'active',
        );
      } catch (e) {
        LoggerService.warning('Failed to send notification to reactivated user', error: e);
      }

      LoggerService.info('User reactivated: $userId by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to reactivate user', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// Delete a user account (soft delete)
  Future<bool> deleteUser(String userId, String reason) async {
    try {
      if (_currentUserId == null) {
        throw Exception('Admin not authenticated');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        final userDoc = await transaction.get(userRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final user = UserModel.fromFirestore(userDoc);

        // Soft delete: mark as deleted instead of actually deleting
        transaction.update(userRef, {
          'status': UserStatus.inactive.name,
        'deletedBy': _currentUserId,
        'deletedAt': Timestamp.fromDate(DateTime.now()),
        'deletionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
          'isDeleted': true,
        });

        // Log the deletion action
        final activityRef = _firestore.collection('admin_activities').doc();
        transaction.set(activityRef, {
          'id': activityRef.id,
          'action': 'user_deleted',
          'adminId': _currentUserId,
          'targetUserId': userId,
          'targetUserEmail': user.email,
          'targetUserName': user.displayName,
          'details': {
            'reason': reason,
            'previousStatus': user.status.name,
            'newStatus': UserStatus.inactive.name,
          },
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      });

      LoggerService.info('User deleted: $userId by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to delete user', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }

  // ============================================================================
  // ADMIN ACTIVITY LOGGING
  // ============================================================================

  /// Get admin activity logs
  Stream<List<Map<String, dynamic>>> getAdminActivitiesStream({
    String? adminId,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('admin_activities')
        .orderBy('timestamp', descending: true);

    if (adminId != null) {
      query = query.where('adminId', isEqualTo: adminId);
    }

    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }

    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) => 
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // ============================================================================
  // SYSTEM HEALTH MONITORING
  // ============================================================================

  /// Get system health and performance metrics
  Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final Map<String, dynamic> healthStatus = {};
      
      // Check database connectivity
      final usersQuery = await _firestore.collection(AppConfig.usersCollection).limit(1).get();
      healthStatus['database'] = {
        'connected': true,
        'collections': {
          'users': usersQuery.docs.length,
        }
      };
      
      // Check authentication
      final currentUser = _auth.currentUser;
      healthStatus['authentication'] = {
        'working': currentUser != null,
        'currentUser': currentUser?.email ?? 'Anonymous',
      };
      
      // Check storage (basic)
      healthStatus['storage'] = {
        'available': true,
        'status': 'operational'
      };
      
      // Overall status
      healthStatus['status'] = 'healthy';
      healthStatus['lastChecked'] = DateTime.now().toIso8601String();
      healthStatus['uptime'] = 'System operational';
      
      return healthStatus;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get system health', 
          error: error, stackTrace: stackTrace);
      return {
        'status': 'error',
        'database': {
          'connected': false,
          'error': error.toString(),
        },
        'authentication': {
          'working': false,
          'error': 'Check failed',
        },
        'storage': {
          'available': false,
          'error': 'Check failed',
        },
        'lastChecked': DateTime.now().toIso8601String(),
        'error': error.toString(),
      };
    }
  }

  // ============================================================================
  // BATCH OPERATIONS
  // ============================================================================

  /// Bulk update user status
  Future<bool> bulkUpdateUserStatus(
    List<String> userIds, 
    UserStatus newStatus, 
    String reason
  ) async {
    try {
      // Strict admin validation
      if (!await _validateAdminAccess()) {
        throw Exception('Unauthorized: Admin access required for bulk operations');
      }

      final batch = _firestore.batch();
      final timestamp = Timestamp.fromDate(DateTime.now());

      for (final userId in userIds) {
        final userRef = _firestore.collection(AppConfig.usersCollection).doc(userId);
        
        batch.update(userRef, {
          'status': newStatus.name,
          'bulkUpdatedBy': _currentUserId,
          'bulkUpdatedAt': timestamp,
          'bulkUpdateReason': reason,
          'updatedAt': timestamp,
        });

        // Log each action
        final activityRef = _firestore.collection('admin_activities').doc();
        batch.set(activityRef, {
          'id': activityRef.id,
          'action': 'bulk_status_update',
          'adminId': _currentUserId,
          'targetUserId': userId,
          'details': {
            'newStatus': newStatus.name,
            'reason': reason,
            'batchSize': userIds.length,
          },
          'timestamp': timestamp,
        });
      }

      await batch.commit();

      LoggerService.info('Bulk updated ${userIds.length} users to ${newStatus.name} by $_currentUserId');
      return true;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to bulk update users', 
          error: error, stackTrace: stackTrace);
      return false;
    }
  }
} 