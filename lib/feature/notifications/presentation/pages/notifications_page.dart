import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  String _selectedFilter = 'all'; // all, unread, read
  final ScrollController _scrollController = ScrollController();

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
    _loadNotifications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Listen to notifications stream
      _notificationService.getUserNotifications(currentUser.id).listen(
        (notifications) {
          if (mounted) {
            setState(() {
              _notifications = notifications;
              _isLoading = false;
            });
          }
        },
        onError: (error) {
          LoggerService.error('Failed to load notifications', error: error);
          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to load notifications: $error';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      LoggerService.error('Error setting up notifications stream', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<NotificationModel> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'read':
        return _notifications.where((n) => n.isRead).toList();
      default:
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: _buildBody(),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notifications'),
          if (unreadCount > 0)
            Text(
              '$unreadCount unread',
              style: AppTheme.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  Icon(Icons.mark_email_read, size: 20),
                  SizedBox(width: 8),
                  Text('Mark all as read'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete_read',
              child: Row(
                children: [
                  Icon(Icons.delete_sweep, size: 20),
                  SizedBox(width: 8),
                  Text('Delete read notifications'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingM),
            Text('Loading notifications...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Failed to load notifications',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: _notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${_notifications.length})'),
                  const SizedBox(width: AppTheme.spacingS),
                  _buildFilterChip('unread', 'Unread (${_notifications.where((n) => !n.isRead).length})'),
                  const SizedBox(width: AppTheme.spacingS),
                  _buildFilterChip('read', 'Read (${_notifications.where((n) => n.isRead).length})'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: AppTheme.smallRadius,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isSelected ? Colors.white : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeInUp(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No notifications yet',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'You\'ll see notifications about certificates,\ndocuments, and system updates here.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    final filteredNotifications = _filteredNotifications;
    
    if (filteredNotifications.isEmpty) {
      return Center(
        child: FadeInUp(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _selectedFilter == 'unread' 
                    ? Icons.mark_email_read_outlined
                    : Icons.notifications_off_outlined,
                size: 96,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                _selectedFilter == 'unread' 
                    ? 'All caught up!'
                    : 'No $_selectedFilter notifications',
                style: AppTheme.titleLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                _selectedFilter == 'unread' 
                    ? 'You\'ve read all your notifications.'
                    : 'Try switching to a different filter.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = filteredNotifications[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 100),
            child: _buildNotificationItem(notification, index),
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: notification.isRead 
            ? AppTheme.surfaceColor 
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: notification.isRead 
              ? AppTheme.dividerColor.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.3),
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: AppTheme.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationIconColor(notification.type).withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationIconColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and timestamp
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTheme.titleSmall.copyWith(
                              fontWeight: notification.isRead 
                                  ? FontWeight.normal 
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingS),
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    
                    // Body
                    Text(
                      notification.body,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // Action buttons
                    const SizedBox(height: AppTheme.spacingS),
                    Row(
                      children: [
                        if (!notification.isRead)
                          TextButton.icon(
                            onPressed: () => _markAsRead(notification),
                            icon: const Icon(Icons.mark_email_read, size: 16),
                            label: const Text('Mark as read'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => _deleteNotification(notification),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          tooltip: 'Delete notification',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: AppTheme.spacingS, top: 4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'certificate':
        return Icons.verified_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'system':
        return Icons.settings_outlined;
      case 'security':
        return Icons.security_outlined;
      case 'reminder':
        return Icons.schedule_outlined;
      case 'achievement':
        return Icons.emoji_events_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'certificate':
        return AppTheme.successColor;
      case 'document':
        return AppTheme.infoColor;
      case 'system':
        return AppTheme.warningColor;
      case 'security':
        return AppTheme.errorColor;
      case 'reminder':
        return AppTheme.primaryColor;
      case 'achievement':
        return Colors.orange;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'mark_all_read':
        await _markAllAsRead();
        break;
      case 'delete_read':
        await _deleteReadNotifications();
        break;
      case 'refresh':
        await _loadNotifications();
        break;
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    try {
      await _notificationService.markAsRead(notification.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification marked as read'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to mark notification as read', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final unreadNotifications = _notifications.where((n) => !n.isRead);
      
      await Future.wait(
        unreadNotifications.map((n) => _notificationService.markAsRead(n.id)),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${unreadNotifications.length} notifications as read'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to mark all as read', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notification.id)
          .delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to delete notification', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notification: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteReadNotifications() async {
    final readNotifications = _notifications.where((n) => n.isRead).toList();
    
    if (readNotifications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No read notifications to delete'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Read Notifications'),
        content: Text('Are you sure you want to delete ${readNotifications.length} read notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      for (final notification in readNotifications) {
        batch.delete(
          FirebaseFirestore.instance.collection('notifications').doc(notification.id),
        );
      }
      
      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${readNotifications.length} read notifications'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to delete read notifications', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notifications: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read if unread
    if (!notification.isRead) {
      _markAsRead(notification);
    }

    // Handle navigation based on notification data
    final data = notification.data;
    if (data.isNotEmpty) {
      // Navigate to relevant page based on notification data
      // This can be expanded based on your app's navigation structure
      LoggerService.info('Notification tapped: ${notification.title}');
    }
  }
} 