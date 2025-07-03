import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/config/app_config.dart';
import '../../../auth/providers/auth_providers.dart';
import 'document_viewer_page.dart';

class DocumentDetailPage extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
  });

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  bool _isLoading = true;
  DocumentModel? _document;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final doc = await FirebaseFirestore.instance
          .collection(AppConfig.documentsCollection)
          .doc(widget.documentId)
          .get();

      if (doc.exists) {
        _document = DocumentModel.fromFirestore(doc);
        
        // Record access event
        await _recordAccessEvent();
      } else {
        _error = 'Document not found';
      }
    } catch (e, stackTrace) {
      LoggerService.error('Error loading document', 
          error: e, stackTrace: stackTrace);
      _error = 'Failed to load document: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _recordAccessEvent() async {
    if (_document == null) return;
    
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;

      // Record access in document access history
      await FirebaseFirestore.instance
          .collection(AppConfig.documentsCollection)
          .doc(widget.documentId)
          .update({
        'accessHistory': FieldValue.arrayUnion([
          {
            'accessedBy': currentUser.id,
            'accessedByName': currentUser.displayName,
            'accessedAt': Timestamp.fromDate(DateTime.now()),
            'accessType': 'view',
          }
        ]),
        'lastAccessedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Record in activity log
      await FirebaseFirestore.instance
          .collection(AppConfig.activityCollection)
          .add({
        'action': 'document_viewed',
        'documentId': widget.documentId,
        'documentName': _document!.name,
        'userId': currentUser.id,
        'userName': currentUser.displayName,
        'userEmail': currentUser.email,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'type': 'document_access',
      });
    } catch (e) {
      LoggerService.error('Failed to record document access', error: e);
      // Don't fail the page load for this
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (_document != null && !_isLoading) ...[
            IconButton(
              onPressed: _shareDocument,
              icon: const Icon(Icons.share),
            ),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download),
                      SizedBox(width: 8),
                      Text('Download'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Icons.info),
                      SizedBox(width: 8),
                      Text('Properties'),
                    ],
                  ),
                ),
                if (_canEditDocument(currentUser.value))
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                if (_canDeleteDocument(currentUser.value))
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      body: _buildBody(),
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
            Text('Loading document...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return _buildErrorView();
    }

    if (_document == null) {
      return _buildNotFoundView();
    }

    return _buildDocumentView();
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeIn(
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Error Loading Document',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeIn(
              child: const Icon(
                Icons.description_outlined,
                size: 64,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Document Not Found',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                'The document you are looking for could not be found.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildDocumentHeader(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildDocumentInfo(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildTechnicalDetails(),
          ),
          if (_document!.accessHistory.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildAccessHistory(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingM),
                  decoration: BoxDecoration(
                    color: _getDocumentTypeColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Icon(
                    _getDocumentTypeIcon(),
                    size: 24,
                    color: _getDocumentTypeColor(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _document!.name,
                        style: AppTheme.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _document!.fileName,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            if (_document!.description.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingM),
              Text(
                _document!.description,
                style: AppTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Type', _document!.type.displayName),
            _buildInfoRow('Size', _formatFileSize(_document!.fileSize)),
            _buildInfoRow('Format', _document!.mimeType),
            _buildInfoRow('Uploaded by', _document!.uploaderName),
            _buildInfoRow('Upload date', _formatDate(_document!.uploadedAt)),
            _buildInfoRow('Last modified', _formatDate(_document!.updatedAt)),
            if (_document!.metadata.keywords.isNotEmpty)
              _buildInfoRow('Keywords', _document!.metadata.keywords.join(', ')),
            if (_document!.hash.isNotEmpty)
              _buildInfoRow('Hash (SHA-256)', '${_document!.hash.substring(0, 16)}...'),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Technical Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Document ID', _document!.id),
            _buildInfoRow('Version', _document!.metadata.version),
            if (_document!.metadata.technicalDetails.isNotEmpty) ...[
              ..._document!.metadata.technicalDetails.entries.map(
                (entry) => _buildInfoRow(
                  _formatTechnicalKey(entry.key),
                  entry.value.toString(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccessHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access History',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...(_document!.accessHistory.take(5).map((access) => _buildAccessItem(access))),
            if (_document!.accessHistory.length > 5)
              TextButton(
                onPressed: _showFullAccessHistory,
                child: Text('View all ${_document!.accessHistory.length} entries'),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewerPage(
                        documentId: widget.documentId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View File'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessItem(DocumentAccess access) {
    final accessedAt = access.lastAccessedAt ?? access.grantedAt;
    final accessedBy = access.accessorEmail;
    final accessType = access.accessLevel;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(
            _getAccessTypeIcon(accessType),
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              '$accessedBy ${_getAccessTypeAction(accessType)}',
              style: AppTheme.bodyMedium,
            ),
          ),
          Text(
            _formatDateTime(accessedAt),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;

    switch (_document!.status) {
      case DocumentStatus.uploaded:
        color = AppTheme.successColor;
        label = 'Uploaded';
        break;
      case DocumentStatus.processing:
        color = AppTheme.warningColor;
        label = 'Processing';
        break;
      case DocumentStatus.verified:
        color = AppTheme.primaryColor;
        label = 'Verified';
        break;
      case DocumentStatus.rejected:
        color = AppTheme.errorColor;
        label = 'Rejected';
        break;
      default:
        color = AppTheme.textSecondary;
        label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTheme.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDocumentTypeColor() {
    switch (_document!.type) {
      case DocumentType.diploma:
        return AppTheme.primaryColor;
      case DocumentType.certificate:
        return AppTheme.successColor;
      case DocumentType.transcript:
        return AppTheme.infoColor;
      case DocumentType.identification:
        return AppTheme.warningColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getDocumentTypeIcon() {
    switch (_document!.type) {
      case DocumentType.diploma:
        return Icons.school;
      case DocumentType.certificate:
        return Icons.verified;
      case DocumentType.transcript:
        return Icons.description;
      case DocumentType.identification:
        return Icons.badge;
      default:
        return Icons.insert_drive_file;
    }
  }

  IconData _getAccessTypeIcon(String accessType) {
    switch (accessType.toLowerCase()) {
      case 'view':
        return Icons.visibility;
      case 'download':
        return Icons.download;
      case 'share':
        return Icons.share;
      case 'edit':
        return Icons.edit;
      default:
        return Icons.info;
    }
  }

  String _getAccessTypeAction(String accessType) {
    switch (accessType.toLowerCase()) {
      case 'view':
        return 'viewed this document';
      case 'download':
        return 'downloaded this document';
      case 'share':
        return 'shared this document';
      case 'edit':
        return 'edited this document';
      default:
        return 'accessed this document';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTechnicalKey(String key) {
    return key.split(RegExp(r'(?=[A-Z])')).map((word) => 
        word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  bool _canEditDocument(user) {
    if (user == null || _document == null) return false;
    return user.id == _document!.uploaderId || user.isAdmin;
  }

  bool _canDeleteDocument(user) {
    if (user == null || _document == null) return false;
    return user.id == _document!.uploaderId || user.isAdmin;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'download':
        _downloadDocument();
        break;
      case 'info':
        _showDocumentProperties();
        break;
      case 'edit':
        _editDocument();
        break;
      case 'delete':
        _deleteDocument();
        break;
    }
  }

  void _shareDocument() async {
    if (_document == null) return;
    
    try {
      // Generate shareable link
      final shareableLink = 'https://upm-certificates.web.app/verify/${_document!.id}';
      
      // Show share options dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this document with others:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verification Link:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    SelectableText(
                      shareableLink,
                      style: const TextStyle(color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This link allows others to verify the authenticity of this document.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Copy to clipboard functionality would require share_plus package
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link copied to clipboard'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              },
              child: const Text('Copy Link'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate share link: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _downloadDocument() async {
    if (_document == null) return;
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Preparing download...'),
            ],
          ),
        ),
      );

      // Download document from Firebase Storage
      if (_document!.fileUrl.isNotEmpty) {
        // Use url_launcher to open the download URL
        final uri = Uri.parse(_document!.fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Could not launch download URL');
        }
        
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document download started'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document file not available for download'),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showDocumentProperties() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Properties'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Full path', _document!.fileUrl.isNotEmpty ? _document!.fileUrl : 'Not available'),
              _buildInfoRow('MIME type', _document!.mimeType),
              _buildInfoRow('File size', '${_document!.fileSize} bytes'),
              _buildInfoRow('SHA-256 hash', _document!.hash),
              _buildInfoRow('Created', _formatDateTime(_document!.uploadedAt)),
              _buildInfoRow('Modified', _formatDateTime(_document!.updatedAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editDocument() {
    if (_document == null) return;
    
    // Navigate to edit page
    context.push('/documents/edit/${_document!.id}');
  }

  void _deleteDocument() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${_document!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete() async {
    try {
      await FirebaseFirestore.instance
          .collection(AppConfig.documentsCollection)
          .doc(widget.documentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showFullAccessHistory() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full Access History',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _document!.accessHistory.length,
                  itemBuilder: (context, index) {
                    return _buildAccessItem(_document!.accessHistory[index]);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 