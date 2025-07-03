import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'logger_service.dart';

class UserProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;


  /// Get current user profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Merge with Firebase Auth data
        return {
          ...data,
          'uid': user.uid,
          'email': user.email,
          'emailVerified': user.emailVerified,
          'createdAt': user.metadata.creationTime?.toIso8601String(),
          'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: $e');
    }
  }

  /// Update user profile information
  Future<void> updateUserProfile({
    String? displayName,
    String? phoneNumber,
    String? department,
    String? position,
    String? bio,
    Map<String, String>? socialLinks,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? privacySettings,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      final updates = <String, dynamic>{};
      
      // Basic profile updates
      if (displayName != null) {
        updates['displayName'] = displayName.trim();
        // Also update Firebase Auth profile
        await user.updateDisplayName(displayName.trim());
      }
      
      if (phoneNumber != null) {
        updates['phoneNumber'] = phoneNumber.trim();
      }
      
      if (department != null) {
        updates['department'] = department.trim();
      }
      
      if (position != null) {
        updates['position'] = position.trim();
      }
      
      if (bio != null) {
        updates['bio'] = bio.trim();
      }
      
      if (socialLinks != null) {
        updates['socialLinks'] = socialLinks;
      }
      
      if (preferences != null) {
        updates['preferences'] = preferences;
      }
      
      if (privacySettings != null) {
        updates['privacySettings'] = privacySettings;
      }

      if (updates.isNotEmpty) {
        updates['updatedAt'] = FieldValue.serverTimestamp();
        
        await _firestore.collection('users').doc(user.uid).update(updates);
        
        // Create activity log
        await _createActivityLog(
          action: 'profile_updated',
          details: {'updatedFields': updates.keys.toList()},
        );
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Upload and update user avatar
  Future<String> updateUserAvatar(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Validate and process image
      final processedImage = await _processImage(imageFile);
      
      // Upload to Firebase Storage
      final fileName = '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = _storage.ref().child('avatars/$fileName');
      
      final uploadTask = storageRef.putData(
        processedImage,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        LoggerService.info('Avatar upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new avatar URL
      await _firestore.collection('users').doc(user.uid).update({
        'avatarUrl': downloadUrl,
        'avatarUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Also update Firebase Auth profile
      await user.updatePhotoURL(downloadUrl);

      // Delete old avatar if exists
      await _deleteOldAvatar(user.uid, fileName);

      // Create activity log
      await _createActivityLog(
        action: 'avatar_updated',
        details: {'newAvatarUrl': downloadUrl},
      );

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }

  /// Process and compress image
  Future<Uint8List> _processImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Invalid image format');
      }

      // Resize image to max 512x512 while maintaining aspect ratio
      final resized = img.copyResize(
        image,
        width: image.width > image.height ? 512 : null,
        height: image.height > image.width ? 512 : null,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG with 85% quality
      final compressed = img.encodeJpg(resized, quality: 85);
      
      // Ensure file size is under 1MB
      if (compressed.length > 1024 * 1024) {
        // Further compress if still too large
        final moreCompressed = img.encodeJpg(resized, quality: 70);
        return Uint8List.fromList(moreCompressed);
      }
      
      return Uint8List.fromList(compressed);
    } catch (e) {
      throw Exception('Failed to process image: $e');
    }
  }

  /// Delete old avatar files to save storage space
  Future<void> _deleteOldAvatar(String userId, String currentFileName) async {
    try {
      final avatarsRef = _storage.ref().child('avatars');
      final listResult = await avatarsRef.listAll();
      
      for (final item in listResult.items) {
        if (item.name.startsWith('${userId}_') && item.name != currentFileName) {
          await item.delete();
          LoggerService.info('Deleted old avatar: ${item.name}');
        }
      }
    } catch (e) {
      LoggerService.warning('Failed to delete old avatars: $e');
      // Don't throw error as this is cleanup operation
    }
  }

  /// Update email with verification
  Future<void> updateEmail(String newEmail, String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Re-authenticate user before changing email
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update email in Firebase Auth using the new method
      await user.verifyBeforeUpdateEmail(newEmail);

      // Update in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'emailUpdateRequested': newEmail,
        'emailUpdateRequestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity log
      await _createActivityLog(
        action: 'email_update_requested',
        details: {'newEmail': newEmail},
      );
    } catch (e) {
      throw Exception('Failed to update email: $e');
    }
  }

  /// Update password
  Future<void> updatePassword(String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Re-authenticate user before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      // Update timestamp in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create activity log
      await _createActivityLog(
        action: 'password_updated',
        details: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  /// Delete user account
  Future<void> deleteAccount(String password, {String? reason}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      // Re-authenticate user before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Create deletion record for audit purposes
      await _firestore.collection('deleted_accounts').doc(user.uid).set({
        'userId': user.uid,
        'email': user.email,
        'deletedAt': FieldValue.serverTimestamp(),
        'reason': reason,
        'userAgent': 'Flutter App',
      });

      // Delete user data from Firestore
      await _deleteUserData(user.uid);

      // Delete user from Firebase Auth (this should be done last)
      await user.delete();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  /// Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    try {
      // Collections to delete user data from
      final collections = [
        'users',
        'certificates',
        'documents',
        'notifications',
        'activities',
        'feedback',
        'user_settings',
        'temp_2fa_setup',
      ];

      for (final collection in collections) {
        final querySnapshot = await _firestore
            .collection(collection)
            .where('userId', isEqualTo: userId)
            .get();

        for (final doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }
      }

      // Delete main user document
      batch.delete(_firestore.collection('users').doc(userId));

      await batch.commit();

      // Delete avatar files from Storage
      await _deleteAllUserFiles(userId);
    } catch (e) {
      throw Exception('Failed to delete user data: $e');
    }
  }

  /// Delete all user files from Firebase Storage
  Future<void> _deleteAllUserFiles(String userId) async {
    try {
      final folders = ['avatars', 'documents', 'certificates'];
      
      for (final folder in folders) {
        final ref = _storage.ref().child(folder);
        final listResult = await ref.listAll();
        
        for (final item in listResult.items) {
          if (item.name.contains(userId)) {
            await item.delete();
          }
        }
      }
    } catch (e) {
      LoggerService.warning('Failed to delete user files: $e');
      // Don't throw error as this is cleanup operation
    }
  }

  /// Create activity log entry
  Future<void> _createActivityLog({
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('activities').add({
        'userId': user.uid,
        'action': action,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'userAgent': 'Flutter App',
        'ipAddress': 'Unknown', // Would need additional service for IP detection
      });
    } catch (e) {
      LoggerService.warning('Failed to create activity log: $e');
      // Don't throw error as logging should not break main functionality
    }
  }

  /// Get user activity history
  Future<List<Map<String, dynamic>>> getUserActivityHistory({
    int limit = 50,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      final querySnapshot = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get activity history: $e');
    }
  }

  /// Export user data (GDPR compliance)
  Future<Map<String, dynamic>> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    try {
      final userData = <String, dynamic>{};

      // Get main user profile
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        userData['profile'] = userDoc.data();
      }

      // Get user certificates
      final certificatesQuery = await _firestore
          .collection('certificates')
          .where('userId', isEqualTo: user.uid)
          .get();
      userData['certificates'] = certificatesQuery.docs.map((doc) => doc.data()).toList();

      // Get user documents
      final documentsQuery = await _firestore
          .collection('documents')
          .where('userId', isEqualTo: user.uid)
          .get();
      userData['documents'] = documentsQuery.docs.map((doc) => doc.data()).toList();

      // Get user activities
      final activitiesQuery = await _firestore
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();
      userData['activities'] = activitiesQuery.docs.map((doc) => doc.data()).toList();

      // Get user feedback
      final feedbackQuery = await _firestore
          .collection('feedback')
          .where('userId', isEqualTo: user.uid)
          .get();
      userData['feedback'] = feedbackQuery.docs.map((doc) => doc.data()).toList();

      userData['exportedAt'] = DateTime.now().toIso8601String();
      userData['exportedBy'] = user.uid;

      // Return formatted result for UI
      return {
        'filename': 'user_data_export_${DateTime.now().millisecondsSinceEpoch}.json',
        'size': '${userData.toString().length} characters',
        'data': userData,
      };
    } catch (e) {
      throw Exception('Failed to export user data: $e');
    }
  }

  /// Stream user profile changes
  Stream<Map<String, dynamic>?> streamUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        return {
          ...data,
          'uid': user.uid,
          'email': user.email,
          'emailVerified': user.emailVerified,
        };
      }
      return null;
    });
  }
} 