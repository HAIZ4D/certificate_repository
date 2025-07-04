import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  systemAdmin,
  certificateAuthority,
  client,
  recipient,
  viewer,
}

enum UserType {
  user,
  ca,
  admin,
}

extension UserTypeExtension on UserType {
  String get displayName {
    switch (this) {
      case UserType.user:
        return 'User';
      case UserType.ca:
        return 'Certificate Authority';
      case UserType.admin:
        return 'Administrator';
    }
  }

  String get value {
    return name; // Returns 'user', 'ca', or 'admin'
  }
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.systemAdmin:
        return 'System Administrator';
      case UserRole.certificateAuthority:
        return 'Certificate Authority';
      case UserRole.client:
        return 'Client';
      case UserRole.recipient:
        return 'Recipient';
      case UserRole.viewer:
        return 'Viewer';
    }
  }
}

enum UserStatus {
  active,
  inactive,
  suspended,
  pending,
}

extension UserStatusExtension on UserStatus {
  String get displayName {
    switch (this) {
      case UserStatus.active:
        return 'Active';
      case UserStatus.inactive:
        return 'Inactive';
      case UserStatus.suspended:
        return 'Suspended';
      case UserStatus.pending:
        return 'Pending';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? phoneNumber;
  final String? bio;
  final UserRole role;
  final UserType userType;
  final UserStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> profile;
  final List<String> permissions;
  final String? organizationId;
  final String? organization;
  final bool isEmailVerified;
  final Map<String, dynamic> metadata;

  // CA-specific fields
  final String? organizationName;
  final String? businessLicense;
  final String? description;
  final String? address;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.bio,
    required this.role,
    required this.userType,
    this.status = UserStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.lastLoginAt,
    this.profile = const {},
    this.permissions = const [],
    this.organizationId,
    this.organization,
    this.isEmailVerified = false,
    this.metadata = const {},
    // CA-specific fields
    this.organizationName,
    this.businessLicense,
    this.description,
    this.address,
  });

