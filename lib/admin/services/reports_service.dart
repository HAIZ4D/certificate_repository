import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/logger_service.dart';
import '../../../core/services/report_export_service.dart';
import '../../../core/config/app_config.dart';

class ReportsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate comprehensive system overview report
  Future<Map<String, dynamic>> generateSystemOverviewReport() async {
    try {
      LoggerService.info('Generating system overview report');

      final futures = await Future.wait([
        _generateUserReport(),
        _generateCertificateReport(),
        _generateDocumentReport(),
        _generateActivityReport(),
      ]);

      return {
        'reportId': 'SYS-${DateTime.now().millisecondsSinceEpoch}',
        'generatedAt': DateTime.now().toIso8601String(),
        'type': 'system_overview',
        'users': futures[0],
        'certificates': futures[1],
        'documents': futures[2],
        'activity': futures[3],
      };
    } catch (e, stackTrace) {
      LoggerService.error('Failed to generate system overview report', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generate user statistics report
  Future<Map<String, dynamic>> _generateUserReport() async {
    try {
      final usersCollection = _firestore.collection(AppConfig.usersCollection);

      // Get all users
      final allUsers = await usersCollection.get();
      
      // Count by role
      final roleCount = <String, int>{};
      final statusCount = <String, int>{};
      final monthlyRegistrations = <String, int>{};
      
      for (final doc in allUsers.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? 'unknown';
        final status = data['status'] as String? ?? 'unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // Count by role
        roleCount[role] = (roleCount[role] ?? 0) + 1;
        
        // Count by status
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        // Count monthly registrations
        if (createdAt != null) {
          final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
          monthlyRegistrations[monthKey] = (monthlyRegistrations[monthKey] ?? 0) + 1;
        }
      }

      return {
        'totalUsers': allUsers.docs.length,
        'roleDistribution': roleCount,
        'statusDistribution': statusCount,
        'monthlyRegistrations': monthlyRegistrations,
        'averageUsersPerMonth': monthlyRegistrations.isNotEmpty 
            ? (allUsers.docs.length / monthlyRegistrations.length).round()
            : 0,
      };
    } catch (e) {
      LoggerService.error('Failed to generate user report', error: e);
      return {'error': e.toString()};
    }
  }

  /// Generate certificate statistics report
  Future<Map<String, dynamic>> _generateCertificateReport() async {
    try {
      final certificatesCollection = _firestore.collection(AppConfig.certificatesCollection);

      // Get all certificates
      final allCertificates = await certificatesCollection.get();
      
      // Count by status and type
      final statusCount = <String, int>{};
      final typeCount = <String, int>{};
      final monthlyIssued = <String, int>{};
      
      for (final doc in allCertificates.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'unknown';
        final type = data['type'] as String? ?? 'unknown';
        final issuedAt = (data['issuedAt'] as Timestamp?)?.toDate();
        
        // Count by status
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        // Count by type
        typeCount[type] = (typeCount[type] ?? 0) + 1;
        
        // Count monthly issued certificates
        if (issuedAt != null && status == 'issued') {
          final monthKey = '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}';
          monthlyIssued[monthKey] = (monthlyIssued[monthKey] ?? 0) + 1;
        }
      }

      return {
        'totalCertificates': allCertificates.docs.length,
        'statusDistribution': statusCount,
        'typeDistribution': typeCount,
        'monthlyIssued': monthlyIssued,
        'issuedCount': statusCount['issued'] ?? 0,
        'pendingCount': statusCount['draft'] ?? 0,
        'revokedCount': statusCount['revoked'] ?? 0,
      };
    } catch (e) {
      LoggerService.error('Failed to generate certificate report', error: e);
      return {'error': e.toString()};
    }
  }

  /// Generate document statistics report
  Future<Map<String, dynamic>> _generateDocumentReport() async {
    try {
      final documentsCollection = _firestore.collection(AppConfig.documentsCollection);

      // Get all documents
      final allDocuments = await documentsCollection.get();
      
      // Calculate statistics
      final typeCount = <String, int>{};
      final statusCount = <String, int>{};
      int totalSize = 0;
      final monthlySizes = <String, int>{};
      
      for (final doc in allDocuments.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'unknown';
        final status = data['status'] as String? ?? 'unknown';
        final fileSize = data['fileSize'] as int? ?? 0;
        final uploadedAt = (data['uploadedAt'] as Timestamp?)?.toDate();
        
        // Count by type
        typeCount[type] = (typeCount[type] ?? 0) + 1;
        
        // Count by status
        statusCount[status] = (statusCount[status] ?? 0) + 1;
        
        // Calculate total size
        totalSize += fileSize;
        
        // Track monthly storage usage
        if (uploadedAt != null) {
          final monthKey = '${uploadedAt.year}-${uploadedAt.month.toString().padLeft(2, '0')}';
          monthlySizes[monthKey] = (monthlySizes[monthKey] ?? 0) + fileSize;
        }
      }

      return {
        'totalDocuments': allDocuments.docs.length,
        'typeDistribution': typeCount,
        'statusDistribution': statusCount,
        'totalStorageBytes': totalSize,
        'totalStorageMB': (totalSize / (1024 * 1024)).round(),
        'averageFileSizeBytes': allDocuments.docs.isNotEmpty 
            ? (totalSize / allDocuments.docs.length).round()
            : 0,
        'monthlyStorageUsage': monthlySizes,
      };
    } catch (e) {
      LoggerService.error('Failed to generate document report', error: e);
      return {'error': e.toString()};
    }
  }

  /// Generate system activity report
  Future<Map<String, dynamic>> _generateActivityReport() async {
    try {
      final activityCollection = _firestore.collection(AppConfig.activityCollection);

      // Get recent activities (last 30 days)
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentActivities = await activityCollection
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();
      
      // Count by action type
      final actionCount = <String, int>{};
      final dailyActivity = <String, int>{};
      
      for (final doc in recentActivities.docs) {
        final data = doc.data();
        final action = data['action'] as String? ?? 'unknown';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        // Count by action
        actionCount[action] = (actionCount[action] ?? 0) + 1;
        
        // Count daily activity
        if (timestamp != null) {
          final dayKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
          dailyActivity[dayKey] = (dailyActivity[dayKey] ?? 0) + 1;
        }
      }

      return {
        'totalActivities': recentActivities.docs.length,
        'actionDistribution': actionCount,
        'dailyActivity': dailyActivity,
        'mostActiveDay': dailyActivity.isNotEmpty 
            ? dailyActivity.entries.reduce((a, b) => a.value > b.value ? a : b).key
            : 'No data',
        'averageActivitiesPerDay': dailyActivity.isNotEmpty 
            ? (recentActivities.docs.length / dailyActivity.length).round()
            : 0,
      };
    } catch (e) {
      LoggerService.error('Failed to generate activity report', error: e);
      return {'error': e.toString()};
    }
  }

  /// Generate CA performance report
  Future<Map<String, dynamic>> generateCAPerformanceReport() async {
    try {
      LoggerService.info('Generating CA performance report');

      // Get all CA users
      final caUsers = await _firestore
          .collection(AppConfig.usersCollection)
          .where('role', isEqualTo: 'certificateAuthority')
          .get();

      final caPerformance = <String, Map<String, dynamic>>{};
      
      for (final caDoc in caUsers.docs) {
        final caData = caDoc.data();
        final caId = caDoc.id;
        final caName = caData['displayName'] as String? ?? 'Unknown';
        
        // Get certificates issued by this CA
        final caCertificates = await _firestore
            .collection(AppConfig.certificatesCollection)
            .where('issuerId', isEqualTo: caId)
            .get();

        // Get documents reviewed by this CA
        final reviewedDocs = await _firestore
            .collection(AppConfig.documentsCollection)
            .where('reviewerId', isEqualTo: caId)
            .get();

        caPerformance[caId] = {
          'name': caName,
          'status': caData['status'] ?? 'unknown',
          'certificatesIssued': caCertificates.docs.length,
          'documentsReviewed': reviewedDocs.docs.length,
          'joinDate': caData['createdAt'],
          'lastActivity': caData['lastActivityAt'],
        };
      }

      return {
        'reportId': 'CA-${DateTime.now().millisecondsSinceEpoch}',
        'generatedAt': DateTime.now().toIso8601String(),
        'type': 'ca_performance',
        'totalCAs': caUsers.docs.length,
        'activeCAs': caUsers.docs.where((doc) => doc.data()['status'] == 'active').length,
        'pendingCAs': caUsers.docs.where((doc) => doc.data()['status'] == 'pending').length,
        'caPerformance': caPerformance,
      };
    } catch (e, stackTrace) {
      LoggerService.error('Failed to generate CA performance report', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Export report to CSV format
  Future<String> exportReportToCsv(Map<String, dynamic> report) async {
    try {
      final exportService = ReportExportService();
      final reportTitle = 'System Report ${report['reportId'] ?? 'Unknown'}';
      
      final downloadUrl = await exportService.exportReportAsCSV(
        reportData: report,
        reportTitle: reportTitle,
      );
      
      LoggerService.info('CSV Report exported successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to export report to CSV', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Export report to PDF format
  Future<String> exportReportToPdf(Map<String, dynamic> report) async {
    try {
      final exportService = ReportExportService();
      final reportTitle = 'System Report ${report['reportId'] ?? 'Unknown'}';
      
      final downloadUrl = await exportService.exportReportAsPDF(
        reportData: report,
        reportTitle: reportTitle,
        description: 'Comprehensive system overview report generated by UPM Digital Certificate System',
      );
      
      LoggerService.info('PDF Report exported successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to export report to PDF', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Export report to Excel format
  Future<String> exportReportToExcel(Map<String, dynamic> report) async {
    try {
      final exportService = ReportExportService();
      final reportTitle = 'System Report ${report['reportId'] ?? 'Unknown'}';
      
      final downloadUrl = await exportService.exportReportAsExcel(
        reportData: report,
        reportTitle: reportTitle,
      );
      
      LoggerService.info('Excel Report exported successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to export report to Excel', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Generate audit trail report
  Future<Map<String, dynamic>> generateAuditTrailReport({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? action,
  }) async {
    try {
      LoggerService.info('Generating audit trail report');

      Query query = _firestore.collection(AppConfig.adminLogsCollection);
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      if (userId != null) {
        query = query.where('adminId', isEqualTo: userId);
      }
      
      if (action != null) {
        query = query.where('action', isEqualTo: action);
      }

      final auditLogs = await query.orderBy('timestamp', descending: true).get();
      
      final actionCounts = <String, int>{};
      final userCounts = <String, int>{};
      final dailyCounts = <String, int>{};
      
      for (final doc in auditLogs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final action = data['action'] as String? ?? 'unknown';
        final adminId = data['adminId'] as String? ?? 'unknown';
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
        userCounts[adminId] = (userCounts[adminId] ?? 0) + 1;
        
        if (timestamp != null) {
          final dayKey = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
          dailyCounts[dayKey] = (dailyCounts[dayKey] ?? 0) + 1;
        }
      }

      return {
        'reportId': 'AUDIT-${DateTime.now().millisecondsSinceEpoch}',
        'generatedAt': DateTime.now().toIso8601String(),
        'type': 'audit_trail',
        'filters': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
          'userId': userId,
          'action': action,
        },
        'totalEntries': auditLogs.docs.length,
        'actionDistribution': actionCounts,
        'userDistribution': userCounts,
        'dailyActivity': dailyCounts,
        'entries': auditLogs.docs.map((doc) => {
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        }).toList(),
      };
    } catch (e, stackTrace) {
      LoggerService.error('Failed to generate audit trail report', 
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
} 