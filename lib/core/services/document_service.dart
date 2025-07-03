import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/document_model.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  // Collection references
  CollectionReference get _documentsCollection =>
      _firestore.collection(AppConfig.documentsCollection);
  CollectionReference get _accessLogsCollection =>
      _firestore.collection('document_access_logs');

  // Upload Document - Web Compatible Version
  Future<DocumentModel> uploadDocumentWeb({
    required String name,
    required String description,
    required DocumentType type,
    required String uploadedBy,
    required Uint8List fileBytes,
    required String fileName,
    required int fileSize,
    required String mimeType,
    String? associatedCertificateId,
    VerificationLevel verificationLevel = VerificationLevel.basic,
    List<String> allowedUsers = const [],
    Map<String, dynamic>? metadata,
    List<String> tags = const [],
  }) async {
    try {
      // Generate unique document ID
      final documentId = _generateDocumentId();
      
      // Create unique file name
      final uniqueFileName = '${documentId}_$fileName';
      final storageRef = _storage.ref().child('documents/$uniqueFileName');
      
      // Upload using bytes for web compatibility
      final uploadTask = await storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: mimeType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Calculate file hash for integrity
      final fileHash = _calculateFileHash(fileBytes);
      
      // Extract metadata from file bytes
      final extractedMetadata = await _extractFileMetadataFromBytes(fileBytes, mimeType);
      
      // Create document model
      final document = DocumentModel(
        id: documentId,
        name: name,
        description: description,
        type: type,
        status: DocumentStatus.uploaded,
        uploaderId: uploadedBy,
        uploaderName: uploadedBy,
        uploadedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileUrl: downloadUrl,
        fileName: uniqueFileName,
        fileSize: fileSize,
        mimeType: mimeType,
        hash: fileHash,
        verificationLevel: verificationLevel,
        verificationStatus: VerificationStatus.pending,
        associatedCertificateId: associatedCertificateId,
        accessLevel: AccessLevel.restricted,
        allowedUsers: allowedUsers,
        tags: tags,
        metadata: DocumentMetadata(
          technicalDetails: extractedMetadata,
          customFields: metadata ?? {},
        ),
        accessHistory: [],
        shareTokens: [],
      );

      // Save to Firestore
      await _documentsCollection.doc(documentId).set(document.toMap());
      
      // Log access
      await _logDocumentAccess(
        documentId: documentId,
        userId: uploadedBy,
        action: DocumentAccessAction.uploaded,
        details: 'Document uploaded via web',
      );

      _logger.i('Document uploaded successfully (Web): $documentId');
      return document;
    } catch (e) {
      _logger.e('Error uploading document (Web): $e');
      rethrow;
    }
  }

  // Upload Document - Platform Agnostic
  Future<DocumentModel> uploadDocument({
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
      // For Web platform, this should not be called
      if (kIsWeb) {
        throw UnsupportedError('Use uploadDocumentWeb for web platform');
      }
      
      // Generate unique document ID
      final documentId = _generateDocumentId();
      
      // Upload file to Firebase Storage
      final file = File(filePath);
      final fileName = '${documentId}_$name';
      final storageRef = _storage.ref().child('documents/$fileName');
      
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Calculate file hash for integrity
      final fileBytes = await file.readAsBytes();
      final fileHash = _calculateFileHash(fileBytes);
      
      // Extract metadata from file
      final extractedMetadata = await _extractFileMetadata(file, mimeType);
      
      // Create document model
      final document = DocumentModel(
        id: documentId,
        name: name,
        description: description,
        type: type,
        status: DocumentStatus.uploaded,
        uploaderId: uploadedBy,
        uploaderName: uploadedBy,
        uploadedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileUrl: downloadUrl,
        fileName: fileName,
        fileSize: fileSize,
        mimeType: mimeType,
        hash: fileHash,
        verificationLevel: verificationLevel,
        verificationStatus: VerificationStatus.pending,
        associatedCertificateId: associatedCertificateId,
        accessLevel: AccessLevel.restricted,
        allowedUsers: allowedUsers,
        tags: tags,
        metadata: DocumentMetadata(
          technicalDetails: extractedMetadata,
          customFields: metadata ?? {},
        ),
        accessHistory: [],
        shareTokens: [],
      );

      // Save to Firestore
      await _documentsCollection.doc(documentId).set(document.toMap());
      
      // Log access
      await _logDocumentAccess(
        documentId: documentId,
        userId: uploadedBy,
        action: DocumentAccessAction.uploaded,
        details: 'Document uploaded',
      );

      _logger.i('Document uploaded successfully: $documentId');
      return document;
    } catch (e) {
      _logger.e('Error uploading document: $e');
      rethrow;
    }
  }

  // Get Document by ID
  Future<DocumentModel?> getDocumentById(String documentId) async {
    try {
      final doc = await _documentsCollection.doc(documentId).get();
      if (doc.exists) {
        return DocumentModel.fromMap(doc.data() as Map<String, dynamic>,doc.id);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting document: $e');
      rethrow;
    }
  }

  // Get Documents by User
  Future<List<DocumentModel>> getDocumentsByUser({
    required String userId,
    UserRole? userRole,
    List<DocumentType>? types,
    List<VerificationStatus>? statuses,
    int? limit,
  }) async {
    try {
      Query query = _documentsCollection;

      // Filter based on user role and permissions
      if (userRole == UserRole.systemAdmin) {
        // Admin can see all documents
      } else {
        // Users can only see documents they uploaded or have access to
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      // Filter by type
      if (types != null && types.isNotEmpty) {
        query = query.where('type', whereIn: types.map((t) => t.name).toList());
      }

      // Filter by status
      if (statuses != null && statuses.isNotEmpty) {
        query = query.where('verificationStatus', whereIn: statuses.map((s) => s.name).toList());
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      // Order by upload date
      query = query.orderBy('uploadedAt', descending: true);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data() as Map<String, dynamic>,doc.id))
          .toList();
    } catch (e) {
      _logger.e('Error getting documents by user: $e');
      rethrow;
    }
  }

  // Search Documents
  Future<List<DocumentModel>> searchDocuments({
    String? searchTerm,
    DocumentType? type,
    List<VerificationStatus>? statuses,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? tags,
    String? userId,
    UserRole? userRole,
    int? limit,
  }) async {
    try {
      Query query = _documentsCollection;

      // Apply user-based filtering
      if (userRole != UserRole.systemAdmin && userId != null) {
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      // Filter by type
      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      // Filter by status
      if (statuses != null && statuses.isNotEmpty) {
        query = query.where('verificationStatus', whereIn: statuses.map((s) => s.name).toList());
      }

      // Filter by date range
      if (startDate != null) {
        query = query.where('uploadedAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('uploadedAt', isLessThanOrEqualTo: endDate);
      }

      // Add limit
      if (limit != null) {
        query = query.limit(limit);
      }

      query = query.orderBy('uploadedAt', descending: true);

      final querySnapshot = await query.get();
      List<DocumentModel> documents = querySnapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data() as Map<String, dynamic>,doc.id))
          .toList();

      // Apply additional filters that can't be done in Firestore query
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final searchLower = searchTerm.toLowerCase();
        documents = documents.where((doc) =>
          doc.name.toLowerCase().contains(searchLower) ||
          doc.description.toLowerCase().contains(searchLower)
        ).toList();
      }

      if (tags != null && tags.isNotEmpty) {
        documents = documents.where((doc) =>
          doc.tags.any((tag) => tags.contains(tag))
        ).toList();
      }

      return documents;
    } catch (e) {
      _logger.e('Error searching documents: $e');
      rethrow;
    }
  }

  // Update Document
  Future<void> updateDocument(
    String documentId,
    Map<String, dynamic> updates,
    String updatedBy,
  ) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _documentsCollection.doc(documentId).update(updates);
      
      await _logDocumentAccess(
        documentId: documentId,
        userId: updatedBy,
        action: DocumentAccessAction.modified,
        details: 'Document updated: ${updates.keys.join(', ')}',
      );

      _logger.i('Document updated: $documentId');
    } catch (e) {
      _logger.e('Error updating document: $e');
      rethrow;
    }
  }

  // Verify Document
  Future<void> verifyDocument(
    String documentId,
    String verifiedBy,
    VerificationStatus status, {
    String? verificationNotes,
    Map<String, dynamic>? verificationData,
  }) async {
    try {
      final updates = <String, dynamic>{
        'verificationStatus': status.name,
        'verifiedBy': verifiedBy,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (verificationNotes != null) {
        updates['verificationNotes'] = verificationNotes;
      }
      if (verificationData != null) {
        updates['verificationData'] = verificationData;
      }

      await _documentsCollection.doc(documentId).update(updates);
      
      await _logDocumentAccess(
        documentId: documentId,
        userId: verifiedBy,
        action: DocumentAccessAction.verified,
        details: 'Document verification: ${status.name}',
      );

      _logger.i('Document verified: $documentId');
    } catch (e) {
      _logger.e('Error verifying document: $e');
      rethrow;
    }
  }

  // Generate Share Token
  Future<String> generateShareToken({
    required String documentId,
    required String sharedBy,
    required Duration validity,
    String? password,
    int? maxAccess,
  }) async {
    try {
      final token = _generateShareToken();
      final expiresAt = DateTime.now().add(validity);
      
      final shareData = ShareToken(
        token: token,
        documentId: documentId,
        sharedBy: sharedBy,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        password: password,
        maxAccess: maxAccess,
        currentAccess: 0,
        isActive: true,
      );

      // Update document with new share token
      await _documentsCollection.doc(documentId).update({
        'shareTokens': FieldValue.arrayUnion([shareData.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logDocumentAccess(
        documentId: documentId,
        userId: sharedBy,
        action: DocumentAccessAction.shared,
        details: 'Share token generated',
      );

      _logger.i('Share token generated for document: $documentId');
      return token;
    } catch (e) {
      _logger.e('Error generating share token: $e');
      rethrow;
    }
  }

  // Access Document via Token
  Future<DocumentModel?> accessDocumentViaToken({
    required String token,
    String? password,
    required String accessedBy,
  }) async {
    try {
      // Find document with this token
      final querySnapshot = await _documentsCollection
          .where('shareTokens', arrayContains: {'token': token})
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid token');
      }

      final doc = querySnapshot.docs.first;
      final document = DocumentModel.fromMap(doc.data() as Map<String, dynamic>,doc.id);
      
      // Find the specific token
      final shareToken = document.shareTokens.firstWhere(
        (t) => t.token == token,
        orElse: () => throw Exception('Token not found'),
      );

      // Validate token
      if (!shareToken.isActive) {
        throw Exception('Token is inactive');
      }
      if (shareToken.expiresAt.isBefore(DateTime.now())) {
        throw Exception('Token has expired');
      }
      if (shareToken.maxAccess != null && 
          shareToken.currentAccess >= shareToken.maxAccess!) {
        throw Exception('Token access limit reached');
      }
      if (shareToken.password != null && shareToken.password != password) {
        throw Exception('Invalid password');
      }

      // Update access count
      final updatedTokens = document.shareTokens.map((t) {
        if (t.token == token) {
          return ShareToken(
            token: t.token,
            documentId: t.documentId,
            sharedBy: t.sharedBy,
            createdAt: t.createdAt,
            expiresAt: t.expiresAt,
            password: t.password,
            maxAccess: t.maxAccess,
            currentAccess: t.currentAccess + 1,
            isActive: t.isActive,
          );
        }
        return t;
      }).toList();
      
      await _documentsCollection.doc(document.id).update({
        'shareTokens': updatedTokens.map((t) => t.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _logDocumentAccess(
        documentId: document.id,
        userId: accessedBy,
        action: DocumentAccessAction.accessed,
        details: 'Accessed via share token',
      );

      return document;
    } catch (e) {
      _logger.e('Error accessing document via token: $e');
      rethrow;
    }
  }

  // Delete Document
  Future<void> deleteDocument(String documentId, String deletedBy) async {
    try {
      final document = await getDocumentById(documentId);
      if (document == null) {
        throw Exception('Document not found');
      }

      // Delete file from storage
      try {
        final storageRef = _storage.refFromURL(document.fileUrl);
        await storageRef.delete();
      } catch (e) {
        _logger.w('Error deleting file from storage: $e');
        // Continue with document deletion even if file deletion fails
      }

      // Delete document from Firestore
      await _documentsCollection.doc(documentId).delete();
      
      await _logDocumentAccess(
        documentId: documentId,
        userId: deletedBy,
        action: DocumentAccessAction.deleted,
        details: 'Document deleted',
      );

      _logger.i('Document deleted: $documentId');
    } catch (e) {
      _logger.e('Error deleting document: $e');
      rethrow;
    }
  }

  // Get Document Statistics
  Future<DocumentStatistics> getDocumentStatistics({
    String? userId,
    UserRole? userRole,
  }) async {
    try {
      Query query = _documentsCollection;
      
      if (userRole != UserRole.systemAdmin && userId != null) {
        query = query.where(Filter.or(
          Filter('uploadedBy', isEqualTo: userId),
          Filter('allowedUsers', arrayContains: userId),
        ));
      }

      final querySnapshot = await query.get();
      final documents = querySnapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data() as Map<String, dynamic>,doc.id))
          .toList();

      return DocumentStatistics(
        totalDocuments: documents.length,
        verifiedDocuments: documents.where((d) => d.verificationStatus == VerificationStatus.verified).length,
        pendingDocuments: documents.where((d) => d.verificationStatus == VerificationStatus.pending).length,
        rejectedDocuments: documents.where((d) => d.verificationStatus == VerificationStatus.rejected).length,
        documentsByType: _groupDocumentsByType(documents),
        documentsByMonth: _groupDocumentsByMonth(documents),
        totalFileSize: documents.fold(0, (total, doc) => total + doc.fileSize),
      );
    } catch (e) {
      _logger.e('Error getting document statistics: $e');
      rethrow;
    }
  }

  // Private helper methods
  String _generateDocumentId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'DOC-${timestamp.toRadixString(36).toUpperCase()}-${random.toRadixString(36).toUpperCase()}';
  }

  String _generateShareToken() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'TOKEN-${timestamp.toRadixString(36)}-${random.toRadixString(36)}';
  }

  String _calculateFileHash(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>> _extractFileMetadata(File file, String mimeType) async {
    try {
      final stat = await file.stat();
      return {
        'fileName': file.path.split('/').last,
        'fileExtension': file.path.split('.').last,
        'createdAt': stat.changed.toIso8601String(),
        'modifiedAt': stat.modified.toIso8601String(),
        'mimeType': mimeType,
        'encoding': 'utf-8', // Default encoding
      };
    } catch (e) {
      _logger.w('Error extracting file metadata: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _extractFileMetadataFromBytes(
    Uint8List fileBytes, 
    String mimeType
  ) async {
    final metadata = <String, dynamic>{
      'size': fileBytes.length,
      'mimeType': mimeType,
      'extractedAt': DateTime.now().toIso8601String(),
    };

    // Add type-specific properties
    if (mimeType.startsWith('image/')) {
      metadata['type'] = 'image';
      metadata['isImage'] = true;
    } else if (mimeType.contains('pdf')) {
      metadata['type'] = 'pdf';
      metadata['isPdf'] = true;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      metadata['type'] = 'document';
      metadata['isDocument'] = true;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      metadata['type'] = 'spreadsheet';
      metadata['isSpreadsheet'] = true;
    } else {
      metadata['type'] = 'other';
    }

    return metadata;
  }

  Future<void> _logDocumentAccess({
    required String documentId,
    required String userId,
    required DocumentAccessAction action,
    required String details,
  }) async {
    try {
      await _accessLogsCollection.add({
        'documentId': documentId,
        'userId': userId,
        'action': action.name,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': null, // Could be added if needed
        'userAgent': null, // Could be added if needed
      });
    } catch (e) {
      _logger.w('Error logging document access: $e');
      // Don't throw error for logging failures
    }
  }

  Map<String, int> _groupDocumentsByType(List<DocumentModel> documents) {
    final Map<String, int> result = {};
    for (final doc in documents) {
      result[doc.type.name] = (result[doc.type.name] ?? 0) + 1;
    }
    return result;
  }

  Map<String, int> _groupDocumentsByMonth(List<DocumentModel> documents) {
    final Map<String, int> result = {};
    for (final doc in documents) {
      final monthKey = '${doc.uploadedAt.year}-${doc.uploadedAt.month.toString().padLeft(2, '0')}';
      result[monthKey] = (result[monthKey] ?? 0) + 1;
    }
    return result;
  }
}

// Supporting classes
enum DocumentAccessAction {
  uploaded,
  accessed,
  modified,
  verified,
  shared,
  deleted,
}

class DocumentStatistics {
  final int totalDocuments;
  final int verifiedDocuments;
  final int pendingDocuments;
  final int rejectedDocuments;
  final Map<String, int> documentsByType;
  final Map<String, int> documentsByMonth;
  final int totalFileSize;

  DocumentStatistics({
    required this.totalDocuments,
    required this.verifiedDocuments,
    required this.pendingDocuments,
    required this.rejectedDocuments,
    required this.documentsByType,
    required this.documentsByMonth,
    required this.totalFileSize,
  });
} 
