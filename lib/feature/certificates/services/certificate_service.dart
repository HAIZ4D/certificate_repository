import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../../core/models/certificate_model.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/services/user_service.dart';

class CertificateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final UserService _userService = UserService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  // Collection references
  CollectionReference get _certificatesCollection =>
      _firestore.collection('certificates');
  CollectionReference get _transactionsCollection =>
      _firestore.collection(AppConfig.transactionsCollection);

  // Helper to generate a random access token
  String _generateAccessToken({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // Create Certificate
  Future<CertificateModel> createCertificate({
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
    try {
      final now = DateTime.now();
      final certificateId = _uuid.v4();
      final verificationId = _generateVerificationId();
      final accessToken = _generateAccessToken(length: 8); // Generate token

      // Generate QR code data
      final qrCodeData = _generateQrCodeData(certificateId, verificationId);

      // Create certificate model
      final certificate = CertificateModel(
        id: certificateId,
        templateId: templateId,
        issuerId: issuerId,
        issuerName: 'Certificate Authority', // Default issuer name
        recipientId: recipientId,
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        organizationId: organizationId,
        organizationName: organizationName,
        verificationCode: _generateVerificationCode(),
        title: title,
        description: description,
        type: type,
        courseName: courseName,
        courseCode: courseCode,
        grade: grade,
        credits: credits,
        achievement: achievement,
        issuedAt: now,
        completedAt: completedAt,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
        status: requiresApproval ? CertificateStatus.pending : CertificateStatus.draft,
        verificationId: verificationId,
        qrCode: qrCodeData,
        hash: _generateCertificateHash(certificateId, verificationId, title),
        metadata: metadata,
        tags: tags,
        notes: notes,
        requiresApproval: requiresApproval,
        approvalSteps: approvalSteps,
        currentApprovalStep: approvalSteps.isNotEmpty ? approvalSteps.first.id : null,
      );

      // Save to Firestore, including accessToken
      final data = certificate.toFirestore();
      data['accessToken'] = accessToken;
      await _certificatesCollection.doc(certificateId).set(data);

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'created',
        performedBy: issuerId,
        details: {'type': type.name, 'title': title},
      );

      _logger.i('Certificate created: $certificateId by $issuerId');
      return certificate;
    } catch (e) {
      _logger.e('Failed to create certificate: $e');
      rethrow;
    }
  }

  // Generate PDF Certificate
  Future<String> generatePdfCertificate(String certificateId) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      final pdf = await _generateCertificatePdf(certificate);
      final pdfBytes = await pdf.save();

      // Upload to Firebase Storage
      final fileName = 'certificate_${certificateId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final storageRef = _storage.ref().child('${AppConfig.certificatesStoragePath}/$fileName');

      final uploadTask = storageRef.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'certificateId': certificateId,
            'type': 'certificate_pdf',
            'generated': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update certificate with PDF URL
      await updateCertificate(
        certificateId,
        {'pdfUrl': downloadUrl, 'fileSize': pdfBytes.length},
      );

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'pdf_generated',
        performedBy: certificate.issuerId,
        details: {'pdfUrl': downloadUrl, 'fileSize': pdfBytes.length},
      );

      _logger.i('PDF generated for certificate: $certificateId');
      return downloadUrl;
    } catch (e) {
      _logger.e('Failed to generate PDF: $e');
      rethrow;
    }
  }

  // Issue Certificate (change status to issued)
  Future<CertificateModel> issueCertificate(String certificateId, String issuerId) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      // Verify issuer has permission
      final issuer = await _userService.getUserById(issuerId);
      if (issuer == null || !issuer.canCreateCertificates) {
        throw Exception('Insufficient permissions to issue certificate');
      }

      // Check if certificate can be issued
      if (certificate.status != CertificateStatus.approved &&
          certificate.status != CertificateStatus.draft) {
        throw Exception('Certificate cannot be issued in current status: ${certificate.statusDisplayName}');
      }

      // Generate PDF if not exists
      String? pdfUrl = certificate.pdfUrl;
      if (pdfUrl == null || pdfUrl.isEmpty) {
        pdfUrl = await generatePdfCertificate(certificateId);
      }

      // Update certificate status
      final updatedCertificate = certificate.copyWith(
        status: CertificateStatus.issued,
        issuedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isVerified: true,
      );

      await _certificatesCollection.doc(certificateId).update(updatedCertificate.toFirestore());

      // Send notification to recipient
      await _sendCertificateNotification(updatedCertificate, 'issued');

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'issued',
        performedBy: issuerId,
        details: {'previousStatus': certificate.status.name},
      );

      _logger.i('Certificate issued: $certificateId by $issuerId');
      return updatedCertificate;
    } catch (e) {
      _logger.e('Failed to issue certificate: $e');
      rethrow;
    }
  }

  // Approve Certificate
  Future<CertificateModel> approveCertificate(
      String certificateId,
      String approverId,
      String stepId,
      String comments,
      ) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      // Find and update approval step
      final approvalSteps = List<ApprovalStep>.from(certificate.approvalSteps);
      final stepIndex = approvalSteps.indexWhere((step) => step.id == stepId);

      if (stepIndex == -1) {
        throw Exception('Approval step not found');
      }

      // Update the approval step
      approvalSteps[stepIndex] = ApprovalStep(
        id: stepId,
        stepName: approvalSteps[stepIndex].stepName,
        approverId: approverId,
        approverName: approvalSteps[stepIndex].approverName,
        approverEmail: approvalSteps[stepIndex].approverEmail,
        status: 'approved',
        approvedAt: DateTime.now(),
        comments: comments,
        order: approvalSteps[stepIndex].order,
      );

      // Check if all steps are approved
      final allApproved = approvalSteps.every((step) => step.status == 'approved');
      final nextStep = approvalSteps.firstWhere(
            (step) => step.status == 'pending',
        orElse: () => approvalSteps.first,
      );

      final updatedCertificate = certificate.copyWith(
        approvalSteps: approvalSteps,
        currentApprovalStep: allApproved ? null : nextStep.id,
        status: allApproved ? CertificateStatus.approved : CertificateStatus.pending,
        updatedAt: DateTime.now(),
      );

      await _certificatesCollection.doc(certificateId).update(updatedCertificate.toFirestore());

      // Send notification
      await _sendCertificateNotification(updatedCertificate, 'approved');

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'approved',
        performedBy: approverId,
        details: {'stepId': stepId, 'comments': comments, 'allApproved': allApproved},
      );

      _logger.i('Certificate approved: $certificateId by $approverId');
      return updatedCertificate;
    } catch (e) {
      _logger.e('Failed to approve certificate: $e');
      rethrow;
    }
  }

  // Revoke Certificate
  Future<CertificateModel> revokeCertificate(
      String certificateId,
      String revokedBy,
      String reason,
      ) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      final updatedCertificate = certificate.copyWith(
        status: CertificateStatus.revoked,
        isRevoked: true,
        revocationReason: reason,
        updatedAt: DateTime.now(),
      );

      await _certificatesCollection.doc(certificateId).update(updatedCertificate.toFirestore());

      // Send notification
      await _sendCertificateNotification(updatedCertificate, 'revoked');

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'revoked',
        performedBy: revokedBy,
        details: {'reason': reason},
      );

      _logger.i('Certificate revoked: $certificateId by $revokedBy');
      return updatedCertificate;
    } catch (e) {
      _logger.e('Failed to revoke certificate: $e');
      rethrow;
    }
  }

  // Create Share Token
  Future<ShareToken> createShareToken(
      String certificateId,
      String sharedBy, {
        Duration? validityDuration,
        String? password,
        int maxAccess = 100,
      }) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      if (!certificate.canBeShared) {
        throw Exception('Certificate cannot be shared in current status');
      }

      final now = DateTime.now();
      final expiresAt = validityDuration != null
          ? now.add(validityDuration)
          : now.add(const Duration(days: AppConfig.defaultShareTokenValidityDays));

      final token = _generateShareToken();

      final shareToken = ShareToken(
        token: token,
        certificateId: certificateId,
        sharedBy: sharedBy,
        createdAt: now,
        expiresAt: expiresAt,
        password: password,
        maxAccess: maxAccess,
        currentAccess: 0,
        isActive: true,
      );

      // Update certificate with new share token
      final updatedTokens = List<ShareToken>.from(certificate.shareTokens);
      updatedTokens.add(shareToken);

      await updateCertificate(certificateId, {
        'shareTokens': updatedTokens.map((t) => t.toMap()).toList(),
        'shareCount': certificate.shareCount + 1,
      });

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'shared',
        performedBy: sharedBy,
        details: {'token': token, 'expiresAt': expiresAt.toIso8601String()},
      );

      _logger.i('Share token created for certificate: $certificateId');
      return shareToken;
    } catch (e) {
      _logger.e('Failed to create share token: $e');
      rethrow;
    }
  }

  // Verify Certificate by Token
  Future<CertificateModel?> verifyCertificateByToken(String token, [String? password]) async {
    try {
      // Query certificates with this token
      final querySnapshot = await _certificatesCollection
          .where('shareTokens', arrayContainsAny: [{'token': token}])
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final certificate = CertificateModel.fromFirestore(querySnapshot.docs.first);

      // Find the specific token
      final shareToken = certificate.shareTokens.firstWhere(
            (t) => t.token == token,
        orElse: () => throw Exception('Invalid token'),
      );

      // Validate token
      if (!shareToken.isValid) {
        throw Exception('Token is expired or exhausted');
      }

      // Check password if required
      if (shareToken.password != null && shareToken.password != password) {
        throw Exception('Invalid password');
      }

      // Update access count
      final updatedTokens = certificate.shareTokens.map((t) {
        if (t.token == token) {
          return ShareToken(
            token: t.token,
            certificateId: t.certificateId,
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

      await updateCertificate(certificate.id, {
        'shareTokens': updatedTokens.map((t) => t.toMap()).toList(),
        'accessCount': certificate.accessCount + 1,
        'lastAccessedAt': FieldValue.serverTimestamp(),
        'verificationCount': certificate.verificationCount + 1,
      });

      // Log access
      await _logTransaction(
        certificateId: certificate.id,
        action: 'accessed_via_token',
        performedBy: 'anonymous',
        details: {'token': token, 'accessCount': certificate.accessCount + 1},
      );

      _logger.i('Certificate accessed via token: ${certificate.id}');
      return certificate;
    } catch (e) {
      _logger.e('Failed to verify certificate by token: $e');
      rethrow;
    }
  }

  // Verify Certificate by ID
  Future<CertificateModel?> verifyCertificateById(String certificateId) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) return null;

      // Update verification count
      await updateCertificate(certificateId, {
        'verificationCount': certificate.verificationCount + 1,
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });

      // Log verification
      await _logTransaction(
        certificateId: certificateId,
        action: 'verified',
        performedBy: 'anonymous',
        details: {'method': 'direct_verification'},
      );

      return certificate;
    } catch (e) {
      _logger.e('Failed to verify certificate: $e');
      rethrow;
    }
  }

  // Get Certificate by ID
  Future<CertificateModel?> getCertificateById(String certificateId) async {
    try {
      final doc = await _certificatesCollection.doc(certificateId).get();
      if (!doc.exists) return null;

      return CertificateModel.fromFirestore(doc);
    } catch (e) {
      _logger.e('Failed to get certificate: $e');
      rethrow;
    }
  }

  // Get Certificates with Filter
  Future<List<CertificateModel>> getCertificates({
    CertificateFilter? filter,
    int limit = 20,
    DocumentSnapshot? startAfter,
    String orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      Query query = _certificatesCollection;

      // Simple single-field filters to avoid composite index requirements
      if (filter != null) {
        // Use only one filter at a time to avoid composite index needs
        if (filter.recipientId != null) {
          query = query.where('recipientId', isEqualTo: filter.recipientId);
        } else if (filter.issuerId != null) {
          query = query.where('issuerId', isEqualTo: filter.issuerId);
        } else if (filter.organizationId != null) {
          query = query.where('organizationId', isEqualTo: filter.organizationId);
        } else if (filter.statuses?.isNotEmpty == true && filter.statuses!.length == 1) {
          // Only allow single status filter to avoid complex queries
          query = query.where('status', isEqualTo: filter.statuses!.first.name);
        } else if (filter.types?.isNotEmpty == true && filter.types!.length == 1) {
          // Only allow single type filter to avoid complex queries
          query = query.where('type', isEqualTo: filter.types!.first.name);
        }
      }

      // Apply ordering and pagination
      query = query.orderBy(orderBy, descending: descending).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      List<CertificateModel> certificates = querySnapshot.docs
          .map((doc) => CertificateModel.fromFirestore(doc))
          .toList();

      // Apply additional client-side filtering for complex conditions
      if (filter != null) {
        certificates = certificates.where((cert) {
          // Apply additional filters client-side
          if (filter.statuses?.isNotEmpty == true && filter.statuses!.length > 1) {
            if (!filter.statuses!.contains(cert.status)) {
              return false;
            }
          }

          if (filter.types?.isNotEmpty == true && filter.types!.length > 1) {
            if (!filter.types!.contains(cert.type)) {
              return false;
            }
          }

          if (filter.startDate != null && cert.createdAt.isBefore(filter.startDate!)) {
            return false;
          }

          if (filter.endDate != null && cert.createdAt.isAfter(filter.endDate!)) {
            return false;
          }

          if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
            final searchTerm = filter.searchTerm!.toLowerCase();
            if (!cert.title.toLowerCase().contains(searchTerm) &&
                !cert.description.toLowerCase().contains(searchTerm) &&
                !cert.recipientName.toLowerCase().contains(searchTerm)) {
              return false;
            }
          }

          if (filter.isExpired != null && filter.isExpired != cert.isExpired) {
            return false;
          }

          if (filter.isVerified != null && filter.isVerified != cert.isVerified) {
            return false;
          }

          if (filter.tags != null && filter.tags!.isNotEmpty) {
            bool hasTag = false;
            for (String tag in filter.tags!) {
              if (cert.tags.contains(tag)) {
                hasTag = true;
                break;
              }
            }
            if (!hasTag) return false;
          }

          return true;
        }).toList();
      }

      return certificates;
    } catch (e) {
      _logger.e('Failed to get certificates: $e');
      rethrow;
    }
  }

  // Enhanced method for user certificates with permission handling
  Future<List<CertificateModel>> getUserCertificates({
    required String userId,
    CertificateUserRole userRole = CertificateUserRole.recipient,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      _logger.i('📋 Loading certificates for user: $userId (role: $userRole)');

      Query query = _certificatesCollection;

      // Use simple single-field queries
      switch (userRole) {
        case CertificateUserRole.recipient:
          query = query.where('recipientId', isEqualTo: userId);
          break;
        case CertificateUserRole.issuer:
          query = query.where('issuerId', isEqualTo: userId);
          break;
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await query.get();
        _logger.i('✅ Successfully queried certificates');
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          _logger.w('⚠️ Permission denied for certificate access. Returning empty list.');
          return [];
        } else {
          _logger.e('❌ Failed to query certificates: $e');
          rethrow;
        }
      }

      final certificates = querySnapshot.docs.map((doc) {
        try {
          return CertificateModel.fromFirestore(doc);
        } catch (e) {
          _logger.w('⚠️ Failed to parse certificate: ${doc.id} - $e');
          return null;
        }
      }).where((cert) => cert != null).cast<CertificateModel>().toList();

      _logger.i('✅ Successfully loaded ${certificates.length} certificates');
      return certificates;
    } catch (e) {
      _logger.e('❌ Failed to get user certificates: $e');

      // Return empty list instead of throwing for permission errors
      if (e.toString().contains('permission-denied')) {
        return [];
      }
      rethrow;
    }
  }

  // Add method for organization certificates
  Future<List<CertificateModel>> getOrganizationCertificates({
    required String organizationId,
    CertificateStatus? status,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _certificatesCollection
          .where('organizationId', isEqualTo: organizationId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => CertificateModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      _logger.e('Failed to get organization certificates: $e');
      rethrow;
    }
  }

  // Update Certificate
  Future<void> updateCertificate(String certificateId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _certificatesCollection.doc(certificateId).update(updates);

      _logger.i('Certificate updated: $certificateId');
    } catch (e) {
      _logger.e('Failed to update certificate: $e');
      rethrow;
    }
  }

  // Delete Certificate
  Future<void> deleteCertificate(String certificateId, String deletedBy) async {
    try {
      final certificate = await getCertificateById(certificateId);
      if (certificate == null) {
        throw Exception('Certificate not found');
      }

      // Delete PDF file if exists
      if (certificate.pdfUrl != null) {
        try {
          final ref = _storage.refFromURL(certificate.pdfUrl!);
          await ref.delete();
        } catch (e) {
          _logger.w('Failed to delete PDF file: $e');
        }
      }

      // Delete from Firestore
      await _certificatesCollection.doc(certificateId).delete();

      // Log transaction
      await _logTransaction(
        certificateId: certificateId,
        action: 'deleted',
        performedBy: deletedBy,
        details: {'title': certificate.title},
      );

      _logger.i('Certificate deleted: $certificateId by $deletedBy');
    } catch (e) {
      _logger.e('Failed to delete certificate: $e');
      rethrow;
    }
  }

  // Get Certificate Statistics
  Future<CertificateStatistics> getCertificateStatistics({
    String? issuerId,
    String? organizationId,
  }) async {
    try {
      Query query = _certificatesCollection;

      if (issuerId != null) {
        query = query.where('issuerId', isEqualTo: issuerId);
      }

      if (organizationId != null) {
        query = query.where('organizationId', isEqualTo: organizationId);
      }

      final querySnapshot = await query.get();
      final certificates = querySnapshot.docs
          .map((doc) => CertificateModel.fromFirestore(doc))
          .toList();

      // Calculate statistics
      final totalCertificates = certificates.length;
      final issuedCertificates = certificates.where((c) => c.status == CertificateStatus.issued).length;
      final pendingCertificates = certificates.where((c) => c.status == CertificateStatus.pending).length;
      final revokedCertificates = certificates.where((c) => c.status == CertificateStatus.revoked).length;
      final expiredCertificates = certificates.where((c) => c.isExpired).length;

      // Group by type
      final certificatesByType = <String, int>{};
      for (final cert in certificates) {
        certificatesByType[cert.type.name] = (certificatesByType[cert.type.name] ?? 0) + 1;
      }

      // Group by status
      final certificatesByStatus = <String, int>{};
      for (final cert in certificates) {
        certificatesByStatus[cert.status.name] = (certificatesByStatus[cert.status.name] ?? 0) + 1;
      }

      // Group by month (last 12 months)
      final certificatesByMonth = <String, int>{};
      final now = DateTime.now();
      for (int i = 11; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
        certificatesByMonth[monthKey] = certificates.where((cert) {
          return cert.createdAt.year == month.year && cert.createdAt.month == month.month;
        }).length;
      }

      return CertificateStatistics(
        totalCertificates: totalCertificates,
        issuedCertificates: issuedCertificates,
        pendingCertificates: pendingCertificates,
        revokedCertificates: revokedCertificates,
        expiredCertificates: expiredCertificates,
        certificatesByType: certificatesByType,
        certificatesByMonth: certificatesByMonth,
        certificatesByStatus: certificatesByStatus,
      );
    } catch (e) {
      _logger.e('Failed to get certificate statistics: $e');
      rethrow;
    }
  }

  // Private helper methods
  String _generateVerificationId() {
    return _uuid.v4().replaceAll('-', '').substring(0, 16).toUpperCase();
  }

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateShareToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  String _generateQrCodeData(String certificateId, String verificationId) {
    const baseUrl = AppConfig.verificationBaseUrl;
    return '$baseUrl/$certificateId?v=$verificationId';
  }

  String _generateCertificateHash(String certificateId, String verificationId, String title) {
    // Generate a secure certificate hash using SHA-256
    final input = '$certificateId$verificationId$title${DateTime.now().millisecondsSinceEpoch}';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<pw.Document> _generateCertificatePdf(CertificateModel certificate) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900, width: 3),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppConfig.universityName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      certificate.typeDisplayName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 40),

              // Certificate Title
              pw.Text(
                certificate.title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),

              pw.SizedBox(height: 30),

              // Recipient Info
              pw.Text(
                'This is to certify that',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 2),
                  ),
                ),
                child: pw.Text(
                  certificate.recipientName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 30),

              // Description
              pw.Text(
                certificate.description,
                style: const pw.TextStyle(fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),

              // Course Info (if applicable)
              if (certificate.courseName.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Course: ${certificate.courseName}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                if (certificate.courseCode.isNotEmpty)
                  pw.Text(
                    'Course Code: ${certificate.courseCode}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                if (certificate.grade.isNotEmpty)
                  pw.Text(
                    'Grade: ${certificate.grade}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
              ],

              pw.Spacer(),

              // Footer with dates and verification
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Issued Date:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${certificate.issuedAt.day}/${certificate.issuedAt.month}/${certificate.issuedAt.year}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      if (certificate.expiresAt != null) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Expires:',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '${certificate.expiresAt!.day}/${certificate.expiresAt!.month}/${certificate.expiresAt!.year}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Verification ID:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        certificate.verificationId,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Verify at: ${AppConfig.verificationBaseUrl}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Digital signature section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Digital Certificate Verification',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Certificate Hash: ${certificate.hash}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Blockchain Verified: ${certificate.metadata['blockchainHash'] ?? 'Pending'}',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Issued by: ${certificate.organizationName}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _logTransaction({
    required String certificateId,
    required String action,
    required String performedBy,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _transactionsCollection.add({
        'certificateId': certificateId,
        'action': action,
        'performedBy': performedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'details': details ?? {},
      });
    } catch (e) {
      _logger.w('Failed to log transaction: $e');
    }
  }

  Future<void> _sendCertificateNotification(
      CertificateModel certificate,
      String action,
      ) async {
    try {
      final notificationService = NotificationService();

      switch (action) {
        case 'issued':
          await notificationService.sendCertificateIssuedNotification(
            recipientEmail: certificate.recipientEmail,
            certificateTitle: certificate.title,
            issuerName: certificate.issuerName,
            verificationCode: certificate.verificationCode,
          );
          break;

        case 'approved':
        // Find recipient user ID
          final userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: certificate.recipientEmail)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            final userId = userQuery.docs.first.id;
            await notificationService.createNotification(
              userId: userId,
              title: 'Certificate Approved',
              message: 'Your certificate "${certificate.title}" has been approved by ${certificate.issuerName}',
              type: 'certificate_approved',
              data: {
                'certificateId': certificate.id,
                'verificationCode': certificate.verificationCode,
                'issuerName': certificate.issuerName,
              },
            );
          }
          break;

        case 'revoked':
        // Find recipient user ID
          final revokedUserQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: certificate.recipientEmail)
              .limit(1)
              .get();

          if (revokedUserQuery.docs.isNotEmpty) {
            final userId = revokedUserQuery.docs.first.id;
            await notificationService.createNotification(
              userId: userId,
              title: 'Certificate Revoked',
              message: 'Your certificate "${certificate.title}" has been revoked',
              type: 'certificate_revoked',
              data: {
                'certificateId': certificate.id,
                'reason': 'Certificate status changed to revoked',
              },
            );
          }
          break;

        case 'rejected':
        // Find recipient user ID
          final rejectedUserQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: certificate.recipientEmail)
              .limit(1)
              .get();

          if (rejectedUserQuery.docs.isNotEmpty) {
            final userId = rejectedUserQuery.docs.first.id;
            await notificationService.createNotification(
              userId: userId,
              title: 'Certificate Rejected',
              message: 'Your certificate application "${certificate.title}" has been rejected',
              type: 'certificate_rejected',
              data: {
                'certificateId': certificate.id,
                'issuerName': certificate.issuerName,
              },
            );
          }
          break;

        case 'updated':
        // Find recipient user ID
          final updatedUserQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: certificate.recipientEmail)
              .limit(1)
              .get();

          if (updatedUserQuery.docs.isNotEmpty) {
            final userId = updatedUserQuery.docs.first.id;
            await notificationService.createNotification(
              userId: userId,
              title: 'Certificate Updated',
              message: 'Your certificate "${certificate.title}" has been updated',
              type: 'certificate_updated',
              data: {
                'certificateId': certificate.id,
                'verificationCode': certificate.verificationCode,
              },
            );
          }
          break;
      }

      _logger.i('Real notification sent: Certificate ${certificate.id} was $action for ${certificate.recipientEmail}');

    } catch (e) {
      _logger.e('Failed to send certificate notification: $e');
    }
  }

  // Generate and set a new access token for sharing
  Future<String> generateAndSetNewAccessToken(String certificateId) async {
    final newToken = _generateAccessToken(length: 8);
    await _certificatesCollection.doc(certificateId).update({'accessToken': newToken});
    return newToken;
  }
} 