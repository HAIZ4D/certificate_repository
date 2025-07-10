import 'package:digital_certificate_repository/core/models/ca_status_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/certificate_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/logger_service.dart';
import '../../auth/providers/auth_providers.dart';
import '../services/ca_service.dart';
import '../presentation/pages/ca_dashboard.dart';

class CAApplicationStatus {
  final String status; // e.g., 'submitted', 'under_review', 'approved'
  final int step; // 1 = submitted, 2 = under review, 3 = approved
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final DateTime? approvedAt;

  const CAApplicationStatus({
    required this.status,
    required this.step,
    required this.submittedAt,
    this.reviewedAt,
    this.approvedAt,
  });

  factory CAApplicationStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CAApplicationStatus(
      status: data['status'] ?? 'submitted',
      step: data['step'] ?? 1,
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
      reviewedAt: data['reviewedAt'] != null
          ? (data['reviewedAt'] as Timestamp).toDate()
          : null,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
final documentsByStatusProvider = FutureProvider.family<List<DocumentModel>, String>((ref, status) async {
  final caService = ref.read(caServiceProvider);
  return await caService.getDocumentsByStatus(status);
});


final caApplicationStatusProvider = FutureProvider<CAStatus?>((ref) async {
  final user = ref.watch(currentUserProvider).value;

  if (user == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('ca_applications')
      .doc(user.id)
      .get();

  if (!doc.exists) {
    return null; // Don't throw!
  }

  return CAStatus.fromFirestore(doc);
});

// CA Service Provider
final caServiceProvider = Provider<CAService>((ref) {
  return CAService();
});

// CA Statistics Provider
final caStatsProvider =
StateNotifierProvider<CAStatsNotifier, AsyncValue<CAStats>>((ref) {
  return CAStatsNotifier(ref.read(caServiceProvider));
});

// Pending Documents for Review Provider
final pendingDocumentsProvider =
FutureProvider<List<DocumentModel>>((ref) async {
  final caService = ref.read(caServiceProvider);
  return await caService.getPendingDocuments();
});

// CA Certificate History Provider
final caCertificatesProvider = StreamProvider<List<CertificateModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('certificates')
      .where('issuerId', isEqualTo: currentUser.id)
      .orderBy('issuedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
      .map((doc) => CertificateModel.fromFirestore(doc))
      .toList());
});

// Certificate Creation Provider
final certificateCreationProvider = StateNotifierProvider<
    CertificateCreationNotifier, CertificateCreationState>((ref) {
  return CertificateCreationNotifier(ref.read(caServiceProvider));
});

// Document Review Provider
final documentReviewProvider =
StateNotifierProvider<DocumentReviewNotifier, DocumentReviewState>((ref) {
  return DocumentReviewNotifier(ref.read(caServiceProvider));
});

// CA Activity Log Provider
final caActivityProvider = StreamProvider<List<CAActivity>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null || (!currentUser.isCA && !currentUser.isAdmin)) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('ca_activities')
      .where('caId', isEqualTo: currentUser.id)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) =>
      snapshot.docs.map((doc) => CAActivity.fromFirestore(doc)).toList());
});

// CA Settings Provider
final caSettingsProvider =
StateNotifierProvider<CASettingsNotifier, CASettingsState>((ref) {
  return CASettingsNotifier(ref.read(caServiceProvider));
});

// State Notifiers

class CAStatsNotifier extends StateNotifier<AsyncValue<CAStats>> {
  CAStatsNotifier(this._caService) : super(const AsyncValue.loading());

  final CAService _caService;

  Future<void> loadStats() async {
    try {
      state = const AsyncValue.loading();
      final stats = await _caService.getCAStats();
      state = AsyncValue.data(stats);
    } catch (error, stackTrace) {
      LoggerService.error('Failed to load CA stats',
          error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadStats();
  }
}

class CertificateCreationNotifier
    extends StateNotifier<CertificateCreationState> {
  CertificateCreationNotifier(this._caService)
      : super(const CertificateCreationState());

  final CAService _caService;

  Future<void> createCertificate({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    required DateTime issuedAt,
    String? templateId,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final certificateId = await _caService.createCertificate(
        title: title,
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        description: description,
        type: type,
        issuedAt: issuedAt,
        customFields: customFields ?? {},
      );

      // Get the actual certificate from Firestore to return real data
      final certificateDoc = await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .get();

      final certificate = CertificateModel.fromFirestore(certificateDoc);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        certificate: certificate,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to create certificate',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> saveDraft({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    String? templateId,
    Map<String, dynamic>? customFields,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _caService.saveCertificateDraft(
        title: title,
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        description: description,
        type: type,
        templateId: templateId,
        customFields: customFields ?? {},
      );

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to save certificate draft',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void clearState() {
    state = const CertificateCreationState();
  }
}

class DocumentReviewNotifier extends StateNotifier<DocumentReviewState> {
  DocumentReviewNotifier(this._caService) : super(const DocumentReviewState());

  final CAService _caService;

  Future<void> approveDocument(String documentId, String comments) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _caService.approveDocument(documentId, comments);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Document approved successfully',
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to approve document',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> rejectDocument(String documentId, String reason) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _caService.rejectDocument(documentId, reason);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Document rejected',
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to reject document',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void clearState() {
    state = const DocumentReviewState();
  }
}

class CASettingsNotifier extends StateNotifier<CASettingsState> {
  CASettingsNotifier(this._caService) : super(const CASettingsState());

  final CAService _caService;

  Future<void> loadSettings() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final settings = await _caService.getCASettings();

      state = state.copyWith(
        isLoading: false,
        settings: settings,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to load CA settings',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> updateSettings(CASettingsModel settings) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _caService.updateCASettings(settings);

      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        settings: settings,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to update CA settings',
          error: error, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
    }
  }

  void clearState() {
    state = const CASettingsState();
  }
}

// State Classes

class CertificateCreationState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final CertificateModel? certificate;

