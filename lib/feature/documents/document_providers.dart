import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/models/document_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/document_service.dart';
import '../../auth/providers/auth_providers.dart';
// here are all true copy
// Document Service Provider
final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService();
});

// Document List Provider
final documentListProvider = StreamProvider.family<List<DocumentModel>, DocumentListParams>((ref, params) {
  final documentService = ref.read(documentServiceProvider);
  
  // Simulate real-time updates with periodic refresh
  return Stream.periodic(const Duration(seconds: 30))
      .asyncMap((_) => documentService.getDocumentsByUser(
        userId: params.userId,
        userRole: params.userRole,
        types: params.types,
        statuses: params.statuses,
        limit: params.limit,
      ))
      .handleError((error) {
        ref.read(documentErrorProvider.notifier).state = error.toString();
      });
});

// Document Search Provider
final documentSearchProvider = FutureProvider.family<List<DocumentModel>, DocumentSearchParams>((ref, params) async {
  final documentService = ref.read(documentServiceProvider);
  
  try {
    return await documentService.searchDocuments(
      searchTerm: params.searchTerm,
      type: params.type,
      statuses: params.statuses,
      startDate: params.startDate,
      endDate: params.endDate,
      tags: params.tags,
      userId: params.userId,
      userRole: params.userRole,
      limit: params.limit,
    );
  } catch (error) {
    ref.read(documentErrorProvider.notifier).state = error.toString();
    rethrow;
  }
});

// Document Detail Provider
final documentDetailProvider = FutureProvider.family<DocumentModel?, String>((ref, documentId) async {
  final documentService = ref.read(documentServiceProvider);
  
  try {
    return await documentService.getDocumentById(documentId);
  } catch (error) {
    ref.read(documentErrorProvider.notifier).state = error.toString();
    rethrow;
  }
});

// Document Statistics Provider
final documentStatisticsProvider = FutureProvider.family<DocumentStatistics, DocumentStatsParams>((ref, params) async {
  final documentService = ref.read(documentServiceProvider);
  
  try {
    return await documentService.getDocumentStatistics(
      userId: params.userId,
      userRole: params.userRole,
    );
  } catch (error) {
    ref.read(documentErrorProvider.notifier).state = error.toString();
    rethrow;
  }
});

// Document Upload State Provider
final documentUploadProvider = StateNotifierProvider<DocumentUploadNotifier, DocumentUploadState>((ref) {
  return DocumentUploadNotifier(ref.read(documentServiceProvider));
});

// Document Error Provider
final documentErrorProvider = StateProvider<String?>((ref) => null);

// Document Loading Provider
final documentLoadingProvider = StateProvider<bool>((ref) => false);

// Parameter classes
class DocumentListParams {
  final String userId;
  final UserRole? userRole;
  final List<DocumentType>? types;
  final List<VerificationStatus>? statuses;
  final int? limit;

  DocumentListParams({
    required this.userId,
    this.userRole,
    this.types,
    this.statuses,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentListParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userRole == other.userRole &&
          types == other.types &&
          statuses == other.statuses &&
          limit == other.limit;

  @override
  int get hashCode =>
      userId.hashCode ^
      userRole.hashCode ^
      types.hashCode ^
      statuses.hashCode ^
      limit.hashCode;
}

class DocumentSearchParams {
  final String? searchTerm;
  final DocumentType? type;
  final List<VerificationStatus>? statuses;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? tags;
  final String? userId;
  final UserRole? userRole;
  final int? limit;

  DocumentSearchParams({
    this.searchTerm,
    this.type,
    this.statuses,
    this.startDate,
    this.endDate,
    this.tags,
    this.userId,
    this.userRole,
    this.limit,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentSearchParams &&
          runtimeType == other.runtimeType &&
          searchTerm == other.searchTerm &&
          type == other.type &&
          statuses == other.statuses &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          tags == other.tags &&
          userId == other.userId &&
          userRole == other.userRole &&
          limit == other.limit;

  @override
  int get hashCode =>
      searchTerm.hashCode ^
      type.hashCode ^
      statuses.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      tags.hashCode ^
      userId.hashCode ^
      userRole.hashCode ^
      limit.hashCode;
}

class DocumentStatsParams {
  final String? userId;
  final UserRole? userRole;

  DocumentStatsParams({
    this.userId,
    this.userRole,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentStatsParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          userRole == other.userRole;

  @override
  int get hashCode => userId.hashCode ^ userRole.hashCode;
}

// Document Upload State
class DocumentUploadState {
  final bool isLoading;
  final String? error;
  final DocumentModel? uploadedDocument;
  final double uploadProgress;
  final Map<String, dynamic> formData;

  const DocumentUploadState({
    this.isLoading = false,
    this.error,
    this.uploadedDocument,
    this.uploadProgress = 0.0,
    this.formData = const {},
  });

  DocumentUploadState copyWith({
    bool? isLoading,
    String? error,
    DocumentModel? uploadedDocument,
    double? uploadProgress,
    Map<String, dynamic>? formData,
  }) {
    return DocumentUploadState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      uploadedDocument: uploadedDocument ?? this.uploadedDocument,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      formData: formData ?? this.formData,
    );
  }

  DocumentUploadState clearError() {
    return copyWith(error: null);
  }

  DocumentUploadState clearUpload() {
    return copyWith(
      uploadedDocument: null,
      uploadProgress: 0.0,
    );
  }
}

// Document Upload Notifier
class DocumentUploadNotifier extends StateNotifier<DocumentUploadState> {
  final DocumentService _documentService;
  final Logger _logger = Logger();

  DocumentUploadNotifier(this._documentService) : super(const DocumentUploadState());

  // Update form data
  void updateFormData(Map<String, dynamic> data) {
    state = state.copyWith(
      formData: {...state.formData, ...data},
    );
  }

  // Clear form data
  void clearFormData() {
    state = state.copyWith(formData: {});
  }

  // Update upload progress
  void updateProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }

  // Upload document
  Future<void> uploadDocument({
    required String name,
    required String description,
    required DocumentType type,
    required String uploadedBy,
    required String filePath,
    required int fileSize,
    required String mimeType,
    String? associatedCertificateId,
    VerificationLevel verificationLevel = VerificationLevel.basic,
    List<String> allowedUsers = const [],
    Map<String, dynamic>? metadata,
    List<String> tags = const [],
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null, uploadProgress: 0.0);

      final document = await _documentService.uploadDocument(
        name: name,
        description: description,
        type: type,
        uploadedBy: uploadedBy,
        filePath: filePath,
        fileSize: fileSize,
        mimeType: mimeType,
        associatedCertificateId: associatedCertificateId,
        verificationLevel: verificationLevel,
        allowedUsers: allowedUsers,
        metadata: metadata,
        tags: tags,
      );

      state = state.copyWith(
        isLoading: false,
        uploadedDocument: document,
        uploadProgress: 1.0,
      );

      _logger.i('Document uploaded successfully: ${document.id}');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        uploadProgress: 0.0,
      );
      _logger.e('Error uploading document: $e');
    }
  }

  // Update document
  Future<void> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _documentService.updateDocument(
        documentId,
        updates,
        updatedBy,
      );

      state = state.copyWith(isLoading: false);
      _logger.i('Document updated successfully: $documentId');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _logger.e('Error updating document: $e');
    }
  }

