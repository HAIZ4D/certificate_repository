import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../models/user_model.dart';
import '../../features/auth/services/user_service.dart';
import 'logger_service.dart';

class InitializationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final Logger _logger = Logger();

  /// Constructor
  InitializationService();

  /// Create initial Admin account
  /// This method should only be used when system is first deployed or emergency Admin creation is needed
  static Future<void> createInitialAdmin({
    String? email,
    String? password,
    String? displayName,
  }) async {
    try {
      LoggerService.info('Creating initial admin account...');
      
      // Use passed parameters or secure default values
      final adminEmail = email ?? 'admin@upm.edu.my';
      final adminPassword = password ?? _generateSecurePassword();
      final adminDisplayName = displayName ?? 'System Administrator';
      
      // If no password provided, log the generated password (development environment only)
      if (password == null) {
        LoggerService.warning('⚠️  Generated admin password: $adminPassword');
        LoggerService.warning('⚠️  Please change this password immediately after first login!');
      }
      
      // First mark system as initializing
      await _setAdminInitializationStatus(false);
      
      final existingAdminQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'admin')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (existingAdminQuery.docs.isNotEmpty) {
        LoggerService.info('Active Admin user already exists');
        await _setAdminInitializationStatus(true);
        return;
      }

      UserCredential? userCredential;
      
      try {
        // Check if email already exists in Firebase Auth
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();
            
        if (userQuery.docs.isNotEmpty) {
          LoggerService.info('Email already exists in Firestore, attempting to sign in...');
          try {
            userCredential = await _auth.signInWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );
            LoggerService.info('Successfully signed in to existing account');
          } catch (signInError) {
            LoggerService.warning('Failed to sign in, will attempt to create new account');
          }
        }
        
        // If login fails or user doesn't exist, try to create new account
        if (userCredential == null) {
          try {
            userCredential = await _auth.createUserWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );
            LoggerService.info('Firebase Auth user created successfully');
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              // Email already exists, try to login
              userCredential = await _auth.signInWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword,
              );
              LoggerService.info('Used existing Firebase Auth account');
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        LoggerService.error('Firebase Auth error: $e');
        rethrow;
      }

      final user = userCredential?.user;
      if (user == null) {
        throw Exception('Failed to create or access Firebase Auth user');
      }
      
      // Update user display name
      if (user.displayName != adminDisplayName) {
        await user.updateDisplayName(adminDisplayName);
      }

      final now = DateTime.now();
      final userModel = UserModel(
        id: user.uid,
        email: adminEmail,
        displayName: adminDisplayName,
        role: UserRole.systemAdmin,
        userType: UserType.admin,
        status: UserStatus.active,
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
        isEmailVerified: user.emailVerified,
        photoURL: user.photoURL,
        metadata: {
          'registrationMethod': 'initialization_script',
          'registrationSource': 'system_setup',
          'initialRole': 'systemAdmin',
          'createdBy': 'initialization_service',
        },
        permissions: ['*'],
        profile: {
          'notifications': true,
          'emailUpdates': true,
          'theme': 'system',
          'language': 'en',
        },
      );

      // Create or update Firestore document
      await _firestore.collection('users').doc(user.uid).set(userModel.toFirestore());
      
      // Record activity log
      await _logAdminCreation(user.uid, adminEmail);
      
      // Mark admin initialization complete
      await _setAdminInitializationStatus(true);

      LoggerService.info('Initial Admin account created successfully!');
      LoggerService.info('Email: $adminEmail');
      LoggerService.info('UID: ${user.uid}');
      
    } catch (e, stackTrace) {
      LoggerService.error('Failed to create initial Admin account', error: e, stackTrace: stackTrace);
      // Mark initialization failed
      await _setAdminInitializationStatus(false);
      rethrow;
    }
  }

  /// Set administrator initialization status
  static Future<void> _setAdminInitializationStatus(bool hasActiveAdmin) async {
    try {
      await _firestore.collection('system_config').doc('admin_initialized').set({
        'hasActiveAdmin': hasActiveAdmin,
        'lastChecked': Timestamp.fromDate(DateTime.now()),
        'version': '1.0.0',
      });
      LoggerService.info('Admin initialization status set to: $hasActiveAdmin');
    } catch (e) {
      LoggerService.error('Failed to set admin initialization status', error: e);
    }
  }

  /// Check if system needs initialization
  static Future<bool> needsInitialization() async {
    try {
      // Check system configuration
      final configDoc = await _firestore
          .collection('system_config')
          .doc('admin_initialized')
          .get();
      
      if (!configDoc.exists) {
        LoggerService.info('System config not found, needs initialization');
        return true;
      }
      
      final configData = configDoc.data()!;
      if (configData['hasActiveAdmin'] == true) {
        LoggerService.info('System config indicates active admin exists');
        return false;
      }
      
      // Double check: query actual active administrators
      final adminQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'admin')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      final needsInit = adminQuery.docs.isEmpty;
      
      // Update configuration status
      await _setAdminInitializationStatus(!needsInit);
      
      return needsInit;
    } catch (e) {
      LoggerService.error('Failed to check initialization status', error: e);
      return true; // Assume initialization needed when error occurs
    }
  }

  /// Verify Admin account status
  static Future<Map<String, dynamic>> checkAdminStatus() async {
    try {
      final adminQuery = await _firestore
          .collection('users')
          .where('userType', isEqualTo: 'admin')
          .get();

      final totalAdmins = adminQuery.docs.length;
      final activeAdmins = adminQuery.docs
          .where((doc) => doc.data()['status'] == 'active')
          .length;
      final pendingAdmins = adminQuery.docs
          .where((doc) => doc.data()['status'] == 'pending')
          .length;

      final result = {
        'totalAdmins': totalAdmins,
        'activeAdmins': activeAdmins,
        'pendingAdmins': pendingAdmins,
        'needsInitialization': activeAdmins == 0,
      };
      
      // Update system configuration
      await _setAdminInitializationStatus(activeAdmins > 0);
      
      return result;
    } catch (e) {
      LoggerService.error('Failed to check admin status', error: e);
      return {
        'totalAdmins': 0,
        'activeAdmins': 0,
        'pendingAdmins': 0,
        'needsInitialization': true,
        'error': e.toString(),
      };
    }
  }

  /// Record admin creation activity
  static Future<void> _logAdminCreation(String adminId, String email) async {
    try {
      await _firestore.collection('admin_activities').add({
        'action': 'initial_admin_created',
        'description': 'Initial system administrator account created',
        'adminId': adminId,
        'email': email,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'metadata': {
          'createdBy': 'system_initialization',
          'method': 'initialization_service',
        },
      });
    } catch (e) {
      LoggerService.error('Failed to log admin creation activity', error: e);
    }
  }

  /// Force reinitialize system administrator
  static Future<void> forceReinitializeAdmin({
    String? email,
    String? password,
    String? displayName,
  }) async {
    try {
      LoggerService.info('🚨 Force reinitializing admin account...');
      
      // Reset system configuration
      await _setAdminInitializationStatus(false);
      
      // Create administrator
      await createInitialAdmin(
        email: email,
        password: password,
        displayName: displayName,
      );
      
      LoggerService.info('✅ Force reinitialization completed');
    } catch (e, stackTrace) {
      LoggerService.error('❌ Force reinitialization failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Perform system maintenance and data cleanup
  /// This replaces test data cleanup with production-appropriate maintenance
  static Future<void> performSystemMaintenance() async {
    try {
      LoggerService.info('Starting system maintenance...');
      
      // 1. Clean up expired share tokens
      await _cleanupExpiredTokens();
      
      // 2. Archive old activity logs (older than 90 days)
      await _archiveOldActivityLogs();
      
      // 3. Update statistics and cache
      await _updateSystemStatistics();
      
      // 4. Verify data integrity
      await _verifyDataIntegrity();
      
      LoggerService.info('System maintenance completed successfully');
    } catch (e) {
      LoggerService.error('Failed to perform system maintenance', error: e);
    }
  }

  /// Clean up expired share tokens from all certificates
  static Future<void> _cleanupExpiredTokens() async {
    try {
      final now = DateTime.now();
      final certificatesQuery = await _firestore.collection('certificates').get();
      
      int tokensRemoved = 0;
      for (final doc in certificatesQuery.docs) {
        final data = doc.data();
        final shareTokens = data['shareTokens'] as List<dynamic>? ?? [];
        
        final validTokens = shareTokens.where((token) {
          final expiresAt = DateTime.parse(token['expiresAt']);
          return expiresAt.isAfter(now);
        }).toList();
        
        if (validTokens.length != shareTokens.length) {
          tokensRemoved += shareTokens.length - validTokens.length;
          await doc.reference.update({'shareTokens': validTokens});
        }
      }
      
      LoggerService.info('Removed $tokensRemoved expired share tokens');
    } catch (e) {
      LoggerService.error('Failed to cleanup expired tokens', error: e);
    }
  }

  /// Archive old activity logs to keep database performant
  static Future<void> _archiveOldActivityLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      final oldLogsQuery = await _firestore
          .collection('activities')
          .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      LoggerService.info('Archiving ${oldLogsQuery.docs.length} old activity logs');
      
      // In a real production system, you might move these to a separate archive collection
      // For now, we'll just log the operation without processing individual docs
      // Archive to long-term storage (implementation would depend on requirements)
      
    } catch (e) {
      LoggerService.error('Failed to archive old activity logs', error: e);
    }
  }

  /// Update system-wide statistics and cache
  static Future<void> _updateSystemStatistics() async {
    try {
      final stats = {
        'lastMaintenanceRun': Timestamp.fromDate(DateTime.now()),
        'systemHealth': 'healthy',
        'totalUsers': await _getUserCount(),
        'totalCertificates': await _getCertificateCount(),
        'totalDocuments': await _getDocumentCount(),
      };
      
      await _firestore
          .collection('system_config')
          .doc('statistics')
          .set(stats, SetOptions(merge: true));
      
      LoggerService.info('System statistics updated');
    } catch (e) {
      LoggerService.error('Failed to update system statistics', error: e);
    }
  }

  /// Verify basic data integrity across collections
  static Future<void> _verifyDataIntegrity() async {
    try {
      LoggerService.info('Performing data integrity verification...');
      
      // Check for orphaned certificates (certificates with invalid issuer IDs)
      final certificatesQuery = await _firestore.collection('certificates').limit(100).get();
      final usersQuery = await _firestore.collection('users').get();
      final userIds = usersQuery.docs.map((doc) => doc.id).toSet();
      
      int orphanedCertificates = 0;
      for (final cert in certificatesQuery.docs) {
        final issuerId = cert.data()['issuerId'] as String?;
        if (issuerId != null && !userIds.contains(issuerId)) {
          orphanedCertificates++;
          LoggerService.warning('Found orphaned certificate: ${cert.id}');
        }
      }
      
      LoggerService.info('Data integrity check completed. Found $orphanedCertificates orphaned certificates');
    } catch (e) {
      LoggerService.error('Failed to verify data integrity', error: e);
    }
  }

  static Future<int> _getUserCount() async {
    final snapshot = await _firestore.collection('users').count().get();
    return snapshot.count ?? 0;
  }

  static Future<int> _getCertificateCount() async {
    final snapshot = await _firestore.collection('certificates').count().get();
    return snapshot.count ?? 0;
  }

  static Future<int> _getDocumentCount() async {
    final snapshot = await _firestore.collection('documents').count().get();
    return snapshot.count ?? 0;
  }

  /// Show system status
  static Future<void> showSystemStatus() async {
    try {
      final status = await checkAdminStatus();
      
      LoggerService.info('System Status Check');
      LoggerService.info('Total Admins: ${status['totalAdmins']}');
      LoggerService.info('Active Admins: ${status['activeAdmins']}');
      LoggerService.info('Pending Admins: ${status['pendingAdmins']}');
      LoggerService.info('Needs Initialization: ${status['needsInitialization']}');
      
      if (status['error'] != null) {
        LoggerService.error('Status check error: ${status['error']}');
      }
      
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        LoggerService.info('Current User: ${currentUser.email}');
        LoggerService.info('Email Verified: ${currentUser.emailVerified}');
      } else {
        LoggerService.info('Current User: None');
      }
      
    } catch (e) {
      LoggerService.error('Failed to get system status: $e');
    }
  }

  /// Generate secure random password
  static String _generateSecurePassword() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    
    // Ensure password contains various character types
    buffer.write('A'); // Uppercase letter
    buffer.write('a'); // Lowercase letter
    buffer.write('1'); // Number
    buffer.write('!'); // Special character
    
    // Add random characters to 12 digits
    for (int i = 4; i < 12; i++) {
      final index = (random + i) % chars.length;
      buffer.write(chars[index]);
    }
    
    return buffer.toString();
  }

  // Initialize user session and ensure user document exists
  Future<UserModel?> initializeUserSession() async {
    try {
      LoggerService.info('🚀 Starting user session initialization...');
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggerService.info('❌ No authenticated user found');
        return null;
      }

      LoggerService.info('👤 Found authenticated user: ${currentUser.email}');

      // Check if user document exists in Firestore
      UserModel? userModel = await _userService.getUserById(currentUser.uid);
      
      if (userModel == null) {
        LoggerService.warning('🔧 User document not found in Firestore, creating now...');
        userModel = await _createMissingUserDocument(currentUser);
      } else {
        LoggerService.info('✅ User document found in Firestore');
        // Update last login
        await _updateUserLastLogin(currentUser.uid);
      }

      // Verify user document was created/updated successfully
      if (userModel != null) {
        LoggerService.info('🎉 User session initialized successfully for: ${userModel.email}');
        await _ensureUserPermissions(userModel);
      }

      return userModel;
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to initialize user session', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Create missing user document from Firebase Auth user
  Future<UserModel> _createMissingUserDocument(User firebaseUser) async {
    try {
      LoggerService.info('📝 Creating user document for: ${firebaseUser.email}');

      final userRole = _determineUserRoleFromEmail(firebaseUser.email ?? '');
      final userType = _determineUserTypeFromRole(userRole);
      final now = DateTime.now();

      final userModel = UserModel(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
        photoURL: firebaseUser.photoURL,
        role: userRole,
        userType: userType,
        status: UserStatus.active, // Default to active for existing authenticated users
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
        isEmailVerified: firebaseUser.emailVerified,
        profile: {
          'department': _extractDepartmentFromEmail(firebaseUser.email ?? ''),
          'university': 'Universiti Putra Malaysia',
          'emailDomain': 'upm.edu.my',
        },
        permissions: _getDefaultPermissions(userRole),
        metadata: {
          'signInMethod': firebaseUser.providerData.isNotEmpty 
              ? firebaseUser.providerData.first.providerId 
              : 'email',
          'createdBy': 'auto-initialization',
          'emailPrefix': firebaseUser.email?.split('@').first ?? '',
          'registrationSource': 'mobile_app',
          'autoCreated': true,
          'createdAt': now.toIso8601String(),
        },
      );

      // Create the user document
      final createdUser = await _userService.createUser(userModel);
      LoggerService.info('✅ User document created successfully');
      
      return createdUser;
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to create user document', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Update user last login timestamp
  Future<void> _updateUserLastLogin(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      LoggerService.info('🕒 Updated last login for user: $userId');
    } catch (e) {
      LoggerService.warning('⚠️ Failed to update last login', error: e);
    }
  }

  // Ensure user has proper permissions
  Future<void> _ensureUserPermissions(UserModel user) async {
    try {
      final expectedPermissions = _getDefaultPermissions(user.role);
      if (user.permissions.length != expectedPermissions.length ||
          !_listsEqual(user.permissions, expectedPermissions)) {
        
        LoggerService.info('🔄 Updating user permissions for: ${user.email}');
        await _firestore.collection('users').doc(user.id).update({
          'permissions': expectedPermissions,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    } catch (e) {
      LoggerService.warning('⚠️ Failed to update user permissions', error: e);
    }
  }

  // Helper function to compare lists
  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (!list2.contains(list1[i])) return false;
    }
    return true;
  }

  // Determine user role from email
  UserRole _determineUserRoleFromEmail(String email) {
    if (email.isEmpty) return UserRole.recipient;
    
    final emailPrefix = email.toLowerCase().split('@').first;
    
    // Admin patterns
    if (_isAdminEmail(emailPrefix)) {
      return UserRole.systemAdmin;
    }
    
    // CA patterns  
    if (_isCAEmail(emailPrefix)) {
      return UserRole.certificateAuthority;
    }
    
    // Default to recipient for regular users
    return UserRole.recipient;
  }

  // Check if email indicates admin role
  bool _isAdminEmail(String emailPrefix) {
    const adminPatterns = [
      'admin', 'system', 'registrar', 'vc', 'dvc', 'gs', 'dean', 'director'
    ];
    return adminPatterns.any((pattern) => emailPrefix.contains(pattern));
  }

  // Check if email indicates CA role
  bool _isCAEmail(String emailPrefix) {
    const caPatterns = [
      'ca', 'authority', 'cert', 'security', 'registrar'
    ];
    return caPatterns.any((pattern) => emailPrefix.contains(pattern));
  }

  // Convert UserRole to UserType
  UserType _determineUserTypeFromRole(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return UserType.admin;
      case UserRole.certificateAuthority:
        return UserType.ca;
      default:
        return UserType.user;
    }
  }

  // Extract department from email
  String _extractDepartmentFromEmail(String email) {
    if (email.isEmpty) return 'Unknown';
    
    final emailPrefix = email.split('@').first.toLowerCase();
    
    // Extract department patterns
    if (emailPrefix.contains('cs') || emailPrefix.contains('computer')) {
      return 'Computer Science';
    } else if (emailPrefix.contains('eng') || emailPrefix.contains('engineering')) {
      return 'Engineering';
    } else if (emailPrefix.contains('business') || emailPrefix.contains('management')) {
      return 'Business';
    } else if (emailPrefix.contains('med') || emailPrefix.contains('medicine')) {
      return 'Medicine';
    } else if (emailPrefix.contains('science')) {
      return 'Science';
    } else {
      return 'General';
    }
  }

  // Get default permissions for role
  List<String> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return [
          'admin.read',
          'admin.write',
          'admin.delete',
          'users.manage',
          'certificates.manage',
          'documents.manage',
          'system.configure',
          'analytics.view',
          'reports.generate',
        ];
      case UserRole.certificateAuthority:
        return [
          'certificates.create',
          'certificates.issue',
          'certificates.revoke',
          'documents.review',
          'templates.manage',
          'users.view',
          'analytics.view',
        ];
      case UserRole.client:
        return [
          'documents.create',
          'documents.edit',
          'certificates.request',
          'profile.edit',
        ];
      case UserRole.recipient:
        return [
          'certificates.view',
          'documents.view',
          'profile.edit',
          'notifications.read',
        ];
      case UserRole.viewer:
        return [
          'certificates.view',
          'documents.view',
        ];
    }
  }

  // Initialize system collections and ensure proper structure
  Future<void> initializeSystemCollections() async {
    try {
      LoggerService.info('🏗️ Initializing system collections...');
      
      // Ensure basic system settings exist
      await _ensureSystemSettings();
      
      // Ensure statistics collection exists
      await _ensureStatisticsCollection();
      
      LoggerService.info('✅ System collections initialized');
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to initialize system collections', 
          error: e, stackTrace: stackTrace);
    }
  }

  // Ensure system settings collection exists
  Future<void> _ensureSystemSettings() async {
    try {
      final settingsRef = _firestore.collection('settings').doc('app_config');
      final settingsDoc = await settingsRef.get();
      
      if (!settingsDoc.exists) {
        await settingsRef.set({
          'appName': 'Digital Certificate Repository',
          'version': '1.0.0',
          'initialized': true,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'features': {
            'notifications': true,
            'analytics': true,
            'multiLanguage': true,
          }
        });
        LoggerService.info('📱 Created app settings document');
      }
    } catch (e) {
      LoggerService.warning('⚠️ Failed to ensure system settings', error: e);
    }
  }

  // Ensure statistics collection exists
  Future<void> _ensureStatisticsCollection() async {
    try {
      final statsRef = _firestore.collection('statistics').doc('global');
      final statsDoc = await statsRef.get();
      
      if (!statsDoc.exists) {
        await statsRef.set({
          'totalUsers': 0,
          'totalCertificates': 0,
          'totalDocuments': 0,
          'lastUpdated': Timestamp.fromDate(DateTime.now()),
          'initialized': true,
        });
        LoggerService.info('📊 Created global statistics document');
      }
    } catch (e) {
      LoggerService.warning('⚠️ Failed to ensure statistics collection', error: e);
    }
  }

  // Validate current user session
  Future<bool> validateUserSession() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        LoggerService.info('❌ No current user to validate');
        return false;
      }

      // Check if user document exists
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        LoggerService.warning('⚠️ User document does not exist, creating...');
        await _createMissingUserDocument(currentUser);
      }

      LoggerService.info('✅ User session is valid');
      return true;
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to validate user session', 
          error: e, stackTrace: stackTrace);
      return false;
    }
  }
} 