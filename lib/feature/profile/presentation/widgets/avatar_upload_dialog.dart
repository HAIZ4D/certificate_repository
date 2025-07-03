import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/avatar_providers.dart';

class AvatarUploadDialog extends ConsumerStatefulWidget {
  final String? currentAvatarUrl;

  const AvatarUploadDialog({
    super.key,
    this.currentAvatarUrl,
  });

  @override
  ConsumerState<AvatarUploadDialog> createState() => _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends ConsumerState<AvatarUploadDialog> {
  @override
  void initState() {
    super.initState();
    // Clear any previous state when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(avatarUploadProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(avatarUploadProvider);
    final uploadNotifier = ref.read(avatarUploadProvider.notifier);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            FadeInDown(
              duration: const Duration(milliseconds: 300),
              child: _buildHeader(),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // Avatar Preview
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildAvatarPreview(uploadState),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // Upload Progress (if uploading)
            if (uploadState.isUploading)
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildUploadProgress(uploadState),
              ),

            // Error Message
            if (uploadState.error != null)
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildErrorMessage(uploadState.error!),
              ),

            // Success Message
            if (uploadState.successMessage != null)
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildSuccessMessage(uploadState.successMessage!),
              ),

            const SizedBox(height: AppTheme.spacingL),

            // Action Buttons
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildActionButtons(uploadState, uploadNotifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.account_circle,
          color: AppTheme.primaryColor,
          size: 28,
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Text(
            'Profile Picture',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPreview(AvatarUploadState uploadState) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.surfaceColor,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: _buildAvatarImage(uploadState),
      ),
    );
  }

  Widget _buildAvatarImage(AvatarUploadState uploadState) {
    // Show selected image if available
    if (uploadState.selectedImage != null) {
      return Image.file(
        uploadState.selectedImage!,
        fit: BoxFit.cover,
        width: 150,
        height: 150,
      );
    }

    // Show current avatar if available
    if (widget.currentAvatarUrl != null && widget.currentAvatarUrl?.isNotEmpty == true) {
      return Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: NetworkImage(widget.currentAvatarUrl!),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.white,
                ),
                onPressed: _selectImage,
              ),
            ),
          ),
        ],
      );
    }

    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person,
        size: 60,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildUploadProgress(AvatarUploadState uploadState) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: uploadState.uploadProgress,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  'Uploading... ${(uploadState.uploadProgress * 100).toInt()}%',
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          LinearProgressIndicator(
            value: uploadState.uploadProgress,
            backgroundColor: AppTheme.dividerColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              error,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppTheme.successColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(AvatarUploadState uploadState, AvatarUploadNotifier uploadNotifier) {
    if (uploadState.isUploading) {
      return const SizedBox.shrink();
    }

    // If image is selected, show upload/cancel buttons
    if (uploadState.selectedImage != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                uploadNotifier.clearSelectedImage();
              },
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: ElevatedButton(
              onPressed: uploadState.isLoading ? null : () async {
                await uploadNotifier.uploadAvatar();
                // Close dialog on success
                if (uploadState.successMessage != null && mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textOnPrimary,
              ),
              child: uploadState.isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upload'),
            ),
          ),
        ],
      );
    }

    // Default buttons: Camera, Gallery, Remove (if has avatar)
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploadState.isLoading ? null : () async {
                  final hasPermissions = await uploadNotifier.requestPermissions();
                  if (hasPermissions) {
                    await uploadNotifier.selectImageFromCamera();
                  }
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: uploadState.isLoading ? null : () async {
                  await uploadNotifier.selectImageFromGallery();
                },
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        if (widget.currentAvatarUrl != null && widget.currentAvatarUrl?.isNotEmpty == true) ...[
          const SizedBox(height: AppTheme.spacingM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: uploadState.isLoading ? null : () async {
                await uploadNotifier.removeAvatar();
                if (uploadState.successMessage != null && mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorColor,
              ),
              label: const Text(
                'Remove Avatar',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTheme.spacingM),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clear messages when dialog is closed
    ref.read(avatarUploadProvider.notifier).clearMessages();
    super.dispose();
  }

  Future<void> _selectImage() async {
    final uploadNotifier = ref.read(avatarUploadProvider.notifier);
    final hasPermissions = await uploadNotifier.requestPermissions();
    if (hasPermissions) {
      await uploadNotifier.selectImageFromGallery();
    }
  }
} 