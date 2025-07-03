import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentType {
  certificate,
  diploma,
  transcript,
  license,
  identification,
  other,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.diploma:
        return 'Diploma';
      case DocumentType.transcript:
        return 'Transcript';
      case DocumentType.license:
        return 'License';
      case DocumentType.identification:
        return 'Identification';
      case DocumentType.other:
        return 'Other';
    }
  }
}

enum DocumentStatus {
  uploaded,
  pending,
  processing,
  pendingVerification,
  verified,
  rejected,
  expired,
}

extension DocumentStatusExtension on DocumentStatus {
  String get displayName {
    switch (this) {
      case DocumentStatus.uploaded:
        return 'Uploaded';
      case DocumentStatus.pending:
        return 'Pending';
      case DocumentStatus.processing:
        return 'Processing';
      case DocumentStatus.pendingVerification:
        return 'Pending Verification';
      case DocumentStatus.verified:
        return 'Verified';
      case DocumentStatus.rejected:
        return 'Rejected';
      case DocumentStatus.expired:
        return 'Expired';
    }
  }
}

enum VerificationStatus {

  pending,
  verified,
  rejected,
  expired,
}

extension VerificationStatusExtension on VerificationStatus {

  String get displayName {
    switch (this) {
      case VerificationStatus.pending:
        return 'Pending';
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.rejected:
        return 'Rejected';
      case VerificationStatus.expired:
        return 'Expired';
    }
  }
}

enum VerificationLevel {
  basic,
  standard,
  enhanced,
  certified,
}

extension VerificationLevelExtension on VerificationLevel {
  String get displayName {
    switch (this) {
      case VerificationLevel.basic:
        return 'Basic';
      case VerificationLevel.standard:
        return 'Standard';
      case VerificationLevel.enhanced:
        return 'Enhanced';
      case VerificationLevel.certified:
        return 'Certified';
    }
  }
}

enum AccessLevel {
  public,
  restricted,
  private,
}

extension AccessLevelExtension on AccessLevel {
  String get displayName {
    switch (this) {
      case AccessLevel.public:
        return 'Public';
      case AccessLevel.restricted:
        return 'Restricted';
      case AccessLevel.private:
        return 'Private';
    }
  }
}

class DocumentModel {
  final String id;
  final String name;
  final String description;
  final DocumentType type;
  final DocumentStatus status;
  final String uploaderId;
  final String uploaderName;
  final String? verifierId;
  final String? verifierName;
  final DateTime uploadedAt;
  final DateTime? verifiedAt;
  final DateTime? expiryDate;
  final DateTime updatedAt;
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final int fileSize;
  final String? thumbnailUrl;
  final DocumentMetadata metadata;
  final List<VerificationStep> verificationHistory;
  final String? shareableLink;
  final String? accessToken;
  final VerificationLevel verificationLevel;
  final VerificationStatus verificationStatus;
  final String? associatedCertificateId;
  final AccessLevel accessLevel;
  final List<String> allowedUsers;
  final bool isPublic;
  final String? rejectionReason;
  final List<String> tags;
  final Map<String, dynamic> extractedData;
  final String? ocrText;
  final String hash;
  final List<ShareToken> shareTokens;
  final List<DocumentAccess> accessHistory;
  final int? downloadCount;

