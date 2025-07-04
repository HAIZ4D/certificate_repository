import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

import '../../../core/models/user_model.dart';

/// UserService
///
/// Encapsulates all Firestore operations for CRUD and query tasks related to
/// `UserModel`. Keeps database logic out of UI layers and AuthService, and
/// offers reusable helpers like bulk updates and statistics retrieval.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger _logger = Logger();
  
  static const String _usersCollection = 'users';

  // Create new user
  Future<UserModel> createUser(UserModel user) async {
    try {
      await _firestore.collection(_usersCollection).doc(user.id).set(user.toFirestore());
      _logger.i('User created successfully: ${user.id}');
      return user;
    } catch (e) {
      _logger.e('Error creating user: $e');
      rethrow;
    }
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user by ID: $e');
      rethrow;
    }
  }

  // Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return UserModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      _logger.e('Error getting user by email: $e');
      rethrow;
    }
  }

  // Update user
  Future<UserModel> updateUser(UserModel user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .update(updatedUser.toFirestore());
      
      _logger.i('User updated successfully: ${user.id}');
      return updatedUser;
    } catch (e) {
      _logger.e('Error updating user: $e');
      rethrow;
    }
  }

  // Update user last login
  Future<void> updateUserLastLogin(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'lastLoginAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      _logger.w('Error updating last login: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).delete();
      _logger.i('User deleted successfully: $userId');
    } catch (e) {
      _logger.e('Error deleting user: $e');
      rethrow;
    }
  }

  // Get users by role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: role.name)
          .get();
      
      return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting users by role: $e');
      rethrow;
    }
  }

  // Get users by status
  Future<List<UserModel>> getUsersByStatus(UserStatus status) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('status', isEqualTo: status.name)
          .get();
      
      return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting users by status: $e');
      rethrow;
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers({
    String? query,
    UserRole? role,
    UserStatus? status,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> firestoreQuery = _firestore.collection(_usersCollection);
      
      if (role != null) {
        firestoreQuery = firestoreQuery.where('role', isEqualTo: role.name);
      }
      
      if (status != null) {
        firestoreQuery = firestoreQuery.where('status', isEqualTo: status.name);
      }
      
      firestoreQuery = firestoreQuery.limit(limit);
      
      final querySnapshot = await firestoreQuery.get();
      List<UserModel> users = querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
      
      // Apply text search filter if query is provided
      if (query != null && query.isNotEmpty) {
        final lowercaseQuery = query.toLowerCase();
        users = users.where((user) {
          return user.displayName.toLowerCase().contains(lowercaseQuery) ||
                 user.email.toLowerCase().contains(lowercaseQuery);
        }).toList();
      }
      
      return users;
    } catch (e) {
      _logger.e('Error searching users: $e');
      rethrow;
    }
  }

  // Get all users (with pagination)
  Future<List<UserModel>> getAllUsers({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_usersCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      _logger.e('Error getting all users: $e');
      rethrow;
    }
  }

  // Update user role
  Future<void> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'role': newRole.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _logger.i('User role updated: $userId -> ${newRole.name}');
    } catch (e) {
      _logger.e('Error updating user role: $e');
      rethrow;
    }
  }

  // Update user status
  Future<void> updateUserStatus(String userId, UserStatus newStatus) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'status': newStatus.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _logger.i('User status updated: $userId -> ${newStatus.name}');
    } catch (e) {
      _logger.e('Error updating user status: $e');
      rethrow;
    }
  }

  // Update user permissions
  Future<void> updateUserPermissions(String userId, List<String> permissions) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'permissions': permissions,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      _logger.i('User permissions updated: $userId');
    } catch (e) {
      _logger.e('Error updating user permissions: $e');
      rethrow;
    }
  }

  // Get user stream for real-time updates
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(_usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return UserModel.fromFirestore(doc);
          }
          return null;
        });
  }

  // Get users stream by role
  Stream<List<UserModel>> getUsersStreamByRole(UserRole role) {
    return _firestore
        .collection(_usersCollection)
        .where('role', isEqualTo: role.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }

  // Check if email exists
  Future<bool> emailExists(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      _logger.e('Error checking email existence: $e');
      return false;
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStatistics() async {
    try {
      final snapshot = await _firestore.collection(_usersCollection).get();
      
      Map<String, int> stats = {
        'total': snapshot.docs.length,
        'active': 0,
        'pending': 0,
        'suspended': 0,
      };
      
      for (var doc in snapshot.docs) {
        final user = UserModel.fromFirestore(doc);
        switch (user.status) {
          case UserStatus.active:
            stats['active'] = stats['active']! + 1;
            break;
          case UserStatus.pending:
            stats['pending'] = stats['pending']! + 1;
            break;
          case UserStatus.suspended:
            stats['suspended'] = stats['suspended']! + 1;
            break;
          default:
            break;
        }
      }
      
      return stats;
    } catch (e) {
      _logger.e('Error getting user statistics: $e');
      rethrow;
    }
  }

  // Bulk update users
  Future<void> bulkUpdateUsers(List<String> userIds, Map<String, dynamic> updates) async {
    try {
      final batch = _firestore.batch();
      final updateData = {
        ...updates,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };
      
      for (String userId in userIds) {
        final userRef = _firestore.collection(_usersCollection).doc(userId);
        batch.update(userRef, updateData);
      }
      
      await batch.commit();
      _logger.i('Bulk update completed for ${userIds.length} users');
    } catch (e) {
      _logger.e('Error in bulk update: $e');
      rethrow;
    }
  }
} 
