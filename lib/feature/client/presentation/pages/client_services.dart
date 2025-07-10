import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import '../../../core/models/certificate_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/notification_service.dart';
import '../providers/ca_providers.dart';
import '../presentation/pages/ca_dashboard.dart';

class CAService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  final _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  Future<CAStats> getCAStats() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final certificatesQuery = await _firestore
          .collection('certificates')
          .where('issuerId', isEqualTo: _currentUserId)
          .get();

      final pendingDocsQuery = await _firestore
          .collection('documents')
          .where('status', isEqualTo: 'pending')
          .get();

      final totalDocsQuery = await _firestore.collection('documents').get();

      final usersQuery = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      return CAStats(
        totalCertificatesIssued: certificatesQuery.docs.length,
        pendingDocuments: pendingDocsQuery.docs.length,
        totalDocuments: totalDocsQuery.docs.length,
        activeUsers: usersQuery.docs.length,
      );
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get CA stats',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<String> createCertificate({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    required DateTime issuedAt,
    String? templateId,
    Map<String, dynamic> customFields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final certificateId = _uuid.v4();
      final verificationCode = _generateVerificationCode();

      // Get default template if none specified
      final actualTemplateId = templateId ?? await _getDefaultTemplateId();

      final certificate = CertificateModel(
        id: certificateId,
        templateId: actualTemplateId,
        issuerId: _currentUserId!,
        issuerName: _auth.currentUser?.displayName ?? 'Unknown CA',
        recipientId: await _getOrCreateRecipientId(recipientEmail),
        recipientName: recipientName,
        recipientEmail: recipientEmail,
        organizationId: _auth.currentUser?.uid ?? '',
        organizationName: 'Certificate Authority',
        verificationCode: verificationCode,
        title: title,
        description: description,
        type: type,
        issuedAt: issuedAt,
        expiresAt: _calculateExpiryDate(type, issuedAt),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: CertificateStatus.issued,
        verificationId: _uuid.v4(),
        qrCode: _generateQRCode(verificationCode),
        hash: _generateCertificateHash(certificateId, verificationCode),
        metadata: {
          'version': '1.0',
          'issuerSignature': await _generateDigitalSignature(certificateId),
          'templateId': actualTemplateId,
          'customFields': customFields,
        },
      );

      await _firestore
          .collection('certificates')
          .doc(certificateId)
          .set(certificate.toFirestore());

      await _logCAActivity(
        action: 'certificate_created',
        description: 'Created certificate: $title for $recipientName',
        metadata: {
          'certificateId': certificateId,
          'recipientEmail': recipientEmail,
          'type': type.name,
        },
      );

      await _sendCertificateNotification(certificate);

      LoggerService.info('Certificate created successfully: $certificateId');
      return certificateId;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to create certificate',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> saveCertificateDraft({
    required String title,
    required String recipientName,
    required String recipientEmail,
    required String description,
    required CertificateType type,
    String? templateId,
    Map<String, dynamic> customFields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final draftId = _uuid.v4();

      await _firestore.collection('certificate_drafts').doc(draftId).set({
        'id': draftId,
        'title': title,
        'recipientName': recipientName,
        'recipientEmail': recipientEmail,
        'description': description,
        'type': type.name,
        'issuerId': _currentUserId,
        'templateId': templateId ?? await _getDefaultTemplateId(),
        'customFields': customFields,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'draft_saved',
        description: 'Saved certificate draft: $title',
        metadata: {
          'draftId': draftId,
          'recipientEmail': recipientEmail,
        },
      );

      LoggerService.info('Certificate draft saved successfully: $draftId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to save certificate draft',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<DocumentModel>> getPendingDocuments() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final querySnapshot = await _firestore
          .collection('documents')
          .where('verificationStatus', isEqualTo: 'pending')
      // .orderBy('uploadedAt', descending: true)
          .limit(50)
          .get();

      return querySnapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get pending documents',
          error: error, stackTrace: stackTrace);
      return [];
    }
  }

  Future<void> approveDocument(String documentId, String comments) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('documents').doc(documentId).update({
        'status': DocumentStatus.verified.name,
        'reviewedBy': _currentUserId,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewComments': comments,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'verificationStatus': 'verified',
        'verifiedAt': FieldValue.serverTimestamp(), // ✅ This is fine
        'verificationHistory': FieldValue.arrayUnion([
          {
            'action': 'approved',
            'timestamp': Timestamp.now(), // ✅ FIXED HERE
            'comments': comments,
          }
        ])
      });


      await _logCAActivity(
        action: 'document_approved',
        description: 'Approved document: $documentId',
        metadata: {
          'documentId': documentId,
          'comments': comments,
        },
      );

      LoggerService.info('Document approved: $documentId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to approve document',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> rejectDocument(String documentId, String reason) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('documents').doc(documentId).update({
        'status': DocumentStatus.rejected.name,
        'reviewedBy': _currentUserId,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'rejectionReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        'verificationStatus': 'rejected',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verificationHistory': FieldValue.arrayUnion([
          {
            'action': 'rejected',
            'timestamp': Timestamp.now(), // ✅ FIXED
            'reason': reason,
          }
        ])
      });

      await _logCAActivity(
        action: 'document_rejected',
        description: 'Rejected document: $documentId',
        metadata: {
          'documentId': documentId,
          'reason': reason,
        },
      );

      LoggerService.info('Document rejected: $documentId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to reject document',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<CASettingsModel> getCASettings() async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final doc =
      await _firestore.collection('ca_settings').doc(_currentUserId).get();

      if (doc.exists) {
        return CASettingsModel.fromFirestore(doc);
      } else {
        return const CASettingsModel(
          organizationName: 'Certificate Authority',
          contactEmail: '',
          contactPhone: '',
          address: '',
        );
      }
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get CA settings',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateCASettings(CASettingsModel settings) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('ca_settings')
          .doc(_currentUserId)
          .set(settings.toFirestore());

      await _logCAActivity(
        action: 'settings_updated',
        description: 'Updated CA settings',
        metadata: settings.toFirestore(),
      );

      LoggerService.info('CA settings updated successfully');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to update CA settings',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> revokeCertificate(String certificateId, String reason) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore.collection('certificates').doc(certificateId).update({
        'status': CertificateStatus.revoked.name,
        'revokedAt': Timestamp.fromDate(DateTime.now()),
        'revokedBy': _currentUserId,
        'revocationReason': reason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      await _logCAActivity(
        action: 'certificate_revoked',
        description: 'Revoked certificate: $certificateId',
        metadata: {
          'certificateId': certificateId,
          'reason': reason,
        },
      );

      LoggerService.info('Certificate revoked successfully: $certificateId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to revoke certificate',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<CertificateTemplate>> getCertificateTemplates() async {
    try {
      final templatesQuery = await _firestore
          .collection('certificate_templates')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      return templatesQuery.docs
          .map((doc) => CertificateTemplate.fromFirestore(doc))
          .toList();
    } catch (error, stackTrace) {
      LoggerService.error('Failed to get certificate templates',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> uploadCertificateTemplate({
    required String name,
    required String description,
    required String templateUrl,
    Map<String, dynamic> fields = const {},
  }) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final templateId = _uuid.v4();

      await _firestore.collection('certificate_templates').doc(templateId).set({
        'id': templateId,
        'name': name,
        'description': description,
        'templateUrl': templateUrl,
        'fields': fields,
        'createdBy': _currentUserId,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'isActive': true,
      });

      await _logCAActivity(
        action: 'template_uploaded',
        description: 'Uploaded certificate template: $name',
        metadata: {
          'templateId': templateId,
          'templateName': name,
        },
      );

      LoggerService.info(
          'Certificate template uploaded successfully: $templateId');
    } catch (error, stackTrace) {
      LoggerService.error('Failed to upload certificate template',
          error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  String _generateQRCode(String verificationCode) {
    return 'QR_${verificationCode}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _generateCertificateHash(
      String certificateId, String verificationCode) {
    final content =
        '$certificateId-$verificationCode-${DateTime.now().millisecondsSinceEpoch}';
    return content.hashCode.abs().toString();
  }

  Future<String> _getOrCreateRecipientId(String email) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        return userQuery.docs.first.id;
      } else {
        final recipientId = _uuid.v4();
        await _firestore.collection('recipients').doc(recipientId).set({
          'id': recipientId,
          'email': email,
          'createdAt': Timestamp.fromDate(DateTime.now()),
          'createdBy': _currentUserId,
        });
        return recipientId;
      }
    } catch (error) {
      LoggerService.error('Failed to get or create recipient ID', error: error);
      return _uuid.v4();
    }
  }

  DateTime? _calculateExpiryDate(CertificateType type, DateTime issuedAt) {
    switch (type) {
      case CertificateType.academic:
        return null;
      case CertificateType.professional:
        return issuedAt.add(const Duration(days: 365 * 3));
      case CertificateType.completion:
        return null;
      case CertificateType.achievement:
        return null;
      case CertificateType.participation:
        return null;
      default:
        return issuedAt.add(const Duration(days: 365));
    }
  }

  Future<String> _generateDigitalSignature(String certificateId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final issuer = _auth.currentUser?.uid ?? 'unknown';
    final content = '$certificateId-$issuer-$timestamp';

    return content.hashCode.abs().toString();
  }

  Future<void> _sendCertificateNotification(
      CertificateModel certificate) async {
    try {
      await _notificationService.sendCertificateIssuedNotification(
        recipientEmail: certificate.recipientEmail,
        certificateTitle: certificate.title,
        issuerName: certificate.issuerName,
        verificationCode: certificate.verificationCode,
      );
    } catch (error) {
      LoggerService.error('Failed to send certificate notification',
          error: error);
    }
  }

  /// Get default template ID or create one if none exists
  Future<String> _getDefaultTemplateId() async {
    try {
      // Check if there's a system default template
      final systemDefaultQuery = await _firestore
          .collection('certificate_templates')
          .where('isDefault', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (systemDefaultQuery.docs.isNotEmpty) {
        return systemDefaultQuery.docs.first.id;
      }

      // If no system default, get the first available template
      final anyTemplateQuery = await _firestore
          .collection('certificate_templates')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (anyTemplateQuery.docs.isNotEmpty) {
        return anyTemplateQuery.docs.first.id;
      }

      // If no templates exist, create a basic default template
      final defaultTemplateId = await _createDefaultTemplate();
      return defaultTemplateId;
    } catch (error) {
      LoggerService.error('Failed to get default template ID', error: error);
      // Return a fallback template ID
      return 'fallback_template';
    }
  }

  /// Create a basic default template if none exists
  Future<String> _createDefaultTemplate() async {
    try {
      final templateId = 'default_${_uuid.v4()}';

      await _firestore.collection('certificate_templates').doc(templateId).set({
        'id': templateId,
        'name': 'Default Certificate Template',
        'description': 'Basic certificate template for general use',
        'templateUrl': 'assets/templates/default_certificate_template.png',
        'fields': {
          'title': 'Certificate Title',
          'recipientName': 'Recipient Name',
          'description': 'Certificate Description',
          'issuedDate': 'Issue Date',
          'issuerName': 'Issuer Name',
        },
        'isDefault': true,
        'isActive': true,
        'createdBy': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      LoggerService.info('Created default certificate template: $templateId');
      return templateId;
    } catch (error) {
      LoggerService.error('Failed to create default template', error: error);
      return 'fallback_template';
    }
  }
  Future<List<DocumentModel>> getDocumentsByStatus(String status) async {
    try {
      Query query = _firestore.collection('documents');

      if (status != 'all') {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => DocumentModel.fromFirestore(doc))
          .toList();
    } catch (e, stack) {
      LoggerService.error('Failed to fetch documents with status $status', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _logCAActivity({
    required String action,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      if (_currentUserId == null) return;

      final activity = CAActivity(
        id: _uuid.v4(),
        caId: _currentUserId!,
        action: action,
        description: description,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      await _firestore
          .collection('ca_activities')
          .doc(activity.id)
          .set(activity.toFirestore());
    } catch (error) {
      LoggerService.error('Failed to log CA activity', error: error);
    }
  }
}

class CertificateTemplate {
  final String id;
  final String name;
  final String description;
  final String templateUrl;
  final Map<String, dynamic> fields;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  const CertificateTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.templateUrl,
    required this.fields,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  factory CertificateTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CertificateTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      templateUrl: data['templateUrl'] ?? '',
      fields: data['fields'] ?? {},
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'templateUrl': templateUrl,
      'fields': fields,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}

Future<List<DocumentModel>> getPendingDocuments() async {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    LoggerService.info('No user logged in');
    return [];
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('documents')
      .where('status', isEqualTo: 'pending') // or any field you filter by
      .get();

  LoggerService.info('Fetched ${snapshot.docs.length} pending docs');

  return snapshot.docs
      .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
      .toList();
}



