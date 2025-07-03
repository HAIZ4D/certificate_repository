import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/services/user_profile_service.dart';
import '../widgets/avatar_upload_dialog.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      setState(() {
        _currentUser = user;
        _displayNameController.text = user.displayName;
        _emailController.text = user.email;
        _phoneController.text = user.phoneNumber ?? '';
        _bioController.text = user.bio ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(
                  color: AppTheme.textOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildProfileImageSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildBasicInfoSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildContactInfoSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildBioSection(),
            ),
            const SizedBox(height: AppTheme.spacingXL),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _currentUser!.profileImageUrl != null
                  ? NetworkImage(_currentUser!.profileImageUrl!)
                  : null,
              child: _currentUser!.profileImageUrl == null
                  ? Text(
                      _currentUser!.displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              onPressed: _changeProfileImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Change Photo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your display name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address *',
                prefixIcon: Icon(Icons.email),
              ),
              enabled: false, // Email shouldn't be editable
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                hintText: 'Tell us about yourself...',
                prefixIcon: Icon(Icons.info_outline),
              ),
              maxLines: 4,
              maxLength: 500,
              validator: (value) {
                if (value != null && value.length > 500) {
                  return 'Bio must be less than 500 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeProfileImage() {
                showDialog(
              context: context,
              builder: (context) => const AvatarUploadDialog(),
            );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProfileService = UserProfileService();
      
      // Update user profile with real service
      await userProfileService.updateUserProfile(
        displayName: _displayNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        bio: _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
      );
      
      // Refresh the current user provider
      ref.invalidate(currentUserProvider);
      
      LoggerService.info('Profile updated for user: ${_currentUser!.id}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Profile updated successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      LoggerService.error('Failed to update profile', error: e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to update profile: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
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