  // Verify document
  Future<void> verifyDocument(
    String documentId,
    String verifiedBy,
    VerificationStatus status, {
    String? verificationNotes,
    Map<String, dynamic>? verificationData,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _documentService.verifyDocument(
        documentId,
        verifiedBy,
        status,
        verificationNotes: verificationNotes,
        verificationData: verificationData,
      );

      state = state.copyWith(isLoading: false);
      _logger.i('Document verified successfully: $documentId');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _logger.e('Error verifying document: $e');
    }
  }

  // Generate share token
  Future<String?> generateShareToken({
    required String documentId,
    required String sharedBy,
    required Duration validity,
    String? password,
    int? maxAccess,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final token = await _documentService.generateShareToken(
        documentId: documentId,
        sharedBy: sharedBy,
        validity: validity,
        password: password,
        maxAccess: maxAccess,
      );

      state = state.copyWith(isLoading: false);
      _logger.i('Share token generated for document: $documentId');
      return token;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _logger.e('Error generating share token: $e');
      return null;
    }
  }

  // Access document via token
  Future<DocumentModel?> accessDocumentViaToken({
    required String token,
    String? password,
    required String accessedBy,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final document = await _documentService.accessDocumentViaToken(
        token: token,
        password: password,
        accessedBy: accessedBy,
      );

      state = state.copyWith(isLoading: false);
      _logger.i('Document accessed via token');
      return document;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _logger.e('Error accessing document via token: $e');
      return null;
    }
  }

  // Delete document
  Future<void> deleteDocument(String documentId, String deletedBy) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _documentService.deleteDocument(documentId, deletedBy);

      state = state.copyWith(isLoading: false);
      _logger.i('Document deleted successfully: $documentId');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      _logger.e('Error deleting document: $e');
    }
  }

  // Clear error
  void clearError() {
    state = state.clearError();
  }

  // Reset state
  void reset() {
    state = const DocumentUploadState();
  }
}

// Convenience providers for current user's documents
final userDocumentsProvider = Provider<AsyncValue<List<DocumentModel>>>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  
  if (currentUser == null) {
    return const AsyncValue.data([]);
  }

  final params = DocumentListParams(
    userId: currentUser.id,
    userRole: currentUser.role,
    limit: 50,
  );

  return ref.watch(documentListProvider(params));
});

// Provider for document token access
final documentTokenAccessProvider = FutureProvider.family<DocumentModel?, DocumentTokenParams>((ref, params) async {
  final documentService = ref.read(documentServiceProvider);
  
  try {
    return await documentService.accessDocumentViaToken(
      token: params.token,
      password: params.password,
      accessedBy: params.accessedBy,
    );
  } catch (error) {
    ref.read(documentErrorProvider.notifier).state = error.toString();
    rethrow;
  }
});

class DocumentTokenParams {
  final String token;
  final String? password;
  final String accessedBy;

  DocumentTokenParams({
    required this.token,
    this.password,
    required this.accessedBy,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentTokenParams &&
          runtimeType == other.runtimeType &&
          token == other.token &&
          password == other.password &&
          accessedBy == other.accessedBy;

  @override
  int get hashCode => token.hashCode ^ password.hashCode ^ accessedBy.hashCode;
} 