  // Factory constructor from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoURL: data['photoURL'],
      phoneNumber: data['phoneNumber'],
      bio: data['bio'],
      role: _parseUserRole(data['role']),
      userType: _parseUserType(data['userType']),
      status: _parseUserStatus(data['status']),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      profile: data['profile'] ?? {},
      permissions: List<String>.from(data['permissions'] ?? []),
      organizationId: data['organizationId'],
      organization: data['organization'],
      isEmailVerified: data['isEmailVerified'] ?? false,
      metadata: data['metadata'] ?? {},
      // CA-specific fields
      organizationName: data['organizationName'],
      businessLicense: data['businessLicense'],
      description: data['description'],
      address: data['address'],
    );
  }

  // Factory constructor from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      photoURL: json['photoURL'],
      phoneNumber: json['phoneNumber'],
      bio: json['bio'],
      role: _parseUserRole(json['role']),
      userType: _parseUserType(json['userType']),
      status: _parseUserStatus(json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : null,
      profile: json['profile'] ?? {},
      permissions: List<String>.from(json['permissions'] ?? []),
      organizationId: json['organizationId'],
      organization: json['organization'],
      isEmailVerified: json['isEmailVerified'] ?? false,
      metadata: json['metadata'] ?? {},
      // CA-specific fields
      organizationName: json['organizationName'],
      businessLicense: json['businessLicense'],
      description: json['description'],
      address: json['address'],
    );
  }

  // Factory constructor from Map (for Firebase data)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'],
      bio: map['bio'],
      role: _parseUserRole(map['role']),
      userType: _parseUserType(map['userType']),
      status: _parseUserStatus(map['status']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      lastLoginAt: map['lastLoginAt'] != null
          ? (map['lastLoginAt'] is Timestamp
              ? (map['lastLoginAt'] as Timestamp).toDate()
              : DateTime.parse(map['lastLoginAt']))
          : null,
      profile: map['profile'] ?? {},
      permissions: List<String>.from(map['permissions'] ?? []),
      organizationId: map['organizationId'],
      organization: map['organization'],
      isEmailVerified: map['isEmailVerified'] ?? false,
      metadata: map['metadata'] ?? {},
      // CA-specific fields
      organizationName: map['organizationName'],
      businessLicense: map['businessLicense'],
      description: map['description'],
      address: map['address'],
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'role': role.name,
      'userType': userType.value,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'profile': profile,
      'permissions': permissions,
      'organizationId': organizationId,
      'organization': organization,
      'isEmailVerified': isEmailVerified,
      'metadata': metadata,
      'organizationName': organizationName,
      'businessLicense': businessLicense,
      'description': description,
      'address': address,
    };
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'role': role.name,
      'userType': userType.value,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'profile': profile,
      'permissions': permissions,
      'organizationId': organizationId,
      'organization': organization,
      'isEmailVerified': isEmailVerified,
      'metadata': metadata,
      'organizationName': organizationName,
      'businessLicense': businessLicense,
      'description': description,
      'address': address,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    String? bio,
    UserRole? role,
    UserType? userType,
    UserStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? profile,
    List<String>? permissions,
    String? organizationId,
    String? organization,
    bool? isEmailVerified,
    Map<String, dynamic>? metadata,
    // CA-specific fields
    String? organizationName,
    String? businessLicense,
    String? description,
    String? address,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      profile: profile ?? this.profile,
      permissions: permissions ?? this.permissions,
      organizationId: organizationId ?? this.organizationId,
      organization: organization ?? this.organization,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      metadata: metadata ?? this.metadata,
      // CA-specific fields
      organizationName: organizationName ?? this.organizationName,
      businessLicense: businessLicense ?? this.businessLicense,
      description: description ?? this.description,
      address: address ?? this.address,
    );
  }

  // Helper methods - permission checks based on userType
  bool get isAdmin => userType == UserType.admin;
  bool get isCA => userType == UserType.ca;
  bool get isUser => userType == UserType.user;
  bool get isClient => role == UserRole.client;
  bool get isRecipient => role == UserRole.recipient;
  bool get isViewer => role == UserRole.viewer;
  bool get isActive => status == UserStatus.active;
  bool get isPending => status == UserStatus.pending;

  // Permission check methods - based on user type
  bool get canCreateCertificates => isCA || isAdmin;
  bool get canApproveCertificates => isCA || isAdmin;
  bool get canManageUsers => isAdmin;
  bool get canAccessAdminPanel => isAdmin;
  bool get canAccessCAPanel => isCA && isActive;
  bool get canUploadDocuments => isUser || isCA || isAdmin;
  bool get canViewReports => isCA || isAdmin;
  bool get canManageSettings => isAdmin;

  // Profile image URL getter (maps to photoURL)
  String? get profileImageUrl => photoURL;

  // Access control methods - access control based on user type
  bool hasAdminAccess() => isAdmin && isActive;
  bool hasCertificateAuthorityAccess() => isCA && isActive;
  bool hasUserAccess() => isUser && isActive;

  // Check if user can access specific path
  bool canAccessPath(String path) {
    // Non-active users can only access login and public pages
    if (path.startsWith('/client-dashboard')) return isClient;
    if (!isActive) {
      // CA pending status can access pending page
      if (isCA && isPending && path == '/ca/pending') {
        return true;
      }
      return path == '/login' || path == '/register' || path.startsWith('/public');
    }

    // Admin permission check
    if (path.startsWith('/admin')) {
      return isAdmin;
    }

    // CA permission check
    if (path.startsWith('/ca')) {
      return isCA || isAdmin;
    }

    // Special management page permissions
    if (path.contains('/analytics') || path.contains('/backup') ||
        path.contains('/ca-approval') || path.contains('/settings')) {
      return isAdmin;
    }

    // Regular user paths require active status
    if (path.startsWith('/dashboard') ||
        path.startsWith('/certificates') ||
        path.startsWith('/documents') ||
        path.startsWith('/profile') ||
        path.startsWith('/notifications')) {
      return isActive;
    }

    // Public paths
    if (path.startsWith('/verify') || path.startsWith('/public') || path.startsWith('/help')) {
      return true;
    }

    return false;
  }

  // Check if user has specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission) || isAdmin;
  }

  // Check if user belongs to UPM domain
  bool get isUPMEmail => email.endsWith('@upm.edu.my');

  // Get user role display name
  String get roleDisplayName => role.displayName;

  // Get user type display name
  String get userTypeDisplayName => userType.displayName;

  // Get user status display name
  String get statusDisplayName => status.displayName;

  // Get the default route path that user should be redirected to
  String getDefaultRoute() {
    if (!isActive) {
      if (isCA && isPending) {
        return '/ca/pending';      }
      return '/login';
    }

    switch (userType) {
      case UserType.admin:
        return '/admin/dashboard';
      case UserType.ca:
        return '/ca/dashboard';
      case UserType.user:
        return '/dashboard';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, role: $role, status: $status)';
  }
}

