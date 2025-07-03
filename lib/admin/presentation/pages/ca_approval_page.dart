import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/admin_service.dart';

// Provider for admin service
final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

// Provider for CA applications stream
final caApplicationsProvider = StreamProvider.family<List<UserModel>, CAApplicationsFilter>(
  (ref, filter) {
    final adminService = ref.read(adminServiceProvider);
    return adminService.getCAApplicationsStream(
      status: filter.status,
      searchQuery: filter.searchQuery,
      sortBy: filter.sortBy,
      descending: filter.descending,
    );
  },
);

// Provider for selected CA application details
final selectedCAProvider = StateProvider<UserModel?>((ref) => null);

// Data class for filtering CA applications
class CAApplicationsFilter {
  final UserStatus? status;
  final String? searchQuery;
  final String sortBy;
  final bool descending;

  const CAApplicationsFilter({
    this.status,
    this.searchQuery,
    this.sortBy = 'createdAt',
    this.descending = true,
  });

  CAApplicationsFilter copyWith({
    UserStatus? status,
    String? searchQuery,
    String? sortBy,
    bool? descending,
  }) {
    return CAApplicationsFilter(
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      descending: descending ?? this.descending,
    );
  }
}

final caFilterProvider = StateProvider<CAApplicationsFilter>((ref) => const CAApplicationsFilter());

class CAApprovalPage extends ConsumerStatefulWidget {
  const CAApprovalPage({super.key});

  @override
  ConsumerState<CAApprovalPage> createState() => _CAApprovalPageState();
}

