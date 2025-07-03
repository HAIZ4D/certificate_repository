import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/document_service.dart';
import '../../../../core/models/document_model.dart';
import '../../../auth/providers/auth_providers.dart';

class DocumentUploadPage extends ConsumerStatefulWidget {
  const DocumentUploadPage({super.key});

  @override
  ConsumerState<DocumentUploadPage> createState() => _DocumentUploadPageState();
}

class _DocumentUploadPageState extends ConsumerState<DocumentUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  
  PlatformFile? _selectedFile;
  String? _selectedFileName;
  int? _selectedFileSize;
  String _selectedCategory = 'Academic';
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  
  final List<String> _categories = [
    'Academic',
    'Professional',
    'Personal',
    'Official',
    'Research',
    'Project',
    'Certificate',
    'Report',
    'Other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (_selectedFile != null && !_isUploading)
            TextButton(
              onPressed: _uploadDocument,
              child: const Text(
                'Upload',
                style: TextStyle(
                  color: AppTheme.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Please log in to upload documents'),
            );
          }
          return _buildUploadForm();
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildUploadForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildFileSelectionCard(),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: _buildFilePreviewCard(),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildDocumentDetailsCard(),
              ),
            ],
            if (_isUploading) ...[
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: _buildUploadProgressCard(),
              ),
            ],
            const SizedBox(height: AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(
              _selectedFile != null ? Icons.check_circle : Icons.cloud_upload,
              size: 64,
              color: _selectedFile != null ? AppTheme.successColor : AppTheme.primaryColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              _selectedFile != null ? 'File Selected' : 'Select Document',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              _selectedFile != null 
                  ? 'Ready to upload: $_selectedFileName'
                  : 'Choose a document file to upload',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _selectFile,
                icon: Icon(_selectedFile != null ? Icons.change_circle : Icons.folder_open),
                label: Text(_selectedFile != null ? 'Change File' : 'Select File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: AppTheme.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow(Icons.description, 'File Name', _selectedFileName ?? 'Unknown'),
            _buildInfoRow(Icons.storage, 'File Size', _formatFileSize(_selectedFileSize ?? 0)),
            _buildInfoRow(Icons.extension, 'File Type', _getFileExtension(_selectedFileName ?? '')),
            _buildInfoRow(Icons.access_time, 'Selected', DateTime.now().toString().split('.')[0]),
          ],
        ),
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

  Widget _buildDocumentDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Document Title *',
                hintText: 'Enter a descriptive title',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a document title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                prefixIcon: Icon(Icons.category),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter document description (optional)',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value != null && value.trim().isNotEmpty && value.trim().length < 10) {
                  return 'Description must be at least 10 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags',
                hintText: 'Enter tags separated by commas (optional)',
                prefixIcon: Icon(Icons.tag),
                helperText: 'Example: academic, research, project',
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.infoColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Expanded(
                    child: Text(
                      'Supported formats: PDF, DOC, DOCX, TXT, JPG, PNG\nMax file size: ${AppConfig.maxFileSizeMB}MB',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.infoColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadProgressCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Row(
              children: [
                CircularProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: AppTheme.dividerColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uploading Document...',
                        style: AppTheme.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}% complete',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppTheme.dividerColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Future <void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
        withData: true,


      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Check file size (max document size limit)
        if (file.size > AppConfig.maxDocumentSize) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File size exceeds ${AppConfig.maxFileSizeMB}MB limit'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedFile = file;
          _selectedFileName = file.name;
          _selectedFileSize = file.size;
          
          // Auto-fill title with filename if empty
          if (_titleController.text.isEmpty) {
            _titleController.text = _getFileNameWithoutExtension(file.name);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    if (_selectedFile?.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to read file content. Please select a different file.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
      });

      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final fileBytes = _selectedFile!.bytes!;

      _updateProgress(0.1);

      final tags = _tagsController.text.trim().isEmpty
          ? <String>[]
          : _tagsController.text.split(',').map((tag) => tag.trim()).toList();

      final metadata = <String, dynamic>{
        'uploadSource': 'web_app',
        'browserInfo': kIsWeb ? 'web_browser' : 'mobile_app',
        'timestamp': DateTime.now().toIso8601String(),
        'originalFileName': _selectedFile!.name,
        'category': _selectedCategory,
      };

      _updateProgress(0.2);

      final documentService = DocumentService();

      _updateProgress(0.3);
      await Future.delayed(const Duration(milliseconds: 200));
      _updateProgress(0.5);

      await documentService.uploadDocumentWeb(
        name: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _getDocumentType(_selectedCategory),
        uploadedBy: currentUser.id,
        fileBytes: fileBytes,
        fileName: _selectedFile!.name,
        fileSize: _selectedFileSize!,
        mimeType: _getMimeType(_getFileExtension(_selectedFileName!)),
        tags: tags,
        metadata: metadata,
      );

      _updateProgress(0.8);
      await Future.delayed(const Duration(milliseconds: 100));
      _updateProgress(1.0);

      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.pop();
      }
    } catch (e, stackTrace) {
      LoggerService.error('Document upload failed', error: e, stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }


  void _updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _uploadProgress = progress;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'Unknown';
  }

  DocumentType _getDocumentType(String category) {
    switch (category.toLowerCase()) {
      case 'academic':
        return DocumentType.diploma;
      case 'professional':
        return DocumentType.certificate;
      case 'certificate':
        return DocumentType.certificate;
      case 'official':
        return DocumentType.identification;
      default:
        return DocumentType.other;
    }
  }

  String _getMimeType(String fileExtension) {
    switch (fileExtension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  String _getFileNameWithoutExtension(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.first : fileName;
  }
} 
