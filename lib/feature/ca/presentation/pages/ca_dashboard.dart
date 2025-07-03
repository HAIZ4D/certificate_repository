import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/ca_providers.dart';

class CADashboard extends ConsumerStatefulWidget {
  const CADashboard({super.key});

  @override
  ConsumerState<CADashboard> createState() => _CADashboardState();
}

class _CADashboardState extends ConsumerState<CADashboard> {
  @override
  void initState() {
    super.initState();
    // Load CA statistics when dashboard loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(caStatsProvider.notifier).loadStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final caStats = ref.watch(caStatsProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // Check if user is authorized for CA system
        if (!user.isCA && !user.isAdmin) {
          return _buildUnauthorizedPage();
        }

        // Check if CA status is approved
        if (user.isCA && user.status != UserStatus.active) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (user.status == UserStatus.pending) {
              context.go('/ca/pending');
            } else {
              // For suspended or other statuses, redirect to login
              context.go('/login');
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return _buildCADashboard(user, caStats);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildCADashboard(UserModel user, AsyncValue<CAStats> caStats) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(caStatsProvider.notifier).loadStats();
          },
          child: CustomScrollView(
            slivers: [
              // Fixed App Bar
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppTheme.primaryColor,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.spacingL,
                          AppTheme.spacingXL,
                          AppTheme.spacingL,
                          AppTheme.spacingL,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CA Dashboard',
                              style: AppTheme.titleLarge.copyWith(
                                color: AppTheme.textOnPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingL),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  backgroundImage: user.photoURL != null
                                      ? NetworkImage(user.photoURL!)
                                      : null,
                                  child: user.photoURL == null
                                      ? Text(
                                          user.displayName
                                              .substring(0, 1)
                                              .toUpperCase(),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back,',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: Colors.white70,
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
                                        'Certificate Authority',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Dashboard Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatsSection(caStats),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildQuickActionsSection(),
                    const SizedBox(height: AppTheme.spacingL),
                    // _buildRecentActivitySection(),
                    const SizedBox(height: AppTheme.spacingL),
                    // _buildPendingReviewsSection(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(AsyncValue<CAStats> caStats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        caStats.when(
          data: (stats) => _buildStatsCards(stats),
          loading: () => _buildLoadingStatsCards(),
          error: (error, stack) => _buildErrorStatsCards(),
        ),
      ],
    );
  }

  Widget _buildStatsCards(CAStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1,
      children: [
        FadeInUp(
          duration: const Duration(milliseconds: 300),
          child: _buildStatCard(
            icon: Icons.description_outlined,
            title: 'Certificates Issued',
            value: stats.totalCertificatesIssued.toString(),
            color: AppTheme.successColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: _buildStatCard(
            icon: Icons.pending_outlined,
            title: 'Pending Reviews',
            value: stats.pendingDocuments.toString(),
            color: AppTheme.warningColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: _buildStatCard(
            icon: Icons.folder_outlined,
            title: 'Total Documents',
            value: stats.totalDocuments.toString(),
            color: AppTheme.infoColor,
          ),
        ),
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: _buildStatCard(
            icon: Icons.people_outlined,
            title: 'Active Users',
            value: stats.activeUsers.toString(),
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              value,
              style: AppTheme.headlineMedium.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStatsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppTheme.spacingM,
      mainAxisSpacing: AppTheme.spacingM,
      childAspectRatio: 1.5,
      children: List.generate(
        4,
        (index) => Card(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorStatsCards() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.errorColor),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Failed to load statistics',
              style: AppTheme.bodyLarge.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: AppTheme.spacingS),
            ElevatedButton(
              onPressed: () => ref.read(caStatsProvider.notifier).loadStats(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white, // 👈 White text
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppTheme.spacingM,
          mainAxisSpacing: AppTheme.spacingM,
          childAspectRatio: 1,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 700),
              child: _buildActionCard(
                icon: Icons.add_circle_outline,
                title: 'Create Certificate',
                subtitle: 'Issue new certificate',
                onTap: () => context.go('/ca/certificates/create'),
                textColor: Colors.white, // 👈 Pass to action card if supported
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 800),
              child: _buildActionCard(
                icon: Icons.rate_review_outlined,
                title: 'Review Documents',
                subtitle: 'Approve or reject submissions',
                onTap: () => context.go('/ca/document-review'),
                textColor: Colors.white,
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 900),
              child: _buildActionCard(
                icon: Icons.history_outlined,
                title: 'Certificate History',
                subtitle: 'View issued certificates',
                onTap: () => context.go('/ca/certificates'),
                textColor: Colors.white,
              ),
            ),
            FadeInUp(
              duration: const Duration(milliseconds: 1000),
              child: _buildActionCard(
                icon: Icons.settings_outlined,
                title: 'CA Settings',
                subtitle: 'Manage CA profile',
                onTap: () => context.go('/ca/settings'),
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    return Card(
      elevation: 2,
      color: AppTheme.primaryColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            children: [
              Icon(
                icon,
                size: 32,
                color: textColor,
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppTheme.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall.copyWith(
                        color: textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildPendingReviewsSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Row(
  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         children: [
  //           Text(
  //             'Pending Reviews',
  //             style: AppTheme.titleLarge.copyWith(
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //           TextButton(
  //             onPressed: () => context.go('/ca/reviews'),
  //             child: const Text('Review All'),
  //           ),
  //         ],
  //       ),
  //       const SizedBox(height: AppTheme.spacingM),
  //       Card(
  //         child: ListView.separated(
  //           shrinkWrap: true,
  //           physics: const NeverScrollableScrollPhysics(),
  //           itemCount: 2,
  //           separatorBuilder: (context, index) => const Divider(),
  //           itemBuilder: (context, index) => ListTile(
  //             leading: CircleAvatar(
  //               backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
  //               child: const Icon(
  //                 Icons.pending_actions,
  //                 color: AppTheme.warningColor,
  //               ),
  //             ),
  //             title: Text(
  //               index == 0
  //                   ? 'Academic Transcript - Jane Smith'
  //                   : 'Professional Certificate - Mike Johnson',
  //               style: AppTheme.bodyMedium.copyWith(
  //                 fontWeight: FontWeight.w500,
  //               ),
  //             ),
  //             subtitle: Text(
  //               index == 0 ? 'Uploaded 3 hours ago' : 'Uploaded 5 hours ago',
  //               style: AppTheme.bodySmall.copyWith(
  //                 color: AppTheme.textSecondary,
  //               ),
  //             ),
  //             trailing: Container(
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: AppTheme.spacingS,
  //                 vertical: 4,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: AppTheme.warningColor.withValues(alpha: 0.1),
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //               child: Text(
  //                 'REVIEW',
  //                 style: AppTheme.labelSmall.copyWith(
  //                   color: AppTheme.warningColor,
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildUnauthorizedPage() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.block,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: AppTheme.spacingXL),
                Text(
                  'Access Denied',
                  style: AppTheme.headlineLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'You do not have permission to access the Certificate Authority system.',
                  style: AppTheme.bodyLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingXXL),
                ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Return to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: AppTheme.errorColor),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                'Something went wrong',
                style: AppTheme.titleLarge.copyWith(color: AppTheme.errorColor),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: AppTheme.spacingL),
              ElevatedButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// CA Statistics Data Model
class CAStats {
  final int totalCertificatesIssued;
  final int pendingDocuments;
  final int totalDocuments;
  final int activeUsers;

  const CAStats({
    required this.totalCertificatesIssued,
    required this.pendingDocuments,
    required this.totalDocuments,
    required this.activeUsers,
  });
}