  const DocumentModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.uploaderId,
    required this.uploaderName,
    this.verifierId,
    this.verifierName,
    required this.uploadedAt,
    this.verifiedAt,
    this.expiryDate,
    required this.updatedAt,
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
    this.thumbnailUrl,
    required this.metadata,
    this.verificationHistory = const [],
    this.shareableLink,
    this.accessToken,
    this.verificationLevel = VerificationLevel.basic,
    this.verificationStatus = VerificationStatus.pending,
    this.associatedCertificateId,
    this.accessLevel = AccessLevel.restricted,
    this.allowedUsers = const [],
    this.isPublic = false,
    this.rejectionReason,
    this.tags = const [],
    this.extractedData = const {},
    this.ocrText,
    required this.hash,
    this.shareTokens = const [],
    this.accessHistory = const [],
    this.downloadCount,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map, String id) {
    return DocumentModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: _parseDocumentType(map['type']),
      status: _parseDocumentStatus(map['status']),
      uploaderId: map['uploaderId'] ?? '',
      uploaderName: map['uploaderName'] ?? '',
      verifierId: map['verifierId'],
      verifierName: map['verifierName'],
      uploadedAt: map['uploadedAt'] is Timestamp
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.parse(
          map['uploadedAt'] ?? DateTime.now().toIso8601String()),
      verifiedAt: map['verifiedAt'] != null
          ? (map['verifiedAt'] is Timestamp
          ? (map['verifiedAt'] as Timestamp).toDate()
          : DateTime.parse(map['verifiedAt']))
          : null,
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] is Timestamp
          ? (map['expiryDate'] as Timestamp).toDate()
          : DateTime.parse(map['expiryDate']))
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(
          map['updatedAt'] ?? DateTime.now().toIso8601String()),
      fileUrl: map['fileUrl'] ?? '',
      fileName: map['fileName'] ?? '',
      mimeType: map['mimeType'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      thumbnailUrl: map['thumbnailUrl'],
      metadata: DocumentMetadata.fromJson(map['metadata'] ?? {}),
      verificationHistory: (map['verificationHistory'] as List<dynamic>? ?? [])
          .map((step) => VerificationStep.fromJson(step))
          .toList(),
      shareableLink: map['shareableLink'],
      accessToken: map['accessToken'],
      verificationLevel: _parseVerificationLevel(map['verificationLevel']),
      verificationStatus: _parseVerificationStatus(map['verificationStatus']),
      associatedCertificateId: map['associatedCertificateId'],
      accessLevel: _parseAccessLevel(map['accessLevel']),
      allowedUsers: List<String>.from(map['allowedUsers'] ?? []),
      isPublic: map['isPublic'] ?? false,
      rejectionReason: map['rejectionReason'],
      tags: List<String>.from(map['tags'] ?? []),
      extractedData: Map<String, dynamic>.from(map['extractedData'] ?? {}),
      ocrText: map['ocrText'],
      hash: map['hash'] ?? '',
      shareTokens: (map['shareTokens'] as List<dynamic>? ?? [])
          .map((token) => ShareToken.fromMap(token))
          .toList(),
      accessHistory: (map['accessHistory'] as List<dynamic>? ?? [])
          .map((access) => DocumentAccess.fromMap(access))
          .toList(),
      downloadCount: map['downloadCount'],
    );
  }

  factory DocumentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return DocumentModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      type: _parseDocumentType(data['type']),
      status: _parseDocumentStatus(data['status']),
      uploaderId: data['uploaderId'] ?? '',
      uploaderName: data['uploaderName'] ?? '',
      verifierId: data['verifierId'],
      verifierName: data['verifierName'],
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      verifiedAt: data['verifiedAt'] != null
          ? (data['verifiedAt'] as Timestamp).toDate()
          : null,
      expiryDate: data['expiryDate'] != null
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      mimeType: data['mimeType'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      thumbnailUrl: data['thumbnailUrl'],
      metadata: DocumentMetadata.fromJson(data['metadata'] ?? {}),
      verificationHistory: (data['verificationHistory'] as List<dynamic>? ?? [])
          .map((step) => VerificationStep.fromJson(step))
          .toList(),
      shareableLink: data['shareableLink'],
      accessToken: data['accessToken'],
      verificationLevel: _parseVerificationLevel(data['verificationLevel']),
      verificationStatus: _parseVerificationStatus(data['verificationStatus']),
      associatedCertificateId: data['associatedCertificateId'],
      accessLevel: _parseAccessLevel(data['accessLevel']),
      allowedUsers: List<String>.from(data['allowedUsers'] ?? []),
      isPublic: data['isPublic'] ?? false,
      rejectionReason: data['rejectionReason'],
      tags: List<String>.from(data['tags'] ?? []),
      extractedData: Map<String, dynamic>.from(data['extractedData'] ?? {}),
      ocrText: data['ocrText'],
      hash: data['hash'] ?? '',
      shareTokens: (data['shareTokens'] as List<dynamic>? ?? [])
          .map((token) => ShareToken.fromMap(token))
          .toList(),
      accessHistory: (data['accessHistory'] as List<dynamic>? ?? [])
          .map((access) => DocumentAccess.fromMap(access))
          .toList(),
      downloadCount: data['downloadCount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'status': status.name,
      'uploaderId': uploaderId,
      'uploaderName': uploaderName,
      'verifierId': verifierId,
      'verifierName': verifierName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'fileUrl': fileUrl,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'thumbnailUrl': thumbnailUrl,
      'metadata': metadata.toJson(),
      'verificationHistory':
      verificationHistory.map((step) => step.toJson()).toList(),
      'shareableLink': shareableLink,
      'accessToken': accessToken,
      'verificationLevel': verificationLevel.name,
      'verificationStatus': verificationStatus.name,
      'associatedCertificateId': associatedCertificateId,
      'accessLevel': accessLevel.name,
      'allowedUsers': allowedUsers,
      'isPublic': isPublic,
      'rejectionReason': rejectionReason,
      'tags': tags,
      'extractedData': extractedData,
      'ocrText': ocrText,
      'hash': hash,
      'shareTokens': shareTokens.map((token) => token.toMap()).toList(),
      'accessHistory': accessHistory.map((access) => access.toMap()).toList(),
      'downloadCount': downloadCount,
    };
  }

  DocumentModel copyWith({
    String? id,
    String? name,
    String? description,
    DocumentType? type,
    DocumentStatus? status,
    String? uploaderId,
    String? uploaderName,
    String? verifierId,
    String? verifierName,
    DateTime? uploadedAt,
    DateTime? verifiedAt,
    DateTime? expiryDate,
    DateTime? updatedAt,
    String? fileUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    String? thumbnailUrl,
    DocumentMetadata? metadata,
    List<VerificationStep>? verificationHistory,
    String? shareableLink,
    String? accessToken,
    VerificationLevel? verificationLevel,
    VerificationStatus? verificationStatus,
    String? associatedCertificateId,
    AccessLevel? accessLevel,
    List<String>? allowedUsers,
    bool? isPublic,
    String? rejectionReason,
    List<String>? tags,
    Map<String, dynamic>? extractedData,
    String? ocrText,
    String? hash,
    List<ShareToken>? shareTokens,
    List<DocumentAccess>? accessHistory,
    int? downloadCount,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      uploaderId: uploaderId ?? this.uploaderId,
      uploaderName: uploaderName ?? this.uploaderName,
      verifierId: verifierId ?? this.verifierId,
      verifierName: verifierName ?? this.verifierName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      updatedAt: updatedAt ?? this.updatedAt,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      verificationHistory: verificationHistory ?? this.verificationHistory,
      shareableLink: shareableLink ?? this.shareableLink,
      accessToken: accessToken ?? this.accessToken,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      associatedCertificateId:
      associatedCertificateId ?? this.associatedCertificateId,
      accessLevel: accessLevel ?? this.accessLevel,
      allowedUsers: allowedUsers ?? this.allowedUsers,
      isPublic: isPublic ?? this.isPublic,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      tags: tags ?? this.tags,
      extractedData: extractedData ?? this.extractedData,
      ocrText: ocrText ?? this.ocrText,
      hash: hash ?? this.hash,
      shareTokens: shareTokens ?? this.shareTokens,
      accessHistory: accessHistory ?? this.accessHistory,
      downloadCount: downloadCount ?? this.downloadCount,
    );
  }

  // Helper methods
  bool get isExpired =>
      expiryDate != null && DateTime.now().isAfter(expiryDate!);
  bool get isVerified => verificationStatus == VerificationStatus.verified;
  bool get isPending => verificationStatus == VerificationStatus.pending;
  bool get isRejected => verificationStatus == VerificationStatus.rejected;
  bool get canBeShared => isVerified && !isExpired;
  bool get requiresVerification =>
      verificationStatus == VerificationStatus.pending;

  String get typeDisplayName {
    return type.displayName;
  }

  String get statusDisplayName {
    return status.displayName;
  }

  String get verificationLevelDisplayName {
    return verificationLevel.displayName;
  }

  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  bool get isPDF => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DocumentModel(id: $id, name: $name, type: $type, status: $status)';
  }
}

