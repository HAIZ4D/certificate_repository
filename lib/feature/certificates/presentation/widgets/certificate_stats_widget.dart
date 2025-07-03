import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../providers/certificate_providers.dart';

class CertificateStatsWidget extends ConsumerWidget {
  const CertificateStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(certificateStatsProvider);

    return statsAsync.when(
      data: (stats) => _buildStatsContent(stats),
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(),
    );
  }

  Widget _buildStatsContent(CertificateStatistics stats) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.secondaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInLeft(
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  'Certificate Statistics',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildMainStats(stats),
          const SizedBox(height: AppTheme.spacingL),
          _buildStatusBreakdown(stats),
        ],
      ),
    );
  }

  Widget _buildMainStats(CertificateStatistics stats) {
    return Row(
      children: [
        Expanded(
          child: FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _buildStatCard(
              title: 'Total',
              value: stats.totalCertificates.toString(),
              icon: Icons.description_outlined,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildStatCard(
              title: 'Issued',
              value: stats.issuedCertificates.toString(),
              icon: Icons.check_circle_outline,
              color: AppTheme.successColor,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildStatCard(
              title: 'Pending',
              value: stats.pendingCertificates.toString(),
              icon: Icons.pending_outlined,
              color: AppTheme.warningColor,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildStatCard(
              title: 'Expired',
              value: stats.expiredCertificates.toString(),
              icon: Icons.schedule_outlined,
              color: AppTheme.errorColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: AppTheme.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            title,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(CertificateStatistics stats) {
    if (stats.certificatesByStatus.isEmpty) {
      return const SizedBox();
    }

    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status Breakdown',
            style: AppTheme.titleSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildStatusChart(stats.certificatesByStatus, stats.totalCertificates),
        ],
      ),
    );
  }

  Widget _buildStatusChart(Map<String, int> statusData, int total) {
    if (total == 0) return const SizedBox();

    return Column(
      children: statusData.entries.map((entry) {
        final status = entry.key;
        final count = entry.value;
        final percentage = (count / total * 100).round();
        final color = _getStatusColor(status);

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  _getStatusDisplayName(status),
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$count ($percentage%)',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                flex: 2,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Container(
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          Row(
            children: List.generate(4, (index) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < 3 ? AppTheme.spacingM : 0,
                ),
                child: Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: AppTheme.smallRadius,
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to load statistics',
                  style: AppTheme.titleSmall.copyWith(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Unable to fetch certificate statistics',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return AppTheme.textSecondary;
      case 'pending':
        return AppTheme.warningColor;
      case 'approved':
        return AppTheme.infoColor;
      case 'issued':
        return AppTheme.successColor;
      case 'revoked':
        return AppTheme.errorColor;
      case 'expired':
        return AppTheme.textSecondary;
      default:
        return AppTheme.primaryColor;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return 'Draft';
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'issued':
        return 'Issued';
      case 'revoked':
        return 'Revoked';
      case 'expired':
        return 'Expired';
      default:
        return status.toUpperCase();
    }
  }
} 