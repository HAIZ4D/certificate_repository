import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';

class CertificateCard extends StatelessWidget {
  final CertificateModel certificate;
  final VoidCallback? onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDownload;
  final VoidCallback? onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onRevoke;
  final bool showActions;

  const CertificateCard({
    super.key,
    required this.certificate,
    this.onTap,
    this.onShare,
    this.onDownload,
    this.onEdit,
    this.onApprove,
    this.onRevoke,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.mediumRadius,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: AppTheme.backgroundLight,
            borderRadius: AppTheme.mediumRadius,
            border: Border.all(
              color: _getStatusBorderColor().withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppTheme.spacingM),
              _buildContent(),
              const SizedBox(height: AppTheme.spacingM),
              _buildMetadata(),
              if (_shouldShowWarning()) ...[
                const SizedBox(height: AppTheme.spacingS),
                _buildWarningBanner(),
              ],
              if (showActions && _hasActions()) ...[
                const SizedBox(height: AppTheme.spacingM),
                _buildActions(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: _getTypeColor().withValues(alpha: 0.1),
            borderRadius: AppTheme.smallRadius,
          ),
          child: Icon(
            _getTypeIcon(),
            color: _getTypeColor(),
            size: 24,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                certificate.title,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                certificate.typeDisplayName,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Prevent overflow
      children: [
        Text(
          certificate.description,
          style: AppTheme.bodyMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (certificate.courseName.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingS),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Text(
              'Course: ${certificate.courseName}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (certificate.grade.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            mainAxisSize: MainAxisSize.min, // Prevent overflow
            children: [
              const Icon(
                Icons.grade,
                size: 16,
                color: AppTheme.successColor,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Flexible( // Wrap grade text in Flexible
                child: Text(
                  'Grade: ${certificate.grade}',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetadata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Prevent overflow
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Expanded(
              child: Text(
                certificate.recipientName,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.spacingXS),
            Flexible( // Wrap date in Flexible
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacingXS),
                  Text(
                    _formatDate(certificate.issuedAt),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (certificate.organizationName.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.business_outlined,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                flex: 3, // Give more space to organization name
                child: Text(
                  certificate.organizationName,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (certificate.isVerified) ...[
                const SizedBox(width: AppTheme.spacingXS),
                Flexible( // Wrap verified badge in Flexible
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified,
                          size: 12,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Verified',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.successColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip() {
    final color = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        certificate.statusDisplayName.toUpperCase(),
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildWarningBanner() {
    String message;
    Color color;
    IconData icon;

    if (certificate.isExpired) {
      message = 'Certificate has expired';
      color = AppTheme.errorColor;
      icon = Icons.error_outline;
    } else if (certificate.isRevoked) {
      message = 'Certificate has been revoked';
      color = AppTheme.errorColor;
      icon = Icons.block;
    } else if (certificate.expiresAt != null && certificate.isNearExpiry) {
      message = 'Expires on ${_formatDate(certificate.expiresAt!)}';
      color = AppTheme.warningColor;
      icon = Icons.warning_outlined;
    } else {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final actions = <Widget>[];

    if (onShare != null) {
      actions.add(
        _buildActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          color: AppTheme.primaryColor,
          onPressed: onShare!,
        ),
      );
    }

    if (onDownload != null) {
      actions.add(
        _buildActionButton(
          icon: Icons.download_outlined,
          label: 'Download',
          color: AppTheme.successColor,
          onPressed: onDownload!,
        ),
      );
    }

    if (onEdit != null) {
      actions.add(
        _buildActionButton(
          icon: Icons.edit_outlined,
          label: 'Edit',
          color: AppTheme.infoColor,
          onPressed: onEdit!,
        ),
      );
    }

    if (onApprove != null) {
      actions.add(
        _buildActionButton(
          icon: Icons.check_circle_outline,
          label: 'Approve',
          color: AppTheme.successColor,
          onPressed: onApprove!,
        ),
      );
    }

    if (onRevoke != null) {
      actions.add(
        _buildActionButton(
          icon: Icons.block_outlined,
          label: 'Revoke',
          color: AppTheme.errorColor,
          onPressed: onRevoke!,
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox();

    return Wrap(
      spacing: AppTheme.spacingS,
      runSpacing: AppTheme.spacingXS,
      children: actions,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingS,
          vertical: AppTheme.spacingXS,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  // Helper methods
  Color _getStatusColor() {
    switch (certificate.status) {
      case CertificateStatus.draft:
        return AppTheme.textSecondary;
      case CertificateStatus.pending:
        return AppTheme.warningColor;
      case CertificateStatus.approved:
        return AppTheme.infoColor;
      case CertificateStatus.issued:
        return AppTheme.successColor;
      case CertificateStatus.revoked:
        return AppTheme.errorColor;
      case CertificateStatus.expired:
        return AppTheme.textSecondary;
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getStatusBorderColor() {
    if (certificate.isExpired || certificate.isRevoked) {
      return AppTheme.errorColor;
    }
    return _getStatusColor();
  }

  Color _getTypeColor() {
    switch (certificate.type) {
      case CertificateType.academic:
        return AppTheme.primaryColor;
      case CertificateType.professional:
        return AppTheme.successColor;
      case CertificateType.achievement:
        return AppTheme.warningColor;
      case CertificateType.completion:
        return AppTheme.infoColor;
      case CertificateType.participation:
        return AppTheme.textSecondary;
      case CertificateType.recognition:
        return Colors.purple;
      case CertificateType.custom:
        return AppTheme.textSecondary;
    }
  }

  IconData _getTypeIcon() {
    switch (certificate.type) {
      case CertificateType.academic:
        return Icons.school_outlined;
      case CertificateType.professional:
        return Icons.work_outline;
      case CertificateType.achievement:
        return Icons.emoji_events_outlined;
      case CertificateType.completion:
        return Icons.task_alt_outlined;
      case CertificateType.participation:
        return Icons.group_outlined;
      case CertificateType.recognition:
        return Icons.star_outline;
      case CertificateType.custom:
        return Icons.description_outlined;
    }
  }

  bool _shouldShowWarning() {
    return certificate.isExpired ||
           certificate.isRevoked ||
           (certificate.expiresAt != null && certificate.isNearExpiry);
  }

  bool _hasActions() {
    return onShare != null ||
           onDownload != null ||
           onEdit != null ||
           onApprove != null ||
           onRevoke != null;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 