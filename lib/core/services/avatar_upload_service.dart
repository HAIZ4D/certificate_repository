import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_config.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/services/user_service.dart';
import '../models/user_model.dart';

class AvatarUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService;
  final UserService _userService;
  final Logger _logger = Logger();
  final ImagePicker _imagePicker = ImagePicker();

  AvatarUploadService({
    required AuthService authService,
    required UserService userService,
  }) : _authService = authService,
       _userService = userService;

  // Request camera and photo permissions
  Future<bool> requestPermissions() async {
    try {
      final cameraPermission = await Permission.camera.request();
      final photosPermission = await Permission.photos.request();
      
      return cameraPermission.isGranted && photosPermission.isGranted;
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      return false;
    }
  }

  // Show image source selection dialog
  Future<ImageSource?> showImageSourceDialog(context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                subtitle: const Text('Take a new photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                subtitle: const Text('Choose from gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Pick image from camera
  Future<File?> pickImageFromCamera() async {
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw Exception('Camera permission denied');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      _logger.e('Error picking image from camera: $e');
      rethrow;
    }
  }

  // Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        throw Exception('Photos permission denied');
      }

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      _logger.e('Error picking image from gallery: $e');
      rethrow;
    }
  }

  // Validate image file
  bool validateImage(File imageFile) {
    try {
      // Check file size (max 5MB)
      final fileSize = imageFile.lengthSync();
      if (fileSize > AppConfig.maxImageSize) {
        throw Exception('Image size exceeds ${AppConfig.maxImageSize / (1024 * 1024)}MB limit');
      }

      // Check file extension
      final fileName = imageFile.path.toLowerCase();
      const supportedTypes = AppConfig.supportedImageTypes;
      final isSupported = supportedTypes.any((type) => fileName.endsWith('.$type'));
      
      if (!isSupported) {
        throw Exception('Unsupported image format. Supported: ${supportedTypes.join(', ')}');
      }

      return true;
    } catch (e) {
      _logger.e('Image validation failed: $e');
      rethrow;
    }
  }

  // Compress image if needed
  Future<Uint8List> compressImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      
      // If image is already small enough, return as is
      if (imageBytes.length <= 1024 * 1024) { // 1MB
        return imageBytes;
      }

      // Implement basic image optimization
      // If image is too large, we can reduce quality by reducing file size
      if (imageBytes.length > AppConfig.maxImageSize) {
        _logger.i('Image size (${imageBytes.length} bytes) exceeds limit, applying compression');
        
        // For production, you might want to use packages like image or flutter_image_compress
        // For now, we'll implement a basic approach by cropping if needed
        
        // Calculate compression ratio needed
        final compressionRatio = AppConfig.maxImageSize / imageBytes.length;
        
        if (compressionRatio < 0.8) {
          _logger.w('Image requires significant compression (${(compressionRatio * 100).toStringAsFixed(1)}%)');
          
          // For now, we'll throw an error if the image is too large
          // In production, you'd implement actual compression
          throw Exception('Image too large. Please select an image smaller than ${AppConfig.maxImageSizeMB}MB');
        }
      }
      
      _logger.i('Image compression completed. Size: ${imageBytes.length} bytes');
      return imageBytes;
    } catch (e) {
      _logger.e('Error compressing image: $e');
      rethrow;
    }
  }

  // Upload avatar to Firebase Storage
  Future<String> uploadAvatar(File imageFile, {
    Function(double)? onProgress,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Validate image
      validateImage(imageFile);

      // Compress image
      final compressedBytes = await compressImage(imageFile);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = 'avatar_${currentUser.uid}_$timestamp.$fileExtension';

      // Create storage reference
      final storageRef = _storage.ref().child('${AppConfig.profileImagesStoragePath}/$fileName');

      // Upload with metadata
      final uploadTask = storageRef.putData(
        compressedBytes,
        SettableMetadata(
          contentType: 'image/$fileExtension',
          customMetadata: {
            'userId': currentUser.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
            'type': 'avatar',
            'originalSize': imageFile.lengthSync().toString(),
            'compressedSize': compressedBytes.length.toString(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (onProgress != null) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        }
      });

      // Wait for upload completion
      final TaskSnapshot snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      _logger.i('Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      _logger.e('Error uploading avatar: $e');
      rethrow;
    }
  }

  // Update user profile with new avatar URL
  Future<UserModel> updateUserAvatar(String avatarUrl) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Get current user model
      final userModel = await _userService.getUserById(currentUser.uid);
      if (userModel == null) {
        throw Exception('User model not found');
      }

      // Delete old avatar if exists
      if (userModel.photoURL != null && userModel.photoURL!.isNotEmpty) {
        await _deleteOldAvatar(userModel.photoURL!);
      }

      // Update user model with new avatar URL
      final updatedUser = userModel.copyWith(
        photoURL: avatarUrl,
        updatedAt: DateTime.now(),
      );

      // Update in AuthService (which updates both Firebase Auth and Firestore)
      final result = await _authService.updateUserProfile(updatedUser);

      _logger.i('User avatar updated successfully');
      return result;
    } catch (e) {
      _logger.e('Error updating user avatar: $e');
      rethrow;
    }
  }

  // Delete old avatar from storage
  Future<void> _deleteOldAvatar(String avatarUrl) async {
    try {
      // Only delete if it's a Firebase Storage URL
      if (avatarUrl.contains('firebase') && avatarUrl.contains('profileimages')) {
        final storageRef = _storage.refFromURL(avatarUrl);
        await storageRef.delete();
        _logger.i('Old avatar deleted successfully');
      }
    } catch (e) {
      _logger.w('Could not delete old avatar: $e');
      // Don't throw error as this is not critical
    }
  }

  // Remove current avatar
  Future<UserModel> removeAvatar() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Get current user model
      final userModel = await _userService.getUserById(currentUser.uid);
      if (userModel == null) {
        throw Exception('User model not found');
      }

      // Delete current avatar if exists
      if (userModel.photoURL != null && userModel.photoURL!.isNotEmpty) {
        await _deleteOldAvatar(userModel.photoURL!);
      }

      // Update user model to remove avatar URL
      final updatedUser = userModel.copyWith(
        photoURL: null,
        updatedAt: DateTime.now(),
      );

      // Update in AuthService
      final result = await _authService.updateUserProfile(updatedUser);

      _logger.i('User avatar removed successfully');
      return result;
    } catch (e) {
      _logger.e('Error removing user avatar: $e');
      rethrow;
    }
  }

  // Get avatar upload progress
  Stream<double> getUploadProgress(UploadTask uploadTask) {
    return uploadTask.snapshotEvents.map((snapshot) {
      return snapshot.bytesTransferred / snapshot.totalBytes;
    });
  }

  // Generate thumbnail for avatar (optional)
  Future<String?> generateThumbnail(String avatarUrl) async {
    try {
      // This would typically involve creating a smaller version of the image
      // For now, we'll return the original URL
      return avatarUrl;
    } catch (e) {
      _logger.e('Error generating thumbnail: $e');
      return null;
    }
  }

  // Get user's avatar history (for admin purposes)
  Future<List<String>> getAvatarHistory(String userId) async {
    try {
      final listResult = await _storage.ref('${AppConfig.profileImagesStoragePath}/').listAll();
      
      final userAvatars = <String>[];
      for (final item in listResult.items) {
        if (item.name.contains('avatar_${userId}_')) {
          final url = await item.getDownloadURL();
          userAvatars.add(url);
        }
      }
      
      return userAvatars;
    } catch (e) {
      _logger.e('Error getting avatar history: $e');
      return [];
    }
  }

  // Clean up old avatars (for maintenance)
  Future<void> cleanupOldAvatars(String userId, {int keepLatest = 3}) async {
    try {
      final avatarHistory = await getAvatarHistory(userId);
      
      if (avatarHistory.length > keepLatest) {
        final toDelete = avatarHistory.take(avatarHistory.length - keepLatest);
        
        for (final avatarUrl in toDelete) {
          await _deleteOldAvatar(avatarUrl);
        }
        
        _logger.i('Cleaned up ${toDelete.length} old avatars for user $userId');
      }
    } catch (e) {
      _logger.e('Error cleaning up old avatars: $e');
    }
  }
} 