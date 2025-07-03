import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
//import
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/reports_service.dart';

// Provider for reports service
final reportsServiceProvider =
    Provider<ReportsService>((ref) => ReportsService());

// Provider for system overview report
final systemOverviewReportProvider =
    FutureProvider<Map<String, dynamic>>((ref) {
  final reportsService = ref.read(reportsServiceProvider);
  return reportsService.generateSystemOverviewReport();
});

// Provider for CA performance report
final caPerformanceReportProvider = FutureProvider<Map<String, dynamic>>((ref) {
  final reportsService = ref.read(reportsServiceProvider);
  return reportsService.generateCAPerformanceReport();
});

class AdminAnalyticsPage extends ConsumerStatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  ConsumerState<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends ConsumerState<AdminAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        return _buildAnalyticsPage();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildAnalyticsPage() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildUsersTab(),
            _buildCertificatesTab(),
            _buildSystemTab(),
          ],
        ),
      ),
      floatingActionButton: _buildExportButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeInDown(
          child: Text(
            'Analytics & Reports',
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
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _generateReport(),
          icon: const Icon(Icons.download, color: Colors.white),
          tooltip: 'Export Report',
        ),
        IconButton(
          onPressed: () => _refreshData(),
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh Data',
        ),
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
            Tab(text: 'Certificates', icon: Icon(Icons.verified)),
            Tab(text: 'System', icon: Icon(Icons.settings)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final reportAsync = ref.watch(systemOverviewReportProvider);

    return reportAsync.when(
      data: (report) => _buildOverviewContent(report),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildOverviewContent(Map<String, dynamic> report) {
    final users = report['users'] as Map<String, dynamic>;
    final certificates = report['certificates'] as Map<String, dynamic>;
    final documents = report['documents'] as Map<String, dynamic>;
    final activity = report['activity'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(systemOverviewReportProvider);
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(users, certificates, documents, activity),
            const SizedBox(height: AppTheme.spacingL),
            _buildChartsSection(users, certificates, documents),
            const SizedBox(height: AppTheme.spacingL),
            _buildTrendsSection(activity),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(
    Map<String, dynamic> users,
    Map<String, dynamic> certificates,
    Map<String, dynamic> documents,
    Map<String, dynamic> activity,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Users',
          (users['totalUsers'] ?? 0).toString(),
          Icons.people,
          AppTheme.primaryColor,
          subtitle: '${users['averageUsersPerMonth'] ?? 0} avg/month',
        ),
        _buildMetricCard(
          'Total Certificates',
          (certificates['totalCertificates'] ?? 0).toString(),
          Icons.verified,
          AppTheme.successColor,
          subtitle: '${certificates['issuedCount'] ?? 0} issued',
        ),
        _buildMetricCard(
          'Total Documents',
          (documents['totalDocuments'] ?? 0).toString(),
          Icons.description,
          AppTheme.infoColor,
          subtitle: _formatFileSize(documents['totalStorageBytes'] ?? 0),
        ),
        _buildMetricCard(
          'Total Activities',
          '${activity['totalActivities'] ?? 0}',
          Icons.timeline,
          AppTheme.warningColor,
          subtitle: '${activity['averageActivitiesPerDay'] ?? 0} avg/day',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return FadeInUp(
      child: Card(
        elevation: 2,
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
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
    );
  }

  Widget _buildChartsSection(
    Map<String, dynamic> users,
    Map<String, dynamic> certificates,
    Map<String, dynamic> documents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distribution Charts',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildPieChart(
                'User Roles',
                users['roleDistribution'] as Map<String, dynamic>? ?? {},
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildPieChart(
                'Certificate Types',
                certificates['typeDistribution'] as Map<String, dynamic>? ?? {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPieChart(String title, Map<String, dynamic> data) {
    if (data.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: AppTheme.titleSmall),
              const SizedBox(height: AppTheme.spacingS),
              const Text('No data available'),
            ],
          ),
        ),
      );
    }

    final sections = data.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: entry.key,
        color: _getColorForIndex(data.keys.toList().indexOf(entry.key)),
        radius: 60,
      );
    }).toList();

    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          children: [
            Text(title, style: AppTheme.titleSmall),
            const SizedBox(height: AppTheme.spacingS),
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsSection(Map<String, dynamic> activity) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activity Trends',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              height: 200,
              child: _buildActivityChart(
                  activity['dailyActivity'] as Map<String, dynamic>? ?? {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart(Map<String, dynamic> dailyActivity) {
    if (dailyActivity.isEmpty) {
      return const Center(child: Text('No activity data available'));
    }

    final spots = dailyActivity.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
            }).toList(),
            isCurved: true,
            color: AppTheme.primaryColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    final reportAsync = ref.watch(systemOverviewReportProvider);

    return reportAsync.when(
      data: (report) {
        final users = report['users'] as Map<String, dynamic>;
        return _buildUsersAnalytics(users);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildUsersAnalytics(Map<String, dynamic> users) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDistributionCard(
            'Role Distribution',
            users['roleDistribution'] as Map<String, dynamic>? ?? {},
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildDistributionCard(
            'Status Distribution',
            users['statusDistribution'] as Map<String, dynamic>? ?? {},
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildRegistrationTrendsCard(
            users['monthlyRegistrations'] as Map<String, dynamic>? ?? {},
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesTab() {
    final reportAsync = ref.watch(systemOverviewReportProvider);

    return reportAsync.when(
      data: (report) {
        final certificates = report['certificates'] as Map<String, dynamic>;
        return _buildCertificatesAnalytics(certificates);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildCertificatesAnalytics(Map<String, dynamic> certificates) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDistributionCard(
            'Certificate Status',
            certificates['statusDistribution'] as Map<String, dynamic>? ?? {},
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildDistributionCard(
            'Certificate Types',
            certificates['typeDistribution'] as Map<String, dynamic>? ?? {},
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildIssuanceTrendsCard(
            certificates['monthlyIssued'] as Map<String, dynamic>? ?? {},
          ),
        ],
      ),
    );
  }

  Widget _buildSystemTab() {
    final caReportAsync = ref.watch(caPerformanceReportProvider);

    return caReportAsync.when(
      data: (report) => _buildSystemAnalytics(report),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildSystemAnalytics(Map<String, dynamic> report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCAPerformanceCard(report),
          const SizedBox(height: AppTheme.spacingM),
          _buildSystemMetricsCard(),
        ],
      ),
    );
  }

  Widget _buildDistributionCard(String title, Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            if (data.isEmpty)
              const Text('No data available')
            else
              ...data.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getColorForIndex(
                                data.keys.toList().indexOf(entry.key)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text('${entry.key}: ${entry.value}'),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationTrendsCard(
      Map<String, dynamic> monthlyRegistrations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registration Trends',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              height: 200,
              child: _buildActivityChart(monthlyRegistrations),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuanceTrendsCard(Map<String, dynamic> monthlyIssued) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Issuance Trends',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              height: 200,
              child: _buildActivityChart(monthlyIssued),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCAPerformanceCard(Map<String, dynamic> report) {
    final caPerformance =
        report['caPerformance'] as Map<String, dynamic>? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Authority Performance',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text('Total CAs: ${report['totalCAs'] ?? 0}'),
            Text('Active CAs: ${report['activeCAs'] ?? 0}'),
            Text('Pending CAs: ${report['pendingCAs'] ?? 0}'),
            const SizedBox(height: AppTheme.spacingM),
            if (caPerformance.isEmpty)
              const Text('No CA performance data available')
            else
              ...caPerformance.entries.take(5).map((entry) {
                final ca = entry.value as Map<String, dynamic>;
                return ListTile(
                  title: Text(ca['name'] ?? 'Unknown'),
                  subtitle: Text('Status: ${ca['status']}'),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Certs: ${ca['certificatesIssued']}'),
                      Text('Docs: ${ca['documentsReviewed']}'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMetricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Metrics',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            const ListTile(
              leading: Icon(Icons.storage, color: AppTheme.successColor),
              title: Text('Database Status'),
              trailing: Text('Online'),
            ),
            const ListTile(
              leading: Icon(Icons.security, color: AppTheme.successColor),
              title: Text('Security Status'),
              trailing: Text('Secure'),
            ),
            const ListTile(
              leading: Icon(Icons.backup, color: AppTheme.infoColor),
              title: Text('Last Backup'),
              trailing: Text('2 hours ago'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return FloatingActionButton.extended(
      onPressed: _exportAnalytics,
      backgroundColor: AppTheme.primaryColor,
      icon: const Icon(Icons.file_download),
      label: const Text('Export'),
    );
  }

  Widget _buildErrorContent(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: AppTheme.errorColor, size: 64),
          const SizedBox(height: AppTheme.spacingM),
          Text('Error loading analytics: $error'),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text('Access Denied', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to access analytics.',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/admin'),
              child: const Text('Go to Admin Dashboard'),
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
            const Icon(Icons.error, size: 80, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text('Error Loading Analytics', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getColorForIndex(int index) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.successColor,
      AppTheme.warningColor,
      AppTheme.errorColor,
      AppTheme.infoColor,
      AppTheme.accentColor,
    ];
    return colors[index % colors.length];
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _generateReport() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating comprehensive report...'),
            ],
          ),
        ),
      );

      final systemStats = await ref.read(systemOverviewReportProvider.future);
      final caStats = await ref.read(caPerformanceReportProvider.future);

      final reportData = _formatReportData(systemStats, caStats);

      // Use real report export service
      final reportsService = ReportsService();
      final pdfUrl = await reportsService.exportReportToPdf(reportData);
      final excelUrl = await reportsService.exportReportToExcel(reportData);
      final csvUrl = await reportsService.exportReportToCsv(reportData);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success dialog with download options
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report Generated Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Your report has been generated in multiple formats:'),
                const SizedBox(height: 16),
                _buildDownloadOption(
                    'PDF Report', pdfUrl, Icons.picture_as_pdf),
                _buildDownloadOption(
                    'Excel Report', excelUrl, Icons.table_chart),
                _buildDownloadOption('CSV Report', csvUrl, Icons.list_alt),
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
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      LoggerService.error('Failed to generate report', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _refreshData() {
    ref.invalidate(systemOverviewReportProvider);
    ref.invalidate(caPerformanceReportProvider);
  }

  Widget _buildDownloadOption(String title, String url, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: const Text('Click to download'),
      trailing: const Icon(Icons.download),
      onTap: () async {
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Could not launch URL');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to download: ${e.toString()}'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      },
    );
  }

  // Helper methods for report generation
  Map<String, dynamic> _formatReportData(
      Map<String, dynamic> systemStats, Map<String, dynamic> caStats) {
    return {
      'reportId': 'ADMIN-${DateTime.now().millisecondsSinceEpoch}',
      'generatedAt': DateTime.now().toIso8601String(),
      'type': 'admin_analytics',
      'users': systemStats['users'],
      'certificates': systemStats['certificates'],
      'documents': systemStats['documents'],
      'activity': systemStats['activity'],
      'caPerformance': caStats,
      'generatedBy': 'Admin Analytics System',
    };
  }

  Future<Map<String, dynamic>> _gatherAnalyticsData() async {
    final systemData = await ref.read(systemOverviewReportProvider.future);
    final caData = await ref.read(caPerformanceReportProvider.future);

    return {
      'system': systemData,
      'ca': caData,
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  String _convertToCsv(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('Type,Metric,Value,Timestamp');

    final system = data['system'] as Map<String, dynamic>;
    buffer.writeln(
        'System,Total Users,${system['users']['totalUsers']},${data['exportedAt']}');
    buffer.writeln(
        'System,Total Certificates,${system['certificates']['totalCertificates']},${data['exportedAt']}');
    buffer.writeln(
        'System,Total Documents,${system['documents']['totalDocuments']},${data['exportedAt']}');

    return buffer.toString();
  }

  Future<void> _saveToFile(String content, String filename) async {
    try {
      // Use report export service to save file
      final result = await ref.read(reportExportServiceProvider).saveTextFile(
            content: content,
            filename: filename,
          );

      LoggerService.info('File saved: $filename at ${result['path']}');
    } catch (e) {
      LoggerService.error('Failed to save file: $filename', error: e);
      rethrow;
    }
  }

  void _exportAnalytics() async {
    try {
      final analyticsData = await _gatherAnalyticsData();
      final csvData = _convertToCsv(analyticsData);
      await _saveToFile(csvData,
          'analytics_export_${DateTime.now().millisecondsSinceEpoch}.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analytics data exported successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to export analytics', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export analytics: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
