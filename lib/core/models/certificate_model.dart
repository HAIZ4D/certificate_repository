import 'package:cloud_firestore/cloud_firestore.dart';

enum CertificateType {
  academic,
  professional,
  achievement,
  completion,
  participation,
  recognition,
  custom,
}

extension CertificateTypeExtension on CertificateType {
  String get displayName {
    switch (this) {
      case CertificateType.academic:
        return 'Academic';
      case CertificateType.professional:
        return 'Professional';
      case CertificateType.achievement:
        return 'Achievement';
      case CertificateType.completion:
        return 'Completion';
      case CertificateType.participation:
        return 'Participation';
      case CertificateType.recognition:
        return 'Recognition';
      case CertificateType.custom:
        return 'Custom';
    }
  }
}

enum CertificateStatus {
  draft,
  pending,
  approved,
  rejected,
  issued,
  revoked,
  expired,
}

extension CertificateStatusExtension on CertificateStatus {
  String get displayName {
    switch (this) {
      case CertificateStatus.draft:
        return 'Draft';
      case CertificateStatus.pending:
        return 'Pending';
      case CertificateStatus.approved:
        return 'Approved';
      case CertificateStatus.rejected:
        return 'Rejected';
      case CertificateStatus.issued:
        return 'Issued';
      case CertificateStatus.revoked:
        return 'Revoked';
      case CertificateStatus.expired:
        return 'Expired';
    }
  }
}

enum CertificateFormat {
  pdf,
  image,
  digital,
}

extension CertificateFormatExtension on CertificateFormat {
  String get displayName {
    switch (this) {
      case CertificateFormat.pdf:
        return 'PDF';
      case CertificateFormat.image:
        return 'Image';
      case CertificateFormat.digital:
        return 'Digital';
    }
  }
}

enum VerificationLevel {
  basic,
  enhanced,
  biometric,
  blockchain,
}

extension VerificationLevelExtension on VerificationLevel {
  String get displayName {
    switch (this) {
      case VerificationLevel.basic:
        return 'Basic';
      case VerificationLevel.enhanced:
        return 'Enhanced';
      case VerificationLevel.biometric:
        return 'Biometric';
      case VerificationLevel.blockchain:
        return 'Blockchain';
    }
  }
}

enum CertificateUserRole {
  recipient,
  issuer,
}

extension CertificateUserRoleExtension on CertificateUserRole {
  String get displayName {
    switch (this) {
      case CertificateUserRole.recipient:
        return 'Recipient';
      case CertificateUserRole.issuer:
        return 'Issuer';
    }
  }
}

class CertificateModel {
  final String id;
  final String templateId;
  final String issuerId; // CA who issued it
  final String issuerName; // Name of the issuer
  final String? issuerTitle; // Title of the issuer
  final String recipientId;
  final String recipientEmail;
  final String recipientName;
  final String organizationId;
  final String organizationName;
  final String verificationCode; // Verification code for public access
  final double? creditsEarned; // Credits earned for this certificate
  
  // Certificate Content
  final String title;
  final String description;
  final CertificateType type;
  final String courseName;
  final String courseCode;
  final String grade;
  final double? credits;
  final String achievement;
  
  // Dates
  final DateTime issuedAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Status and Verification
  final CertificateStatus status;
  final VerificationLevel verificationLevel;
  final String verificationId;
  final String qrCode;
  final String digitalSignature;
  final String hash;
  final bool isVerified;
  final bool isRevoked;
  final String? revocationReason;
  
  // Files and Links
  final String? pdfUrl;
  final String? imageUrl;
  final String? originalDocumentUrl;
  final CertificateFormat format;
  final int fileSize;
  
  // Sharing and Access
  final List<ShareToken> shareTokens;
  final List<String> allowedViewers;
  final bool isPublic;
  final int accessCount;
  final DateTime? lastAccessedAt;
  
  // Metadata
  final Map<String, dynamic> metadata;
  final List<String> tags;
  final String? notes;
  final double version;
  
  // Approval Workflow
  final List<ApprovalStep> approvalSteps;
  final String? currentApprovalStep;
  final bool requiresApproval;
  
  // Analytics
  final int downloadCount;
  final int shareCount;
  final int verificationCount;

