class AppConfig {
  // ⚠️ SECURITY NOTE: 
  // This file contains application configuration.
  // Sensitive data like passwords should NEVER be hardcoded here.
  // Use environment variables or secure storage for sensitive information.
  
  // Application Information
  static const String appName = 'Digital Certificate Repository';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'UPM Digital Certificate Management System';
  
  // University Information
  static const String universityName = 'Universiti Putra Malaysia';
  static const String universityCode = 'UPM';
  static const String upmEmailDomain = '@upm.edu.my';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String certificatesCollection = 'certificates';
  static const String documentsCollection = 'documents';
  static const String templatesCollection = 'certificate_templates';
  static const String transactionsCollection = 'certificate_transactions';
  static const String accessLogsCollection = 'document_access_logs';
  static const String notificationsCollection = 'notifications';
  static const String settingsCollection = 'app_settings';
  static const String activityCollection = 'activities';
  
  // Admin System Collections
  static const String adminLogsCollection = 'admin_logs';
  static const String systemConfigCollection = 'system_config';
  static const String backupJobsCollection = 'backup_jobs';
  static const String auditTrailCollection = 'audit_trail';
  
  // File Storage
  static const String documentsStoragePath = 'documents';
  static const String certificatesStoragePath = 'certificates';
  static const String templatesStoragePath = 'templates';
  static const String profileImagesStoragePath = 'profile_images';
  
  // File Size Limits (in bytes)
  static const int maxDocumentSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxCertificateSize = 20 * 1024 * 1024; // 20MB
  
  // File Size Limits (in MB for easier reference)
  static const int maxFileSizeMB = 10;
  static const int maxImageSizeMB = 5;
  static const int maxCertificateSizeMB = 20;
  
  // Supported File Types
  static const List<String> supportedDocumentTypes = [
    'pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'
  ];
  
  static const List<String> supportedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  
  // Application URLs
  static const String baseUrl = 'https://upm-digital-certificates.web.app';
  static const String verificationBaseUrl = '$baseUrl/verify';
  static const String publicBaseUrl = '$baseUrl/public';
  
  // Security Configuration
  static const int maxLoginAttempts = 5;
  static const int lockoutDurationMinutes = 30;
  static const int sessionTimeoutMinutes = 480; // 8 hours
  static const int passwordMinLength = 8;
  
  // Certificate Configuration
  static const int defaultCertificateValidityDays = 365;
  static const int maxCertificateValidityDays = 3650; // 10 years
  static const String defaultCertificateFormat = 'PDF';
  
  // Share Token Configuration
  static const int defaultShareTokenValidityDays = 7;
  static const int maxShareTokenValidityDays = 90;
  static const int maxShareTokenAccess = 100;
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Rate Limiting
  static const int maxRequestsPerMinute = 60;
  static const int maxUploadRequestsPerHour = 10;
  
  // Notification Configuration
  static const bool enablePushNotifications = true;
  static const bool enableEmailNotifications = true;
  static const String defaultNotificationTopic = 'upm_certificates';
  
  // Development Configuration
  static const bool isDebugMode = true; // Temporarily enable debug mode
  static const bool enableDetailedLogging = true; // Temporarily enable detailed logging
  static const bool enablePerformanceLogging = false; // Disable in production
  static const bool enableAnalytics = true;
  
  // Cache Configuration
  static const int cacheValidityMinutes = 15;
  static const int maxCacheEntries = 1000;
  
  // Backup Configuration
  static const int backupIntervalDays = 7;
  static const int maxBackupRetentionDays = 90;
  
  // Helper Methods
  static bool isValidUpmEmail(String email) {
    return email.toLowerCase().endsWith(upmEmailDomain);
  }
  
  static bool isValidFileSize(int fileSize, String fileType) {
    if (supportedImageTypes.contains(fileType.toLowerCase())) {
      return fileSize <= maxImageSize;
    } else if (supportedDocumentTypes.contains(fileType.toLowerCase())) {
      return fileSize <= maxDocumentSize;
    }
    return false;
  }
  
  static bool isSupportedFileType(String fileType) {
    return supportedDocumentTypes.contains(fileType.toLowerCase()) ||
           supportedImageTypes.contains(fileType.toLowerCase());
  }
  
  static String getStoragePath(String fileType) {
    if (supportedImageTypes.contains(fileType.toLowerCase())) {
      return profileImagesStoragePath;
    } else if (fileType.toLowerCase() == 'pdf') {
      return certificatesStoragePath;
    } else {
      return documentsStoragePath;
    }
  }
  
  static String getVerificationUrl(String certificateId) {
    return '$verificationBaseUrl/$certificateId';
  }
  
  static String getPublicUrl(String resourceId) {
    return '$publicBaseUrl/$resourceId';
  }
} 
