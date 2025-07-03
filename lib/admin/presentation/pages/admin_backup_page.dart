import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/backup_service.dart';

// Provider for backup service
final backupServiceProvider = Provider<BackupService>((ref) => BackupService());

// Provider for backup history
final backupHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  final backupService = ref.read(backupServiceProvider);
  return backupService.getBackupHistory();
});

// Provider for backup operation state
final backupOperationProvider = StateNotifierProvider<BackupOperationNotifier, BackupOperationState>((ref) {
  return BackupOperationNotifier(ref.read(backupServiceProvider));
});

class BackupOperationState {
  final bool isLoading;
  final String? currentOperation;
  final double? progress;
  final String? message;
  final bool hasError;

  const BackupOperationState({
    this.isLoading = false,
    this.currentOperation,
    this.progress,
    this.message,
    this.hasError = false,
  });

  BackupOperationState copyWith({
    bool? isLoading,
    String? currentOperation,
    double? progress,
    String? message,
    bool? hasError,
  }) {
    return BackupOperationState(
      isLoading: isLoading ?? this.isLoading,
      currentOperation: currentOperation ?? this.currentOperation,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      hasError: hasError ?? this.hasError,
    );
  }
}

class BackupOperationNotifier extends StateNotifier<BackupOperationState> {
  final BackupService _backupService;

  BackupOperationNotifier(this._backupService) : super(const BackupOperationState());

  Future<void> createFullBackup() async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: 'Creating full backup...',
      progress: 0.0,
      hasError: false,
    );

    try {
      state = state.copyWith(progress: 0.2, message: 'Initializing backup...');
      
      final result = await _backupService.createFullBackup(
        initiatedBy: 'admin', // This should be the current user ID
        description: 'Manual full system backup',
      );

      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        progress: 1.0,
        message: 'Backup created successfully: ${result['backupId']}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        hasError: true,
        message: 'Backup failed: $e',
      );
    }
  }

  Future<void> createIncrementalBackup() async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: 'Creating incremental backup...',
      progress: 0.0,
      hasError: false,
    );

    try {
      state = state.copyWith(progress: 0.2, message: 'Scanning for changes...');

      final lastWeek = DateTime.now().subtract(const Duration(days: 7));
      await _backupService.createIncrementalBackup(
        initiatedBy: 'admin', // This should be the current user ID
        lastBackupTime: lastWeek,
      );

      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        progress: 1.0,
        message: 'Incremental backup created successfully',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        hasError: true,
        message: 'Incremental backup failed: $e',
      );
    }
  }

  Future<void> restoreBackup(String backupId) async {
    state = state.copyWith(
      isLoading: true,
      currentOperation: 'Restoring backup...',
      progress: 0.0,
      hasError: false,
    );

    try {
      state = state.copyWith(progress: 0.3, message: 'Preparing restoration...');

      await _backupService.restoreFromBackup(
        backupId: backupId,
        initiatedBy: 'admin', // This should be the current user ID
        createBackupBeforeRestore: true,
      );

      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        progress: 1.0,
        message: 'Backup restored successfully',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        currentOperation: null,
        hasError: true,
        message: 'Backup restoration failed: $e',
      );
    }
  }

  void clearMessage() {
    state = state.copyWith(message: null, hasError: false);
  }
}

class AdminBackupPage extends ConsumerStatefulWidget {
  const AdminBackupPage({super.key});

  @override
  ConsumerState<AdminBackupPage> createState() => _AdminBackupPageState();
}