class DocumentMetadata {
  final String version;
  final String? issuer;
  final String? subject;
  final DateTime? issueDate;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? certificateNumber;
  final String? institutionName;
  final Map<String, dynamic> customFields;
  final List<String> keywords;
  final String? originalFormat;
  final String? scanQuality;
  final Map<String, dynamic> technicalDetails;

  const DocumentMetadata({
    this.version = '1.0',
    this.issuer,
    this.subject,
    this.issueDate,
    this.validFrom,
    this.validTo,
    this.certificateNumber,
    this.institutionName,
    this.customFields = const {},
    this.keywords = const [],
    this.originalFormat,
    this.scanQuality,
    this.technicalDetails = const {},
  });

  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      version: json['version'] ?? '1.0',
      issuer: json['issuer'],
      subject: json['subject'],
      issueDate:
      json['issueDate'] != null ? DateTime.parse(json['issueDate']) : null,
      validFrom:
      json['validFrom'] != null ? DateTime.parse(json['validFrom']) : null,
      validTo: json['validTo'] != null ? DateTime.parse(json['validTo']) : null,
      certificateNumber: json['certificateNumber'],
      institutionName: json['institutionName'],
      customFields: Map<String, dynamic>.from(json['customFields'] ?? {}),
      keywords: List<String>.from(json['keywords'] ?? []),
      originalFormat: json['originalFormat'],
      scanQuality: json['scanQuality'],
      technicalDetails:
      Map<String, dynamic>.from(json['technicalDetails'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'issuer': issuer,
      'subject': subject,
      'issueDate': issueDate?.toIso8601String(),
      'validFrom': validFrom?.toIso8601String(),
      'validTo': validTo?.toIso8601String(),
      'certificateNumber': certificateNumber,
      'institutionName': institutionName,
      'customFields': customFields,
      'keywords': keywords,
      'originalFormat': originalFormat,
      'scanQuality': scanQuality,
      'technicalDetails': technicalDetails,
    };
  }
}

