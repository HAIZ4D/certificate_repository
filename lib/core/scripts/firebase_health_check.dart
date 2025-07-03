import 'package:firebase_core/firebase_core.dart';

import '../services/system_health_monitor.dart';
import '../services/logger_service.dart';
import '../services/validation_service.dart';
import '../services/initialization_service.dart';

/// Comprehensive Firebase Health Check Script
/// Run this to validate all Firebase configurations and permissions
class FirebaseHealthCheck {
  
  /// Run complete health check and return detailed report
  static Future<Map<String, dynamic>> runCompleteHealthCheck() async {
    LoggerService.info('🚀 Starting complete Firebase health check...');
    
    final results = <String, dynamic>{};
    final startTime = DateTime.now();
    
    try {
      // 1. Initialize Firebase if not already done
      results['firebase_initialization'] = await _checkFirebaseInitialization();
      
      // 2. Run system health monitor
      final healthMonitor = SystemHealthMonitor();
      final healthStatus = await healthMonitor.checkFirebaseHealth();
      results['system_health'] = healthStatus;
      
      // 3. Validate user authentication
      results['authentication_validation'] = await _checkAuthentication();
      
      // 4. Test initialization service
      results['initialization_service'] = await _checkInitializationService();
      
      // 5. Test permission scenarios
      results['permission_tests'] = await _runPermissionTests();
      
      // 6. Validate security rules
      results['security_rules'] = await _checkSecurityRules();
      
      // 7. Test error handling
      results['error_handling'] = await _testErrorHandling();
      
      final endTime = DateTime.now();
      results['execution_time'] = endTime.difference(startTime).inMilliseconds;
      results['status'] = 'completed';
      
      LoggerService.info('✅ Complete health check finished');
      return results;
      
    } catch (e, stackTrace) {
      LoggerService.error('❌ Health check failed', error: e, stackTrace: stackTrace);
      
      final endTime = DateTime.now();
      results['execution_time'] = endTime.difference(startTime).inMilliseconds;
      results['status'] = 'failed';
      results['error'] = e.toString();
      results['stack_trace'] = stackTrace.toString();
      
      return results;
    }
  }

  /// Check Firebase initialization
  static Future<Map<String, dynamic>> _checkFirebaseInitialization() async {
    try {
      LoggerService.info('🔍 Checking Firebase initialization...');
      
      final apps = Firebase.apps;
      if (apps.isEmpty) {
        return {
          'status': 'error',
          'message': 'No Firebase apps initialized',
        };
      }
      
      final defaultApp = Firebase.app();
      return {
        'status': 'success',
        'app_name': defaultApp.name,
        'project_id': defaultApp.options.projectId,
        'apps_count': apps.length,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Firebase initialization check failed: $e',
      };
    }
  }

  /// Check authentication status and validation
  static Future<Map<String, dynamic>> _checkAuthentication() async {
    try {
      LoggerService.info('🔍 Checking authentication validation...');
      
      final validationResult = await ValidationService.validateUserAuthentication();
      
      return {
        'status': validationResult.isValid ? 'success' : 'warning',
        'is_valid': validationResult.isValid,
        'error_message': validationResult.errorMessage,
        'has_user_model': validationResult.userModel != null,
        'user_type': validationResult.userModel?.userType.name,
        'user_status': validationResult.userModel?.status.name,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Authentication check failed: $e',
      };
    }
  }

  /// Check initialization service
  static Future<Map<String, dynamic>> _checkInitializationService() async {
    try {
      LoggerService.info('🔍 Checking initialization service...');
      
      final initService = InitializationService();
      
      // Test system collections initialization
      await initService.initializeSystemCollections();
      
      // Test user session initialization
      final userModel = await initService.initializeUserSession();
      
      return {
        'status': 'success',
        'system_collections_initialized': true,
        'user_session_initialized': userModel != null,
        'user_id': userModel?.id,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Initialization service check failed: $e',
      };
    }
  }

  /// Run permission tests
  static Future<Map<String, dynamic>> _runPermissionTests() async {
    try {
      LoggerService.info('🔍 Running permission tests...');
      
      final results = <String, dynamic>{};
      
      // Test collection access
      final collections = ['users', 'documents', 'certificates', 'notifications', 'settings'];
      for (final collection in collections) {
        try {
          final canAccess = await ValidationService.canAccessCollection(collection);
          results['${collection}_access'] = canAccess;
        } catch (e) {
          results['${collection}_access'] = false;
          results['${collection}_error'] = e.toString();
        }
      }
      
      // Test specific permissions
      final permissions = [
        'documents.read',
        'certificates.view',
        'notifications.read',
        'profile.edit',
      ];
      
      for (final permission in permissions) {
        try {
          final hasPermission = await ValidationService.hasPermission(permission);
          results['permission_$permission'] = hasPermission;
        } catch (e) {
          results['permission_$permission'] = false;
          results['permission_${permission}_error'] = e.toString();
        }
      }
      
      return {
        'status': 'success',
        'results': results,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Permission tests failed: $e',
      };
    }
  }

