import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/config/app_config.dart';

class WebSafeDocumentList extends StatelessWidget {
  final String userId;
  final String searchQuery;
  final String selectedFilter;
  final Function(DocumentModel) onDocumentTap;
  final Function(DocumentModel)? onDownload;
  final Function(DocumentModel)? onShare;
  final Function(DocumentModel)? onDelete;

  const WebSafeDocumentList({
    super.key,
    required this.userId,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onDocumentTap,
    this.onDownload,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(AppConfig.documentsCollection)
          .where('uploaderId', isEqualTo: userId)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Enhanced error handling for permission issues
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          
          if (error.contains('permission-denied')) {
            return _buildPermissionDeniedState(context);
          }
          
          return _buildErrorState(error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        try {
          final documents = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DocumentModel.fromMap({
              'id': doc.id,
              ...data,
            },doc.id);
          }).toList();

          final filteredDocuments = _filterDocuments(documents);

          if (filteredDocuments.isEmpty) {
            return _buildEmptyFilteredState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              // The stream will automatically refresh
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: filteredDocuments.length,
              itemBuilder: (context, index) {
                final document = filteredDocuments[index];
                
                return WebSafeDocumentCard(
                  document: document,
                  onTap: () => onDocumentTap(document),
                  onDownload: onDownload != null ? () => onDownload!(document) : null,
                  onShare: onShare != null ? () => onShare!(document) : null,
                  onDelete: onDelete != null ? () => onDelete!(document) : null,
                );
              },
            ),
          );
        } catch (e) {
          return _buildErrorState('Failed to parse documents: $e');
        }
      },
    );
  }

  List<DocumentModel> _filterDocuments(List<DocumentModel> documents) {
    return documents.where((document) {
      // Search filter
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        if (!document.name.toLowerCase().contains(query) &&
            !document.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter
      switch (selectedFilter) {
        case 'uploaded':
          return document.status == DocumentStatus.uploaded;
        case 'verified':
          return document.status == DocumentStatus.verified;
        case 'pending':
          return document.status == DocumentStatus.pendingVerification;
        case 'rejected':
          return document.status == DocumentStatus.rejected;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No Documents Yet',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Upload your first document to get started',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'No Results Found',
            style: AppTheme.titleLarge.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Try adjusting your search or filter',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Error Loading Documents',
            style: AppTheme.titleLarge.copyWith(
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
        ],
      ),
    );
  }

  // Permission denied state widget
  Widget _buildPermissionDeniedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You don\'t have permission to view documents.\nPlease contact your administrator for access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Trigger a refresh of the parent widget
                Navigator.of(context).pushReplacementNamed('/documents');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Empty filtered state widget
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.filter_list_off,
              size: 80,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'No documents match your criteria',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Try adjusting your search or filter settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WebSafeDocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const WebSafeDocumentCard({
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
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(document.fileSize),
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.infoColor.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                            child: Text(
                              'Web Compatible',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.infoColor,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
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
                    style: AppTheme.bodySmall.copyWith(
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
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              if (_hasActions()) ...[
                const SizedBox(height: AppTheme.spacingM),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onDownload != null)
                      TextButton.icon(
                        onPressed: () => _safeDownload(),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text(kIsWeb ? 'Open' : 'Download'),
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

  bool _hasActions() {
    return onDownload != null || onShare != null || onDelete != null;
  }

  void _safeDownload() {
    if (kIsWeb) {
      // For web, convert URL to be CORS-safe
      // Use a safe method to open the document
      onDownload?.call();
    } else {
      // For mobile, normal download
      onDownload?.call();
    }
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
        borderRadius: const BorderRadius.all(Radius.circular(8)),
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
        statusText = 'Pending';
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
        backgroundColor = AppTheme.primaryColor;
        textColor = Colors.white;
        statusText = 'Uploaded';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        statusText,
        style: AppTheme.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 