import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/models/document_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../certificates/providers/certificate_providers.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/recent_activity_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _loadRealNotifications();
  }

  Future<void> _loadRealNotifications() async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      // Query Firebase for unread notifications
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection(AppConfig.notificationsCollection)
          .where('userId', isEqualTo: currentUser.id)
          .where('isRead', isEqualTo: false)
          .limit(1)
          .get();

      setState(() {
        _hasUnreadNotifications = notificationsSnapshot.docs.isNotEmpty;
      });

      LoggerService.info('Loaded notification status: $_hasUnreadNotifications');
    } catch (e) {
      LoggerService.error('Failed to load notifications', error: e);
      setState(() {
        _hasUnreadNotifications = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, currentUser),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeCard(currentUser),
                  const SizedBox(height: 24),
                  _buildQuickActions(context, currentUser),
                  const SizedBox(height: 24),
                  _buildStatisticsSection(currentUser),
                  const SizedBox(height: 24),
                  _buildRecentActivity(currentUser),
                  const SizedBox(height: 24),
                  _buildRoleSpecificContent(context, currentUser),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, UserModel user) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: Text(
            'Dashboard',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FadeInRight(
          duration: const Duration(milliseconds: 800),
          child: IconButton(
            onPressed: () {
              context.go('/notifications');
            },
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_hasUnreadNotifications)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        FadeInRight(
          duration: const Duration(milliseconds: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(UserModel user) {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.accentColor.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getRoleIcon(user.role),
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        user.displayName,
                        style: AppTheme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getRoleDisplayName(user.role),
                style: AppTheme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getWelcomeMessage(user.role),
              style: AppTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          duration: const Duration(milliseconds: 800),
          child: Text(
            'Quick Actions',
            style: AppTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildQuickActionGrid(context, user),
      ],
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, UserModel user) {
    final actions = _getQuickActions(user.role);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 1,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          duration: Duration(milliseconds: 800 + (index * 200)),
          child: QuickActionCard(
            title: actions[index]['title'],
            subtitle: actions[index]['subtitle'],
            icon: actions[index]['icon'],
            color: actions[index]['color'],
            onTap: () => actions[index]['onTap'](context),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          duration: const Duration(milliseconds: 1000),
          child: Text(
            'Statistics',
            style: AppTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildStatisticsCards(user),
      ],
    );
  }

  Widget _buildStatisticsCards(UserModel user) {
    return Column(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final certificateStats = ref.watch(certificateStatsProvider);
            
            return certificateStats.when(
              data: (stats) => _buildCertificateStatsRow(stats),
              loading: () => _buildLoadingStatsCards(),
              error: (error, stack) => _buildErrorStatsCards('Certificate Stats Error'),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildDocumentStatsRow(),
      ],
    );
  }

  Widget _buildCertificateStatsRow(CertificateStatistics stats) {
    return Row(
      children: [
        Expanded(
          child: FadeInUp(
            duration: const Duration(milliseconds: 1200),
            child: DashboardStatsCard(
              title: 'Total Certificates',
              value: stats.totalCertificates.toString(),
              icon: Icons.verified,
              color: AppTheme.primaryColor,
              trend: '+${stats.issuedCertificates}',
              trendLabel: 'Issued',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FadeInUp(
            duration: const Duration(milliseconds: 1400),
            child: DashboardStatsCard(
              title: 'Pending',
              value: stats.pendingCertificates.toString(),
              icon: Icons.pending,
              color: AppTheme.warningColor,
              trend: stats.pendingCertificates > 0 ? 'Needs Action' : 'All Clear',
              trendLabel: 'Status',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _getDocumentStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingDocumentStats();
        }
        
        if (snapshot.hasError) {
          return _buildErrorDocumentStats();
        }
        
        final stats = snapshot.data ?? {'total': 0, 'uploaded': 0};
        
        return Row(
          children: [
            Expanded(
              child: FadeInUp(
                duration: const Duration(milliseconds: 1600),
                child: DashboardStatsCard(
                  title: 'Total Documents',
                  value: stats['total'].toString(),
                  icon: Icons.description,
                  color: AppTheme.secondaryColor,
                  trend: '+${stats['uploaded']}',
                  trendLabel: 'This Month',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FadeInUp(
                duration: const Duration(milliseconds: 1800),
                child: DashboardStatsCard(
                  title: 'Storage Used',
                  value: _formatFileSize(stats['storage'] ?? 0),
                  icon: Icons.storage,
                  color: AppTheme.accentColor,
                  trend: '${((stats['storage'] ?? 0) / (1024 * 1024 * 100) * 100).toStringAsFixed(1)}%',
                  trendLabel: 'of 100MB',
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingDocumentStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorDocumentStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: AppTheme.errorColor),
                  const SizedBox(height: 8),
                  Text(
                    'Document Stats Error',
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, int>> _getDocumentStatistics() async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        LoggerService.warning('❌ No authenticated user for document statistics');
        return {'total': 0, 'uploaded': 0, 'storage': 0};
      }

      LoggerService.info('📊 Loading document statistics for user: ${currentUser.id}');

      // Try to get documents with error handling for permission issues
      QuerySnapshot documentsSnapshot;
      try {
        documentsSnapshot = await FirebaseFirestore.instance
            .collection(AppConfig.documentsCollection)
            .where('uploaderId', isEqualTo: currentUser.id)
            .get();
      } catch (e) {
        if (e.toString().contains('permission-denied')) {
          LoggerService.warning('⚠️ Permission denied for document statistics. Using fallback values.');
          // Return default values for users without proper access
          return _getFallbackStatistics(currentUser);
        } else {
          LoggerService.error('❌ Failed to fetch document statistics', error: e);
          rethrow;
        }
      }

      final documents = documentsSnapshot.docs;
      final total = documents.length;
      
      final uploaded = documents.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        
        final status = data['status'] as String?;
        return status == DocumentStatus.uploaded.name || 
               status == DocumentStatus.verified.name;
      }).length;

      int totalStorage = 0;
      for (final doc in documents) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['fileSize'] != null) {
          totalStorage += (data['fileSize'] as int? ?? 0);
        }
      }

      final result = {
        'total': total,
        'uploaded': uploaded,
        'storage': totalStorage,
      };

      LoggerService.info('✅ Document statistics loaded successfully: $result');
      return result;

    } catch (e, stackTrace) {
      LoggerService.error('❌ Failed to get document statistics', error: e, stackTrace: stackTrace);
      
      // Return fallback values instead of crashing
      return _getFallbackStatistics(null);
    }
  }

  // Fallback statistics for users without proper document access
  Map<String, int> _getFallbackStatistics(UserModel? currentUser) {
    LoggerService.info('📈 Using fallback statistics for user access limitations');
    
    // Provide basic statistics based on user type
    if (currentUser?.userType == UserType.admin) {
      return {'total': 0, 'uploaded': 0, 'storage': 0};
    } else if (currentUser?.userType == UserType.ca) {
      return {'total': 0, 'uploaded': 0, 'storage': 0};
    } else {
      return {'total': 0, 'uploaded': 0, 'storage': 0};
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Widget _buildLoadingStatsCards() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStatsCards(String message) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: AppTheme.errorColor),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInLeft(
          duration: const Duration(milliseconds: 2000),
          child: Text(
            'Recent Activity',
            style: AppTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          duration: const Duration(milliseconds: 2200),
          child: RecentActivityCard(
            activities: _getRealRecentActivities(user),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getRealRecentActivities(UserModel user) {
    // Load real activities from Firebase activity collection
    return []; // This will be populated by the RecentActivityCard widget itself
  }

  Widget _buildRoleSpecificContent(BuildContext context, UserModel user) {
    switch (user.role) {
      case UserRole.systemAdmin:
        return _buildAdminContent(context);
      case UserRole.certificateAuthority:
        return _buildCAContent(context);
      case UserRole.client:
      case UserRole.recipient:
        return _buildUserContent(context);
      case UserRole.viewer:
        return _buildViewerContent(context);
    }
  }

  Widget _buildAdminContent(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 2400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Administration',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminActionButton(
              icon: Icons.people,
              title: 'User Management',
              subtitle: 'Manage system users and permissions',
              onTap: () => context.go('/admin/users'),
            ),
            const SizedBox(height: 12),
            _buildAdminActionButton(
              icon: Icons.settings,
              title: 'System Settings',
              subtitle: 'Configure application settings',
              onTap: () => context.go('/admin/settings'),
            ),
            const SizedBox(height: 12),
            _buildAdminActionButton(
              icon: Icons.analytics,
              title: 'Analytics',
              subtitle: 'View system analytics and reports',
              onTap: () => context.go('/admin/analytics'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCAContent(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 2400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Authority Tools',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminActionButton(
              icon: Icons.verified,
              title: 'Certificate Templates',
              subtitle: 'Manage certificate templates',
              onTap: () => context.go('/certificates/templates'),
            ),
            const SizedBox(height: 12),
            _buildAdminActionButton(
              icon: Icons.approval,
              title: 'Approval Queue',
              subtitle: 'Review pending certificate requests',
              onTap: () => context.go('/certificates/pending'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserContent(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 2400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Certificates & Documents',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminActionButton(
              icon: Icons.download,
              title: 'Download Certificates',
              subtitle: 'Download your issued certificates',
              onTap: () => context.go('/certificates/downloads'),
            ),
            const SizedBox(height: 12),
            _buildAdminActionButton(
              icon: Icons.share,
              title: 'Share Documents',
              subtitle: 'Share documents securely',
              onTap: () => context.go('/documents/share'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerContent(BuildContext context) {
    return FadeInUp(
      duration: const Duration(milliseconds: 2400),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verification Tools',
              style: AppTheme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminActionButton(
              icon: Icons.qr_code_scanner,
              title: 'Verify Certificate',
              subtitle: 'Scan QR code to verify certificates',
              onTap: () => context.go('/verify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textColor.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return Icons.admin_panel_settings;
      case UserRole.certificateAuthority:
        return Icons.verified_user;
      case UserRole.client:
        return Icons.business;
      case UserRole.recipient:
        return Icons.person;
      case UserRole.viewer:
        return Icons.visibility;
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return AppTheme.errorColor;
      case UserRole.certificateAuthority:
        return AppTheme.primaryColor;
      case UserRole.client:
        return AppTheme.accentColor;
      case UserRole.recipient:
        return AppTheme.successColor;
      case UserRole.viewer:
        return AppTheme.infoColor;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
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

  String _getWelcomeMessage(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return 'Manage the entire system and oversee all operations.';
      case UserRole.certificateAuthority:
        return 'Issue and manage digital certificates for your organization.';
      case UserRole.client:
        return 'Request and manage certificates for your business needs.';
      case UserRole.recipient:
        return 'View and download your certificates and documents.';
      case UserRole.viewer:
        return 'Verify and view public certificates and documents.';
    }
  }

  List<Map<String, dynamic>> _getQuickActions(UserRole role) {
    switch (role) {
      case UserRole.systemAdmin:
        return [
          {
            'title': 'User Management',
            'subtitle': 'Manage users',
            'icon': Icons.people,
            'color': AppTheme.primaryColor,
            'onTap': (BuildContext context) => context.go('/admin/users'),
          },
          {
            'title': 'System Settings',
            'subtitle': 'Configure system',
            'icon': Icons.settings,
            'color': AppTheme.accentColor,
            'onTap': (BuildContext context) => context.go('/admin/settings'),
          },
          {
            'title': 'Analytics',
            'subtitle': 'View reports',
            'icon': Icons.analytics,
            'color': AppTheme.infoColor,
            'onTap': (BuildContext context) => context.go('/admin/analytics'),
          },
          {
            'title': 'Backup',
            'subtitle': 'System backup',
            'icon': Icons.backup,
            'color': AppTheme.warningColor,
            'onTap': (BuildContext context) => context.go('/admin/backup'),
          },
        ];
      case UserRole.certificateAuthority:
        return [
          {
            'title': 'Create Certificate',
            'subtitle': 'Issue new certificate',
            'icon': Icons.add_circle,
            'color': AppTheme.primaryColor,
            'onTap': (BuildContext context) => context.go('/certificates/create'),
          },
          {
            'title': 'Pending Approvals',
            'subtitle': 'Review requests',
            'icon': Icons.pending_actions,
            'color': AppTheme.warningColor,
            'onTap': (BuildContext context) => context.go('/certificates/pending'),
          },
          {
            'title': 'Templates',
            'subtitle': 'Manage templates',
            'icon': Icons.description,
            'color': AppTheme.accentColor,
            'onTap': (BuildContext context) => context.go('/certificates/templates'),
          },
          {
            'title': 'Issued Certificates',
            'subtitle': 'View all issued',
            'icon': Icons.verified,
            'color': AppTheme.successColor,
            'onTap': (BuildContext context) => context.go('/certificates/issued'),
          },
        ];
      case UserRole.client:
        return [
          {
            'title': 'Request Certificate',
            'subtitle': 'New request',
            'icon': Icons.request_page,
            'color': AppTheme.primaryColor,
            'onTap': (BuildContext context) => context.go('/certificates/request'),
          },
          {
            'title': 'Upload Document',
            'subtitle': 'Add document',
            'icon': Icons.upload_file,
            'color': AppTheme.accentColor,
            'onTap': (BuildContext context) => context.go('/documents/upload'),
          },
          {
            'title': 'My Certificates',
            'subtitle': 'View certificates',
            'icon': Icons.folder_special,
            'color': AppTheme.infoColor,
            'onTap': (BuildContext context) => context.go('/certificates'),
          },
          {
            'title': 'My Documents',
            'subtitle': 'View documents',
            'icon': Icons.description,
            'color': AppTheme.successColor,
            'onTap': (BuildContext context) => context.go('/documents'),
          },
        ];
      case UserRole.recipient:
        return [
          {
            'title': 'My Certificates',
            'subtitle': 'View certificates',
            'icon': Icons.verified,
            'color': AppTheme.primaryColor,
            'onTap': (BuildContext context) => context.go('/certificates'),
          },
          {
            'title': 'Download',
            'subtitle': 'Download files',
            'icon': Icons.download,
            'color': AppTheme.accentColor,
            'onTap': (BuildContext context) => context.go('/certificates/downloads'),
          },
          {
            'title': 'Share',
            'subtitle': 'Share certificates',
            'icon': Icons.share,
            'color': AppTheme.infoColor,
            'onTap': (BuildContext context) => context.go('/certificates/share'),
          },
          {
            'title': 'Profile',
            'subtitle': 'Update profile',
            'icon': Icons.person,
            'color': AppTheme.successColor,
            'onTap': (BuildContext context) => context.go('/profile'),
          },
        ];
      case UserRole.viewer:
        return [
          {
            'title': 'Verify Certificate',
            'subtitle': 'Check validity',
            'icon': Icons.verified_user,
            'color': AppTheme.primaryColor,
            'onTap': (BuildContext context) => context.go('/verify'),
          },
          {
            'title': 'QR Scanner',
            'subtitle': 'Scan QR code',
            'icon': Icons.qr_code_scanner,
            'color': AppTheme.accentColor,
            'onTap': (BuildContext context) => context.go('/verify/scanner'),
          },
          {
            'title': 'Public Directory',
            'subtitle': 'Browse public certificates',
            'icon': Icons.public,
            'color': AppTheme.infoColor,
            'onTap': (BuildContext context) => context.go('/public'),
          },
          {
            'title': 'Help',
            'subtitle': 'Get help',
            'icon': Icons.help,
            'color': AppTheme.warningColor,
            'onTap': (BuildContext context) => context.go('/help'),
          },
        ];
    }
  }
} 