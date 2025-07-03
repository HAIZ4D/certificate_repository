import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/logger_service.dart';

// Admin Statistics Provider
final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  try {
    final firestore = FirebaseFirestore.instance;
    // Note: Date filtering can be added here for future enhancements

    // Get user counts
    final usersSnapshot = await firestore.collection('users').get();
    final totalUsers = usersSnapshot.docs.length;
    final activeUsers = usersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'active')
        .length;
    final pendingUsers = usersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;

    // Get certificate counts
    final certificatesSnapshot = await firestore.collection('certificates').get();
    final totalCertificates = certificatesSnapshot.docs.length;
    final issuedCertificates = certificatesSnapshot.docs
        .where((doc) => doc.data()['status'] == 'issued')
        .length;
    final pendingCertificates = certificatesSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;

    // Get document counts
    final documentsSnapshot = await firestore.collection('documents').get();
    final totalDocuments = documentsSnapshot.docs.length;

    // Get CA counts
    final caUsersSnapshot = await firestore
        .collection('users')
        .where('userType', isEqualTo: 'ca')
        .get();
    final totalCAs = caUsersSnapshot.docs.length;
    final activeCAs = caUsersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'active')
        .length;
    final pendingCAs = caUsersSnapshot.docs
        .where((doc) => doc.data()['status'] == 'pending')
        .length;

    // Calculate growth (compare with previous period)
    final userGrowth = _calculateGrowth(totalUsers, totalUsers - 5); // Mock growth
    final certificateGrowth = _calculateGrowth(totalCertificates, totalCertificates - 3);

    return AdminStats(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      pendingUsers: pendingUsers,
      totalCertificates: totalCertificates,
      issuedCertificates: issuedCertificates,
      pendingCertificates: pendingCertificates,
      totalDocuments: totalDocuments,
      totalCAs: totalCAs,
      activeCAs: activeCAs,
      pendingCAs: pendingCAs,
      userGrowth: userGrowth,
      certificateGrowth: certificateGrowth,
    );
  } catch (e) {
    LoggerService.error('Failed to load admin stats', error: e);
    throw Exception('Failed to load admin statistics: $e');
  }
});

// Recent Activities Provider
final recentActivitiesProvider = FutureProvider<List<AdminActivity>>((ref) async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    final activitiesSnapshot = await firestore
        .collection('admin_activities')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();

    return activitiesSnapshot.docs.map((doc) {
      final data = doc.data();
      return AdminActivity(
        id: doc.id,
        action: data['action'] ?? '',
        description: data['description'] ?? '',
        adminId: data['adminId'] ?? '',
        targetUserId: data['targetUserId'],
        targetUserName: data['targetUserName'],
        targetUserEmail: data['targetUserEmail'],
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        details: data['details'],
      );
    }).toList();
  } catch (e) {
    LoggerService.error('Failed to load recent activities', error: e);
    return [];
  }
});

// System Health Provider
final systemHealthProvider = FutureProvider<SystemHealth>((ref) async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Check database connectivity
    await firestore.collection('_health_check').doc('test').get();
    const dbConnected = true; // If we reach here, DB is connected

    // Get error counts from logs (last 24 hours)
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final errorLogsSnapshot = await firestore
        .collection('error_logs')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(yesterday))
        .get();
    final errorCount = errorLogsSnapshot.docs.length;

    // Get system performance metrics
    final performanceSnapshot = await firestore
        .collection('system_metrics')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    double avgResponseTime = 150.0; // Default
    double cpuUsage = 25.0; // Default
    double memoryUsage = 45.0; // Default

    if (performanceSnapshot.docs.isNotEmpty) {
      final metrics = performanceSnapshot.docs.first.data();
      avgResponseTime = metrics['avgResponseTime']?.toDouble() ?? avgResponseTime;
      cpuUsage = metrics['cpuUsage']?.toDouble() ?? cpuUsage;
      memoryUsage = metrics['memoryUsage']?.toDouble() ?? memoryUsage;
    }

    // Calculate overall health score
    double healthScore = 100.0;
    if (errorCount > 10) healthScore -= 20;
    if (avgResponseTime > 300) healthScore -= 15;
    if (cpuUsage > 80) healthScore -= 10;
    if (memoryUsage > 85) healthScore -= 10;

    final status = healthScore >= 90 
        ? HealthStatus.excellent
        : healthScore >= 70 
            ? HealthStatus.good
            : healthScore >= 50 
                ? HealthStatus.warning
                : HealthStatus.critical;

    return SystemHealth(
      status: status,
      healthScore: healthScore,
      dbConnected: dbConnected,
      errorCount: errorCount,
      avgResponseTime: avgResponseTime,
      cpuUsage: cpuUsage,
      memoryUsage: memoryUsage,
      lastUpdated: DateTime.now(),
    );
  } catch (e) {
    LoggerService.error('Failed to load system health', error: e);
    return SystemHealth(
      status: HealthStatus.critical,
      healthScore: 0.0,
      dbConnected: false,
      errorCount: 999,
      avgResponseTime: 9999.0,
      cpuUsage: 100.0,
      memoryUsage: 100.0,
      lastUpdated: DateTime.now(),
    );
  }
});

// Helper function to calculate growth percentage
double _calculateGrowth(int current, int previous) {
  if (previous == 0) return 0.0;
  return ((current - previous) / previous) * 100;
}

// Data Models
class AdminStats {
  final int totalUsers;
  final int activeUsers;
  final int pendingUsers;
  final int totalCertificates;
  final int issuedCertificates;
  final int pendingCertificates;
  final int totalDocuments;
  final int totalCAs;
  final int activeCAs;
  final int pendingCAs;
  final double userGrowth;
  final double certificateGrowth;

  const AdminStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.pendingUsers,
    required this.totalCertificates,
    required this.issuedCertificates,
    required this.pendingCertificates,
    required this.totalDocuments,
    required this.totalCAs,
    required this.activeCAs,
    required this.pendingCAs,
    required this.userGrowth,
    required this.certificateGrowth,
  });
}

class AdminActivity {
  final String id;
  final String action;
  final String description;
  final String adminId;
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserEmail;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  const AdminActivity({
    required this.id,
    required this.action,
    required this.description,
    required this.adminId,
    this.targetUserId,
    this.targetUserName,
    this.targetUserEmail,
    required this.timestamp,
    this.details,
  });
}

class SystemHealth {
  final HealthStatus status;
  final double healthScore;
  final bool dbConnected;
  final int errorCount;
  final double avgResponseTime;
  final double cpuUsage;
  final double memoryUsage;
  final DateTime lastUpdated;

  const SystemHealth({
    required this.status,
    required this.healthScore,
    required this.dbConnected,
    required this.errorCount,
    required this.avgResponseTime,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.lastUpdated,
  });
}

enum HealthStatus {
  excellent,
  good,
  warning,
  critical,
} 