class _CAApprovalPageState extends ConsumerState<CAApprovalPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  
  bool _isProcessing = false;
  final Set<String> _selectedCAs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final currentFilter = ref.read(caFilterProvider);
    ref.read(caFilterProvider.notifier).state = currentFilter.copyWith(
      searchQuery: _searchController.text.isEmpty ? null : _searchController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null || user.userType != UserType.admin || !user.isActive) {
          return _buildUnauthorizedPage();
        }
        return _buildApprovalPage();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildApprovalPage() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildSearchAndFilters(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildApplicationsList(null), // All applications
            _buildApplicationsList(UserStatus.pending), // Pending
            _buildApplicationsList(UserStatus.active), // Approved
            _buildApplicationsList(UserStatus.suspended), // Rejected
          ],
        ),
      ),
      floatingActionButton: _buildQuickStatsButton(),
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
            'CA Registration Approvals',
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
          onPressed: _exportApplicationsList,
          icon: const Icon(Icons.download, color: Colors.white),
          tooltip: 'Export Applications',
        ),
        IconButton(
          onPressed: () => _showBulkActions(),
          icon: const Icon(Icons.checklist, color: Colors.white),
          tooltip: 'Bulk Actions',
        ),
          IconButton(
            onPressed: () {
            ref.invalidate(caApplicationsProvider);
          },
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
        ),
        const SizedBox(width: AppTheme.spacingS),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppTheme.primaryColor,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FadeInUp(
          child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
              borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
            child: Row(
        children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
              hintText: 'Search CA applications...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort Options',
                  onSelected: _onSortSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'createdAt_desc',
                      child: Text('Newest First'),
                    ),
                    const PopupMenuItem(
                      value: 'createdAt_asc',
                      child: Text('Oldest First'),
                    ),
                    const PopupMenuItem(
                      value: 'displayName_asc',
                      child: Text('Name A-Z'),
                    ),
                    const PopupMenuItem(
                      value: 'displayName_desc',
                      child: Text('Name Z-A'),
                    ),
                    const PopupMenuItem(
                      value: 'organizationName_asc',
                      child: Text('Organization A-Z'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
          tabs: [
            const Tab(
              text: 'All',
              icon: Icon(Icons.list),
            ),
            Tab(
              text: 'Pending',
              icon: Stack(
                        children: [
                  const Icon(Icons.pending_actions),
                  _buildTabBadge(UserStatus.pending),
                        ],
                      ),
                    ),
            const Tab(
              text: 'Approved',
              icon: Icon(Icons.verified),
            ),
            const Tab(
              text: 'Rejected',
              icon: Icon(Icons.block),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBadge(UserStatus status) {
    return Consumer(
      builder: (context, ref, child) {
        final filter = CAApplicationsFilter(status: status);
        final applicationsAsync = ref.watch(caApplicationsProvider(filter));
        
        return applicationsAsync.when(
          data: (applications) {
            final count = applications.length;
            if (count == 0) return const SizedBox();
            
            return Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
          loading: () => const SizedBox(),
          error: (error, stack) => const SizedBox(),
        );
      },
    );
  }

  Widget _buildApplicationsList(UserStatus? filterStatus) {
    return Consumer(
      builder: (context, ref, child) {
        final currentFilter = ref.watch(caFilterProvider);
        final filter = currentFilter.copyWith(status: filterStatus);
        final applicationsAsync = ref.watch(caApplicationsProvider(filter));
        
        return applicationsAsync.when(
          data: (applications) => _buildApplicationsContent(applications),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorContent(error.toString()),
        );
      },
    );
  }

  Widget _buildApplicationsContent(List<UserModel> applications) {
    if (applications.isEmpty) {
          return _buildEmptyState();
        }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(caApplicationsProvider);
      },
      child: ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: applications.length,
          itemBuilder: (context, index) {
          final application = applications[index];
            return FadeInUp(
            delay: Duration(milliseconds: index * 50),
              child: _buildApplicationCard(application),
            );
          },
      ),
    );
  }

  Widget _buildApplicationCard(UserModel application) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      elevation: 2,
      child: InkWell(
        onTap: () => _showApplicationDetails(application),
        borderRadius: AppTheme.mediumRadius,
      child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: _getStatusColor(application.status).withValues(alpha: 0.1),
                  backgroundImage: application.photoURL != null 
                      ? NetworkImage(application.photoURL!) 
                      : null,
                  child: application.photoURL == null 
                      ? Text(
                            application.displayName.isNotEmpty 
                                ? application.displayName[0].toUpperCase()
                                : 'CA',
                            style: TextStyle(
                              color: _getStatusColor(application.status),
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
                        application.displayName,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                        if (application.organizationName != null) ...[
                      Text(
                            application.organizationName!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                        Text(
                          application.email,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
                  ),
                  _buildStatusBadge(application.status),
                ],
              ),
            const SizedBox(height: AppTheme.spacingM),
              if (application.businessLicense != null || 
                  application.description != null) ...[
                const Divider(),
                const SizedBox(height: AppTheme.spacingS),
                if (application.description != null) ...[
                  Text(
                    'Description:',
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    application.description!,
                    style: AppTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                ],
                if (application.businessLicense != null) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.business,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Business License: ${application.businessLicense}',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
                ],
              ],
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Applied ${_formatTimeAgo(application.createdAt)}',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (application.status == UserStatus.pending) ...[
                    TextButton.icon(
                      onPressed: _isProcessing 
                          ? null 
                          : () => _showRejectDialog(application),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    ElevatedButton.icon(
                      onPressed: _isProcessing 
                          ? null 
                          : () => _showApproveDialog(application),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatusBadge(UserStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case UserStatus.pending:
        color = AppTheme.warningColor;
        text = 'Pending';
        icon = Icons.pending;
        break;
      case UserStatus.active:
        color = AppTheme.successColor;
        text = 'Approved';
        icon = Icons.verified;
        break;
      case UserStatus.suspended:
        color = AppTheme.errorColor;
        text = 'Rejected';
        icon = Icons.block;
        break;
      default:
        color = AppTheme.textSecondary;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.business_center,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No CA applications found',
            style: AppTheme.titleMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No CA applications found. '
            'Applications will appear here when users register as Certificate Authorities.',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildErrorContent(String error) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const Icon(
            Icons.error,
            size: 80,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppTheme.spacingM),
            Text(
            'Error loading applications',
            style: AppTheme.titleMedium.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            error,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
              const SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: () => ref.invalidate(caApplicationsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsButton() {
    return FloatingActionButton.extended(
      onPressed: _showQuickStats,
      backgroundColor: AppTheme.primaryColor,
      icon: const Icon(Icons.analytics),
      label: const Text('Stats'),
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
              'You do not have permission to access CA approvals.',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
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
            const Icon(
              Icons.error,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Page',
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
              onPressed: () {
                ref.invalidate(caApplicationsProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.pending:
        return AppTheme.warningColor;
      case UserStatus.active:
        return AppTheme.successColor;
      case UserStatus.suspended:
        return AppTheme.errorColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  void _onSortSelected(String sortOption) {
    final parts = sortOption.split('_');
    final sortBy = parts[0];
    final descending = parts[1] == 'desc';

    final currentFilter = ref.read(caFilterProvider);
    ref.read(caFilterProvider.notifier).state = currentFilter.copyWith(
      sortBy: sortBy,
      descending: descending,
    );
  }

  void _showApplicationDetails(UserModel application) {
    ref.read(selectedCAProvider.notifier).state = application;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: _getStatusColor(application.status).withValues(alpha: 0.1),
                    backgroundImage: application.photoURL != null 
                        ? NetworkImage(application.photoURL!)
                        : null,
                    child: application.photoURL == null
                        ? Text(
                            application.displayName.isNotEmpty 
                                ? application.displayName[0].toUpperCase()
                                : 'CA',
                            style: TextStyle(
                              color: _getStatusColor(application.status),
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
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
                          application.displayName,
                          style: AppTheme.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (application.organizationName != null) ...[
                          Text(
                            application.organizationName!,
                            style: AppTheme.titleMedium.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        Text(
                          application.email,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(application.status),
                  const SizedBox(width: AppTheme.spacingS),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: AppTheme.spacingL * 2),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Contact Information', [
                        _buildDetailRow('Email', application.email),
                        if (application.phoneNumber != null)
                          _buildDetailRow('Phone', application.phoneNumber!),
                        if (application.address != null)
                          _buildDetailRow('Address', application.address!),
                      ]),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildDetailSection('Organization Details', [
                        if (application.organizationName != null)
                          _buildDetailRow('Organization', application.organizationName!),
                        if (application.businessLicense != null)
                          _buildDetailRow('Business License', application.businessLicense!),
                        if (application.description != null)
                          _buildDetailRow('Description', application.description!),
                      ]),
                      const SizedBox(height: AppTheme.spacingL),
                      _buildDetailSection('Application Timeline', [
                        _buildDetailRow('Applied', _formatDateTime(application.createdAt)),
                        _buildDetailRow('Last Updated', _formatDateTime(application.updatedAt)),
                        _buildDetailRow('Current Status', application.status.displayName),
                      ]),
                      if (application.status != UserStatus.pending) ...[
                        const SizedBox(height: AppTheme.spacingL),
                        _buildDetailSection('Decision Details', [
                          // Add approval/rejection details here when available
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
              if (application.status == UserStatus.pending) ...[
                const Divider(height: AppTheme.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing 
                            ? null 
                            : () {
                                Navigator.of(context).pop();
                                _showRejectDialog(application);
                              },
                        icon: const Icon(Icons.close),
                        label: const Text('Reject Application'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing 
                            ? null 
                            : () {
                                Navigator.of(context).pop();
                                _showApproveDialog(application);
                              },
                        icon: const Icon(Icons.check),
                        label: const Text('Approve Application'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showApproveDialog(UserModel application) {
    final commentsController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor),
            SizedBox(width: 8),
            Text('Approve CA Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to approve the CA application for:',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.displayName,
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (application.organizationName != null)
                    Text(application.organizationName!),
                  Text(application.email),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: commentsController,
              decoration: const InputDecoration(
                labelText: 'Approval Comments (Optional)',
                hintText: 'Add any comments about the approval...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessing 
                ? null 
                : () => _approveApplication(
                    application, 
                    commentsController.text,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(UserModel application) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Reject CA Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to reject the CA application for:',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.displayName,
                    style: AppTheme.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (application.organizationName != null)
                    Text(application.organizationName!),
                  Text(application.email),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'Please provide a reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isProcessing || reasonController.text.trim().isEmpty
                ? null 
                : () => _rejectApplication(
                    application, 
                    reasonController.text.trim(),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: _isProcessing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveApplication(UserModel application, String comments) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final adminService = ref.read(adminServiceProvider);
      final success = await adminService.approveCAApplication(
        application.id,
        comments.isEmpty ? 'Application approved' : comments,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully approved ${application.displayName}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
          
          // Refresh the applications list
          ref.invalidate(caApplicationsProvider);
        } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to approve application. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving application: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
      setState(() {
          _isProcessing = false;
      });
      }
    }
  }

  Future<void> _rejectApplication(UserModel application, String reason) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final adminService = ref.read(adminServiceProvider);
      final success = await adminService.rejectCAApplication(
        application.id,
        reason,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        
        if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully rejected ${application.displayName}'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
          
          // Refresh the applications list
          ref.invalidate(caApplicationsProvider);
        } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reject application. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting application: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
      setState(() {
          _isProcessing = false;
      });
      }
    }
  }

  void _showQuickStats() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
          mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              'CA Applications Statistics',
                      style: AppTheme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            const SizedBox(height: AppTheme.spacingL),
            // Add statistics display here
            const Text('Statistics will be displayed here'),
          ],
        ),
      ),
    );
  }

  void _showBulkActions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
          mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
              'Bulk Actions',
                                  style: AppTheme.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      const SizedBox(height: AppTheme.spacingL),
            // Add bulk actions here
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectedCAs.isEmpty ? null : _bulkApprove,
                  icon: const Icon(Icons.check),
                  label: Text('Approve Selected (${_selectedCAs.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                ElevatedButton.icon(
                  onPressed: _selectedCAs.isEmpty ? null : _bulkReject,
                  icon: const Icon(Icons.close),
                  label: Text('Reject Selected (${_selectedCAs.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportApplicationsList() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating CA applications export...'),
            ],
          ),
        ),
      );

      // Use existing export functionality
      // final exportService = CSVExportService();
      
      // Get all CA applications data from different filter states
      const pendingFilter = CAApplicationsFilter(status: UserStatus.pending);
      const approvedFilter = CAApplicationsFilter(status: UserStatus.active);
      const rejectedFilter = CAApplicationsFilter(status: UserStatus.suspended);
      
      final pendingCAs = ref.read(caApplicationsProvider(pendingFilter)).value ?? [];
      final approvedCAs = ref.read(caApplicationsProvider(approvedFilter)).value ?? [];
      final rejectedCAs = ref.read(caApplicationsProvider(rejectedFilter)).value ?? [];
      
      // Combine all CA applications
      final allCAs = [...pendingCAs, ...approvedCAs, ...rejectedCAs];
      
      // Generate CSV data
      final csvData = _generateCAListCSV(allCAs);
      
      // Actual file export
      final result = await ref.read(reportExportServiceProvider).exportCSV(
        data: csvData,
        filename: 'ca_applications_${DateTime.now().millisecondsSinceEpoch}.csv',
        headers: [
          'ID', 'Organization', 'Email', 'Phone', 'Status', 'Submitted', 
          'Reviewed', 'Reviewer', 'Rejection Reason', 'Type', 'Website', 
          'Registration', 'Country', 'Documents'
        ],
      );
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (result['success'] == true) {
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Complete'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${result['filename']}'),
                const SizedBox(height: 8),
                Text('Records: ${allCAs.length}'),
                const SizedBox(height: 8),
                Text('Size: ${result['size']}'),
                const SizedBox(height: 16),
                const Text('The file has been saved to your downloads folder.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _showErrorDialog('Export failed: ${result['error']}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Export failed: $e');
    }
  }

  List<List<String>> _generateCAListCSV(List<dynamic> caApplications) {
    final List<List<String>> csvData = [];
    
    for (final ca in caApplications) {
      csvData.add([
        ca['id']?.toString() ?? '',
        ca['organizationName']?.toString() ?? '',
        ca['contactEmail']?.toString() ?? '',
        ca['contactPhone']?.toString() ?? '',
        ca['status']?.toString() ?? '',
        _formatExportDate(ca['submittedAt']),
        _formatExportDate(ca['reviewedAt']),
        ca['reviewedBy']?.toString() ?? '',
        ca['rejectionReason']?.toString() ?? '',
        ca['organizationType']?.toString() ?? '',
        ca['website']?.toString() ?? '',
        ca['registrationNumber']?.toString() ?? '',
        ca['country']?.toString() ?? '',
        (ca['documents'] as List?)?.length.toString() ?? '0',
      ]);
    }
    
    return csvData;
  }

  String _formatExportDate(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkApprove() async {
    if (_selectedCAs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Approval'),
        content: Text('Are you sure you want to approve ${_selectedCAs.length} CA applications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isProcessing = true);
        
        for (final caId in _selectedCAs) {
          await ref.read(adminServiceProvider).approveCAApplication(caId);
        }
        
        setState(() => _selectedCAs.clear());
        ref.invalidate(caApplicationsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully approved ${_selectedCAs.length} CA applications'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        LoggerService.error('Bulk approval failed', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bulk approval failed: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _bulkReject() async {
    if (_selectedCAs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Rejection'),
        content: Text('Are you sure you want to reject ${_selectedCAs.length} CA applications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Reject All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isProcessing = true);
        
        for (final caId in _selectedCAs) {
          await ref.read(adminServiceProvider).rejectCAApplication(caId, 'Bulk rejection by admin');
        }
        
        setState(() => _selectedCAs.clear());
        ref.invalidate(caApplicationsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully rejected ${_selectedCAs.length} CA applications'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      } catch (e) {
        LoggerService.error('Bulk rejection failed', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bulk rejection failed: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
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
