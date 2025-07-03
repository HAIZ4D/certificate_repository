import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../dashboard/services/activity_service.dart';

class DocumentViewerPage extends ConsumerStatefulWidget {
  final String documentId;
  
  const DocumentViewerPage({
    super.key,
    required this.documentId,
  });

  @override
  ConsumerState<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends ConsumerState<DocumentViewerPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();
  
  DocumentModel? _document;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      setState(() {
        _isLoading = true;
      });

      LoggerService.info('Loading document: ${widget.documentId}');

      // Get current user
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Query Firebase for the document
      final docSnapshot = await _firestore
          .collection(AppConfig.documentsCollection)
          .doc(widget.documentId)
          .get();

      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
        });
        
        LoggerService.warning('Document not found: ${widget.documentId}');
        return;
      }

      final documentData = {
        'id': docSnapshot.id,
        ...docSnapshot.data()!,
      };

      final document = DocumentModel.fromMap(docSnapshot.data()!, docSnapshot.id);

      // Check if user has permission to view this document
      if (document.uploaderId != currentUser.id && 
          !currentUser.hasAdminAccess() &&
          !currentUser.hasCertificateAuthorityAccess()) {
        setState(() {
          _isLoading = false;
        });
        
        LoggerService.warning('Unauthorized document access attempt: ${widget.documentId} by ${currentUser.id}');
        return;
      }

      setState(() {
        _document = document;
        _isLoading = false;
      });

      // Log document access
      await _activityService.logDocumentActivity(
        action: 'document_viewed',
        documentId: document.id,
        details: 'Document "${document.name}" viewed by ${currentUser.displayName}',
        metadata: {
          'document_name': document.name,
          'file_type': document.type.name,
          'viewer_id': currentUser.id,
          'viewer_name': currentUser.displayName,
        },
      );

      // Update document access history in Firestore
      await _updateDocumentAccessHistory(document.id, currentUser.id, currentUser.displayName);

      LoggerService.info('Document loaded successfully: ${document.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to load document', error: e, stackTrace: stackTrace);
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateDocumentAccessHistory(String documentId, String userId, String userName) async {
    try {
      final accessRecord = {
        'userId': userId,
        'userName': userName,
        'accessedAt': FieldValue.serverTimestamp(),
        'accessType': 'view',
      };

      await _firestore
          .collection(AppConfig.documentsCollection)
          .doc(documentId)
          .update({
        'accessHistory': FieldValue.arrayUnion([accessRecord]),
        'lastAccessedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      LoggerService.error('Failed to update document access history', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_document?.name ?? 'Document Viewer'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (_document != null && !_isLoading)
            PopupMenuButton<String>(
              onSelected: _handleMenuSelection,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Download'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: ListTile(
                    leading: Icon(Icons.info),
                    title: Text('Document Info'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _document != null
              ? _buildDocumentViewer()
              : _buildErrorState(),
    );
  }

  Widget _buildDocumentViewer() {
    return SingleChildScrollView(
      child: Column(
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildDocumentHeader(),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildDocumentPreview(),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildDocumentInfo(),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: _buildDocumentMetadata(),
          ),
          FadeInUp(
            duration: const Duration(milliseconds: 700),
            child: _buildActionButtons(),
          ),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              _getFileIcon(_document!.mimeType),
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            _document!.name,
            style: AppTheme.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            _document!.fileName,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentPreview() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingL),
      height: 400,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        child: _buildPreviewContent(),
      ),
    );
  }

  Widget _buildPreviewContent() {
    switch (_document!.mimeType.toLowerCase()) {
      case 'application/pdf':
        return _buildPDFPreview();
      case 'image/jpg':
      case 'image/jpeg':
      case 'image/png':
        return _buildImagePreview();
      case 'text/plain':
        return _buildTextPreview();
      case 'application/msword':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return _buildWordDocumentPreview();
      default:
        return _buildUnsupportedPreview();
    }
  }

  Widget _buildPDFPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 80,
            color: Colors.red[400],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'PDF Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Pages: ${_document!.metadata.technicalDetails['pages'] ?? 'Unknown'}',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: _openPDFViewer,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open PDF Viewer'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Icon(
              Icons.image,
              size: 80,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Image Preview',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            '${_document!.mimeType} Image',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.text_snippet,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Text Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'This is a text document. To view the full content, please download the file.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: _downloadDocument,
            icon: const Icon(Icons.download),
            label: const Text('Download to View'),
          ),
        ],
      ),
    );
  }

  Widget _buildWordDocumentPreview() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.blue[50],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 80,
            color: Colors.blue[400],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Word Document',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Size: ${_formatFileSize(_document!.fileSize)}',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _downloadDocument,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              const SizedBox(width: AppTheme.spacingM),
              ElevatedButton.icon(
                onPressed: _openWithExternalApp,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open External'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedPreview() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.insert_drive_file,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Preview Not Available',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'This file type cannot be previewed',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
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
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoRow(Icons.category, 'Category', _document!.type.toString()),
            if (_document!.description.isNotEmpty)
              _buildInfoRow(Icons.description, 'Description', _document!.description),
            _buildInfoRow(Icons.person, 'Uploaded by', _document!.uploaderName),
            _buildInfoRow(Icons.calendar_today, 'Upload date', _formatDate(_document!.uploadedAt)),
            _buildInfoRow(Icons.download, 'Downloads', '${_document!.downloadCount ?? 0}'),
            if (_document!.metadata.keywords.isNotEmpty)
              _buildTagsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tag, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: Text(
              'Tags',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: AppTheme.spacingS,
              children: _document!.metadata.keywords.map((tag) {
                return Chip(
                  label: Text(tag),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentMetadata() {
    return Card(
      margin: const EdgeInsets.all(AppTheme.spacingL),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Technical Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoRow(Icons.fingerprint, 'File Hash', 
                '${_document!.hash.substring(0, 16)}...'),
            _buildInfoRow(Icons.info, 'Version', 
                _document!.metadata.version),
            if (_document!.metadata.technicalDetails.containsKey('author') && 
                _document!.metadata.technicalDetails['author'] != null)
              _buildInfoRow(Icons.edit, 'Author', 
                _document!.metadata.technicalDetails['author']?.toString() ?? 'Unknown'),
            _buildInfoRow(Icons.source, 'Upload Source', 
                _document!.metadata.technicalDetails['uploadSource']?.toString() ?? 'Unknown'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _downloadDocument,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareDocument,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Document Not Found',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'The requested document could not be loaded.',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileType.contains('doc')) {
      return Icons.description;
    } else if (fileType.contains('text')) {
      return Icons.text_snippet;
    } else if (fileType.contains('image')) {
      return Icons.image;
    } else {
      return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'download':
        _downloadDocument();
        break;
      case 'share':
        _shareDocument();
        break;
      case 'info':
        _showDocumentInfo();
        break;
    }
  }

  Future<void> _downloadDocument() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      if (_document!.fileUrl.isNotEmpty) {
        // Download from Firebase Storage URL
        LoggerService.info('Starting document download: ${_document!.id}');
        
        final uri = Uri.parse(_document!.fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Log download activity
          await _activityService.logDocumentActivity(
            action: 'document_downloaded',
            documentId: _document!.id,
            details: 'Document "${_document!.name}" downloaded',
            metadata: {
              'document_name': _document!.name,
              'file_type': _document!.type.name,
              'file_size': _document!.fileSize,
            },
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Document download initiated successfully!'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          throw Exception('Could not launch download URL');
        }
      } else {
        throw Exception('Document download URL not available');
      }
    } catch (e) {
      LoggerService.error('Failed to download document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  void _shareDocument() {
    Share.share(
      'Check out this document: ${_document!.name}\n\nFile: ${_document!.fileName}',
      subject: 'Document: ${_document!.name}',
    );
  }

  Future<void> _openPDFViewer() async {
    final fileUrl = _document?.fileUrl;

    if (fileUrl == null || fileUrl.isEmpty) {
      LoggerService.error('Missing file URL');
      return;
    }

    final uri = Uri.tryParse(fileUrl);
    if (uri == null) {
      LoggerService.error('Invalid URI: $fileUrl');
      return;
    }

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!launched) {
        LoggerService.error('Could not launch file URL');
      }
    } catch (e, st) {
      LoggerService.error('Error launching URL', error: e, stackTrace: st);
    }
  }

  void _openWithExternalApp() {
    _openInExternalApp();
  }

  void _openInExternalApp() async {
    try {
      if (_document!.fileUrl.isNotEmpty) {
        final uri = Uri.parse(_document!.fileUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Log external app access
          await _activityService.logDocumentActivity(
            action: 'document_external_opened',
            documentId: _document!.id,
            details: 'Document opened in external application',
            metadata: {
              'document_name': _document!.name,
              'file_type': _document!.mimeType,
            },
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening document in external application...'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } else {
          throw Exception('Could not launch external application');
        }
      } else {
        throw Exception('Document file URL not available');
      }
    } catch (e) {
      LoggerService.error('Failed to open in external app', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open external app: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showDocumentInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Title: ${_document!.name}'),
              Text('File: ${_document!.fileName}'),
              Text('Size: ${_formatFileSize(_document!.fileSize)}'),
              Text('Type: ${_document!.mimeType}'),
              Text('Uploaded: ${_formatDate(_document!.uploadedAt)}'),
              Text('Downloads: ${_document!.downloadCount ?? 0}'),
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
} 