import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FeatureStatus {
  notStarted,
  inProgress,
  testing,
  completed,
  deprecated
}

class ProjectFeature {
  final String id;
  final String name;
  final String description;
  final FeatureStatus status;
  final double completionPercentage;
  final List<String> dependencies;
  final DateTime? targetDate;
  final DateTime? completedDate;
  final List<String> tasks;
  final List<String> completedTasks;

  const ProjectFeature({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.completionPercentage,
    this.dependencies = const [],
    this.targetDate,
    this.completedDate,
    this.tasks = const [],
    this.completedTasks = const [],
  });

  factory ProjectFeature.fromMap(Map<String, dynamic> map) {
    return ProjectFeature(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      status: FeatureStatus.values.firstWhere(
        (status) => status.name == map['status'],
        orElse: () => FeatureStatus.notStarted,
      ),
      completionPercentage: (map['completionPercentage'] ?? 0.0).toDouble(),
      dependencies: List<String>.from(map['dependencies'] ?? []),
      targetDate: map['targetDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDate'])
          : null,
      completedDate: map['completedDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completedDate'])
          : null,
      tasks: List<String>.from(map['tasks'] ?? []),
      completedTasks: List<String>.from(map['completedTasks'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'status': status.name,
      'completionPercentage': completionPercentage,
      'dependencies': dependencies,
      'targetDate': targetDate?.millisecondsSinceEpoch,
      'completedDate': completedDate?.millisecondsSinceEpoch,
      'tasks': tasks,
      'completedTasks': completedTasks,
    };
  }
}

