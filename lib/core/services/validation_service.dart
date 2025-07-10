import '../config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';
import 'logger_service.dart';

class ValidationService {
  static ValidationService? _instance;
  
  ValidationService._internal();
  
  factory ValidationService() {
    _instance ??= ValidationService._internal();
    return _instance!;
  }

  /// Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Basic email format validation
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Invalid email format';
    }
    
    return null;
  }

  /// UPM email validation
  static String? validateUpmEmail(String? value) {
    final basicValidation = validateEmail(value);
    if (basicValidation != null) return basicValidation;
    
    if (!AppConfig.isValidUpmEmail(value!)) {
      return 'Please use your UPM email address (@upm.edu.my)';
    }
    
    return null;
  }

  /// Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < AppConfig.passwordMinLength) {
      return 'Password must be at least ${AppConfig.passwordMinLength} characters';
    }
    
    return null;
  }

  /// Required field validation
  static String? validateRequired(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  /// Name validation
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    
    return null;
  }

  /// File size validation
  static String? validateFileSize(int? sizeInBytes, {int? maxSizeInMB}) {
    if (sizeInBytes == null) {
      return 'File size information not available';
    }
    
    final maxSize = (maxSizeInMB ?? AppConfig.maxFileSizeMB) * 1024 * 1024;
    
    if (sizeInBytes > maxSize) {
      return 'File size exceeds ${maxSizeInMB ?? AppConfig.maxFileSizeMB}MB limit';
    }
    
    return null;
  }

  /// Safe string validation
  static String sanitizeInput(String input) {
    return input.trim();
  }

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Enhanced authentication validation
  static Future<AuthValidationResult> validateUserAuthentication() async {
    try {
      final currentUser = _auth.currentUser;
      
      if (currentUser == null) {
        LoggerService.warning('❌ No authenticated Firebase user found');
        return AuthValidationResult(
          isValid: false,
          errorMessage: 'User not authenticated',
          userModel: null,
        );
      }

      LoggerService.info('🔍 Validating user authentication for: ${currentUser.email}');

      // Check if user document exists in Firestore
      UserModel? userModel;
      try {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        
        if (!userDoc.exists) {
          LoggerService.warning('⚠️ User document not found in Firestore for: ${currentUser.uid}');
          // Try to create missing user document
          userModel = await _createMissingUserDocument(currentUser);
        } else {
          userModel = UserModel.fromFirestore(userDoc);
          LoggerService.info('✅ User document found and validated');
        }
      } catch (e) {
        LoggerService.error('❌ Failed to fetch user document', error: e);
        return AuthValidationResult(
          isValid: false,
          errorMessage: 'Failed to validate user document: ${e.toString()}',
          userModel: null,
        );
      }

      // Validate user status
      if (userModel?.status == UserStatus.suspended) {
        LoggerService.warning('🚫 User account is suspended');
        return AuthValidationResult(
          isValid: false,
          errorMessage: 'Your account has been suspended. Please contact administrator.',
          userModel: userModel,
        );
      }

      if (userModel?.status == UserStatus.pending) {
        LoggerService.warning('⏳ User account is pending approval');
        return AuthValidationResult(
          isValid: false,
          errorMessage: 'Your account is pending approval. Please wait for confirmation.',
          userModel: userModel,
        );
      }

      LoggerService.info('✅ User authentication validated successfully');
      return AuthValidationResult(
        isValid: true,
        errorMessage: null,
        userModel: userModel,
      );

    } catch (e, stackTrace) {
      LoggerService.error('❌ Authentication validation failed', error: e, stackTrace: stackTrace);
      return AuthValidationResult(
        isValid: false,
        errorMessage: 'Authentication validation error: ${e.toString()}',
        userModel: null,
      );
    }
  }

  // Check if user has permission for a specific action
  static Future<bool> hasPermission(String permission, [UserModel? userModel]) async {
    try {
      final validationResult = await validateUserAuthentication();
      if (!validationResult.isValid) {
        LoggerService.warning('❌ Cannot check permission - user not authenticated');
        return false;
      }

      final user = userModel ?? validationResult.userModel;
      if (user == null) {
        LoggerService.warning('❌ Cannot check permission - no user model available');
        return false;
      }

      // Admin users have all permissions
      if (user.userType == UserType.admin) {
        LoggerService.info('✅ Admin user - permission granted for: $permission');
        return true;
      }

      // Check specific permission
      final hasPermission = user.permissions.contains(permission);
      LoggerService.info('🔐 Permission check for "$permission": ${hasPermission ? "GRANTED" : "DENIED"}');
      
      return hasPermission;
    } catch (e) {
      LoggerService.error('❌ Permission check failed', error: e);
      return false;
    }
  }

  // Validate access to a specific collection
  static Future<bool> canAccessCollection(String collection, [String? action]) async {
    try {
      final validationResult = await validateUserAuthentication();
      if (!validationResult.isValid) return false;

      final user = validationResult.userModel;
      if (user == null) return false;

      // Admin can access everything
      if (user.userType == UserType.admin) {
        LoggerService.info('✅ Admin access granted for collection: $collection');
        return true;
      }

      // Define collection access rules
      switch (collection) {
        case 'notifications':
          return true; // All authenticated users can access their notifications
        case 'documents':
          return user.userType == UserType.ca || user.userType == UserType.user;
        case 'certificates':
          return true; // All users can view certificates
        case 'users':
          return user.userType == UserType.admin; // Only admins can access user collection
        case 'statistics':
          return true; // All users can view basic statistics
        case 'settings':
          return true; // All users can read basic settings
        default:
          LoggerService.warning('⚠️ Unknown collection access check: $collection');
          return false;
      }
    } catch (e) {
      LoggerService.error('❌ Collection access validation failed', error: e);
      return false;
    }
  }

  // Create missing user document for authenticated Firebase user
  static Future<UserModel> _createMissingUserDocument(User firebaseUser) async {
    try {
      LoggerService.info('🔧 Creating missing user document for: ${firebaseUser.email}');

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
        status: UserStatus.active, // Default to active for existing Firebase users
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
          'createdBy': 'auto-validation',
          'emailPrefix': firebaseUser.email?.split('@').first ?? '',
          'autoCreated': true,
          'createdAt': now.toIso8601String(),
        },
      );

      // Create the user document
      await _firestore.collection('users').doc(firebaseUser.uid).set(userModel.toFirestore());
      LoggerService.info('✅ Missing user document created successfully');
      
      return userModel;
    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to create missing user document', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Helper methods
  static UserRole _determineUserRoleFromEmail(String email) {
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

  static bool _isAdminEmail(String emailPrefix) {
    const adminPatterns = [
      'admin', 'system', 'registrar', 'vc', 'dvc', 'gs', 'dean', 'director'
    ];
    return adminPatterns.any((pattern) => emailPrefix.contains(pattern));
  }

  static bool _isCAEmail(String emailPrefix) {
    const caPatterns = [
      'ca', 'authority', 'cert', 'security', 'registrar'
    ];
    return caPatterns.any((pattern) => emailPrefix.contains(pattern));
  }

  static UserType _determineUserTypeFromRole(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return UserType.admin;
      case UserRole.certificateAuthority:
        return UserType.ca;
      default:
        return UserType.user;
    }
  }

  static String _extractDepartmentFromEmail(String email) {
    if (email.isEmpty) return 'Unknown';
    
    final emailPrefix = email.split('@').first.toLowerCase();
    
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

  static List<String> _getDefaultPermissions(UserRole role) {
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

  // Validate Firestore operation before execution
  static Future<bool> validateFirestoreOperation({
    required String collection,
    required String operation, // 'read', 'write', 'create', 'update', 'delete'
    String? documentId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final canAccess = await canAccessCollection(collection, operation);
      if (!canAccess) {
        LoggerService.warning('🚫 Access denied for $operation on $collection');
        return false;
      }

      LoggerService.info('✅ Firestore operation validated: $operation on $collection');
      return true;
    } catch (e) {
      LoggerService.error('❌ Firestore operation validation failed', error: e);
      return false;
    }
  }
}

// Result class for authentication validation
class AuthValidationResult {
  final bool isValid;
  final String? errorMessage;
  final UserModel? userModel;

  AuthValidationResult({
    required this.isValid,
    this.errorMessage,
    this.userModel,
  });
} 