class VerificationStep {
  final String id;
  final String verifierId;
  final String verifierName;
  final String action; // verify, reject, request_info
  final String? comment;
  final DateTime timestamp;
  final VerificationLevel level;
  final Map<String, dynamic> evidence;
  final List<String> checkedItems;

  const VerificationStep({
    required this.id,
    required this.verifierId,
    required this.verifierName,
    required this.action,
    this.comment,
    required this.timestamp,
    required this.level,
    this.evidence = const {},
    this.checkedItems = const [],
  });

  factory VerificationStep.fromJson(Map<String, dynamic> json) {
    return VerificationStep(
      id: json['id'] ?? '',
      verifierId: json['verifierId'] ?? '',
      verifierName: json['verifierName'] ?? '',
      action: json['action'] ?? '',
      comment: json['comment'],
      timestamp: json['timestamp'] is Timestamp
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      level: _parseVerificationLevel(json['level']),
      evidence: Map<String, dynamic>.from(json['evidence'] ?? {}),
      checkedItems: List<String>.from(json['checkedItems'] ?? []),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'verifierId': verifierId,
      'verifierName': verifierName,
      'action': action,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'evidence': evidence,
      'checkedItems': checkedItems,
    };
  }
}

class ShareToken {
  final String token;
  final String documentId;
  final String sharedBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? password;
  final int? maxAccess;
  final int currentAccess;
  final bool isActive;

  const ShareToken({
    required this.token,
    required this.documentId,
    required this.sharedBy,
    required this.createdAt,
    required this.expiresAt,
    this.password,
    this.maxAccess,
    this.currentAccess = 0,
    this.isActive = true,
  });