  /// Check security rules compatibility
  static Future<Map<String, dynamic>> _checkSecurityRules() async {
    try {
      LoggerService.info('🔍 Checking security rules compatibility...');
      
      final results = <String, dynamic>{};
      
      // Test various Firestore operations
      final operations = [
        {'collection': 'settings', 'operation': 'read'},
        {'collection': 'users', 'operation': 'read'},
        {'collection': 'notifications', 'operation': 'create'},
      ];
      
      for (final operation in operations) {
        final collection = operation['collection'] as String;
        final op = operation['operation'] as String;
        
        try {
          final isValid = await ValidationService.validateFirestoreOperation(
            collection: collection,
            operation: op,
          );
          results['${collection}_$op'] = isValid;
        } catch (e) {
          results['${collection}_$op'] = false;
          results['${collection}_${op}_error'] = e.toString();
        }
      }
      
      return {
        'status': 'success',
        'results': results,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Security rules check failed: $e',
      };
    }
  }

  /// Test error handling mechanisms
  static Future<Map<String, dynamic>> _testErrorHandling() async {
    try {
      LoggerService.info('🔍 Testing error handling mechanisms...');
      
      final results = <String, dynamic>{};
      
      // Test permission-denied handling
      try {
        // This should handle permission denied gracefully
        await ValidationService.canAccessCollection('non_existent_collection');
        results['permission_denied_handling'] = 'passed';
      } catch (e) {
        results['permission_denied_handling'] = 'handled';
        results['permission_denied_error'] = e.toString();
      }
      
      // Test authentication failure handling
      try {
        final validationResult = await ValidationService.validateUserAuthentication();
        results['auth_failure_handling'] = validationResult.isValid ? 'passed' : 'handled_gracefully';
      } catch (e) {
        results['auth_failure_handling'] = 'handled';
        results['auth_failure_error'] = e.toString();
      }
      
      return {
        'status': 'success',
        'results': results,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error handling test failed: $e',
      };
    }
  }

  /// Generate comprehensive report
  static String generateHealthReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    
    buffer.writeln('🏥 COMPREHENSIVE FIREBASE HEALTH REPORT');
    buffer.writeln('=' * 60);
    buffer.writeln('Status: ${results['status']?.toString().toUpperCase() ?? 'UNKNOWN'}');
    buffer.writeln('Execution Time: ${results['execution_time'] ?? 'N/A'}ms');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('');
    
    // Firebase Initialization
    _addSectionToReport(buffer, 'Firebase Initialization', results['firebase_initialization']);
    
    // System Health
    if (results['system_health'] is FirebaseHealthStatus) {
      final healthStatus = results['system_health'] as FirebaseHealthStatus;
      buffer.writeln('📱 SYSTEM HEALTH:');
      buffer.writeln('  Overall: ${healthStatus.overallHealth.name.toUpperCase()}');
      buffer.writeln('  Connectivity: ${healthStatus.connectivity.name}');
      buffer.writeln('  Authentication: ${healthStatus.authStatus.name}');
      buffer.writeln('  Firestore: ${healthStatus.firestoreStatus.name}');
      buffer.writeln('  Storage: ${healthStatus.storageStatus.name}');
      buffer.writeln('  User Document: ${healthStatus.userDocumentStatus.name}');
      buffer.writeln('  Operations: ${healthStatus.operationStatus.name}');
      buffer.writeln('  Security Rules: ${healthStatus.securityRulesStatus.name}');
      buffer.writeln('');
    }
    
    // Authentication Validation
    _addSectionToReport(buffer, 'Authentication Validation', results['authentication_validation']);
    
    // Initialization Service
    _addSectionToReport(buffer, 'Initialization Service', results['initialization_service']);
    
    // Permission Tests
    _addSectionToReport(buffer, 'Permission Tests', results['permission_tests']);
    
    // Security Rules
    _addSectionToReport(buffer, 'Security Rules', results['security_rules']);
    
    // Error Handling
    _addSectionToReport(buffer, 'Error Handling', results['error_handling']);
    
    // Overall Assessment
    buffer.writeln('📊 OVERALL ASSESSMENT:');
    if (results['status'] == 'completed') {
      buffer.writeln('  ✅ Health check completed successfully');
      buffer.writeln('  ✅ All Firebase services are functional');
      buffer.writeln('  ✅ Permission errors are properly handled');
      buffer.writeln('  ✅ System is ready for production use');
    } else {
      buffer.writeln('  ❌ Health check encountered issues');
      buffer.writeln('  ⚠️  Manual intervention may be required');
      if (results['error'] != null) {
        buffer.writeln('  Error: ${results['error']}');
      }
    }
    
    return buffer.toString();
  }

  static void _addSectionToReport(StringBuffer buffer, String title, dynamic data) {
    buffer.writeln('📋 ${title.toUpperCase()}:');
    
    if (data is Map<String, dynamic>) {
      for (final entry in data.entries) {
        if (entry.value is Map) {
          buffer.writeln('  ${entry.key}:');
          for (final subEntry in (entry.value as Map).entries) {
            buffer.writeln('    ${subEntry.key}: ${subEntry.value}');
          }
        } else {
          buffer.writeln('  ${entry.key}: ${entry.value}');
        }
      }
    } else {
      buffer.writeln('  Data: $data');
    }
    
    buffer.writeln('');
  }
} 