  const CertificateModel({
    required this.id,
    required this.templateId,
    required this.issuerId,
    required this.issuerName,
    this.issuerTitle,
    required this.recipientId,
    required this.recipientEmail,
    required this.recipientName,
    required this.organizationId,
    required this.organizationName,
    required this.verificationCode,
    this.creditsEarned,
    required this.title,
    required this.description,
    required this.type,
    this.courseName = '',
    this.courseCode = '',
    this.grade = '',
    this.credits,
    this.achievement = '',
    required this.issuedAt,
    this.completedAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.status = CertificateStatus.draft,
    this.verificationLevel = VerificationLevel.basic,
    required this.verificationId,
    required this.qrCode,
    this.digitalSignature = '',
    required this.hash,
    this.isVerified = false,
    this.isRevoked = false,
    this.revocationReason,
    this.pdfUrl,
    this.imageUrl,
    this.originalDocumentUrl,
    this.format = CertificateFormat.pdf,
    this.fileSize = 0,
    this.shareTokens = const [],
    this.allowedViewers = const [],
    this.isPublic = false,
    this.accessCount = 0,
    this.lastAccessedAt,
    this.metadata = const {},
    this.tags = const [],
    this.notes,
    this.version = 1.0,
    this.approvalSteps = const [],
    this.currentApprovalStep,
    this.requiresApproval = false,
    this.downloadCount = 0,
    this.shareCount = 0,
    this.verificationCount = 0,
  });