  const CertificateCreationState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.certificate,
  });

  CertificateCreationState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    CertificateModel? certificate,
  }) {
    return CertificateCreationState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error ?? this.error,
      certificate: certificate ?? this.certificate,
    );
  }
}

class DocumentReviewState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const DocumentReviewState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  DocumentReviewState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return DocumentReviewState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      successMessage: successMessage ?? this.successMessage,
    );
  }
}

class CASettingsState {
  final bool isLoading;
  final bool isSuccess;
  final String? error;
  final CASettingsModel? settings;

  const CASettingsState({
    this.isLoading = false,
    this.isSuccess = false,
    this.error,
    this.settings,
  });

  CASettingsState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? error,
    CASettingsModel? settings,
  }) {
    return CASettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      settings: settings ?? this.settings,
    );
  }
}

// Data Models

class CAActivity {
  final String id;
  final String caId;
  final String action;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const CAActivity({
    required this.id,
    required this.caId,
    required this.action,
    required this.description,
    required this.timestamp,
    required this.metadata,
  });

  factory CAActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CAActivity(
      id: doc.id,
      caId: data['caId'] ?? '',
      action: data['action'] ?? '',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      metadata: data['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'caId': caId,
      'action': action,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
    };
  }
}

class CASettingsModel {
  final String organizationName;
  final String contactEmail;
  final String contactPhone;
  final String address;
  final bool autoApproveDocuments;
  final List<String> allowedFileTypes;
  final int maxFileSize;
  final String certificateTemplate;
  final String digitalSignature;
  final Map<String, dynamic> emailTemplates;

  const CASettingsModel({
    required this.organizationName,
    required this.contactEmail,
    required this.contactPhone,
    required this.address,
    this.autoApproveDocuments = false,
    this.allowedFileTypes = const ['pdf', 'doc', 'docx', 'jpg', 'png'],
    this.maxFileSize = 10,
    this.certificateTemplate = 'default',
    this.digitalSignature = '',
    this.emailTemplates = const {},
  });

  factory CASettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CASettingsModel(
      organizationName: data['organizationName'] ?? '',
      contactEmail: data['contactEmail'] ?? '',
      contactPhone: data['contactPhone'] ?? '',
      address: data['address'] ?? '',
      autoApproveDocuments: data['autoApproveDocuments'] ?? false,
      allowedFileTypes: List<String>.from(
          data['allowedFileTypes'] ?? ['pdf', 'doc', 'docx', 'jpg', 'png']),
      maxFileSize: data['maxFileSize'] ?? 10,
      certificateTemplate: data['certificateTemplate'] ?? 'default',
      digitalSignature: data['digitalSignature'] ?? '',
      emailTemplates: data['emailTemplates'] ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizationName': organizationName,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'address': address,
      'autoApproveDocuments': autoApproveDocuments,
      'allowedFileTypes': allowedFileTypes,
      'maxFileSize': maxFileSize,
      'certificateTemplate': certificateTemplate,
      'digitalSignature': digitalSignature,
      'emailTemplates': emailTemplates,
    };
  }

  CASettingsModel copyWith({
    String? organizationName,
    String? contactEmail,
    String? contactPhone,
    String? address,
    bool? autoApproveDocuments,
    List<String>? allowedFileTypes,
    int? maxFileSize,
    String? certificateTemplate,
    String? digitalSignature,
    Map<String, dynamic>? emailTemplates,
  }) {
    return CASettingsModel(
      organizationName: organizationName ?? this.organizationName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      autoApproveDocuments: autoApproveDocuments ?? this.autoApproveDocuments,
      allowedFileTypes: allowedFileTypes ?? this.allowedFileTypes,
      maxFileSize: maxFileSize ?? this.maxFileSize,
      certificateTemplate: certificateTemplate ?? this.certificateTemplate,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      emailTemplates: emailTemplates ?? this.emailTemplates,
    );
  }
}
