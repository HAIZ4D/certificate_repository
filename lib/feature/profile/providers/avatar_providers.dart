import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/services/avatar_upload_service.dart';
import '../../auth/providers/auth_providers.dart';

// Avatar Upload State
class AvatarUploadState {
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final String? successMessage;
  final File? selectedImage;

  const AvatarUploadState({
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.error,
    this.successMessage,
    this.selectedImage,
  });

  AvatarUploadState copyWith({
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? error,
    String? successMessage,
    File? selectedImage,
  }) {
    return AvatarUploadState(
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      successMessage: successMessage,
      selectedImage: selectedImage ?? this.selectedImage,
    );
  }

  AvatarUploadState clearMessages() {
    return copyWith(
      error: null,
      successMessage: null,
    );
  }

  AvatarUploadState reset() {
    return const AvatarUploadState();
  }
}

// Avatar Upload Notifier
class AvatarUploadNotifier extends StateNotifier<AvatarUploadState> {
  final AvatarUploadService _avatarService;
  final Ref _ref;
  final Logger _logger = Logger();

  AvatarUploadNotifier(this._avatarService, this._ref) : super(const AvatarUploadState());

  // Clear any error or success messages
  void clearMessages() {
    state = state.clearMessages();
  }

  // Reset the entire state
  void reset() {
    state = state.reset();
  }

  // Request necessary permissions for camera and gallery access
  Future<bool> requestPermissions() async {
    try {
      return await _avatarService.requestPermissions();
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      state = state.copyWith(error: 'Permission denied. Please allow access to camera and photos.');
      return false;
    }
  }

  // Select image from camera
  Future<void> selectImageFromCamera() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      // Check permissions first
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        state = state.copyWith(
          isLoading: false,
          error: 'Camera permission is required to take photos',
        );
        return;
      }

      final imageFile = await _avatarService.pickImageFromCamera();
      
      if (imageFile != null) {
        state = state.copyWith(
          isLoading: false,
          selectedImage: imageFile,
          successMessage: 'Image selected from camera',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'No image selected',
        );
      }
    } catch (e) {
      _logger.e('Error selecting image from camera: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to access camera: ${e.toString()}',
      );
    }
  }

  // Select image from gallery
  Future<void> selectImageFromGallery() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final imageFile = await _avatarService.pickImageFromGallery();
      
      if (imageFile != null) {
        state = state.copyWith(
          isLoading: false,
          selectedImage: imageFile,
          successMessage: 'Image selected from gallery',
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'No image selected',
        );
      }
    } catch (e) {
      _logger.e('Error selecting image from gallery: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to access gallery: ${e.toString()}',
      );
    }
  }

  // Clear selected image
  void clearSelectedImage() {
    state = state.copyWith(
      selectedImage: null,
      error: null,
      successMessage: null,
    );
  }

  // Upload selected image as avatar
  Future<void> uploadAvatar() async {
    if (state.selectedImage == null) {
      state = state.copyWith(error: 'No image selected');
      return;
    }

    try {
      state = state.copyWith(
        isUploading: true,
        uploadProgress: 0.0,
        error: null,
      );

      // Upload image with progress tracking
      final avatarUrl = await _avatarService.uploadAvatar(
        state.selectedImage!,
        onProgress: (progress) {
          state = state.copyWith(uploadProgress: progress);
        },
      );

      // Update user profile with new avatar
      await _avatarService.updateUserAvatar(avatarUrl);

      // Refresh current user data
      _ref.invalidate(currentUserProvider);

      state = state.copyWith(
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: 'Avatar updated successfully!',
        selectedImage: null,
      );

      _logger.i('Avatar uploaded and updated successfully');
    } catch (e) {
      _logger.e('Error uploading avatar: $e');
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
        error: e.toString(),
      );
    }
  }

  // Remove current avatar
  Future<void> removeAvatar() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _avatarService.removeAvatar();

      // Refresh current user data
      _ref.invalidate(currentUserProvider);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Avatar removed successfully!',
        selectedImage: null,
      );

      _logger.i('Avatar removed successfully');
    } catch (e) {
      _logger.e('Error removing avatar: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

}

// Provider for AvatarUploadService
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  final authService = ref.read(authServiceProvider);
  final userService = ref.read(userServiceProvider);
  
  return AvatarUploadService(
    authService: authService,
    userService: userService,
  );
});

// Provider for AvatarUploadNotifier
final avatarUploadProvider = StateNotifierProvider<AvatarUploadNotifier, AvatarUploadState>((ref) {
  final avatarService = ref.read(avatarUploadServiceProvider);
  return AvatarUploadNotifier(avatarService, ref);
});

// Helper provider to check if user has avatar
final hasAvatarProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.photoURL != null && user!.photoURL!.isNotEmpty,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Provider for avatar URL
final avatarUrlProvider = Provider<String?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser.when(
    data: (user) => user?.photoURL,
    loading: () => null,
    error: (_, __) => null,
  );
}); 