  factory ShareToken.fromMap(Map<String, dynamic> map) {
    return ShareToken(
      token: map['token'] ?? '',
      documentId: map['documentId'] ?? '',
      sharedBy: map['sharedBy'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : DateTime.parse(
          map['expiresAt'] ?? DateTime.now().toIso8601String()),
      password: map['password'],
      maxAccess: map['maxAccess'],
      currentAccess: map['currentAccess'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'documentId': documentId,
      'sharedBy': sharedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'password': password,
      'maxAccess': maxAccess,
      'currentAccess': currentAccess,
      'isActive': isActive,
    };
  }
}

// Document sharing and access models
class DocumentAccess {
  final String id;
  final String documentId;
  final String accessorId;
  final String accessorEmail;
  final String accessLevel; // view, download, share
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final String grantedById;
  final bool isActive;
  final int accessCount;
  final DateTime? lastAccessedAt;

  const DocumentAccess({
    required this.id,
    required this.documentId,
    required this.accessorId,
    required this.accessorEmail,
    required this.accessLevel,
    required this.grantedAt,
    this.expiresAt,
    required this.grantedById,
    this.isActive = true,
    this.accessCount = 0,
    this.lastAccessedAt,
  });

  factory DocumentAccess.fromMap(Map<String, dynamic> map) {
    return DocumentAccess(
      id: map['id'] ?? '',
      documentId: map['documentId'] ?? '',
      accessorId: map['accessorId'] ?? '',
      accessorEmail: map['accessorEmail'] ?? '',
      accessLevel: map['accessLevel'] ?? 'view',
      grantedAt: map['grantedAt'] is Timestamp
          ? (map['grantedAt'] as Timestamp).toDate()
          : DateTime.parse(
          map['grantedAt'] ?? DateTime.now().toIso8601String()),
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] is Timestamp
          ? (map['expiresAt'] as Timestamp).toDate()
          : DateTime.parse(map['expiresAt']))
          : null,
      grantedById: map['grantedById'] ?? '',
      isActive: map['isActive'] ?? true,
      accessCount: map['accessCount'] ?? 0,
      lastAccessedAt: map['lastAccessedAt'] != null
          ? (map['lastAccessedAt'] is Timestamp
          ? (map['lastAccessedAt'] as Timestamp).toDate()
          : DateTime.parse(map['lastAccessedAt']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'accessorId': accessorId,
      'accessorEmail': accessorEmail,
      'accessLevel': accessLevel,
      'grantedAt': Timestamp.fromDate(grantedAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'grantedById': grantedById,
      'isActive': isActive,
      'accessCount': accessCount,
      'lastAccessedAt':
      lastAccessedAt != null ? Timestamp.fromDate(lastAccessedAt!) : null,
    };
  }

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get canAccess => isActive && !isExpired;
}

// Helper functions
DocumentType _parseDocumentType(dynamic typeData) {
  if (typeData is String) {
    return DocumentType.values.firstWhere(
          (type) => type.name == typeData,
      orElse: () => DocumentType.other,
    );
  }
  return DocumentType.other;
}

DocumentStatus _parseDocumentStatus(dynamic statusData) {
  if (statusData is String) {
    return DocumentStatus.values.firstWhere(
          (status) => status.name == statusData,
      orElse: () => DocumentStatus.uploaded,
    );
  }
  return DocumentStatus.uploaded;
}

VerificationLevel _parseVerificationLevel(dynamic levelData) {
  if (levelData is String) {
    return VerificationLevel.values.firstWhere(
          (level) => level.name == levelData,
      orElse: () => VerificationLevel.basic,
    );
  }
  return VerificationLevel.basic;
}

VerificationStatus _parseVerificationStatus(dynamic statusData) {
  if (statusData is String) {
    return VerificationStatus.values.firstWhere(
          (status) => status.name == statusData,
      orElse: () => VerificationStatus.pending,
    );
  }
  return VerificationStatus.pending;
}

AccessLevel _parseAccessLevel(dynamic levelData) {
  if (levelData is String) {
    return AccessLevel.values.firstWhere(
          (level) => level.name == levelData,
      orElse: () => AccessLevel.restricted,
    );
  }
  return AccessLevel.restricted;
}
