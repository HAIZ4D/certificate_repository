import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onDownload,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildDocumentIcon(),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(document.fileSize),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    document.uploaderName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(document.uploadedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (onDownload != null || onShare != null || onDelete != null) ...[
                const SizedBox(height: AppTheme.spacingM),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDownload != null)
                      TextButton.icon(
                        onPressed: onDownload,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Download'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                    if (onShare != null)
                      TextButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.infoColor,
                        ),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
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

  Widget _buildDocumentIcon() {
    IconData iconData;
    Color iconColor;

    switch (document.type) {
      case DocumentType.certificate:
        iconData = Icons.verified;
        iconColor = AppTheme.primaryColor;
        break;
      case DocumentType.diploma:
        iconData = Icons.school;
        iconColor = AppTheme.successColor;
        break;
      case DocumentType.transcript:
        iconData = Icons.description;
        iconColor = AppTheme.infoColor;
        break;
      case DocumentType.license:
        iconData = Icons.card_membership;
        iconColor = AppTheme.warningColor;
        break;
      case DocumentType.identification:
        iconData = Icons.badge;
        iconColor = AppTheme.warningColor;
        break;
      case DocumentType.other:
        iconData = Icons.insert_drive_file;
        iconColor = AppTheme.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (document.status) {
      case DocumentStatus.verified:
        backgroundColor = AppTheme.successColor;
        textColor = Colors.white;
        statusText = 'Verified';
        break;
      case DocumentStatus.pending:
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.white;
        statusText = 'Pending';
        break;
      case DocumentStatus.processing:
        backgroundColor = AppTheme.infoColor;
        textColor = Colors.white;
        statusText = 'Processing';
        break;
      case DocumentStatus.pendingVerification:
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.white;
        statusText = 'Pending Verification';
        break;
      case DocumentStatus.rejected:
        backgroundColor = AppTheme.errorColor;
        textColor = Colors.white;
        statusText = 'Rejected';
        break;
      case DocumentStatus.expired:
        backgroundColor = AppTheme.textSecondary;
        textColor = Colors.white;
        statusText = 'Expired';
        break;
      case DocumentStatus.uploaded:
        backgroundColor = AppTheme.surfaceColor;
        textColor = AppTheme.textPrimary;
        statusText = 'Uploaded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(date);
    }
  }
} 