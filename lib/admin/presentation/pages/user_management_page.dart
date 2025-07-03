import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../dashboard/services/activity_service.dart';

class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> 
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();
  
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  UserRole? _selectedRole;
  UserStatus? _selectedStatus;
  String _searchQuery = '';
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    
    if (currentUser == null || currentUser.role != UserRole.systemAdmin) {
      return _buildAccessDenied();
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(),
            _buildSearchHeader(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllUsersTab(),
            _buildPendingUsersTab(),
            _buildSuspendedUsersTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUserDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: AppTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to access this page.',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: const Text(
            'User Management',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return SliverToBoxAdapter(
      child: Container(
        color: AppTheme.primaryColor,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FadeInUp(
          duration: const Duration(milliseconds: 800),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarHeaderDelegate(
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Pending'),
            Tab(text: 'Suspended'),
          ],
        ),
      ),
    );
  }

  Widget _buildAllUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _buildUsersList(_filteredUsers);
  }

  Widget _buildPendingUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final pendingUsers = _filteredUsers.where((user) => user.status == UserStatus.pending).toList();
    return _buildUsersList(pendingUsers);
  }

  Widget _buildSuspendedUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final suspendedUsers = _filteredUsers.where((user) => user.status == UserStatus.suspended).toList();
    return _buildUsersList(suspendedUsers);
  }

  Widget _buildUsersList(List<UserModel> users) {
    if (users.isEmpty) {
      return _buildEmptyState('No users found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          duration: Duration(milliseconds: 400 + (index * 100)),
          child: _buildUserCard(users[index]),
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showUserDetails(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getUserStatusColor(user.status),
                    child: Text(
                      user.displayName.isNotEmpty 
                          ? user.displayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(user.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.person_outline,
                    user.role.name.toUpperCase(),
                    AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.access_time,
                    _formatDate(user.createdAt),
                    AppTheme.textSecondary,
                  ),
                ],
              ),
              if (user.status == UserStatus.pending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _approveUser(user),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Approve'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successColor,
                          side: const BorderSide(color: AppTheme.successColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectUser(user),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (user.status == UserStatus.active) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _suspendUser(user),
                        icon: const Icon(Icons.pause, size: 16),
                        label: const Text('Suspend'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.warningColor,
                          side: const BorderSide(color: AppTheme.warningColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _editUser(user),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(UserStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case UserStatus.active:
        color = AppTheme.successColor;
        label = 'Active';
        break;
      case UserStatus.pending:
        color = AppTheme.warningColor;
        label = 'Pending';
        break;
      case UserStatus.suspended:
        color = AppTheme.errorColor;
        label = 'Suspended';
        break;
      case UserStatus.inactive:
        color = AppTheme.textSecondary;
        label = 'Inactive';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getUserStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.active:
        return AppTheme.successColor;
      case UserStatus.pending:
        return AppTheme.warningColor;
      case UserStatus.suspended:
        return AppTheme.errorColor;
      case UserStatus.inactive:
        return AppTheme.textSecondary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.titleMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Future<void> _fetchUsers() async {
    try {
      setState(() {
        _isLoading = true;
      });

      LoggerService.info('Fetching users from Firebase');

      // Query Firebase for all users
      final querySnapshot = await _firestore
          .collection(AppConfig.usersCollection)
          .orderBy('createdAt', descending: true)
          .get();

      final users = querySnapshot.docs.map((doc) {
        return UserModel.fromMap({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();

      setState(() {
        _allUsers = users;
        _filterUsers();
        _isLoading = false;
      });

      LoggerService.info('Successfully fetched ${users.length} users');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to fetch users', error: e, stackTrace: stackTrace);
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _filterUsers() {
    final filtered = _allUsers.where((user) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!user.displayName.toLowerCase().contains(query) &&
            !user.email.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Role filter
      if (_selectedRole != null && user.role != _selectedRole) {
        return false;
      }

      // Status filter
      if (_selectedStatus != null && user.status != _selectedStatus) {
        return false;
      }

      return true;
    }).toList();

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Users'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<UserRole>(
              value: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Roles'),
                ),
                ...UserRole.values.map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<UserStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All Statuses'),
                ),
                ...UserStatus.values.map((status) => DropdownMenuItem(
                  value: status,
                  child: Text(status.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedRole = null;
                _selectedStatus = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    UserRole selectedRole = UserRole.client;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New User'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) selectedRole = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty || 
                  emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();
              
              try {
                // Show loading
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Creating user...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                LoggerService.info('Creating new user: ${emailController.text}');

                // Create user document in Firestore
                final userData = {
                  'displayName': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': selectedRole.name,
                  'status': UserStatus.pending.name,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                  'emailVerified': false,
                  'phoneNumber': '',
                  'photoURL': '',
                  'organizationId': null,
                  'preferences': {
                    'emailNotifications': true,
                    'pushNotifications': true,
                    'theme': 'light',
                    'language': 'en',
                  },
                };

                final docRef = await _firestore
                    .collection(AppConfig.usersCollection)
                    .add(userData);

                // Log user creation activity
                await _activityService.logActivity(
                  action: 'user_created',
                  details: 'New user ${nameController.text} (${emailController.text}) created by admin',
                  targetId: docRef.id,
                  targetType: 'user',
                  metadata: {
                    'user_name': nameController.text.trim(),
                    'user_email': emailController.text.trim(),
                    'user_role': selectedRole.name,
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User "${nameController.text}" created successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );

                  // Refresh the list
                  _fetchUsers();
                }

                LoggerService.info('User creation completed: ${docRef.id}');

              } catch (e, stackTrace) {
                LoggerService.error('Failed to create user', error: e, stackTrace: stackTrace);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to create user: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Create User'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('User Details: ${user.displayName}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', user.displayName),
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Role', user.role.name.toUpperCase()),
              _buildDetailRow('Status', user.status.name.toUpperCase()),
              _buildDetailRow('Created', _formatDate(user.createdAt)),
              if (user.lastLoginAt != null)
                _buildDetailRow('Last Login', _formatDate(user.lastLoginAt!)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (user.status == UserStatus.pending)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _approveUser(user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _editUser(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => _UserEditDialog(user: user),
    ).then((result) {
      if (result == true) {
        // Refresh user list if changes were made
        _fetchUsers();
      }
    });
  }

  void _approveUser(UserModel user) async {
    try {
      LoggerService.info('Approving user: ${user.id}');

      // Update user status in Firebase
      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.id)
          .update({
        'status': UserStatus.active.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log approval activity
      await _activityService.logActivity(
        action: 'user_approved',
        details: 'User ${user.displayName} (${user.email}) approved',
        targetId: user.id,
        targetType: 'user',
        metadata: {
          'user_name': user.displayName,
          'user_email': user.email,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Refresh user list
        _fetchUsers();
      }

      LoggerService.info('User approval completed: ${user.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to approve user', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve user: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _rejectUser(UserModel user) async {
    try {
      LoggerService.info('Rejecting user: ${user.id}');

      // Update user status in Firebase
      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.id)
          .update({
        'status': UserStatus.inactive.name,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log rejection activity
      await _activityService.logActivity(
        action: 'user_rejected',
        details: 'User ${user.displayName} (${user.email}) rejected',
        targetId: user.id,
        targetType: 'user',
        metadata: {
          'user_name': user.displayName,
          'user_email': user.email,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User rejected successfully'),
            backgroundColor: AppTheme.errorColor,
          ),
        );

        // Refresh user list
        _fetchUsers();
      }

      LoggerService.info('User rejection completed: ${user.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to reject user', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject user: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _suspendUser(UserModel user) async {
    try {
      LoggerService.info('Suspending user: ${user.id}');

      // Update user status in Firebase
      await _firestore
          .collection(AppConfig.usersCollection)
          .doc(user.id)
          .update({
        'status': UserStatus.suspended.name,
        'suspendedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log suspension activity
      await _activityService.logActivity(
        action: 'user_suspended',
        details: 'User ${user.displayName} (${user.email}) suspended',
        targetId: user.id,
        targetType: 'user',
        metadata: {
          'user_name': user.displayName,
          'user_email': user.email,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User suspended successfully'),
            backgroundColor: AppTheme.errorColor,
          ),
        );

        // Refresh user list
        _fetchUsers();
      }

      LoggerService.info('User suspension completed: ${user.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to suspend user', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to suspend user: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// Custom delegate for sticky tab bar
class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _TabBarHeaderDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.backgroundColor,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => 48;

  @override
  double get minExtent => 48;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

// User Edit Dialog
class _UserEditDialog extends StatefulWidget {
  final UserModel user;

  const _UserEditDialog({required this.user});

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _organizationController = TextEditingController();
  final ActivityService _activityService = ActivityService();
  
  UserRole _selectedRole = UserRole.recipient;
  UserStatus _selectedStatus = UserStatus.active;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName;
    _organizationController.text = widget.user.organization ?? '';
    _selectedRole = widget.user.role;
    _selectedStatus = widget.user.status;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit User: ${widget.user.email}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(
                  labelText: 'Organization',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
              const SizedBox(height: AppTheme.spacingM),
              DropdownButtonFormField<UserStatus>(
                value: _selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: UserStatus.values.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = {
        'displayName': _displayNameController.text.trim(),
        'organization': _organizationController.text.trim().isEmpty 
            ? null 
            : _organizationController.text.trim(),
        'role': _selectedRole.name,
        'status': _selectedStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection(AppConfig.usersCollection)
          .doc(widget.user.id)
          .update(updatedData);

      // Log the edit activity
      await _activityService.logActivity(
        action: 'user_edited',
        details: 'User ${widget.user.email} profile updated',
        targetId: widget.user.id,
        targetType: 'user',
        metadata: {
          'user_email': widget.user.email,
          'changes': updatedData,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      LoggerService.error('Failed to update user', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user: $e'),
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
