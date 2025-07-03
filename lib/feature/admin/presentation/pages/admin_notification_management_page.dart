import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/admin_notification_service.dart';

class AdminNotificationManagementPage extends ConsumerStatefulWidget {
  const AdminNotificationManagementPage({super.key});

  @override
  ConsumerState<AdminNotificationManagementPage> createState() => _AdminNotificationManagementPageState();
}

class _AdminNotificationManagementPageState extends ConsumerState<AdminNotificationManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AdminNotificationService _adminNotificationService = AdminNotificationService();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user?.role != UserRole.systemAdmin) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Access Denied', style: TextStyle(fontSize: 24)),
                  Text('Only system administrators can access this page'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notification Management'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Create', icon: Icon(Icons.add_alert)),
                Tab(text: 'Manage', icon: Icon(Icons.notifications_active)),
                Tab(text: 'Templates', icon: Icon(Icons.library_books)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildCreateNotificationTab(),
              _buildManageNotificationsTab(),
              _buildTemplatesTab(),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildCreateNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            child: _buildIndividualNotificationCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: _buildBroadcastNotificationCard(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            child: _buildScheduledNotificationCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualNotificationCard() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    final List<String> selectedUserIds = [];
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Send to Individual Users',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // User Selection
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(
                    selectedUserIds.isEmpty 
                        ? 'Select Recipients' 
                        : '${selectedUserIds.length} users selected',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showUserSelectionDialog(
                    context,
                    selectedUserIds,
                    setState,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Title
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Notification Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Message
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message Content',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading || selectedUserIds.isEmpty
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            final currentUser = ref.read(currentUserProvider).asData?.value;
                            if (currentUser != null) {
                              await _adminNotificationService.sendCustomNotification(
                                adminId: currentUser.id,
                                targetUserIds: selectedUserIds,
                                title: titleController.text,
                                message: messageController.text,
                              );
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Notification sent to ${selectedUserIds.length} users'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                titleController.clear();
                                messageController.clear();
                                selectedUserIds.clear();
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send notification: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Notification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBroadcastNotificationCard() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    UserType? selectedUserType;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setState) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Broadcast Notification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // User Type Selection
              DropdownButtonFormField<UserType?>(
                value: selectedUserType,
                decoration: const InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
                items: [
                  const DropdownMenuItem<UserType?>(
                    value: null,
                    child: Text('All Users'),
                  ),
                  ...UserType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  )),
                ],
                onChanged: (value) => setState(() => selectedUserType = value),
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Title
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Broadcast Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Message
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Broadcast Message',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: AppTheme.spacingM),
              
              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            final currentUser = ref.read(currentUserProvider).asData?.value;
                            if (currentUser != null) {
                              await _adminNotificationService.sendBroadcastNotification(
                                adminId: currentUser.id,
                                title: titleController.text,
                                message: messageController.text,
                                targetUserType: selectedUserType,
                              );
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Broadcast sent to ${selectedUserType?.name ?? 'all users'}'
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                titleController.clear();
                                messageController.clear();
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send broadcast: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send Broadcast'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledNotificationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Scheduled Notifications',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            const Text(
              'Set up automated notifications based on time or events.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingM),
            ElevatedButton(
              onPressed: () => _showScheduleConfigDialog(),
              child: const Text('Configure Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final notifications = snapshot.data?.docs ?? [];

        if (notifications.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No notifications found'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final data = notification.data() as Map<String, dynamic>;
            
            return FadeInUp(
              duration: Duration(milliseconds: 200 + (index * 100)),
              child: Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: data['isRead'] == true 
                        ? Colors.grey 
                        : AppTheme.primaryColor,
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: TextStyle(
                      fontWeight: data['isRead'] == true 
                          ? FontWeight.normal 
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? 'No Message'),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${data['type'] ?? 'unknown'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Notification'),
                            content: const Text('Are you sure you want to delete this notification?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            final currentUser = ref.read(currentUserProvider).asData?.value;
                            if (currentUser != null) {
                              await _adminNotificationService.deleteNotification(
                                notification.id,
                                currentUser.id,
                              );
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notification deleted'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplatesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminNotificationService.getNotificationTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final templates = snapshot.data ?? [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: ElevatedButton.icon(
                onPressed: () => _showCreateTemplateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create Template'),
              ),
            ),
            Expanded(
              child: templates.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.library_books, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No templates found'),
                          Text('Create your first notification template!'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.library_books),
                            ),
                            title: Text(template['name'] ?? 'Unnamed Template'),
                            subtitle: Text(template['category'] ?? 'No Category'),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                // Handle template actions
                                if (value == 'delete') {
                                  _deleteTemplate(template['id']);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showUserSelectionDialog(
    BuildContext context,
    List<String> selectedUserIds,
    StateSetter setState,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Users'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs;
              
              return StatefulBuilder(
                builder: (context, setDialogState) => ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userData = user.data() as Map<String, dynamic>;
                    final isSelected = selectedUserIds.contains(user.id);

                    return CheckboxListTile(
                      title: Text(userData['email'] ?? 'No Email'),
                      subtitle: Text(userData['displayName'] ?? 'No Name'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedUserIds.add(user.id);
                          } else {
                            selectedUserIds.remove(user.id);
                          }
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Refresh the list
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Template'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Template Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Template Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && contentController.text.isNotEmpty) {
                try {
                                     final currentUser = ref.read(currentUserProvider).asData?.value;
                   if (currentUser != null) {
                     await _adminNotificationService.createNotificationTemplate(
                       adminId: currentUser.id,
                       name: nameController.text,
                       title: nameController.text,
                       message: contentController.text,
                       category: categoryController.text,
                     );
                   }
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() {}); // Refresh the list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create template: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deleteTemplate(String templateId) {
    // Implementation for deleting notification templates
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text('Are you sure you want to delete this template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete implementation
              setState(() {}); // Refresh the list
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showScheduleConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configure Schedule'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Set up automated notification schedules:'),
              const SizedBox(height: AppTheme.spacingM),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Daily Reminders'),
                subtitle: const Text('Send daily certificate reminders'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // Handle daily reminders toggle
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Event-based Notifications'),
                subtitle: const Text('Notify on certificate events'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // Handle event notifications toggle
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.warning),
                title: const Text('Expiry Warnings'),
                subtitle: const Text('Warn before certificate expiry'),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    // Handle expiry warnings toggle
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Schedule configuration saved'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 