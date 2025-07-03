import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/certificate_model.dart';
import '../../../core/models/user_model.dart';
import '../services/certificate_service.dart';
import '../../auth/providers/auth_providers.dart';

final draftCertificatesProvider =
StreamProvider.autoDispose<List<CertificateModel>>((ref) {
  final query = FirebaseFirestore.instance
      .collection(AppConfig.certificatesCollection)
      .where('status', isEqualTo: CertificateStatus.draft.name);

  return query.snapshots().map((snap) =>
      snap.docs.map((doc) => CertificateModel.fromFirestore(doc)).toList());
});

// Certificate Service Provider
final certificateServiceProvider = Provider<CertificateService>((ref) {
  return CertificateService();
});

// User's Certificates Provider (optimized for simple queries)
final userCertificatesProvider = FutureProvider.family<List<CertificateModel>, String>((ref, userId) async {
  final service = ref.read(certificateServiceProvider);
  return service.getUserCertificates(
    userId: userId,
    userRole: CertificateUserRole.recipient,
  );
});

// Issued Certificates Provider (for CAs)
final issuedCertificatesProvider = FutureProvider.family<List<CertificateModel>, String>((ref, issuerId) async {
  final service = ref.read(certificateServiceProvider);
  return service.getUserCertificates(
    userId: issuerId,
    userRole: CertificateUserRole.issuer,
  );
});

// Organization Certificates Provider
final organizationCertificatesProvider = FutureProvider.family<List<CertificateModel>, String>((ref, orgId) async {
  final service = ref.read(certificateServiceProvider);
  return service.getOrganizationCertificates(organizationId: orgId);
});

// Pending Certificates Provider (for approval workflow)
final pendingCertificatesProvider = FutureProvider.family<List<CertificateModel>, String>((ref, orgId) async {
  final service = ref.read(certificateServiceProvider);
  return service.getOrganizationCertificates(
    organizationId: orgId,
    status: CertificateStatus.pending,
  );
});

// Certificate Statistics Provider
final certificateStatsProvider = FutureProvider<CertificateStatistics>((ref) async {
  final service = ref.read(certificateServiceProvider);
  final currentUser = ref.read(currentUserProvider).value;
  
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  // Get stats based on user role
  switch (currentUser.role) {
    case UserRole.systemAdmin:
      return service.getCertificateStatistics();
    case UserRole.certificateAuthority:
      return service.getCertificateStatistics(issuerId: currentUser.id);
    case UserRole.client:
      return service.getCertificateStatistics(organizationId: currentUser.organizationId);
    default:
      // For recipients and viewers, return limited stats
      final userCerts = await service.getUserCertificates(
        userId: currentUser.id,
        userRole: CertificateUserRole.recipient,
      );
      return CertificateStatistics(
        totalCertificates: userCerts.length,
        issuedCertificates: userCerts.where((c) => c.status == CertificateStatus.issued).length,
        pendingCertificates: userCerts.where((c) => c.status == CertificateStatus.pending).length,
        revokedCertificates: userCerts.where((c) => c.status == CertificateStatus.revoked).length,
        expiredCertificates: userCerts.where((c) => c.isExpired).length,
        certificatesByType: {},
        certificatesByMonth: {},
        certificatesByStatus: {},
      );
  }
});

// Certificate Detail Provider
final certificateDetailProvider = FutureProvider.family<CertificateModel?, String>((ref, certificateId) async {
  final service = ref.read(certificateServiceProvider);
  return service.getCertificateById(certificateId);
});

// Simple All Certificates Provider (with basic ordering only)
final allCertificatesProvider = FutureProvider<List<CertificateModel>>((ref) async {
  final service = ref.read(certificateServiceProvider);
  final currentUser = ref.read(currentUserProvider).value;
  
  if (currentUser == null) {
    throw Exception('User not authenticated');
  }

  // Return certificates based on user role and permissions
  switch (currentUser.role) {
    case UserRole.systemAdmin:
    case UserRole.certificateAuthority:
      // Use simple query without complex filters
      return service.getCertificates(limit: 50);
    case UserRole.client:
      if (currentUser.organizationId != null) {
        return service.getOrganizationCertificates(
          organizationId: currentUser.organizationId!,
        );
      }
      return [];
    case UserRole.recipient:
      return service.getUserCertificates(
        userId: currentUser.id,
        userRole: CertificateUserRole.recipient,
      );
    case UserRole.viewer:
      // Return only public certificates
      return service.getCertificates(
        filter: const CertificateFilter(
          statuses: [CertificateStatus.issued],
        ),
        limit: 20,
      );
  }
});

