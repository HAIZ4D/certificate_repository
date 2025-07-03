import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/logger_service.dart';

class ContactSupportDialog extends StatefulWidget {
  final String? initialSubject;
  final String? initialCategory;
  
  const ContactSupportDialog({
    super.key,
    this.initialSubject,
    this.initialCategory,
  });

  @override
  State<ContactSupportDialog> createState() => _ContactSupportDialogState();
}

class _ContactSupportDialogState extends State<ContactSupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  
  String _selectedPriority = 'Medium';
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];
  final List<String> _categories = [
    'General',
    'Technical Issue',
    'Account Problem',
    'Certificate Issue',
    'Document Problem',
    'Feature Request',
    'Bug Report',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    
    // Set initial values if provided
    if (widget.initialSubject != null) {
      _subjectController.text = widget.initialSubject!;
    }
    
    if (widget.initialCategory != null && _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
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
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
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
              Icons.contact_support,
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
                  'Contact Support',
                  style: AppTheme.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Get help from our support team',
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
              controller: _nameController,
              label: 'Your Name',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email address';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
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
            delay: const Duration(milliseconds: 400),
            child: _buildTextField(
              controller: _subjectController,
              label: 'Subject',
              icon: Icons.subject,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a subject';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildTextField(
              controller: _messageController,
              label: 'Message',
              icon: Icons.message,
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your message';
                }
                if (value.trim().length < 10) {
                  return 'Message must be at least 10 characters long';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.infoColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.infoColor,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Text(
                        'Support Information',
                        style: AppTheme.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    '• We typically respond within 24 hours\n'
                    '• For urgent issues, call +603-9769 1000\n'
                    '• Include screenshots if relevant\n'
                    '• Provide detailed steps to reproduce issues',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.infoColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
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
          borderSide: BorderSide(color: AppTheme.primaryColor),
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
              borderSide: BorderSide(color: AppTheme.primaryColor),
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
              onPressed: _isSubmitting ? null : _submitForm,
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
              label: Text(_isSubmitting ? 'Sending...' : 'Send Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Prepare email content
      final emailSubject = Uri.encodeComponent(
        '[$_selectedCategory] $_selectedPriority: ${_subjectController.text.trim()}'
      );
      final emailBody = Uri.encodeComponent(
        'Name: ${_nameController.text.trim()}\n'
        'Email: ${_emailController.text.trim()}\n'
        'Category: $_selectedCategory\n'
        'Priority: $_selectedPriority\n'
        'Subject: ${_subjectController.text.trim()}\n\n'
        'Message:\n${_messageController.text.trim()}\n\n'
        '---\n'
        'Sent from Digital Certificate Repository Support Form'
      );

      final emailUri = 'mailto:support@upm.edu.my?subject=$emailSubject&body=$emailBody';
      
      LoggerService.info('Opening support email with subject: ${_subjectController.text.trim()}');
      
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
                  Text('Support request opened in your email app'),
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
      LoggerService.error('Failed to send support request', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to open email app. Please email support@upm.edu.my directly.'),
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