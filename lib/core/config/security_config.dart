import 'dart:io';
import 'package:flutter/foundation.dart';

class SecurityConfig {
  // Network Security Headers
  static const Map<String, String> securityHeaders = {
    'Content-Security-Policy': "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  };
  
  // Encryption settings
  static const String encryptionAlgorithm = 'AES-256-GCM';
  static const int keyLength = 256;
  static const int ivLength = 16;
  
  // Password requirements
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumbers = true;
  static const bool requireSpecialChars = true;
  
  // Session security
  static const Duration sessionTimeout = Duration(hours: 8);
  static const Duration tokenRefreshInterval = Duration(minutes: 30);
  static const int maxConcurrentSessions = 3;
  
  // Rate limiting
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 30);
  static const int maxRequestsPerMinute = 60;
  static const int maxUploadRequestsPerHour = 10;
  
  // File upload security
  static const List<String> allowedFileTypes = [
    'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  static const List<String> blockedFileTypes = [
    'exe', 'bat', 'cmd', 'com', 'pif', 'scr', 'vbs', 'js', 'jar', 
    'php', 'asp', 'aspx', 'jsp', 'pl', 'py', 'rb', 'sh'
  ];
  
  static const int maxFileSize = 20 * 1024 * 1024; // 20MB
  static const List<String> allowedMimeTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  ];
  
  // Domain restrictions
  static const List<String> allowedDomains = [
    'upm.edu.my',
    'firebase.google.com',
    'firebaseapp.com',
    'googleapis.com',
    'gstatic.com',
  ];
  
  // Content security
  static const List<String> allowedSchemes = ['https'];
  static const bool enforceHttps = true;
  static const bool validateSSLCertificates = true;
  
  // API security
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Data sanitization patterns
  static final RegExp sqlInjectionPattern = RegExp(
    r'(\b(ALTER|CREATE|DELETE|DROP|EXEC(UTE){0,1}|INSERT( +INTO){0,1}|MERGE|SELECT|UPDATE|UNION( +ALL){0,1})\b)',
    caseSensitive: false,
  );
  
  static final RegExp xssPattern = RegExp(
    r'(<script[^>]*>.*?</script>|javascript:|on\w+\s*=)',
    caseSensitive: false,
  );
  
  static final RegExp emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@upm\.edu\.my$',
    caseSensitive: false,
  );
  
  // Security validation methods
  static bool isValidEmail(String email) {
    return emailPattern.hasMatch(email);
  }
  
  static bool isSecurePassword(String password) {
    if (password.length < minPasswordLength) return false;
    if (password.length > maxPasswordLength) return false;
    
    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) return false;
    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) return false;
    if (requireNumbers && !password.contains(RegExp(r'[0-9]'))) return false;
    if (requireSpecialChars && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    
    return true;
  }
  
  static bool isValidFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return allowedFileTypes.contains(extension) && !blockedFileTypes.contains(extension);
  }
  
  static bool isValidFileSize(int fileSize) {
    return fileSize <= maxFileSize && fileSize > 0;
  }
  
  static bool isValidMimeType(String mimeType) {
    return allowedMimeTypes.contains(mimeType.toLowerCase());
  }
  
  static String sanitizeInput(String input) {
    // Remove potential SQL injection patterns
    String sanitized = input.replaceAll(sqlInjectionPattern, '');
    
    // Remove potential XSS patterns
    sanitized = sanitized.replaceAll(xssPattern, '');
    
    // Remove null bytes and control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    
    // Trim whitespace
    sanitized = sanitized.trim();
    
    return sanitized;
  }
  
  static bool isValidDomain(String domain) {
    return allowedDomains.any((allowed) => domain.endsWith(allowed));
  }
  
  static bool isSecureUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    
    // Check scheme
    if (enforceHttps && !allowedSchemes.contains(uri.scheme)) return false;
    
    // Check domain
    if (!isValidDomain(uri.host)) return false;
    
    return true;
  }
  
  // Get secure HTTP client configuration
  static HttpClient getSecureHttpClient() {
    final client = HttpClient();
    
    // Configure security context
    client.badCertificateCallback = (cert, host, port) {
      return !validateSSLCertificates || kDebugMode;
    };
    
    // Set timeouts
    client.connectionTimeout = apiTimeout;
    client.idleTimeout = apiTimeout;
    
    return client;
  }
  
  // Security audit methods
  static Map<String, dynamic> getSecurityConfiguration() {
    return {
      'enforceHttps': enforceHttps,
      'validateSSLCertificates': validateSSLCertificates,
      'minPasswordLength': minPasswordLength,
      'sessionTimeout': sessionTimeout.inMinutes,
      'maxLoginAttempts': maxLoginAttempts,
      'allowedFileTypes': allowedFileTypes,
      'maxFileSize': maxFileSize,
      'allowedDomains': allowedDomains,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
  
  // Environment-specific configurations
  static Map<String, String> getProductionHeaders() {
    if (kReleaseMode) {
      return securityHeaders;
    }
    return {};
  }
  
  static bool isProductionEnvironment() {
    return kReleaseMode && !kDebugMode;
  }
} 