// Search Certificates Provider (simplified)
final searchCertificatesProvider = FutureProvider.family<List<CertificateModel>, String>((ref, searchTerm) async {
  final service = ref.read(certificateServiceProvider);
  final currentUser = ref.read(currentUserProvider).value;
  
  if (currentUser == null || searchTerm.isEmpty) {
    return [];
  }

  // Get all accessible certificates first, then filter client-side
  List<CertificateModel> certificates = [];
  
  switch (currentUser.role) {
    case UserRole.systemAdmin:
    case UserRole.certificateAuthority:
      certificates = await service.getCertificates(limit: 100);
      break;
    case UserRole.client:
      if (currentUser.organizationId != null) {
        certificates = await service.getOrganizationCertificates(
          organizationId: currentUser.organizationId!,
          limit: 100,
        );
      }
      break;
    case UserRole.recipient:
      certificates = await service.getUserCertificates(
        userId: currentUser.id,
        userRole: CertificateUserRole.recipient,
        limit: 100,
      );
      break;
    case UserRole.viewer:
      certificates = await service.getCertificates(
        filter: const CertificateFilter(statuses: [CertificateStatus.issued]),
        limit: 50,
      );
      break;
  }

  // Filter results client-side
  final searchTermLower = searchTerm.toLowerCase();
  return certificates.where((cert) {
    return cert.title.toLowerCase().contains(searchTermLower) ||
           cert.description.toLowerCase().contains(searchTermLower) ||
           cert.recipientName.toLowerCase().contains(searchTermLower) ||
           cert.organizationName.toLowerCase().contains(searchTermLower);
  }).toList();
});

// Certificate Filter State Provider
final certificateFilterProvider = StateNotifierProvider<CertificateFilterNotifier, CertificateFilter>((ref) {
  return CertificateFilterNotifier();
});

// Certificate Creation State Provider
final certificateCreationProvider = StateNotifierProvider<CertificateCreationNotifier, CertificateCreationState>((ref) {
  return CertificateCreationNotifier(ref.read(certificateServiceProvider));
});

// Recent Certificates Provider (for dashboard)
final recentCertificatesProvider = StreamProvider<List<CertificateModel>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  
  if (user == null) {
    return Stream.value([]);
  }

  String fieldName = user.canCreateCertificates ? 'issuerId' : 'recipientId';

  return FirebaseFirestore.instance
      .collection('certificates')
      .where(fieldName, isEqualTo: user.id)
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CertificateModel.fromFirestore(doc))
          .toList());
});

// Certificate Types Provider
final certificateTypesProvider = Provider<List<CertificateType>>((ref) {
  return CertificateType.values;
});

// Certificate Status Options Provider
final certificateStatusOptionsProvider = Provider<List<CertificateStatus>>((ref) {
  return CertificateStatus.values;
});

// Share Certificate Provider
final shareTokenProvider = FutureProvider.family<ShareToken, ShareTokenRequest>((ref, request) async {
  final service = ref.read(certificateServiceProvider);
  return await service.createShareToken(
    request.certificateId,
    request.sharedBy,
    validityDuration: request.validityDuration,
    password: request.password,
    maxAccess: request.maxAccess,
  );
});

// Verify Certificate by Token Provider
final verifyTokenProvider = FutureProvider.family<CertificateModel?, VerifyTokenRequest>((ref, request) async {
  final service = ref.read(certificateServiceProvider);
  return await service.verifyCertificateByToken(request.token, request.password);
});

// Certificate PDF Generation Provider
final generatePdfProvider = FutureProvider.family<String, String>((ref, certificateId) async {
  final service = ref.read(certificateServiceProvider);
  return await service.generatePdfCertificate(certificateId);
});

// State Notifiers

class CertificateFilterNotifier extends StateNotifier<CertificateFilter> {
  CertificateFilterNotifier() : super(const CertificateFilter());

  void updateStatuses(List<CertificateStatus>? statuses) {
    state = CertificateFilter(
      statuses: statuses,
      types: state.types,
      startDate: state.startDate,
      endDate: state.endDate,
      searchTerm: state.searchTerm,
      tags: state.tags,
      isExpired: state.isExpired,
      isVerified: state.isVerified,
    );
  }

  void updateTypes(List<CertificateType>? types) {
    state = CertificateFilter(
      statuses: state.statuses,
      types: types,
      startDate: state.startDate,
      endDate: state.endDate,
      searchTerm: state.searchTerm,
      tags: state.tags,
      isExpired: state.isExpired,
      isVerified: state.isVerified,
    );
  }

  void updateDateRange(DateTime? startDate, DateTime? endDate) {
    state = CertificateFilter(
      statuses: state.statuses,
      types: state.types,
      startDate: startDate,
      endDate: endDate,
      searchTerm: state.searchTerm,
      tags: state.tags,
      isExpired: state.isExpired,
      isVerified: state.isVerified,
    );
  }

  void updateSearchTerm(String? searchTerm) {
    state = state.copyWith(searchTerm: searchTerm);
  }

  void updateStartDate(DateTime? startDate) {
    state = state.copyWith(startDate: startDate);
  }

  void updateEndDate(DateTime? endDate) {
    state = state.copyWith(endDate: endDate);
  }

  void updateTags(List<String>? tags) {
    state = state.copyWith(tags: tags);
  }

  void updateIsExpired(bool? isExpired) {
    state = state.copyWith(isExpired: isExpired);
  }

  void updateIsVerified(bool? isVerified) {
    state = state.copyWith(isVerified: isVerified);
  }

