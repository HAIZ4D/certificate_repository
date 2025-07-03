import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';

class FeatureRequestDialog extends StatefulWidget {
  const FeatureRequestDialog({super.key});

  @override
  State<FeatureRequestDialog> createState() => _FeatureRequestDialogState();
}

class _FeatureRequestDialogState extends State<FeatureRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _useCaseController = TextEditingController();
  
  String _selectedCategory = 'UI/UX Improvement';
  String _selectedPriority = 'Medium';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'UI/UX Improvement',
    'New Feature',
    'Performance Enhancement',
    'Security Enhancement',
    'Integration',
    'Mobile App Feature',
    'Reporting/Analytics',
    'Automation',
    'Other',
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _useCaseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: _buildForm(),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningColor,
            AppTheme.warningColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: AppTheme.smallRadius,
            ),
            child: const Icon(
              Icons.lightbulb,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feature Request',
                  style: AppTheme.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Suggest new features or improvements',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInUp(
            delay: const Duration(milliseconds: 100),
            child: _buildTextField(
              controller: _titleController,
              label: 'Feature Title',
              icon: Icons.title,
              hint: 'Brief title for your feature request',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title for your feature request';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Category',
                    value: _selectedCategory,
                    items: _categories,
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                    icon: Icons.category,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildDropdown(
                    label: 'Priority',
                    value: _selectedPriority,
                    items: _priorities,
                    onChanged: (value) => setState(() => _selectedPriority = value!),
                    icon: Icons.priority_high,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              icon: Icons.description,
              hint: 'Describe the feature you would like to see...',
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a description';
                }
                if (value.trim().length < 20) {
                  return 'Description must be at least 20 characters long';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildTextField(
              controller: _useCaseController,
              label: 'Use Case / Benefit',
              icon: Icons.thumb_up,
              hint: 'How would this feature help you? What problem does it solve?',
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please explain the use case or benefit';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.warningColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Feature Request Guidelines',
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '• Be specific about what you want\n'
                    '• Explain why it would be useful\n'
                    '• Consider how it fits with existing features\n'
                    '• We review all requests but cannot guarantee implementation',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warningColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildExampleSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(
            color: AppTheme.dividerColor,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppTheme.mediumRadius,
          borderSide: BorderSide(color: AppTheme.warningColor),
        ),
        filled: true,
        fillColor: AppTheme.surfaceColor,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
              borderSide: BorderSide(
                color: AppTheme.dividerColor,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppTheme.mediumRadius,
              borderSide: BorderSide(color: AppTheme.warningColor),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingM,
              vertical: AppTheme.spacingS,
            ),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildExampleSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.05),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.infoColor,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Example Feature Request',
                style: AppTheme.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.infoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Title: "Bulk Certificate Operations"\n\n'
            'Description: "Add the ability to perform actions on multiple certificates at once, such as downloading, sharing, or archiving multiple certificates simultaneously."\n\n'
            'Use Case: "As a user with many certificates, I want to download multiple certificates at once instead of downloading them one by one, which would save me significant time and effort."',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusL)),
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitRequest,
              icon: _isSubmitting 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare email content
      final emailSubject = Uri.encodeComponent(
        'Feature Request: ${_titleController.text.trim()}'
      );
      final emailBody = Uri.encodeComponent(
        'FEATURE REQUEST\n'
        '===============\n\n'
        'Title: ${_titleController.text.trim()}\n'
        'Category: $_selectedCategory\n'
        'Priority: $_selectedPriority\n\n'
        'Description:\n${_descriptionController.text.trim()}\n\n'
        'Use Case / Benefit:\n${_useCaseController.text.trim()}\n\n'
        '---\n'
        'Submitted from Digital Certificate Repository Feature Request Form\n'
        'Date: ${DateTime.now().toIso8601String()}'
      );

      final emailUri = 'mailto:features@upm.edu.my?subject=$emailSubject&body=$emailBody';
      
      LoggerService.info('Opening feature request email with title: ${_titleController.text.trim()}');
      
      final uri = Uri.parse(emailUri);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Feature request opened in your email app'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception('Could not open email app');
      }
    } catch (e) {
      LoggerService.error('Failed to send feature request', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to open email app. Please email features@upm.edu.my directly.'),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Email',
              textColor: Colors.white,
              onPressed: () {
                // In a real app, copy email to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email address copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
} 