// Helper functions
UserRole _parseUserRole(dynamic roleData) {
  if (roleData is String) {
    return UserRole.values.firstWhere(
      (role) => role.name == roleData,
      orElse: () => UserRole.recipient,
    );
  }
  return UserRole.recipient;
}

UserType _parseUserType(dynamic typeData) {
  if (typeData is String) {
    return UserType.values.firstWhere(
      (type) => type.name == typeData,
      orElse: () => UserType.user,
    );
  }
  return UserType.user;
}

UserStatus _parseUserStatus(dynamic statusData) {
  if (statusData is String) {
    return UserStatus.values.firstWhere(
      (status) => status.name == statusData,
      orElse: () => UserStatus.active,
    );
  }
  return UserStatus.active;
}

// User profile models for different roles
class CAProfile {
  final String organizationName;
  final String licenseNumber;
  final DateTime licenseExpiry;
  final String contactPerson;
  final String phoneNumber;
  final String address;
  final List<String> authorizedDomains;
  final bool isVerified;

  const CAProfile({
    required this.organizationName,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.contactPerson,
    required this.phoneNumber,
    required this.address,
    this.authorizedDomains = const [],
    this.isVerified = false,
  });

  factory CAProfile.fromJson(Map<String, dynamic> json) {
    return CAProfile(
      organizationName: json['organizationName'] ?? '',
      licenseNumber: json['licenseNumber'] ?? '',
      licenseExpiry: DateTime.parse(json['licenseExpiry']),
      contactPerson: json['contactPerson'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      address: json['address'] ?? '',
      authorizedDomains: List<String>.from(json['authorizedDomains'] ?? []),
      isVerified: json['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationName': organizationName,
      'licenseNumber': licenseNumber,
      'licenseExpiry': licenseExpiry.toIso8601String(),
      'contactPerson': contactPerson,
      'phoneNumber': phoneNumber,
      'address': address,
      'authorizedDomains': authorizedDomains,
      'isVerified': isVerified,
    };
  }
}

class RecipientProfile {
  final String firstName;
  final String lastName;
  final String? studentId;
  final String? employeeId;
  final String department;
  final String faculty;
  final String phoneNumber;

  const RecipientProfile({
    required this.firstName,
    required this.lastName,
    this.studentId,
    this.employeeId,
    required this.department,
    required this.faculty,
    required this.phoneNumber,
  });

  factory RecipientProfile.fromJson(Map<String, dynamic> json) {
    return RecipientProfile(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      studentId: json['studentId'],
      employeeId: json['employeeId'],
      department: json['department'] ?? '',
      faculty: json['faculty'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'studentId': studentId,
      'employeeId': employeeId,
      'department': department,
      'faculty': faculty,
      'phoneNumber': phoneNumber,
    };
  }

  String get fullName => '$firstName $lastName';
}