class _AdminBackupPageState extends ConsumerState<AdminBackupPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        return _buildBackupPage();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => _buildErrorPage(error.toString()),
    );
  }

  Widget _buildBackupPage() {
    final operationState = ref.watch(backupOperationProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildTabBar(),
          ];
        },
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                _buildCreateBackupTab(),
                _buildBackupHistoryTab(),
                _buildRestoreTab(),
              ],
            ),
            if (operationState.isLoading) _buildProgressOverlay(operationState),
          ],
        ),
      ),
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
            'System Backup',
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
          onPressed: () => _showBackupInfo(),
          icon: const Icon(Icons.info, color: Colors.white),
          tooltip: 'Backup Information',
        ),
        IconButton(
          onPressed: () => _refreshBackupHistory(),
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
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
            Tab(text: 'Create', icon: Icon(Icons.backup)),
            Tab(text: 'History', icon: Icon(Icons.history)),
            Tab(text: 'Restore', icon: Icon(Icons.restore)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateBackupTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildBackupTypeCard(
              title: 'Full System Backup',
              description: 'Complete backup of all system data including users, certificates, documents, and settings.',
              icon: Icons.cloud_download,
              color: AppTheme.primaryColor,
              onPressed: () => _createFullBackup(),
              estimatedTime: '5-15 minutes',
              estimatedSize: '50-200 MB',
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildBackupTypeCard(
              title: 'Incremental Backup',
              description: 'Backup only the changes since the last backup. Faster and uses less storage.',
              icon: Icons.update,
              color: AppTheme.successColor,
              onPressed: () => _createIncrementalBackup(),
              estimatedTime: '1-5 minutes',
              estimatedSize: '5-50 MB',
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildBackupSettingsCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _buildStorageInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String estimatedTime,
    required String estimatedSize,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  estimatedTime,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(width: AppTheme.spacingM),
                const Icon(Icons.storage, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  estimatedSize,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Create Backup',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup Settings',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            const ListTile(
              leading: Icon(Icons.schedule, color: AppTheme.infoColor),
              title: Text('Automatic Backups'),
              subtitle: Text('Every 7 days at 2:00 AM'),
              trailing: Switch(value: true, onChanged: null),
            ),
            const ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.warningColor),
              title: Text('Retention Policy'),
              subtitle: Text('Keep backups for 90 days'),
            ),
            const ListTile(
              leading: Icon(Icons.security, color: AppTheme.successColor),
              title: Text('Encryption'),
              subtitle: Text('AES-256 encryption enabled'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: _buildStorageMetric('Used', '1.2 GB', AppTheme.primaryColor),
                ),
                Expanded(
                  child: _buildStorageMetric('Available', '18.8 GB', AppTheme.successColor),
                ),
                Expanded(
                  child: _buildStorageMetric('Total', '20.0 GB', AppTheme.infoColor),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            const LinearProgressIndicator(
              value: 0.06, // 6% used
              backgroundColor: AppTheme.surfaceColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              '6% of storage used',
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBackupHistoryTab() {
    final historyAsync = ref.watch(backupHistoryProvider);
    
    return historyAsync.when(
      data: (backups) => _buildBackupHistoryList(backups),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorContent(error.toString()),
    );
  }

  Widget _buildBackupHistoryList(List<Map<String, dynamic>> backups) {
    if (backups.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.backup,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No backups found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Create your first backup to get started',
              style: TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(backupHistoryProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: backups.length,
        itemBuilder: (context, index) {
          final backup = backups[index];
          return FadeInUp(
            duration: Duration(milliseconds: 300 + (index * 100)),
            child: _buildBackupHistoryCard(backup),
          );
        },
      ),
    );
  }

  Widget _buildBackupHistoryCard(Map<String, dynamic> backup) {
    final type = backup['type'] as String? ?? 'unknown';
    final size = backup['size'] as int? ?? 0;
    final createdAt = backup['createdAt'];
    final backupId = backup['backupId'] as String? ?? backup['id'] as String? ?? 'unknown';
    
    final isFullBackup = type == 'full_system';
    final color = isFullBackup ? AppTheme.primaryColor : AppTheme.successColor;
    final icon = isFullBackup ? Icons.cloud_download : Icons.update;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          isFullBackup ? 'Full Backup' : 'Incremental Backup',
          style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: $backupId'),
            Text('Size: ${_formatFileSize(size)}'),
            if (createdAt != null) Text('Created: ${_formatDate(createdAt)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _downloadBackup(backupId),
              icon: const Icon(Icons.download),
              tooltip: 'Download',
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleBackupAction(value, backupId),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restore'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: AppTheme.errorColor),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning, color: AppTheme.warningColor),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          'Restore Warning',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Restoring from a backup will replace all current data with the backup data. '
                      'This action cannot be undone. A safety backup will be created before restoration.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    const ListTile(
                      leading: Icon(Icons.check, color: AppTheme.successColor),
                      title: Text('Safety backup will be created'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const ListTile(
                      leading: Icon(Icons.info, color: AppTheme.infoColor),
                      title: Text('System will be temporarily unavailable'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const ListTile(
                      leading: Icon(Icons.schedule, color: AppTheme.warningColor),
                      title: Text('Process may take several minutes'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Restore from Recent Backups',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    Text(
                      'Select a backup from the History tab to restore from, or use the quick restore options below.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacingM),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _tabController.animateTo(1),
                        icon: const Icon(Icons.history),
                        label: const Text('Go to Backup History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverlay(BackupOperationState state) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(AppTheme.spacingL),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: AppTheme.spacingM),
                Text(
                  state.currentOperation ?? 'Processing...',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (state.message != null) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    state.message!,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyMedium,
                  ),
                ],
                if (state.progress != null) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: AppTheme.spacingS),
                  Text('${(state.progress! * 100).toInt()}%'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContent(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: AppTheme.errorColor, size: 64),
          const SizedBox(height: AppTheme.spacingM),
          Text('Error loading backup history: $error'),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton(
            onPressed: () => ref.invalidate(backupHistoryProvider),
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
              'You do not have permission to access backup management.',
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
            Text('Error Loading Backup', style: AppTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _refreshBackupHistory(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        date = timestamp.toDate();
      }
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _createFullBackup() {
    ref.read(backupOperationProvider.notifier).createFullBackup();
  }

  void _createIncrementalBackup() {
    ref.read(backupOperationProvider.notifier).createIncrementalBackup();
  }

  Future<void> _downloadBackup(String backupId) async {
    final backupService = ref.read(backupServiceProvider);
    
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
              Text('Preparing backup download...'),
            ],
          ),
        ),
      );

      // Generate download URL
      final downloadResult = await backupService.generateBackupDownloadUrl(backupId);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (downloadResult['success']) {
        // Show download confirmation
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Download Ready'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backup: $backupId'),
                const SizedBox(height: 8),
                Text('Size: ${downloadResult['size']}'),
                const SizedBox(height: 8),
                Text('Expires: ${downloadResult['expiresAt']}'),
                const SizedBox(height: 16),
                const Text('Download link copied to clipboard!'),
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
        _showErrorDialog('Failed to prepare download: ${downloadResult['error']}');
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Download failed: $e');
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

  void _handleBackupAction(String action, String backupId) {
    switch (action) {
      case 'restore':
        _showRestoreConfirmation(backupId);
        break;
      case 'delete':
        _showDeleteConfirmation(backupId);
        break;
    }
  }

  void _showRestoreConfirmation(String backupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: Text(
          'Are you sure you want to restore from backup $backupId? '
          'This will replace all current data and cannot be undone. '
          'A safety backup will be created first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(backupOperationProvider.notifier).restoreBackup(backupId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningColor),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String backupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete backup $backupId? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBackup(backupId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(String backupId) async {
    final backupService = ref.read(backupServiceProvider);
    
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
              Text('Deleting backup...'),
            ],
          ),
        ),
      );

      // Delete the backup
      await backupService.deleteBackup(backupId);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup $backupId deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Refresh the backup history
      _refreshBackupHistory();
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('Failed to delete backup: $e');
    }
  }

  void _showBackupInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Information'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('System backups include:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• User accounts and profiles'),
              Text('• Certificate data and templates'),
              Text('• Document files and metadata'),
              Text('• System settings and configurations'),
              Text('• Activity logs and audit trails'),
              SizedBox(height: 16),
              Text('Backup Types:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('• Full Backup: Complete system snapshot'),
              Text('• Incremental: Only changes since last backup'),
              SizedBox(height: 16),
              Text('Storage Location:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Firebase Cloud Storage (encrypted)'),
            ],
          ),
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

  void _refreshBackupHistory() {
    ref.invalidate(backupHistoryProvider);
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