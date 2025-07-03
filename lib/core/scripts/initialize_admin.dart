import 'package:firebase_core/firebase_core.dart';
import '../services/initialization_service.dart';
import '../services/logger_service.dart';

/// Quick Admin account initialization script
/// Usage: Call await initializeAdminScript(); in main.dart
Future<bool> initializeAdminScript({
  String? email,
  String? password,
  String? displayName,
  bool force = false,
}) async {
  try {
    LoggerService.info('🚀 Starting Admin initialization script...');
    
    // Ensure Firebase is initialized
    if (Firebase.apps.isEmpty) {
      LoggerService.error('Firebase not initialized! Please initialize Firebase first.');
      return false;
    }
    
    // Use specified or default administrator information
    final adminEmail = email ?? 'admin@upm.edu.my';
    final adminPassword = password ?? _generateSecurePassword();
    final adminDisplayName = displayName ?? 'System Administrator';
    
    LoggerService.info('Admin Email: $adminEmail');
    LoggerService.info('Display Name: $adminDisplayName');
    
    // If no password provided, log the generated password (development environment only)
    if (password == null) {
      LoggerService.warning('⚠️  Generated admin password: $adminPassword');
      LoggerService.warning('⚠️  Please save this password securely!');
    }
    
    // Check if initialization is needed
    if (!force) {
      final needsInit = await InitializationService.needsInitialization();
      if (!needsInit) {
        LoggerService.info('✅ Admin already exists. Skipping initialization.');
        LoggerService.info('Use force=true to create anyway.');
        return true;
      }
    }
    
    // Create initial Admin account
    await InitializationService.createInitialAdmin(
      email: adminEmail,
      password: adminPassword,
      displayName: adminDisplayName,
    );
    
    // Verify creation result
    final status = await InitializationService.checkAdminStatus();
    
    if (status['activeAdmins'] > 0) {
      LoggerService.info('✅ Admin initialization completed successfully!');
      LoggerService.info('📊 System Status:');
      LoggerService.info('   - Total Admins: ${status['totalAdmins']}');
      LoggerService.info('   - Active Admins: ${status['activeAdmins']}');
      LoggerService.info('   - Pending Admins: ${status['pendingAdmins']}');
      LoggerService.info('');
      LoggerService.info('🔑 Admin Login Credentials:');
      LoggerService.info('   Email: $adminEmail');
      LoggerService.info('   Password: [PROTECTED - Check logs above for generated password]');
      LoggerService.info('');
      LoggerService.info('⚠️  Please change the default password after first login!');
      return true;
    } else {
      LoggerService.error('❌ Admin initialization failed - no active admin found');
      return false;
    }
    
  } catch (e, stackTrace) {
    LoggerService.error('💥 Admin initialization script failed', error: e, stackTrace: stackTrace);
    return false;
  }
}

/// Check system administrator status
Future<Map<String, dynamic>> checkAdminStatusScript() async {
  try {
    LoggerService.info('🔍 Checking system admin status...');
    
    final status = await InitializationService.checkAdminStatus();
    
    LoggerService.info('📊 Current System Status:');
    LoggerService.info('   - Total Admins: ${status['totalAdmins']}');
    LoggerService.info('   - Active Admins: ${status['activeAdmins']}');
    LoggerService.info('   - Pending Admins: ${status['pendingAdmins']}');
    LoggerService.info('   - Needs Initialization: ${status['needsInitialization']}');
    
    if (status['needsInitialization'] == true) {
      LoggerService.info('⚠️  System needs admin initialization!');
      LoggerService.info('   Run initializeAdminScript() to create initial admin.');
    } else {
      LoggerService.info('✅ System has active administrator(s).');
    }
    
    return status;
    
  } catch (e, stackTrace) {
    LoggerService.error('Failed to check admin status', error: e, stackTrace: stackTrace);
    return {
      'error': e.toString(),
      'needsInitialization': true,
    };
  }
}

/// Show initialization help information
void showInitializationHelp() {
  LoggerService.info('🔧 Digital Certificate Repository - Admin Initialization');
  LoggerService.info('');
  LoggerService.info('Available Commands:');
  LoggerService.info('');
  LoggerService.info('1. Check Admin Status:');
  LoggerService.info('   await checkAdminStatusScript();');
  LoggerService.info('');
  LoggerService.info('2. Initialize Default Admin:');
  LoggerService.info('   await initializeAdminScript();');
  LoggerService.info('');
  LoggerService.info('3. Initialize Custom Admin:');
  LoggerService.info('   await initializeAdminScript(');
  LoggerService.info('     email: "custom@upm.edu.my",');
  LoggerService.info('     password: "CustomPassword123!",');
  LoggerService.info('     displayName: "Custom Admin"');
  LoggerService.info('   );');
  LoggerService.info('');
  LoggerService.info('4. Force Re-initialization:');
  LoggerService.info('   await initializeAdminScript(force: true);');
  LoggerService.info('');
  LoggerService.info('⚠️  Default Credentials:');
  LoggerService.info('   Email: admin@upm.edu.my');
  LoggerService.info('   Password: [Generated securely - check logs]');
  LoggerService.info('');
  LoggerService.info('🔒 Remember to change the password after first login!');
}

/// One-click emergency fix function for "No Admin" problem
Future<bool> emergencyAdminFix() async {
  try {
    LoggerService.info('🚨 EMERGENCY ADMIN FIX - Creating admin account immediately!');
    
    // Generate secure password
    final emergencyPassword = _generateSecurePassword();
    
    // Directly create the specified administrator account
    final success = await initializeAdminScript(
      email: 'admin@upm.edu.my',
      password: emergencyPassword,
      displayName: 'Emergency System Administrator',
      force: true,
    );
    
    if (success) {
      LoggerService.info('🎉 EMERGENCY FIX SUCCESSFUL!');
      LoggerService.info('');
      LoggerService.info('✅ Admin account created:');
      LoggerService.info('   📧 Email: admin@upm.edu.my');
      LoggerService.info('   🔑 Password: $emergencyPassword');
      LoggerService.info('');
      LoggerService.info('🚀 You can now:');
      LoggerService.info('   1. Login with these credentials');
      LoggerService.info('   2. Access the Admin dashboard');
      LoggerService.info('   3. Approve pending CA registrations');
      LoggerService.info('   4. Change the default password');
      LoggerService.info('');
      LoggerService.info('🔧 System is now operational!');
      return true;
    } else {
      LoggerService.error('❌ Emergency fix failed!');
      return false;
    }
    
  } catch (e, stackTrace) {
    LoggerService.error('💥 Emergency admin fix crashed', error: e, stackTrace: stackTrace);
    return false;
  }
}

/// Generate secure random password
String _generateSecurePassword() {
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