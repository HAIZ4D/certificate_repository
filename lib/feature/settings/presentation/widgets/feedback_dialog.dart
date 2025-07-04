import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/services/logger_service.dart';

/// FeedbackDialog
///
/// Modal dialog that allows authenticated users to submit structured feedback
/// (general, bug, feature request, etc.) to Firestore. Includes validation,
/// category selection and priority mapping.
class FeedbackDialog extends ConsumerStatefulWidget {
  const FeedbackDialog({super.key});

  @override
  ConsumerState<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends ConsumerState<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'general';
  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'general', 'label': 'General Feedback'},
    {'value': 'bug', 'label': 'Bug Report'},
    {'value': 'feature', 'label': 'Feature Request'},
    {'value': 'ui', 'label': 'UI/UX Improvement'},
    {'value': 'performance', 'label': 'Performance Issue'},
    {'value': 'security', 'label': 'Security Concern'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Feedback'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We value your feedback! Help us improve the app.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _selectedCategory = value!),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category['value'],
                      child: Text(category['label']!),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                    hintText: 'Brief description of your feedback',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a subject';
                    }
                    if (value.trim().length < 5) {
                      return 'Subject must be at least 5 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    hintText: 'Describe your feedback in detail...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your feedback message';
                    }
                    if (value.trim().length < 10) {
                      return 'Message must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your feedback will be sent to our development team and may be used to improve the app.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitFeedback,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Feedback'),
        ),
      ],
    );
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) throw Exception('User not authenticated');

      // Submit feedback to Firestore
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId': user.id,
        'userEmail': user.email,
        'userName': user.displayName,
        'category': _selectedCategory,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'status': 'new',
        'priority': _getPriority(_selectedCategory),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'appVersion': '1.0.0',
          'platform': 'flutter',
          'userAgent': 'UPM Digital Certificate Repository',
        },
      });

      // Log the feedback submission
      LoggerService.info('Feedback submitted by user: ${user.id}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your feedback has been submitted successfully.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Failed to submit feedback', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getPriority(String category) {
    switch (category) {
      case 'bug':
      case 'security':
        return 'high';
      case 'performance':
      case 'feature':
        return 'medium';
      default:
        return 'low';
    }
  }
} 
