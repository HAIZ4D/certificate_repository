import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/admin_service.dart';
import '../../providers/admin_providers.dart';

// Provider for admin service
final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// Provider for real-time dashboard statistics
final adminDashboardStatsProvider = StreamProvider<Map<String, dynamic>>((ref) async* {
  final adminService = ref.read(adminServiceProvider);
  
  await for (final userStats in adminService.getUserStatisticsStream()) {
    await for (final certStats in adminService.getCertificateStatisticsStream()) {
      await for (final docStats in adminService.getDocumentStatisticsStream()) {
        yield {
          'users': userStats,
          'certificates': certStats,
          'documents': docStats,
          'lastUpdated': DateTime.now(),
        };
      }
    }
  }
});

// Provider for recent admin activities
final recentAdminActivitiesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final adminService = ref.read(adminServiceProvider);
  return adminService.getAdminActivitiesStream(limit: 10);
});

// Provider for system health
final systemHealthProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final adminService = ref.read(adminServiceProvider);
  return adminService.getSystemHealth();
});

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
        data: (user) {
        if (user == null || user.userType != UserType.admin || !user.isActive) {
          return _buildUnauthorizedPage();
        }
        return _buildAdminDashboard(user);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildAdminDashboard(UserModel user) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(user),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
        children: [
            _buildOverviewTab(),
            _buildUsersTab(),
            _buildActivitiesTab(),
            _buildSystemTab(),
          ],
        ),
      ),
      floatingActionButton: _buildQuickActionsButton(),
    );
  }

  Widget _buildAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeInDown(
          child: Text(
            'Admin Dashboard',
            style: AppTheme.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        background: Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
          child: Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: user.photoURL != null 
                          ? NetworkImage(user.photoURL!) 
                    : null,
                      child: user.photoURL == null 
                    ? Text(
                              user.displayName.substring(0, 1).toUpperCase(),
                        style: AppTheme.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                            'Welcome back,',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            user.displayName,
                            style: AppTheme.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                            'System Administrator',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _showNotifications(),
          icon: Stack(
        children: [
              const Icon(Icons.notifications, color: Colors.white),
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
        IconButton(
          onPressed: () => context.push('/admin/settings'),
          icon: const Icon(Icons.settings, color: Colors.white),
        ),
        const SizedBox(width: AppTheme.spacingS),
      ],
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Users', icon: Icon(Icons.people)),
            Tab(text: 'Activities', icon: Icon(Icons.history)),
            Tab(text: 'System', icon: Icon(Icons.settings_applications)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    
    return statsAsync.when(
      data: (stats) => _buildOverviewContent(stats),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildOverviewContent(Map<String, dynamic> stats) {
    final userStats = stats['users'] as Map<String, dynamic>;
    final certStats = stats['certificates'] as Map<String, dynamic>;
    final docStats = stats['documents'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminDashboardStatsProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // Quick Stats Grid
            _buildQuickStatsGrid(userStats, certStats, docStats),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Charts Section
            _buildChartsSection(userStats, certStats, docStats),
            
            const SizedBox(height: AppTheme.spacingL),
            
            // Recent Activities and Alerts
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentActivities()),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(child: _buildSystemAlerts()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsGrid(
    Map<String, dynamic> userStats,
    Map<String, dynamic> certStats,
    Map<String, dynamic> docStats,
  ) {
    return GridView.count(
      crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppTheme.spacingM,
          mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1.8,
          children: [
            _buildStatCard(
              'Total Users',
          '${userStats['total'] ?? 0}',
              Icons.people,
              AppTheme.primaryColor,
          trend: _calculateTrend(userStats['thisMonth'], userStats['lastMonth']),
          onTap: () => context.push('/admin/users'),
        ),
        _buildStatCard(
          'Pending CAs',
          '${userStats['pendingCAs'] ?? 0}',
          Icons.pending_actions,
          AppTheme.warningColor,
          onTap: () => context.push('/admin/ca-approval'),
            ),
            _buildStatCard(
              'Certificates',
          '${certStats['total'] ?? 0}',
              Icons.verified,
              AppTheme.successColor,
          trend: _calculateTrend(certStats['thisMonth'], 0),
          onTap: () => context.push('/certificates'),
            ),
            _buildStatCard(
              'Documents',
          '${docStats['total'] ?? 0}',
              Icons.description,
              AppTheme.infoColor,
          subtitle: _formatFileSize(docStats['totalSize'] ?? 0),
          onTap: () => context.push('/documents'),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
    double? trend,
    VoidCallback? onTap,
  }) {
    return FadeInUp(
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.mediumRadius,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                        borderRadius: AppTheme.smallRadius,
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const Spacer(),
                    if (trend != null) _buildTrendIndicator(trend),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
                  style: AppTheme.headlineMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
                  style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
              Text(
                    subtitle,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                      fontSize: 10,
                ),
              ),
                ],
          ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(double trend) {
    final isPositive = trend >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPositive ? AppTheme.successColor.withValues(alpha: 0.1) : AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 12,
            color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
          ),
          Text(
            '${trend.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    Map<String, dynamic> userStats,
    Map<String, dynamic> certStats,
    Map<String, dynamic> docStats,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analytics',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildUserStatusChart(userStats),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildCertificateTypeChart(certStats),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserStatusChart(Map<String, dynamic> userStats) {
    return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
              'User Status Distribution',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildStatusIndicator('Active', userStats['active'] ?? 0, AppTheme.successColor),
            _buildStatusIndicator('Pending', userStats['pending'] ?? 0, AppTheme.warningColor),
            _buildStatusIndicator('Suspended', userStats['suspended'] ?? 0, AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingS),
                      Text(
              'Total: ${userStats['total'] ?? 0} users',
                        style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text('$label: $count'),
        ],
      ),
    );
  }

  Widget _buildCertificateTypeChart(Map<String, dynamic> certStats) {
    final byType = certStats['byType'] as Map<String, int>? ?? {};
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
              'Certificate Types',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
            const SizedBox(height: AppTheme.spacingM),
            if (byType.isEmpty)
              Text(
                'No certificates yet',
                    style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              )
            else
              ...byType.entries.map((entry) => 
                _buildStatusIndicator(entry.key, entry.value, AppTheme.primaryColor)
              ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Total: ${certStats['total'] ?? 0} certificates',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        ),
    );
  }

  Widget _buildRecentActivities() {
    final activitiesAsync = ref.watch(recentAdminActivitiesProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Activities',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _tabController.animateTo(2),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            activitiesAsync.when(
              data: (activities) => activities.isEmpty
                  ? Text(
                      'No recent activities',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              )
                  : Column(
                      children: activities.take(5).map((activity) => 
                        _buildActivityItem(activity)
                      ).toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final timestamp = (activity['timestamp'] as Timestamp).toDate();
    final action = activity['action'] as String;
    final targetUserName = activity['targetUserName'] as String?;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getActivityColor(action),
              shape: BoxShape.circle,
            ),
            ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getActivityDescription(action, targetUserName),
                  style: AppTheme.bodySmall,
                ),
                Text(
                  _formatTimeAgo(timestamp),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemAlerts() {
    final healthAsync = ref.watch(systemHealthProvider);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Status',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            healthAsync.when(
              data: (health) => _buildSystemHealthContent(health),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => _buildSystemErrorContent(error.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemHealthContent(Map<String, dynamic> health) {
    final status = health['status'] as String;
    final isHealthy = status == 'healthy';
    
    return Column(
                  children: [
        Row(
          children: [
            Icon(
              isHealthy ? Icons.check_circle : Icons.error,
              color: isHealthy ? AppTheme.successColor : AppTheme.errorColor,
            ),
            const SizedBox(width: AppTheme.spacingS),
                    Text(
              isHealthy ? 'System Healthy' : 'System Issues',
              style: AppTheme.titleSmall.copyWith(
                color: isHealthy ? AppTheme.successColor : AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        if (isHealthy) ...[
          _buildSystemMetric('Database', 'Connected', AppTheme.successColor),
          _buildSystemMetric('Authentication', 'Working', AppTheme.successColor),
          _buildSystemMetric('Storage', 'Available', AppTheme.successColor),
        ] else ...[
          Text(
            'Error: ${health['error']}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemErrorContent(String error) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.error, color: AppTheme.errorColor),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'System Error',
              style: AppTheme.titleSmall.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          error,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.errorColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMetric(String name, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text('$name: $status'),
            ],
          ),
        );
      }

  Widget _buildUsersTab() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                children: [
                  const Icon(Icons.people, size: 64, color: AppTheme.primaryColor),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'User Management',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  const Text(
                    'Manage users, roles, and permissions from the dedicated user management page.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin/users'),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open User Management'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesTab() {
    final activitiesAsync = ref.watch(recentAdminActivitiesProvider);
    
    return activitiesAsync.when(
      data: (activities) => ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
    return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getActivityColor(activity['action']),
                child: Icon(
                  _getActivityIcon(activity['action']),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              title: Text(_getActivityDescription(
                activity['action'], 
                activity['targetUserName']
              )),
              subtitle: Text(_formatTimeAgo(
                (activity['timestamp'] as Timestamp).toDate()
              )),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showActivityDetails(activity),
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildSystemTab() {
    final healthAsync = ref.watch(systemHealthProvider);
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
      child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                    'System Health',
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  healthAsync.when(
                    data: (health) => _buildDetailedSystemHealth(health),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                  ),
          ],
        ),
      ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
          children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/admin/backup'),
                  icon: const Icon(Icons.backup),
                  label: const Text('System Backup'),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/admin/logs'),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Logs'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedSystemHealth(Map<String, dynamic> health) {
    final database = health['database'] as Map<String, dynamic>? ?? {};
    final authentication = health['authentication'] as Map<String, dynamic>? ?? {};
    final collections = database['collections'] as Map<String, dynamic>? ?? {};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        _buildHealthSection('Database', database['connected'] == true, [
          'Users: ${collections['users'] ?? 0}',
          'Certificates: ${collections['certificates'] ?? 0}',
          'Documents: ${collections['documents'] ?? 0}',
        ]),
        const SizedBox(height: AppTheme.spacingM),
        _buildHealthSection('Authentication', authentication['working'] == true, [
          'Current User: ${authentication['currentUser'] ?? 'Unknown'}',
        ]),
      ],
    );
  }

  Widget _buildHealthSection(String title, bool isHealthy, List<String> details) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        border: Border.all(
          color: isHealthy ? AppTheme.successColor : AppTheme.errorColor,
          width: 1,
        ),
        borderRadius: AppTheme.smallRadius,
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle : Icons.error,
                color: isHealthy ? AppTheme.successColor : AppTheme.errorColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                title,
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          ...details.map((detail) => Text(
            detail,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActionsButton() {
    return FloatingActionButton(
      onPressed: _showQuickActions,
      backgroundColor: AppTheme.primaryColor,
      child: const Icon(Icons.add),
    );
  }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: AppTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
                            Text(
              'You do not have permission to access the admin dashboard.',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
                            ),
                          ],
                        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Dashboard',
              style: AppTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.invalidate(adminDashboardStatsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
          ),
        );
      }

  Widget _buildErrorContent(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: AppTheme.errorColor),
          const SizedBox(height: 8),
          Text('Error: $error'),
          ElevatedButton(
            onPressed: () => _retryLoadData(),
            child: const Text('Retry'),
          ),
        ],
        ),
      );
    }

  // Helper methods
  double _calculateTrend(int? current, int? previous) {
    if (previous == null || previous == 0) return 0.0;
    if (current == null) return 0.0;
    return ((current - previous) / previous) * 100;
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Color _getActivityColor(String action) {
    switch (action) {
      case 'ca_application_approved':
        return AppTheme.successColor;
      case 'ca_application_rejected':
      case 'user_suspended':
        return AppTheme.errorColor;
      case 'user_reactivated':
        return AppTheme.infoColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'ca_application_approved':
        return Icons.check_circle;
      case 'ca_application_rejected':
        return Icons.cancel;
      case 'user_suspended':
        return Icons.block;
      case 'user_reactivated':
        return Icons.refresh;
      default:
        return Icons.info;
    }
  }

  String _getActivityDescription(String action, String? targetUserName) {
    final name = targetUserName ?? 'Unknown User';
    switch (action) {
      case 'ca_application_approved':
        return 'Approved CA application for $name';
      case 'ca_application_rejected':
        return 'Rejected CA application for $name';
      case 'user_suspended':
        return 'Suspended user account: $name';
      case 'user_reactivated':
        return 'Reactivated user account: $name';
      case 'bulk_status_update':
        return 'Bulk updated user statuses';
      default:
        return 'Admin action: $action';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showNotifications() {
    context.push('/notifications');
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              'Quick Actions',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
              Row(
                children: [
                  Expanded(
                  child: _buildQuickActionButton(
                    'Manage Users',
                    Icons.people,
                    () => context.push('/admin/users'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildQuickActionButton(
                    'CA Approvals',
                    Icons.verified,
                    () => context.push('/admin/ca-approvals'),
                  ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
            Row(
                          children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'System Backup',
                    Icons.backup,
                    () => context.push('/admin/backup'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildQuickActionButton(
                    'Analytics',
                    Icons.analytics,
                    () => context.push('/admin/analytics'),
                  ),
                ),
              ],
            ),
          ],
        ),
                        ),
                      );
                    }
                    
  Widget _buildQuickActionButton(String title, IconData icon, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(AppTheme.spacingM),
      ),
                        child: Column(
                          children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }
                    
  void _retryLoadData() {
    setState(() {
      // Trigger rebuild to reload all data
    });
    
    // Refresh all providers
    ref.invalidate(adminStatsProvider);
    ref.invalidate(recentActivitiesProvider);
    ref.invalidate(systemHealthProvider);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing data...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showActivityDetails(Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
            Text('Action: ${activity['action']}'),
            if (activity['targetUserName'] != null)
              Text('Target User: ${activity['targetUserName']}'),
            if (activity['targetUserEmail'] != null)
              Text('Email: ${activity['targetUserEmail']}'),
            Text('Time: ${(activity['timestamp'] as Timestamp).toDate()}'),
            if (activity['details'] != null) ...[
              const SizedBox(height: 8),
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(activity['details'].toString()),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
} 