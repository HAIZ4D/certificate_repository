import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_profile_service.dart';
import '../services/report_export_service.dart';

/// User Profile Service Provider
final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

/// Report Export Service Provider
final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService();
}); 