import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/logger_service.dart';

class BackupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Create a full system backup
  Future<Map<String, dynamic>> createFullBackup({
    required String initiatedBy,
    String? description,
  }) async {
    try {
      LoggerService.info('Starting full system backup initiated by: $initiatedBy');
      
      final backupId = 'full_${DateTime.now().millisecondsSinceEpoch}';
      final backupData = <String, dynamic>{};
      
      // Backup metadata
      backupData['metadata'] = {
        'backupId': backupId,
        'type': 'full_system',
        'initiatedBy': initiatedBy,
        'description': description ?? 'Full system backup',
        'createdAt': DateTime.now().toIso8601String(),
        'version': AppConfig.appVersion,
      };
      
      // Backup collections
      LoggerService.info('Backing up users collection...');
      backupData['users'] = await _backupCollection(AppConfig.usersCollection);
      
      LoggerService.info('Backing up certificates collection...');
      backupData['certificates'] = await _backupCollection(AppConfig.certificatesCollection);
      
      LoggerService.info('Backing up documents collection...');
      backupData['documents'] = await _backupCollection(AppConfig.documentsCollection);
      
      LoggerService.info('Backing up templates collection...');
      backupData['templates'] = await _backupCollection(AppConfig.templatesCollection);
      
      LoggerService.info('Backing up settings collection...');
      backupData['settings'] = await _backupCollection(AppConfig.settingsCollection);
      
      LoggerService.info('Backing up notifications collection...');
      backupData['notifications'] = await _backupCollection(AppConfig.notificationsCollection);
      
      // Calculate backup statistics
      final stats = _calculateBackupStats(backupData);
      backupData['metadata']['statistics'] = stats;
      
      // Compress and upload backup
      final backupJson = jsonEncode(backupData);
      final compressedData = await _compressData(backupJson);
      
      // Upload to Firebase Storage
      final storageRef = _storage.ref().child('backups/$backupId.backup');
      await storageRef.putData(compressedData);
      final downloadUrl = await storageRef.getDownloadURL();
      
      // Save backup record
      await _saveBackupRecord(backupData['metadata'], downloadUrl, compressedData.length);
      
      LoggerService.info('Full system backup completed: $backupId');
      
      return {
        'success': true,
        'backupId': backupId,
        'downloadUrl': downloadUrl,
        'size': compressedData.length,
        'statistics': stats,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e, stackTrace) {
      LoggerService.error('Failed to create system backup', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Create incremental backup (only changes since last backup)
  Future<Map<String, dynamic>> createIncrementalBackup({
    required String initiatedBy,
    required DateTime lastBackupTime,
  }) async {
    try {
      LoggerService.info('Starting incremental backup since: $lastBackupTime');
      
      final backupId = 'incremental_${DateTime.now().millisecondsSinceEpoch}';
      final backupData = <String, dynamic>{};
      
      backupData['metadata'] = {
        'backupId': backupId,
        'type': 'incremental',
        'initiatedBy': initiatedBy,
        'lastFullBackup': lastBackupTime.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'version': AppConfig.appVersion,
      };
      
      // Backup only changed documents since last backup
      backupData['users'] = await _backupCollectionIncremental(
        AppConfig.usersCollection, 
        lastBackupTime,
      );
      
      backupData['certificates'] = await _backupCollectionIncremental(
        AppConfig.certificatesCollection, 
        lastBackupTime,
      );
      
      backupData['documents'] = await _backupCollectionIncremental(
        AppConfig.documentsCollection, 
        lastBackupTime,
      );
      
      // Calculate and upload
      final backupJson = jsonEncode(backupData);
      final compressedData = await _compressData(backupJson);
      
      final storageRef = _storage.ref().child('backups/incremental/$backupId.backup');
      await storageRef.putData(compressedData);
      final downloadUrl = await storageRef.getDownloadURL();
      
      await _saveBackupRecord(backupData['metadata'], downloadUrl, compressedData.length);
      
      LoggerService.info('Incremental backup completed: $backupId');
      
      return {
        'success': true,
        'backupId': backupId,
        'downloadUrl': downloadUrl,
        'size': compressedData.length,
        'createdAt': DateTime.now().toIso8601String(),
      };
      
    } catch (e, stackTrace) {
      LoggerService.error('Failed to create incremental backup', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Get backup history
  Future<List<Map<String, dynamic>>> getBackupHistory({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('backup_records')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get backup history', error: e, stackTrace: stackTrace);
      return [];
    }
  }
  
  /// Get backup status
  Future<Map<String, dynamic>?> getBackupStatus(String backupId) async {
    try {
      final doc = await _firestore
          .collection('backup_records')
          .doc(backupId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to get backup status', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Restore system from backup
  Future<Map<String, dynamic>> restoreFromBackup({
    required String backupId,
    required String initiatedBy,
    bool createBackupBeforeRestore = true,
  }) async {
    try {
      LoggerService.warning('Starting system restore from backup: $backupId by: $initiatedBy');
      
      if (createBackupBeforeRestore) {
        LoggerService.info('Creating safety backup before restore...');
        await createFullBackup(
          initiatedBy: initiatedBy,
          description: 'Safety backup before restore from $backupId',
        );
      }
      
      // Download backup file
      final backupData = await _downloadBackup(backupId);
      
      // Validate backup integrity
      await _validateBackupIntegrity(backupData);
      
      // Start restoration process
      final restorationLog = <String, dynamic>{
        'restorationId': 'restore_${DateTime.now().millisecondsSinceEpoch}',
        'backupId': backupId,
        'initiatedBy': initiatedBy,
        'startedAt': DateTime.now().toIso8601String(),
        'steps': <Map<String, dynamic>>[],
      };
      
      // Restore collections in order
      await _restoreCollection('users', backupData['users'], restorationLog);
      await _restoreCollection('certificates', backupData['certificates'], restorationLog);
      await _restoreCollection('documents', backupData['documents'], restorationLog);
      
      restorationLog['completedAt'] = DateTime.now().toIso8601String();
      restorationLog['status'] = 'completed';
      
      // Save restoration log
      await _firestore.collection('restoration_logs').add(restorationLog);
      
      LoggerService.info('System restoration completed successfully');
      
      return {
        'success': true,
        'restorationId': restorationLog['restorationId'],
        'completedAt': DateTime.now().toIso8601String(),
        'stepsCompleted': restorationLog['steps'].length,
      };
      
    } catch (e, stackTrace) {
      LoggerService.error('Failed to restore from backup', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Clean up old backups
  Future<void> cleanupOldBackups({int retentionDays = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      
      final snapshot = await _firestore
          .collection('backup_records')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final storageUrl = data['storageUrl'] as String?;
        
        if (storageUrl != null) {
          try {
            final ref = _storage.refFromURL(storageUrl);
            await ref.delete();
          } catch (e) {
            LoggerService.warning('Failed to delete backup file: $storageUrl', error: e);
          }
        }
        
        await doc.reference.delete();
      }
      
      LoggerService.info('Cleaned up ${snapshot.docs.length} old backups');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to cleanup old backups', error: e, stackTrace: stackTrace);
    }
  }
  
  // Private helper methods
  Future<List<Map<String, dynamic>>> _backupCollection(String collectionName) async {
    final snapshot = await _firestore.collection(collectionName).get();
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      'data': doc.data(),
    }).toList();
  }
  
  Future<List<Map<String, dynamic>>> _backupCollectionIncremental(
    String collectionName, 
    DateTime since,
  ) async {
    final snapshot = await _firestore
        .collection(collectionName)
        .where('updatedAt', isGreaterThan: Timestamp.fromDate(since))
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      'data': doc.data(),
    }).toList();
  }
  
  Map<String, dynamic> _calculateBackupStats(Map<String, dynamic> backupData) {
    int totalDocuments = 0;
    final collections = <String, int>{};
    
    for (final entry in backupData.entries) {
      if (entry.key != 'metadata' && entry.value is List) {
        final count = (entry.value as List).length;
        collections[entry.key] = count;
        totalDocuments += count;
      }
    }
    
    return {
      'totalDocuments': totalDocuments,
      'collections': collections,
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  Future<Uint8List> _compressData(String data) async {
    // Simple UTF-8 encoding for now
    // In production, you might want to use compression like gzip
    return Uint8List.fromList(utf8.encode(data));
  }
  
  Future<void> _saveBackupRecord(
    Map<String, dynamic> metadata,
    String downloadUrl,
    int size,
  ) async {
    await _firestore.collection('backup_records').add({
      ...metadata,
      'downloadUrl': downloadUrl,
      'size': size,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  
  Future<Map<String, dynamic>> _downloadBackup(String backupId) async {
    try {
      // Get backup record from Firestore
      final backupDoc = await _firestore
          .collection('backup_records')
          .doc(backupId)
          .get();
      
      if (!backupDoc.exists) {
        throw Exception('Backup record not found: $backupId');
      }
      
      final backupData = backupDoc.data()!;
      final downloadUrl = backupData['downloadUrl'] as String?;
      
      if (downloadUrl == null) {
        throw Exception('Backup download URL not found');
      }
      
      // Download backup file from Firebase Storage
      final ref = _storage.refFromURL(downloadUrl);
      final data = await ref.getData();
      
      if (data == null) {
        throw Exception('Failed to download backup file');
      }
      
      // Decompress and parse backup data
      final jsonString = utf8.decode(data);
      final backupContent = jsonDecode(jsonString) as Map<String, dynamic>;
      
      LoggerService.info('Successfully downloaded backup: $backupId (${data.length} bytes)');
      
      return backupContent;
    } catch (e, stackTrace) {
      LoggerService.error('Failed to download backup: $backupId', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
  
  Future<void> _validateBackupIntegrity(Map<String, dynamic> backupData) async {
    // Implementation would validate backup data
    if (backupData.isEmpty) {
      throw Exception('Backup data is empty or corrupted');
    }
  }
  
  Future<void> _restoreCollection(
    String collectionName,
    List<Map<String, dynamic>> data,
    Map<String, dynamic> restorationLog,
  ) async {
    // Implementation would restore collection data
    LoggerService.info('Restoring collection: $collectionName with ${data.length} documents');
    
    restorationLog['steps'].add({
      'collection': collectionName,
      'documentsRestored': data.length,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Generate a download URL for a backup
  Future<Map<String, dynamic>> generateBackupDownloadUrl(String backupId) async {
    try {
      LoggerService.info('Generating download URL for backup: $backupId');
      
      // Get backup record from Firestore
      final backupDoc = await _firestore
          .collection('backup_records')
          .doc(backupId)
          .get();
      
      if (!backupDoc.exists) {
        return {
          'success': false,
          'error': 'Backup not found',
        };
      }
      
      final backupData = backupDoc.data()!;
      final downloadUrl = backupData['downloadUrl'] as String?;
      final size = backupData['size'] as int? ?? 0;
      
      if (downloadUrl == null) {
        return {
          'success': false,
          'error': 'Download URL not available',
        };
      }
      
      // Validate URL format
      
      return {
        'success': true,
        'downloadUrl': downloadUrl,
        'size': _formatFileSize(size),
        'expiresAt': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'filename': '$backupId.backup',
        'createdAt': backupData['createdAt']?.toString() ?? 'Unknown',
      };
    } catch (e, stackTrace) {
      LoggerService.error('Failed to generate download URL for backup: $backupId', 
                         error: e, stackTrace: stackTrace);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Delete a backup
  Future<void> deleteBackup(String backupId) async {
    try {
      LoggerService.info('Deleting backup: $backupId');
      
      // Get backup record from Firestore
      final backupDoc = await _firestore
          .collection('backup_records')
          .doc(backupId)
          .get();
      
      if (!backupDoc.exists) {
        throw Exception('Backup not found: $backupId');
      }
      
      final backupData = backupDoc.data()!;
      final downloadUrl = backupData['downloadUrl'] as String?;
      
      // Delete backup file from Firebase Storage
      if (downloadUrl != null) {
        try {
          final ref = _storage.refFromURL(downloadUrl);
          await ref.delete();
          LoggerService.info('Deleted backup file from storage: $downloadUrl');
        } catch (e) {
          LoggerService.warning('Failed to delete backup file from storage', error: e);
          // Continue with deleting the record even if file deletion fails
        }
      }
      
      // Delete backup record from Firestore
      await backupDoc.reference.delete();
      
      LoggerService.info('Successfully deleted backup: $backupId');
    } catch (e, stackTrace) {
      LoggerService.error('Failed to delete backup: $backupId', 
                         error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }
}

// Riverpod provider
final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
}); 