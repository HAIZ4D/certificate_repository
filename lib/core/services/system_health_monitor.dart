import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

import '../models/user_model.dart';

import '../models/document_model.dart';
import '../config/app_config.dart';
import 'logger_service.dart';
import 'validation_service.dart';

/// Real-time System Health Monitor
/// Monitors all three systems (Admin, CA, User) and their interconnections
class SystemHealthMonitor {
  static final SystemHealthMonitor _instance = SystemHealthMonitor._internal();
  factory SystemHealthMonitor() => _instance;
  SystemHealthMonitor._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  Timer? _healthCheckTimer;
  final StreamController<SystemHealthStatus> _healthStatusController =
      StreamController<SystemHealthStatus>.broadcast();

  /// Get real-time system health status stream
  Stream<SystemHealthStatus> get healthStatusStream => _healthStatusController.stream;

  /// Start continuous health monitoring
  void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(interval, (_) => _performHealthCheck());
    
    // Perform initial health check
    _performHealthCheck();
    
    LoggerService.info('System health monitoring started with ${interval.inMinutes} minute intervals');
  }

  /// Stop health monitoring
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    LoggerService.info('System health monitoring stopped');
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      LoggerService.info('🔍 Performing system health check...');
      
      final healthStatus = SystemHealthStatus(
        timestamp: DateTime.now(),
        overall: SystemStatus.checking,
        adminSystem: await _checkAdminSystemHealth(),
        caSystem: await _checkCASystemHealth(),
        userSystem: await _checkUserSystemHealth(),
        database: await _checkDatabaseHealth(),
        storage: await _checkStorageHealth(),
        authentication: await _checkAuthenticationHealth(),
        crossSystemIntegration: await _checkCrossSystemIntegration(),
        notifications: await _checkNotificationSystemHealth(),
      );

      // Determine overall system status
      healthStatus.overall = _calculateOverallStatus(healthStatus);
      
      _healthStatusController.add(healthStatus);
      
      LoggerService.info('✅ System health check completed: ${healthStatus.overall.displayName}');
      
    } catch (e, stackTrace) {
      LoggerService.error('❌ System health check failed', error: e, stackTrace: stackTrace);
      
      _healthStatusController.add(SystemHealthStatus(
        timestamp: DateTime.now(),
        overall: SystemStatus.critical,
        error: e.toString(),
      ));
    }
  }

  /// Check Admin System Health
  Future<SystemComponentHealth> _checkAdminSystemHealth() async {
    try {
      final adminQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .where('userType', isEqualTo: UserType.admin.name)
          .where('status', isEqualTo: UserStatus.active.name)
          .limit(1)
          .get();

      if (adminQuery.docs.isEmpty) {
        return SystemComponentHealth(
          status: SystemStatus.critical,
          message: 'No active admin users found',
          lastChecked: DateTime.now(),
          details: {
            'totalAdmins': 0,
            'activeAdmins': 0,
          },
        );
      }

      // Check admin activities in last 24 hours
      final last24h = DateTime.now().subtract(const Duration(days: 1));
      final recentActivities = await _firestore
          .collection('admin_activities')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(last24h))
          .limit(10)
          .get();

      return SystemComponentHealth(
        status: SystemStatus.healthy,
        message: 'Admin system operational',
        lastChecked: DateTime.now(),
        details: {
          'totalAdmins': adminQuery.docs.length,
          'activeAdmins': adminQuery.docs.length,
          'recentActivities': recentActivities.docs.length,
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'Admin system check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check CA System Health
  Future<SystemComponentHealth> _checkCASystemHealth() async {
    try {
      final caQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .where('userType', isEqualTo: UserType.ca.name)
          .get();

      final activeCAs = caQuery.docs
          .where((doc) => doc.data()['status'] == UserStatus.active.name)
          .length;
      
      final pendingCAs = caQuery.docs
          .where((doc) => doc.data()['status'] == UserStatus.pending.name)
          .length;

      // Check recent certificate issuance
      final last7days = DateTime.now().subtract(const Duration(days: 7));
      final recentCertificates = await _firestore
          .collection(AppConfig.certificatesCollection)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last7days))
          .limit(10)
          .get();

      final status = activeCAs > 0 ? SystemStatus.healthy : SystemStatus.warning;
      
      return SystemComponentHealth(
        status: status,
        message: activeCAs > 0 
            ? 'CA system operational with $activeCAs active CAs'
            : 'No active CAs available',
        lastChecked: DateTime.now(),
        details: {
          'totalCAs': caQuery.docs.length,
          'activeCAs': activeCAs,
          'pendingCAs': pendingCAs,
          'recentCertificates': recentCertificates.docs.length,
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'CA system check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check User System Health
  Future<SystemComponentHealth> _checkUserSystemHealth() async {
    try {
      final userQuery = await _firestore
          .collection(AppConfig.usersCollection)
          .where('userType', isEqualTo: UserType.user.name)
          .get();

      final activeUsers = userQuery.docs
          .where((doc) => doc.data()['status'] == UserStatus.active.name)
          .length;

      // Check recent user registrations
      final last7days = DateTime.now().subtract(const Duration(days: 7));
      final recentUsers = userQuery.docs
          .where((doc) {
            final createdAt = (doc.data()['createdAt'] as Timestamp).toDate();
            return createdAt.isAfter(last7days);
          })
          .length;

      // Check recent document uploads
      final recentDocuments = await _firestore
          .collection(AppConfig.documentsCollection)
          .where('uploadedAt', isGreaterThan: Timestamp.fromDate(last7days))
          .limit(10)
          .get();

      return SystemComponentHealth(
        status: SystemStatus.healthy,
        message: 'User system operational with $activeUsers active users',
        lastChecked: DateTime.now(),
        details: {
          'totalUsers': userQuery.docs.length,
          'activeUsers': activeUsers,
          'recentRegistrations': recentUsers,
          'recentDocuments': recentDocuments.docs.length,
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'User system check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check Database Health
  Future<SystemComponentHealth> _checkDatabaseHealth() async {
    try {
      final startTime = DateTime.now();
      
      // Test database connectivity and performance
      await _firestore.collection('system_config').doc('health_check').get();
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      // Check collection counts
      final userCount = await _getCollectionCount(AppConfig.usersCollection);
      final certCount = await _getCollectionCount(AppConfig.certificatesCollection);
      final docCount = await _getCollectionCount(AppConfig.documentsCollection);
      
      final status = responseTime < 1000 ? SystemStatus.healthy : SystemStatus.warning;
      
      return SystemComponentHealth(
        status: status,
        message: 'Database responsive (${responseTime}ms)',
        lastChecked: DateTime.now(),
        details: {
          'responseTime': responseTime,
          'userCount': userCount,
          'certificateCount': certCount,
          'documentCount': docCount,
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.critical,
        message: 'Database connection failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check Storage Health
  Future<SystemComponentHealth> _checkStorageHealth() async {
    try {
      final startTime = DateTime.now();
      
      // Test storage connectivity
      final ref = _storage.ref().child('health_check');
      
      try {
        await ref.getDownloadURL();
      } catch (e) {
        // File doesn't exist, which is fine for health check
      }
      
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;
      
      return SystemComponentHealth(
        status: SystemStatus.healthy,
        message: 'Storage accessible (${responseTime}ms)',
        lastChecked: DateTime.now(),
        details: {
          'responseTime': responseTime,
          'storageEndpoint': 'Firebase Storage',
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'Storage check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check Authentication Health
  Future<SystemComponentHealth> _checkAuthenticationHealth() async {
    try {
      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        return SystemComponentHealth(
          status: SystemStatus.warning,
          message: 'No authenticated user for health check',
          lastChecked: DateTime.now(),
        );
      }

      // Check if user data exists in Firestore
      final userDoc = await _firestore
          .collection(AppConfig.usersCollection)
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        return SystemComponentHealth(
          status: SystemStatus.error,
          message: 'Authentication-Firestore data mismatch',
          lastChecked: DateTime.now(),
        );
      }

      return SystemComponentHealth(
        status: SystemStatus.healthy,
        message: 'Authentication system operational',
        lastChecked: DateTime.now(),
        details: {
          'currentUser': currentUser.email,
          'emailVerified': currentUser.emailVerified,
          'dataConsistency': 'verified',
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'Authentication check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check Cross-System Integration
  Future<SystemComponentHealth> _checkCrossSystemIntegration() async {
    try {
      int issues = 0;
      final details = <String, dynamic>{};
      final List<String> errors = [];

      // Check Admin-CA integration
      final adminCAResult = await _checkAdminCAIntegration();
      if (!adminCAResult['success']) {
        issues++;
        errors.add(adminCAResult['error']);
      }
      details['adminCAIntegration'] = adminCAResult['success'];

      // Check CA-User integration
      final caUserResult = await _checkCAUserIntegration();
      if (!caUserResult['success']) {
        issues++;
        errors.add(caUserResult['error']);
      }
      details['caUserIntegration'] = caUserResult['success'];

      // Check Certificate-User linkages
      final certUserResult = await _checkCertificateUserLinkages();
      if (!certUserResult['success']) {
        issues++;
        errors.add(certUserResult['error']);
      }
      details['certificateUserLinkages'] = certUserResult['success'];

      final status = issues == 0 ? SystemStatus.healthy : 
                     issues < 2 ? SystemStatus.warning : SystemStatus.error;

      return SystemComponentHealth(
        status: status,
        message: issues == 0 
            ? 'All cross-system integrations working'
            : '$issues integration issues found',
        lastChecked: DateTime.now(),
        details: details,
        errors: errors,
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'Cross-system integration check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  /// Check Notification System Health
  Future<SystemComponentHealth> _checkNotificationSystemHealth() async {
    try {
      // Check if notification collection is accessible
      await _firestore
          .collection(AppConfig.notificationsCollection)
          .limit(1)
          .get();

      // Check recent notifications
      final last24h = DateTime.now().subtract(const Duration(days: 1));
      final recentNotifications = await _firestore
          .collection(AppConfig.notificationsCollection)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(last24h))
          .limit(10)
          .get();

      return SystemComponentHealth(
        status: SystemStatus.healthy,
        message: 'Notification system operational',
        lastChecked: DateTime.now(),
        details: {
          'collectionAccessible': true,
          'recentNotifications': recentNotifications.docs.length,
        },
      );
    } catch (e) {
      return SystemComponentHealth(
        status: SystemStatus.error,
        message: 'Notification system check failed: $e',
        lastChecked: DateTime.now(),
      );
    }
  }

  // Helper methods for cross-system integration checks
  Future<Map<String, dynamic>> _checkAdminCAIntegration() async {
    try {
      // Check if admin can manage CA applications
      final pendingCAs = await _firestore
          .collection(AppConfig.usersCollection)
          .where('userType', isEqualTo: UserType.ca.name)
          .where('status', isEqualTo: UserStatus.pending.name)
          .limit(5)
          .get();

      return {'success': true, 'pendingCAs': pendingCAs.docs.length};
    } catch (e) {
      return {'success': false, 'error': 'Admin-CA integration failed: $e'};
    }
  }

  Future<Map<String, dynamic>> _checkCAUserIntegration() async {
    try {
      // Check if CAs can manage user documents
      final pendingDocs = await _firestore
          .collection(AppConfig.documentsCollection)
          .where('status', isEqualTo: DocumentStatus.pending.name)
          .limit(5)
          .get();

      return {'success': true, 'pendingDocuments': pendingDocs.docs.length};
    } catch (e) {
      return {'success': false, 'error': 'CA-User integration failed: $e'};
    }
  }

  Future<Map<String, dynamic>> _checkCertificateUserLinkages() async {
    try {
      // Check for orphaned certificates
      final certificates = await _firestore
          .collection(AppConfig.certificatesCollection)
          .limit(10)
          .get();

      final users = await _firestore
          .collection(AppConfig.usersCollection)
          .get();

      final userIds = users.docs.map((doc) => doc.id).toSet();
      int orphanedCount = 0;

      for (final cert in certificates.docs) {
        final issuerId = cert.data()['issuerId'] as String?;
        if (issuerId != null && !userIds.contains(issuerId)) {
          orphanedCount++;
        }
      }

      return {
        'success': orphanedCount == 0,
        'orphanedCertificates': orphanedCount,
        'error': orphanedCount > 0 ? 'Found $orphanedCount orphaned certificates' : null,
      };
    } catch (e) {
      return {'success': false, 'error': 'Certificate-User linkage check failed: $e'};
    }
  }

  Future<int> _getCollectionCount(String collection) async {
    try {
      final snapshot = await _firestore.collection(collection).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      LoggerService.warning('Failed to get count for collection $collection', error: e);
      return -1;
    }
  }

  SystemStatus _calculateOverallStatus(SystemHealthStatus health) {
    final components = [
      health.adminSystem?.status,
      health.caSystem?.status,
      health.userSystem?.status,
      health.database?.status,
      health.storage?.status,
      health.authentication?.status,
      health.crossSystemIntegration?.status,
      health.notifications?.status,
    ].whereType<SystemStatus>();

    if (components.contains(SystemStatus.critical)) {
      return SystemStatus.critical;
    } else if (components.contains(SystemStatus.error)) {
      return SystemStatus.error;
    } else if (components.contains(SystemStatus.warning)) {
      return SystemStatus.warning;
    } else if (components.contains(SystemStatus.checking)) {
      return SystemStatus.checking;
    } else {
      return SystemStatus.healthy;
    }
  }

  void dispose() {
    _healthCheckTimer?.cancel();
    _healthStatusController.close();
  }

  // Comprehensive Firebase health check
  Future<FirebaseHealthStatus> checkFirebaseHealth() async {
    LoggerService.info('🔍 Starting comprehensive Firebase health check...');
    
    final results = FirebaseHealthStatus();
    
    try {
      // 1. Check internet connectivity
      results.connectivity = await _checkConnectivity();
      
      // 2. Check Firebase Auth status
      results.authStatus = await _checkAuthStatus();
      
      // 3. Check Firestore connection and permissions
      results.firestoreStatus = await _checkFirestoreStatus();
      
      // 4. Check Firebase Storage access
      results.storageStatus = await _checkStorageStatus();
      
      // 5. Check user document integrity
      results.userDocumentStatus = await _checkUserDocumentStatus();
      
      // 6. Test basic Firestore operations
      results.operationStatus = await _testBasicOperations();
      
      // 7. Check security rules compatibility
      results.securityRulesStatus = await _checkSecurityRulesCompatibility();

      LoggerService.info('✅ Firebase health check completed');
      return results;
      
    } catch (e, stackTrace) {
      LoggerService.error('❌ Firebase health check failed', error: e, stackTrace: stackTrace);
      //results.overallHealth = HealthStatus.critical;
      results.errors.add('Health check failed: ${e.toString()}');
      return results;
    }
  }

  // Check internet connectivity
  Future<HealthStatus> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        LoggerService.warning('⚠️ No internet connectivity');
        return HealthStatus.critical;
      }
      
      LoggerService.info('✅ Internet connectivity confirmed');
      return HealthStatus.healthy;
    } catch (e) {
      LoggerService.error('❌ Connectivity check failed', error: e);
      return HealthStatus.critical;
    }
  }

  // Check Firebase Auth status
  Future<HealthStatus> _checkAuthStatus() async {
    try {
      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        LoggerService.info('ℹ️ No authenticated user');
        return HealthStatus.warning;
      }
      
      // Check if user token is valid
      try {
        await currentUser.getIdToken();
        LoggerService.info('✅ Firebase Auth token is valid');
        return HealthStatus.healthy;
      } catch (e) {
        LoggerService.error('❌ Firebase Auth token is invalid', error: e);
        return HealthStatus.critical;
      }
    } catch (e) {
      LoggerService.error('❌ Firebase Auth check failed', error: e);
      return HealthStatus.critical;
    }
  }

  // Check Firestore connection and basic permissions
  Future<HealthStatus> _checkFirestoreStatus() async {
    try {
      LoggerService.info('🔍 Testing Firestore connection...');
      
      // Test basic read operation
      try {
        await _firestore.collection('settings').doc('app_config').get();
        LoggerService.info('✅ Firestore read access confirmed');
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          LoggerService.warning('⚠️ Firestore read permission denied for settings');
          return HealthStatus.warning;
        } else {
          LoggerService.error('❌ Firestore connection failed', error: e);
          return HealthStatus.critical;
        }
      }
      
      return HealthStatus.healthy;
    } catch (e) {
      LoggerService.error('❌ Firestore status check failed', error: e);
      return HealthStatus.critical;
    }
  }

  // Check Firebase Storage access
  Future<HealthStatus> _checkStorageStatus() async {
    try {
      LoggerService.info('🔍 Testing Firebase Storage connection...');
      
      // Test storage reference creation
      final storageRef = _storage.ref().child('health-check');
      await storageRef.listAll();
      
      LoggerService.info('✅ Firebase Storage access confirmed');
      return HealthStatus.healthy;
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        LoggerService.warning('⚠️ Firebase Storage permission denied');
        return HealthStatus.warning;
      } else {
        LoggerService.error('❌ Firebase Storage check failed', error: e);
        return HealthStatus.critical;
      }
    }
  }

  // Check user document integrity
  Future<HealthStatus> _checkUserDocumentStatus() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggerService.info('ℹ️ No user to check document status for');
        return HealthStatus.healthy; // Not critical if no user
      }
      
      LoggerService.info('🔍 Checking user document integrity...');
      
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        
        if (!userDoc.exists) {
          LoggerService.warning('⚠️ User document does not exist');
          
          // Try to create missing user document
          try {
            final validationResult = await ValidationService.validateUserAuthentication();
            if (validationResult.isValid) {
              LoggerService.info('✅ User document created successfully');
              return HealthStatus.healthy;
            } else {
              LoggerService.error('❌ Failed to create user document');
              return HealthStatus.critical;
            }
          } catch (e) {
            LoggerService.error('❌ Failed to auto-create user document', error: e);
            return HealthStatus.critical;
          }
        }
        
        // Validate user document structure
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData == null) {
          LoggerService.error('❌ User document data is null');
          return HealthStatus.critical;
        }
        
        // Check required fields
        final requiredFields = ['email', 'userType', 'status', 'createdAt'];
        for (final field in requiredFields) {
          if (!userData.containsKey(field)) {
            LoggerService.warning('⚠️ User document missing field: $field');
            return HealthStatus.warning;
          }
        }
        
        LoggerService.info('✅ User document integrity confirmed');
        return HealthStatus.healthy;
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          LoggerService.warning('⚠️ Permission denied when checking user document');
          return HealthStatus.warning;
        } else {
          LoggerService.error('❌ User document check failed', error: e);
          return HealthStatus.critical;
        }
      }
    } catch (e) {
      LoggerService.error('❌ User document status check failed', error: e);
      return HealthStatus.critical;
    }
  }

  // Test basic Firestore operations
  Future<HealthStatus> _testBasicOperations() async {
    try {
      LoggerService.info('🔍 Testing basic Firestore operations...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggerService.info('ℹ️ Skipping operations test - no authenticated user');
        return HealthStatus.healthy;
      }
      
      // Test read operations on user-accessible collections
      final testCollections = ['notifications', 'certificates', 'documents'];
      int successfulOperations = 0;
      
      for (final collection in testCollections) {
        try {
          await _firestore.collection(collection).limit(1).get();
          successfulOperations++;
          LoggerService.info('✅ Read access confirmed for: $collection');
        } catch (e) {
          if (e.toString().contains('permission-denied')) {
            LoggerService.warning('⚠️ Permission denied for collection: $collection');
          } else {
            LoggerService.error('❌ Failed to access collection: $collection', error: e);
          }
        }
      }
      
      if (successfulOperations == 0) {
        LoggerService.error('❌ No successful operations');
        return HealthStatus.critical;
      } else if (successfulOperations < testCollections.length) {
        LoggerService.warning('⚠️ Some operations failed');
        return HealthStatus.warning;
      } else {
        LoggerService.info('✅ All basic operations successful');
        return HealthStatus.healthy;
      }
    } catch (e) {
      LoggerService.error('❌ Basic operations test failed', error: e);
      return HealthStatus.critical;
    }
  }

  // Check security rules compatibility
  Future<HealthStatus> _checkSecurityRulesCompatibility() async {
    try {
      LoggerService.info('🔍 Checking security rules compatibility...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggerService.info('ℹ️ Skipping security rules check - no authenticated user');
        return HealthStatus.healthy;
      }
      
      // Test user document access
      try {
        await _firestore.collection('users').doc(currentUser.uid).get();
        LoggerService.info('✅ User document access confirmed');
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          LoggerService.error('❌ Security rules deny user document access');
          return HealthStatus.critical;
        }
      }
      
      // Test notification creation (should be allowed)
      try {
        await _firestore.collection('notifications').add({
          'userId': currentUser.uid,
          'title': 'Health Check',
          'message': 'System health check notification',
          'type': 'system',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        LoggerService.info('✅ Notification creation confirmed');
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          LoggerService.warning('⚠️ Security rules deny notification creation');
          return HealthStatus.warning;
        }
      }
      
      LoggerService.info('✅ Security rules compatibility confirmed');
      return HealthStatus.healthy;
    } catch (e) {
      LoggerService.error('❌ Security rules compatibility check failed', error: e);
      return HealthStatus.warning; // Not critical, but concerning
    }
  }

  // Generate health report
  String generateHealthReport(FirebaseHealthStatus status) {
    final buffer = StringBuffer();
    buffer.writeln('🏥 FIREBASE HEALTH REPORT');
    buffer.writeln('=' * 50);
    buffer.writeln('Overall Health: ${status.overallHealth.name.toUpperCase()}');
    buffer.writeln('');
    
    buffer.writeln('📱 Component Status:');
    buffer.writeln('  Connectivity: ${status.connectivity.name}');
    buffer.writeln('  Authentication: ${status.authStatus.name}');
    buffer.writeln('  Firestore: ${status.firestoreStatus.name}');
    buffer.writeln('  Storage: ${status.storageStatus.name}');
    buffer.writeln('  User Document: ${status.userDocumentStatus.name}');
    buffer.writeln('  Operations: ${status.operationStatus.name}');
    buffer.writeln('  Security Rules: ${status.securityRulesStatus.name}');
    
    if (status.errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('❌ Errors:');
      for (final error in status.errors) {
        buffer.writeln('  • $error');
      }
    }
    
    if (status.warnings.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('⚠️ Warnings:');
      for (final warning in status.warnings) {
        buffer.writeln('  • $warning');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('⏰ Report generated: ${DateTime.now()}');
    
    return buffer.toString();
  }
}

/// System Health Status Classes
class SystemHealthStatus {
  final DateTime timestamp;
  SystemStatus overall;
  final SystemComponentHealth? adminSystem;
  final SystemComponentHealth? caSystem;
  final SystemComponentHealth? userSystem;
  final SystemComponentHealth? database;
  final SystemComponentHealth? storage;
  final SystemComponentHealth? authentication;
  final SystemComponentHealth? crossSystemIntegration;
  final SystemComponentHealth? notifications;
  final String? error;

  SystemHealthStatus({
    required this.timestamp,
    required this.overall,
    this.adminSystem,
    this.caSystem,
    this.userSystem,
    this.database,
    this.storage,
    this.authentication,
    this.crossSystemIntegration,
    this.notifications,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'overall': overall.name,
    'adminSystem': adminSystem?.toJson(),
    'caSystem': caSystem?.toJson(),
    'userSystem': userSystem?.toJson(),
    'database': database?.toJson(),
    'storage': storage?.toJson(),
    'authentication': authentication?.toJson(),
    'crossSystemIntegration': crossSystemIntegration?.toJson(),
    'notifications': notifications?.toJson(),
    'error': error,
  };
}

class SystemComponentHealth {
  final SystemStatus status;
  final String message;
  final DateTime lastChecked;
  final Map<String, dynamic>? details;
  final List<String>? errors;

  SystemComponentHealth({
    required this.status,
    required this.message,
    required this.lastChecked,
    this.details,
    this.errors,
  });

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'message': message,
    'lastChecked': lastChecked.toIso8601String(),
    'details': details,
    'errors': errors,
  };
}

enum SystemStatus {
  healthy,
  warning,
  error,
  critical,
  checking,
}

extension SystemStatusExtension on SystemStatus {
  String get displayName {
    switch (this) {
      case SystemStatus.healthy:
        return 'Healthy';
      case SystemStatus.warning:
        return 'Warning';
      case SystemStatus.error:
        return 'Error';
      case SystemStatus.critical:
        return 'Critical';
      case SystemStatus.checking:
        return 'Checking';
    }
  }

  String get emoji {
    switch (this) {
      case SystemStatus.healthy:
        return '✅';
      case SystemStatus.warning:
        return '⚠️';
      case SystemStatus.error:
        return '❌';
      case SystemStatus.critical:
        return '🚨';
      case SystemStatus.checking:
        return '🔍';
    }
  }
}

// Health status enumeration
enum HealthStatus {
  healthy,
  warning,
  critical,
}

// Firebase health status model
class FirebaseHealthStatus {
  HealthStatus connectivity = HealthStatus.critical;
  HealthStatus authStatus = HealthStatus.critical;
  HealthStatus firestoreStatus = HealthStatus.critical;
  HealthStatus storageStatus = HealthStatus.critical;
  HealthStatus userDocumentStatus = HealthStatus.critical;
  HealthStatus operationStatus = HealthStatus.critical;
  HealthStatus securityRulesStatus = HealthStatus.critical;
  
  List<String> errors = [];
  List<String> warnings = [];
  
  HealthStatus get overallHealth {
    final statuses = [
      connectivity,
      authStatus,
      firestoreStatus,
      storageStatus,
      userDocumentStatus,
      operationStatus,
      securityRulesStatus,
    ];
    
    if (statuses.any((status) => status == HealthStatus.critical)) {
      return HealthStatus.critical;
    } else if (statuses.any((status) => status == HealthStatus.warning)) {
      return HealthStatus.warning;
    } else {
      return HealthStatus.healthy;
    }
  }
} 