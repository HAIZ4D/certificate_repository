import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/validation_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/services/logger_service.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_emailSent) ...[
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildInstructions(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildEmailForm(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildSubmitButton(),
                ),
              ] else ...[
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildSuccessMessage(),
                ),
              ],
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: _buildBackToLogin(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.lock_reset,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Reset Your Password',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email address',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (value) {
            return ValidationService.validateUpmEmail(value);
          },
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Send Reset Link'),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: AppTheme.successColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Reset Link Sent!',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'We\'ve sent a password reset link to ${_emailController.text}. Please check your email and follow the instructions.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () => setState(() => _emailSent = false),
              child: const Text('Send Another Link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return Center(
      child: TextButton(
        onPressed: () => context.go('/login'),
        child: const Text('Back to Login'),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(authServiceProvider).resetPassword(_emailController.text);
      
      setState(() {
        _emailSent = true;
      });
      
      LoggerService.info('Password reset email sent to: ${_emailController.text}');
      
    } catch (e) {
      LoggerService.error('Failed to send password reset email', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send reset email: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 