  void updateFilter(CertificateFilter filter) {
    state = filter;
  }

  void clearFilters() {
    state = const CertificateFilter();
  }
}

class CertificateCreationNotifier extends StateNotifier<CertificateCreationState> {
  final CertificateService _certificateService;

  CertificateCreationNotifier(this._certificateService) : super(CertificateCreationState.initial());

  Future<void> createCertificate({
    required String templateId,
    required String issuerId,
    required String recipientId,
    required String recipientEmail,
    required String recipientName,
    required String organizationId,
    required String organizationName,
    required String title,
    required String description,
    required CertificateType type,
    String courseName = '',
    String courseCode = '',
    String grade = '',
    double? credits,
    String achievement = '',
    DateTime? completedAt,
    DateTime? expiresAt,
    Map<String, dynamic> metadata = const {},
    List<String> tags = const [],
    String? notes,
    bool requiresApproval = false,
    List<ApprovalStep> approvalSteps = const [],
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final certificate = await _certificateService.createCertificate(
        templateId: templateId,
        issuerId: issuerId,
        recipientId: recipientId,
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        organizationId: organizationId,
        organizationName: organizationName,
        title: title,
        description: description,
        type: type,
        courseName: courseName,
        courseCode: courseCode,
        grade: grade,
        credits: credits,
        achievement: achievement,
        completedAt: completedAt,
        expiresAt: expiresAt,
        metadata: metadata,
        tags: tags,
        notes: notes,
        requiresApproval: requiresApproval,
        approvalSteps: approvalSteps,
      );

      state = state.copyWith(
        isLoading: false,
        certificate: certificate,
        isSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }

  Future<void> issueCertificate(String certificateId, String issuerId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final certificate = await _certificateService.issueCertificate(certificateId, issuerId);
      state = state.copyWith(
        isLoading: false,
        certificate: certificate,
        isSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }

  Future<void> approveCertificate({
    required String certificateId,
    required String approverId,
    required String stepId,
    required String comments,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final certificate = await _certificateService.approveCertificate(
        certificateId,
        approverId,
        stepId,
        comments,
      );
      state = state.copyWith(
        isLoading: false,
        certificate: certificate,
        isSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }

  Future<void> revokeCertificate({
    required String certificateId,
    required String revokedBy,
    required String reason,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final certificate = await _certificateService.revokeCertificate(
        certificateId,
        revokedBy,
        reason,
      );
      state = state.copyWith(
        isLoading: false,
        certificate: certificate,
        isSuccess: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isSuccess: false,
      );
    }
  }

  void clearState() {
    state = CertificateCreationState.initial();
  }
}

// State classes
class CertificateCreationState {
  final bool isLoading;
  final String? error;
  final CertificateModel? certificate;
  final bool isSuccess;

  const CertificateCreationState({
    required this.isLoading,
    this.error,
    this.certificate,
    required this.isSuccess,
  });

  factory CertificateCreationState.initial() {
    return const CertificateCreationState(
      isLoading: false,
      error: null,
      certificate: null,
      isSuccess: false,
    );
  }

  CertificateCreationState copyWith({
    bool? isLoading,
    String? error,
    CertificateModel? certificate,
    bool? isSuccess,
  }) {
    return CertificateCreationState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      certificate: certificate ?? this.certificate,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

// Request classes
class ShareTokenRequest {
  final String certificateId;
  final String sharedBy;
  final Duration? validityDuration;
  final String? password;
  final int maxAccess;

  const ShareTokenRequest({
    required this.certificateId,
    required this.sharedBy,
    this.validityDuration,
    this.password,
    this.maxAccess = 100,
  });
}

class VerifyTokenRequest {
  final String token;
  final String? password;

  const VerifyTokenRequest({
    required this.token,
    this.password,
  });
}

// Permission-based providers
final canCreateCertificatesProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.canCreateCertificates ?? false;
});

final canApproveCertificatesProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.canApproveCertificates ?? false;
});

final canManageCertificatesProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).value;
  return user?.isAdmin ?? false;
});

// Available tags provider (dynamically fetch from certificates)
final availableTagsProvider = FutureProvider<List<String>>((ref) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('certificates')
        .get();
    
    final tags = <String>{};
    for (final doc in snapshot.docs) {
      final certTags = List<String>.from(doc.data()['tags'] ?? []);
      tags.addAll(certTags);
    }
    
    return tags.toList()..sort();
  } catch (e) {
    return [];
  }
});

// Certificate template provider (if you have templates)
final certificateTemplatesProvider = StreamProvider<List<CertificateTemplate>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CertificateTemplate.fromFirestore(doc))
          .toList());
});

// Simple Certificate Template class (you might want to create a full model)
class CertificateTemplate {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> template;
  final bool isActive;

  const CertificateTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.template,
    required this.isActive,
  });

  factory CertificateTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CertificateTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      template: Map<String, dynamic>.from(data['template'] ?? {}),
      isActive: data['isActive'] ?? true,
    );
  }
} 