  // Factory constructor from Firestore
  factory CertificateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CertificateModel(
      id: doc.id,
      templateId: data['templateId'] ?? '',
      issuerId: data['issuerId'] ?? '',
      issuerName: data['issuerName'] ?? '',
      issuerTitle: data['issuerTitle'],
      recipientId: data['recipientId'] ?? '',
      recipientEmail: data['recipientEmail'] ?? '',
      recipientName: data['recipientName'] ?? '',
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      verificationCode: data['verificationCode'] ?? '',
      creditsEarned: data['creditsEarned']?.toDouble(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: _parseCertificateType(data['type']),
      courseName: data['courseName'] ?? '',
      courseCode: data['courseCode'] ?? '',
      grade: data['grade'] ?? '',
      credits: data['credits']?.toDouble(),
      achievement: data['achievement'] ?? '',
      issuedAt: (data['issuedAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      expiresAt: data['expiresAt'] != null 
          ? (data['expiresAt'] as Timestamp).toDate() 
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      status: _parseCertificateStatus(data['status']),
      verificationLevel: _parseVerificationLevel(data['verificationLevel']),
      verificationId: data['verificationId'] ?? '',
      qrCode: data['qrCode'] ?? '',
      digitalSignature: data['digitalSignature'] ?? '',
      hash: data['hash'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isRevoked: data['isRevoked'] ?? false,
      revocationReason: data['revocationReason'],
      pdfUrl: data['pdfUrl'],
      imageUrl: data['imageUrl'],
      originalDocumentUrl: data['originalDocumentUrl'],
      format: _parseCertificateFormat(data['format']),
      fileSize: data['fileSize'] ?? 0,
      shareTokens: (data['shareTokens'] as List<dynamic>? ?? [])
          .map((token) => ShareToken.fromMap(token as Map<String, dynamic>))
          .toList(),
      allowedViewers: List<String>.from(data['allowedViewers'] ?? []),
      isPublic: data['isPublic'] ?? false,
      accessCount: data['accessCount'] ?? 0,
      lastAccessedAt: data['lastAccessedAt'] != null 
          ? (data['lastAccessedAt'] as Timestamp).toDate() 
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      notes: data['notes'],
      version: data['version']?.toDouble() ?? 1.0,
      approvalSteps: (data['approvalSteps'] as List<dynamic>? ?? [])
          .map((step) => ApprovalStep.fromMap(step as Map<String, dynamic>))
          .toList(),
      currentApprovalStep: data['currentApprovalStep'],
      requiresApproval: data['requiresApproval'] ?? false,
      downloadCount: data['downloadCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      verificationCount: data['verificationCount'] ?? 0,
    );
  }

  // Factory constructor from Map
  factory CertificateModel.fromMap(Map<String, dynamic> data) {
    return CertificateModel(
      id: data['id'] ?? '',
      templateId: data['templateId'] ?? '',
      issuerId: data['issuerId'] ?? '',
      issuerName: data['issuerName'] ?? '',
      issuerTitle: data['issuerTitle'],
      recipientId: data['recipientId'] ?? '',
      recipientEmail: data['recipientEmail'] ?? '',
      recipientName: data['recipientName'] ?? '',
      organizationId: data['organizationId'] ?? '',
      organizationName: data['organizationName'] ?? '',
      verificationCode: data['verificationCode'] ?? '',
      creditsEarned: data['creditsEarned']?.toDouble(),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      type: _parseCertificateType(data['type']),
      courseName: data['courseName'] ?? '',
      courseCode: data['courseCode'] ?? '',
      grade: data['grade'] ?? '',
      credits: data['credits']?.toDouble(),
      achievement: data['achievement'] ?? '',
      issuedAt: DateTime.parse(data['issuedAt']),
      completedAt: data['completedAt'] != null 
          ? DateTime.parse(data['completedAt']) 
          : null,
      expiresAt: data['expiresAt'] != null 
          ? DateTime.parse(data['expiresAt']) 
          : null,
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
      status: _parseCertificateStatus(data['status']),
      verificationLevel: _parseVerificationLevel(data['verificationLevel']),
      verificationId: data['verificationId'] ?? '',
      qrCode: data['qrCode'] ?? '',
      digitalSignature: data['digitalSignature'] ?? '',
      hash: data['hash'] ?? '',
      isVerified: data['isVerified'] ?? false,
      isRevoked: data['isRevoked'] ?? false,
      revocationReason: data['revocationReason'],
      pdfUrl: data['pdfUrl'],
      imageUrl: data['imageUrl'],
      originalDocumentUrl: data['originalDocumentUrl'],
      format: _parseCertificateFormat(data['format']),
      fileSize: data['fileSize'] ?? 0,
      shareTokens: (data['shareTokens'] as List<dynamic>? ?? [])
          .map((token) => ShareToken.fromMap(token as Map<String, dynamic>))
          .toList(),
      allowedViewers: List<String>.from(data['allowedViewers'] ?? []),
      isPublic: data['isPublic'] ?? false,
      accessCount: data['accessCount'] ?? 0,
      lastAccessedAt: data['lastAccessedAt'] != null 
          ? DateTime.parse(data['lastAccessedAt']) 
          : null,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      tags: List<String>.from(data['tags'] ?? []),
      notes: data['notes'],
      version: data['version']?.toDouble() ?? 1.0,
      approvalSteps: (data['approvalSteps'] as List<dynamic>? ?? [])
          .map((step) => ApprovalStep.fromMap(step as Map<String, dynamic>))
          .toList(),
      currentApprovalStep: data['currentApprovalStep'],
      requiresApproval: data['requiresApproval'] ?? false,
      downloadCount: data['downloadCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      verificationCount: data['verificationCount'] ?? 0,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'templateId': templateId,
      'issuerId': issuerId,
      'issuerName': issuerName,
      'issuerTitle': issuerTitle,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'verificationCode': verificationCode,
      'creditsEarned': creditsEarned,
      'title': title,
      'description': description,
      'type': type.name,
      'courseName': courseName,
      'courseCode': courseCode,
      'grade': grade,
      'credits': credits,
      'achievement': achievement,
      'issuedAt': Timestamp.fromDate(issuedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'status': status.name,
      'verificationLevel': verificationLevel.name,
      'verificationId': verificationId,
      'qrCode': qrCode,
      'digitalSignature': digitalSignature,
      'hash': hash,
      'isVerified': isVerified,
      'isRevoked': isRevoked,
      'revocationReason': revocationReason,
      'pdfUrl': pdfUrl,
      'imageUrl': imageUrl,
      'originalDocumentUrl': originalDocumentUrl,
      'format': format.name,
      'fileSize': fileSize,
      'shareTokens': shareTokens.map((token) => token.toMap()).toList(),
      'allowedViewers': allowedViewers,
      'isPublic': isPublic,
      'accessCount': accessCount,
      'lastAccessedAt': lastAccessedAt != null ? Timestamp.fromDate(lastAccessedAt!) : null,
      'metadata': metadata,
      'tags': tags,
      'notes': notes,
      'version': version,
      'approvalSteps': approvalSteps.map((step) => step.toMap()).toList(),
      'currentApprovalStep': currentApprovalStep,
      'requiresApproval': requiresApproval,
      'downloadCount': downloadCount,
      'shareCount': shareCount,
      'verificationCount': verificationCount,
    };
  }

  // Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'templateId': templateId,
      'issuerId': issuerId,
      'issuerName': issuerName,
      'issuerTitle': issuerTitle,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'organizationId': organizationId,
      'organizationName': organizationName,
      'verificationCode': verificationCode,
      'creditsEarned': creditsEarned,
      'title': title,
      'description': description,
      'type': type.name,
      'courseName': courseName,
      'courseCode': courseCode,
      'grade': grade,
      'credits': credits,
      'achievement': achievement,
      'issuedAt': issuedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'verificationLevel': verificationLevel.name,
      'verificationId': verificationId,
      'qrCode': qrCode,
      'digitalSignature': digitalSignature,
      'hash': hash,
      'isVerified': isVerified,
      'isRevoked': isRevoked,
      'revocationReason': revocationReason,
      'pdfUrl': pdfUrl,
      'imageUrl': imageUrl,
      'originalDocumentUrl': originalDocumentUrl,
      'format': format.name,
      'fileSize': fileSize,
      'shareTokens': shareTokens.map((token) => token.toMap()).toList(),
      'allowedViewers': allowedViewers,
      'isPublic': isPublic,
      'accessCount': accessCount,
      'lastAccessedAt': lastAccessedAt?.toIso8601String(),
      'metadata': metadata,
      'tags': tags,
      'notes': notes,
      'version': version,
      'approvalSteps': approvalSteps.map((step) => step.toMap()).toList(),
      'currentApprovalStep': currentApprovalStep,
      'requiresApproval': requiresApproval,
      'downloadCount': downloadCount,
      'shareCount': shareCount,
      'verificationCount': verificationCount,
    };
  }

  // Copy with method
  CertificateModel copyWith({
    String? id,
    String? templateId,
    String? issuerId,
    String? issuerName,
    String? issuerTitle,
    String? recipientId,
    String? recipientEmail,
    String? recipientName,
    String? organizationId,
    String? organizationName,
    String? verificationCode,
    double? creditsEarned,
    String? title,
    String? description,
    CertificateType? type,
    String? courseName,
    String? courseCode,
    String? grade,
    double? credits,
    String? achievement,
    DateTime? issuedAt,
    DateTime? completedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    CertificateStatus? status,
    VerificationLevel? verificationLevel,
    String? verificationId,
    String? qrCode,
    String? digitalSignature,
    String? hash,
    bool? isVerified,
    bool? isRevoked,
    String? revocationReason,
    String? pdfUrl,
    String? imageUrl,
    String? originalDocumentUrl,
    CertificateFormat? format,
    int? fileSize,
    List<ShareToken>? shareTokens,
    List<String>? allowedViewers,
    bool? isPublic,
    int? accessCount,
    DateTime? lastAccessedAt,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? notes,
    double? version,
    List<ApprovalStep>? approvalSteps,
    String? currentApprovalStep,
    bool? requiresApproval,
    int? downloadCount,
    int? shareCount,
    int? verificationCount,
  }) {
    return CertificateModel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      issuerId: issuerId ?? this.issuerId,
      issuerName: issuerName ?? this.issuerName,
      issuerTitle: issuerTitle ?? this.issuerTitle,
      recipientId: recipientId ?? this.recipientId,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      organizationId: organizationId ?? this.organizationId,
      organizationName: organizationName ?? this.organizationName,
      verificationCode: verificationCode ?? this.verificationCode,
      creditsEarned: creditsEarned ?? this.creditsEarned,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      grade: grade ?? this.grade,
      credits: credits ?? this.credits,
      achievement: achievement ?? this.achievement,
      issuedAt: issuedAt ?? this.issuedAt,
      completedAt: completedAt ?? this.completedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      verificationId: verificationId ?? this.verificationId,
      qrCode: qrCode ?? this.qrCode,
      digitalSignature: digitalSignature ?? this.digitalSignature,
      hash: hash ?? this.hash,
      isVerified: isVerified ?? this.isVerified,
      isRevoked: isRevoked ?? this.isRevoked,
      revocationReason: revocationReason ?? this.revocationReason,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      originalDocumentUrl: originalDocumentUrl ?? this.originalDocumentUrl,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      shareTokens: shareTokens ?? this.shareTokens,
      allowedViewers: allowedViewers ?? this.allowedViewers,
      isPublic: isPublic ?? this.isPublic,
      accessCount: accessCount ?? this.accessCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      metadata: metadata ?? this.metadata,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      version: version ?? this.version,
      approvalSteps: approvalSteps ?? this.approvalSteps,
      currentApprovalStep: currentApprovalStep ?? this.currentApprovalStep,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      downloadCount: downloadCount ?? this.downloadCount,
      shareCount: shareCount ?? this.shareCount,
      verificationCount: verificationCount ?? this.verificationCount,
    );
  }

  // Helper getters
  String get statusDisplayName {
    switch (status) {
      case CertificateStatus.draft:
        return 'Draft';
      case CertificateStatus.pending:
        return 'Pending';
      case CertificateStatus.approved:
        return 'Approved';
      case CertificateStatus.rejected:
        return 'Rejected';
      case CertificateStatus.issued:
        return 'Issued';
      case CertificateStatus.revoked:
        return 'Revoked';
      case CertificateStatus.expired:
        return 'Expired';
    }
  }

  String get typeDisplayName {
    switch (type) {
      case CertificateType.academic:
        return 'Academic Certificate';
      case CertificateType.professional:
        return 'Professional Certificate';
      case CertificateType.achievement:
        return 'Achievement Certificate';
      case CertificateType.completion:
        return 'Completion Certificate';
      case CertificateType.participation:
        return 'Participation Certificate';
      case CertificateType.recognition:
        return 'Recognition Certificate';
      case CertificateType.custom:
        return 'Custom Certificate';
    }
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive {
    return status == CertificateStatus.issued && 
           !isRevoked && 
           !isExpired;
  }

  bool get isNearExpiry {
    if (expiresAt == null) return false;
    final now = DateTime.now();
    final daysUntilExpiry = expiresAt!.difference(now).inDays;
    return daysUntilExpiry <= 30 && daysUntilExpiry > 0; // Within 30 days
  }

  bool get canBeShared {
    return isActive && (isPublic || allowedViewers.isNotEmpty || shareTokens.isNotEmpty);
  }

  // Static helper methods
  static CertificateType _parseCertificateType(dynamic value) {
    if (value is String) {
    return CertificateType.values.firstWhere(
        (e) => e.name == value,
      orElse: () => CertificateType.custom,
    );
  }
  return CertificateType.custom;
}

  static CertificateStatus _parseCertificateStatus(dynamic value) {
    if (value is String) {
    return CertificateStatus.values.firstWhere(
        (e) => e.name == value,
      orElse: () => CertificateStatus.draft,
    );
  }
  return CertificateStatus.draft;
}

  static CertificateFormat _parseCertificateFormat(dynamic value) {
    if (value is String) {
      return CertificateFormat.values.firstWhere(
        (e) => e.name == value,
        orElse: () => CertificateFormat.pdf,
      );
    }
    return CertificateFormat.pdf;
  }

  static VerificationLevel _parseVerificationLevel(dynamic value) {
    if (value is String) {
      return VerificationLevel.values.firstWhere(
        (e) => e.name == value,
        orElse: () => VerificationLevel.basic,
      );
    }
    return VerificationLevel.basic;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertificateModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CertificateModel(id: $id, title: $title, status: $status)';
}

// Share Token Model
class ShareToken {
  final String token;
  final String certificateId;
  final String sharedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? password;
  final int maxAccess;
  final int currentAccess;
  final bool isActive;

  const ShareToken({
    required this.token,
    required this.certificateId,
    required this.sharedBy,
    required this.createdAt,
    required this.expiresAt,
    this.password,
    this.maxAccess = 100,
    this.currentAccess = 0,
    this.isActive = true,
  });

  factory ShareToken.fromMap(Map<String, dynamic> data) {
    return ShareToken(
      token: data['token'] ?? '',
      certificateId: data['certificateId'] ?? '',
      sharedBy: data['sharedBy'] ?? '',
      createdAt: DateTime.parse(data['createdAt']),
      expiresAt: DateTime.parse(data['expiresAt']),
      password: data['password'],
      maxAccess: data['maxAccess'] ?? 100,
      currentAccess: data['currentAccess'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'certificateId': certificateId,
      'sharedBy': sharedBy,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'password': password,
      'maxAccess': maxAccess,
      'currentAccess': currentAccess,
      'isActive': isActive,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isExhausted => currentAccess >= maxAccess;
  bool get isValid => isActive && !isExpired && !isExhausted;
}

// Approval Step Model
class ApprovalStep {
  final String id;
  final String stepName;
  final String approverId;
  final String approverName;
  final String approverEmail;
  final String status; // pending, approved, rejected
  final DateTime? approvedAt;
  final String? comments;
  final int order;

  const ApprovalStep({
    required this.id,
    required this.stepName,
    required this.approverId,
    required this.approverName,
    required this.approverEmail,
    this.status = 'pending',
    this.approvedAt,
    this.comments,
    required this.order,
  });

  factory ApprovalStep.fromMap(Map<String, dynamic> data) {
    return ApprovalStep(
      id: data['id'] ?? '',
      stepName: data['stepName'] ?? '',
      approverId: data['approverId'] ?? '',
      approverName: data['approverName'] ?? '',
      approverEmail: data['approverEmail'] ?? '',
      status: data['status'] ?? 'pending',
      approvedAt: data['approvedAt'] != null ? DateTime.parse(data['approvedAt']) : null,
      comments: data['comments'],
      order: data['order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stepName': stepName,
      'approverId': approverId,
      'approverName': approverName,
      'approverEmail': approverEmail,
      'status': status,
      'approvedAt': approvedAt?.toIso8601String(),
      'comments': comments,
      'order': order,
    };
  }
}

// Certificate Statistics Model
class CertificateStatistics {
  final int totalCertificates;
  final int issuedCertificates;
  final int pendingCertificates;
  final int revokedCertificates;
  final int expiredCertificates;
  final int sharedCertificates;
  final int? totalDocuments;
  final Map<String, int> certificatesByType;
  final Map<String, int> certificatesByMonth;
  final Map<String, int> certificatesByStatus;

  const CertificateStatistics({
    required this.totalCertificates,
    required this.issuedCertificates,
    required this.pendingCertificates,
    required this.revokedCertificates,
    required this.expiredCertificates,
    this.sharedCertificates = 0,
    this.totalDocuments,
    required this.certificatesByType,
    required this.certificatesByMonth,
    required this.certificatesByStatus,
  });
}

// Certificate Filter Model
class CertificateFilter {
  final List<CertificateStatus>? statuses;
  final List<CertificateType>? types;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? issuerId;
  final String? recipientId;
  final String? organizationId;
  final String? searchTerm;
  final List<String>? tags;
  final bool? isExpired;
  final bool? isVerified;

  const CertificateFilter({
    this.statuses,
    this.types,
    this.startDate,
    this.endDate,
    this.issuerId,
    this.recipientId,
    this.organizationId,
    this.searchTerm,
    this.tags,
    this.isExpired,
    this.isVerified,
  });

  CertificateFilter copyWith({
    List<CertificateStatus>? statuses,
    List<CertificateType>? types,
    DateTime? startDate,
    DateTime? endDate,
    String? issuerId,
    String? recipientId,
    String? organizationId,
    String? searchTerm,
    List<String>? tags,
    bool? isExpired,
    bool? isVerified,
  }) {
    return CertificateFilter(
      statuses: statuses ?? this.statuses,
      types: types ?? this.types,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      issuerId: issuerId ?? this.issuerId,
      recipientId: recipientId ?? this.recipientId,
      organizationId: organizationId ?? this.organizationId,
      searchTerm: searchTerm ?? this.searchTerm,
      tags: tags ?? this.tags,
      isExpired: isExpired ?? this.isExpired,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

// Certificate Template Model
class CertificateTemplate {
  final String id;
  final String name;
  final String description;
  final CertificateType type;
  final String organizationId;
  final Map<String, dynamic> fields;
  final Map<String, dynamic> design;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CertificateTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.organizationId,
    required this.fields,
    required this.design,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CertificateTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return CertificateTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: CertificateModel._parseCertificateType(data['type']),
      organizationId: data['organizationId'] ?? '',
      fields: Map<String, dynamic>.from(data['fields'] ?? {}),
      design: Map<String, dynamic>.from(data['design'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'type': type.name,
      'organizationId': organizationId,
      'fields': fields,
      'design': design,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
} 

import 'package:cloud_firestore/cloud_firestore.dart';

enum CertificateType {
  academic,
  professional,
  achievement,
  completion,
  participation,
  recognition,
  custom,
}


  }
} 