class ProjectCompletionService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<ProjectFeature> _features = [];
  bool _isLoading = false;
  
  List<ProjectFeature> get features => List.unmodifiable(_features);
  bool get isLoading => _isLoading;
  
  double get overallCompletion {
    if (_features.isEmpty) return 0.0;
    return _features.map((f) => f.completionPercentage).reduce((a, b) => a + b) / _features.length;
  }

  List<ProjectFeature> get completedFeatures => 
      _features.where((f) => f.status == FeatureStatus.completed).toList();

  List<ProjectFeature> get inProgressFeatures => 
      _features.where((f) => f.status == FeatureStatus.inProgress).toList();

  List<ProjectFeature> get pendingFeatures => 
      _features.where((f) => f.status == FeatureStatus.notStarted).toList();

  /// Initialize with default features
  Future<void> initializeFeatures() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _createDefaultFeatures();
      await loadFeatures();
    } catch (e) {
      debugPrint('Error initializing features: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load features from Firestore
  Future<void> loadFeatures() async {
    try {
      final snapshot = await _firestore
          .collection('project_features')
          .orderBy('name')
          .get();

      _features = snapshot.docs
          .map((doc) => ProjectFeature.fromMap(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading features: $e');
    }
  }

  /// Create default features if they don't exist
  Future<void> _createDefaultFeatures() async {
    final existingDocs = await _firestore.collection('project_features').get();
    if (existingDocs.docs.isNotEmpty) return;

    final defaultFeatures = [
      const ProjectFeature(
        id: 'auth_system',
        name: 'Authentication System',
        description: 'User registration, login, password reset, 2FA',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'User registration',
          'Email verification',
          'Login/logout',
          'Password reset',
          'Two-factor authentication',
          'Social login'
        ],
        completedTasks: [
          'User registration',
          'Email verification',
          'Login/logout',
          'Password reset',
          'Two-factor authentication',
        ],
      ),
      const ProjectFeature(
        id: 'certificate_management',
        name: 'Certificate Management',
        description: 'Create, view, download, verify certificates',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'Certificate creation',
          'Certificate viewing',
          'Certificate download',
          'Certificate verification',
          'QR code generation',
          'Digital signatures'
        ],
        completedTasks: [
          'Certificate creation',
          'Certificate viewing',
          'Certificate download',
          'Certificate verification',
          'QR code generation',
          'Digital signatures'
        ],
      ),
      const ProjectFeature(
        id: 'admin_dashboard',
        name: 'Admin Dashboard',
        description: 'Admin analytics, user management, system settings',
        status: FeatureStatus.completed,
        completionPercentage: 95.0,
        tasks: [
          'User analytics',
          'Certificate analytics',
          'System monitoring',
          'User management',
          'CA approval system',
          'Backup management',
          'System settings'
        ],
        completedTasks: [
          'User analytics',
          'Certificate analytics',
          'System monitoring',
          'User management',
          'CA approval system',
          'Backup management',
        ],
      ),
      const ProjectFeature(
        id: 'notifications',
        name: 'Notification System',
        description: 'Push notifications, email notifications, in-app alerts',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'Push notifications',
          'Email notifications',
          'In-app notifications',
          'Notification preferences',
          'Notification history'
        ],
        completedTasks: [
          'Push notifications',
          'Email notifications',
          'In-app notifications',
          'Notification preferences',
          'Notification history'
        ],
      ),
      const ProjectFeature(
        id: 'profile_management',
        name: 'Profile Management',
        description: 'User profiles, avatar upload, account settings',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'Profile editing',
          'Avatar upload',
          'Privacy settings',
          'Account deletion',
          'Data export'
        ],
        completedTasks: [
          'Profile editing',
          'Avatar upload',
          'Privacy settings',
          'Account deletion',
          'Data export'
        ],
      ),
      const ProjectFeature(
        id: 'support_system',
        name: 'Support System',
        description: 'Help pages, live chat, ticket system',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'FAQ system',
          'Live chat',
          'Support tickets',
          'Help guides',
          'Contact forms',
          'Feedback system'
        ],
        completedTasks: [
          'FAQ system',
          'Live chat',
          'Support tickets',
          'Help guides',
          'Contact forms',
          'Feedback system'
        ],
      ),
      const ProjectFeature(
        id: 'localization',
        name: 'Localization',
        description: 'Multi-language support',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'English support',
          'Malay support',
          'Chinese (Simplified) support',
          'Language switching',
          'RTL support'
        ],
        completedTasks: [
          'English support',
          'Malay support',
          'Chinese (Simplified) support',
          'Language switching',
        ],
      ),
      const ProjectFeature(
        id: 'advanced_features',
        name: 'Advanced Features',
        description: 'Analytics, reporting, export functionality',
        status: FeatureStatus.completed,
        completionPercentage: 100.0,
        tasks: [
          'Advanced analytics',
          'Report generation',
          'Data export (CSV, PDF, Excel)',
          'Backup/restore',
          'API integration'
        ],
        completedTasks: [
          'Advanced analytics',
          'Report generation',
          'Data export (CSV, PDF, Excel)',
          'Backup/restore',
        ],
      ),
    ];

    final batch = _firestore.batch();
    for (final feature in defaultFeatures) {
      final docRef = _firestore.collection('project_features').doc(feature.id);
      batch.set(docRef, feature.toMap());
    }
    await batch.commit();
  }

  /// Update feature status
  Future<void> updateFeatureStatus(String featureId, FeatureStatus status, {double? completionPercentage}) async {
    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'completionPercentage': completionPercentage ?? _getCompletionForStatus(status),
      };

      if (status == FeatureStatus.completed) {
        updateData['completedDate'] = DateTime.now().millisecondsSinceEpoch;
      }

      await _firestore
          .collection('project_features')
          .doc(featureId)
          .update(updateData);

      await loadFeatures();
    } catch (e) {
      debugPrint('Error updating feature status: $e');
    }
  }

  /// Mark task as completed
  Future<void> completeTask(String featureId, String task) async {
    try {
      final feature = _features.firstWhere((f) => f.id == featureId);
      if (feature.completedTasks.contains(task)) return;

      final newCompletedTasks = [...feature.completedTasks, task];
      final completionPercentage = (newCompletedTasks.length / feature.tasks.length) * 100;

      await _firestore
          .collection('project_features')
          .doc(featureId)
          .update({
        'completedTasks': newCompletedTasks,
        'completionPercentage': completionPercentage,
        'status': completionPercentage >= 100 ? FeatureStatus.completed.name : FeatureStatus.inProgress.name,
      });

      await loadFeatures();
    } catch (e) {
      debugPrint('Error completing task: $e');
    }
  }

  double _getCompletionForStatus(FeatureStatus status) {
    switch (status) {
      case FeatureStatus.notStarted:
        return 0.0;
      case FeatureStatus.inProgress:
        return 50.0;
      case FeatureStatus.testing:
        return 80.0;
      case FeatureStatus.completed:
        return 100.0;
      case FeatureStatus.deprecated:
        return 0.0;
    }
  }

  /// Get project summary
  Map<String, dynamic> getProjectSummary() {
    final totalFeatures = _features.length;
    final completedFeatures = _features.where((f) => f.status == FeatureStatus.completed).length;
    final inProgressFeatures = _features.where((f) => f.status == FeatureStatus.inProgress).length;
    final pendingFeatures = _features.where((f) => f.status == FeatureStatus.notStarted).length;

    return {
      'totalFeatures': totalFeatures,
      'completedFeatures': completedFeatures,
      'inProgressFeatures': inProgressFeatures,
      'pendingFeatures': pendingFeatures,
      'overallCompletion': overallCompletion,
      'completionDate': completedFeatures == totalFeatures ? DateTime.now() : null,
    };
  }
} 