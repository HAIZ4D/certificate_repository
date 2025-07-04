import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';

/// RecentActivityCard
///
/// Displays a list preview of the most recent user actions, helping users
/// quickly recall what they have done inside the application. Falls back to an
/// informative empty state when no activities are available.
class RecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final int maxItems;
  final VoidCallback? onViewAll;

  const RecentActivityCard({
    super.key,
    required this.activities,
    this.maxItems = 5,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayActivities = activities.take(maxItems).toList();
    
    return Container(
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: AppTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'View All',
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Activity List
          if (displayActivities.isEmpty)
            _buildEmptyState()
          else
            Column(
              children: displayActivities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                return FadeInUp(
                  duration: Duration(milliseconds: 300 + (index * 100)),
                  child: ActivityItem(
                    activity: activity,
                    isLast: index == displayActivities.length - 1,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent actions will appear here',
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isLast;

  const ActivityItem({
    super.key,
    required this.activity,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = activity['title'] as String? ?? 'Unknown Activity';
    final subtitle = activity['subtitle'] as String? ?? '';
    final time = activity['time'] as String? ?? '';
    final icon = activity['icon'] as IconData? ?? Icons.circle;
    final color = activity['color'] as Color? ?? AppTheme.primaryColor;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: AppTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Compact version for smaller spaces
class CompactRecentActivityCard extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  final int maxItems;

  const CompactRecentActivityCard({
    super.key,
    required this.activities,
    this.maxItems = 3,
  });

  @override
  Widget build(BuildContext context) {
    final displayActivities = activities.take(maxItems).toList();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: AppTheme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          
          const SizedBox(height: 12),
          
          if (displayActivities.isEmpty)
            Text(
              'No recent activity',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            )
          else
            Column(
              children: displayActivities.map((activity) {
                return CompactActivityItem(activity: activity);
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class CompactActivityItem extends StatelessWidget {
  final Map<String, dynamic> activity;

  const CompactActivityItem({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final title = activity['title'] as String? ?? 'Unknown Activity';
    final time = activity['time'] as String? ?? '';
    final icon = activity['icon'] as IconData? ?? Icons.circle;
    final color = activity['color'] as Color? ?? AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 14,
            ),
          ),
          
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: AppTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Activity types for consistent styling
class ActivityType {
  static const Map<String, dynamic> certificateIssued = {
    'icon': Icons.verified,
    'color': AppTheme.successColor,
  };
  
  static const Map<String, dynamic> documentUploaded = {
    'icon': Icons.upload_file,
    'color': AppTheme.infoColor,
  };
  
  static const Map<String, dynamic> profileUpdated = {
    'icon': Icons.person,
    'color': AppTheme.primaryColor,
  };
  
  static const Map<String, dynamic> certificateRevoked = {
    'icon': Icons.cancel,
    'color': AppTheme.errorColor,
  };
  
  static const Map<String, dynamic> documentVerified = {
    'icon': Icons.verified_user,
    'color': AppTheme.successColor,
  };
  
  static const Map<String, dynamic> loginActivity = {
    'icon': Icons.login,
    'color': AppTheme.infoColor,
  };
  
  static const Map<String, dynamic> settingsChanged = {
    'icon': Icons.settings,
    'color': AppTheme.warningColor,
  };
  
  static const Map<String, dynamic> shareActivity = {
    'icon': Icons.share,
    'color': AppTheme.accentColor,
  };
}

// Helper function to create activity items
Map<String, dynamic> createActivity({
  required String title,
  required String subtitle,
  required String time,
  required String type,
}) {
  Map<String, dynamic> typeData;
  
  switch (type.toLowerCase()) {
    case 'certificate_issued':
      typeData = ActivityType.certificateIssued;
      break;
    case 'document_uploaded':
      typeData = ActivityType.documentUploaded;
      break;
    case 'profile_updated':
      typeData = ActivityType.profileUpdated;
      break;
    case 'certificate_revoked':
      typeData = ActivityType.certificateRevoked;
      break;
    case 'document_verified':
      typeData = ActivityType.documentVerified;
      break;
    case 'login':
      typeData = ActivityType.loginActivity;
      break;
    case 'settings':
      typeData = ActivityType.settingsChanged;
      break;
    case 'share':
      typeData = ActivityType.shareActivity;
      break;
    default:
      typeData = {
        'icon': Icons.circle,
        'color': AppTheme.primaryColor,
      };
  }
  
  return {
    'title': title,
    'subtitle': subtitle,
    'time': time,
    'icon': typeData['icon'],
    'color': typeData['color'],
    'type': type,
  };
} 
