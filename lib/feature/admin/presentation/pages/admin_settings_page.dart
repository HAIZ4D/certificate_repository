import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../services/backup_service.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  // System Settings
  bool _enableRegistration = true;
  bool _requireEmailVerification = true;
  bool _enableNotifications = true;
  bool _enableAnalytics = true;
  bool _maintenanceMode = false;
  
  // Security Settings
  int _maxLoginAttempts = 5;
  int _sessionTimeout = 480; // minutes
  int _passwordMinLength = 8;
  
  // Certificate Settings
  int _defaultValidityDays = 365;
  int _maxValidityDays = 3650;
  
  // File Upload Settings
  double _maxFileSize = 10.0; // MB
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    // Load current settings from AppConfig or Firebase
    setState(() {
      _maxLoginAttempts = AppConfig.maxLoginAttempts;
      _sessionTimeout = AppConfig.sessionTimeoutMinutes;
      _passwordMinLength = AppConfig.passwordMinLength;
      _defaultValidityDays = AppConfig.defaultCertificateValidityDays;
      _maxValidityDays = AppConfig.maxCertificateValidityDays;
      _maxFileSize = AppConfig.maxDocumentSize / (1024 * 1024); // Convert to MB
      _enableAnalytics = AppConfig.enableAnalytics;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'System Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user?.role != UserRole.systemAdmin) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock,
                    size: 64,
                    color: Colors.red,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Access Denied',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Only system administrators can access this page',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: _buildSystemSettingsSection(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildSecuritySettingsSection(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildCertificateSettingsSection(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _buildFileUploadSettingsSection(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                  duration: const Duration(milliseconds: 700),
                  child: _buildMaintenanceSection(),
                ),
                const SizedBox(height: AppTheme.spacingXL),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SwitchListTile(
              title: const Text('Enable User Registration'),
              subtitle: const Text('Allow new users to register'),
              value: _enableRegistration,
              onChanged: (value) {
                setState(() {
                  _enableRegistration = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Require Email Verification'),
              subtitle: const Text('Users must verify their email'),
              value: _requireEmailVerification,
              onChanged: (value) {
                setState(() {
                  _requireEmailVerification = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Send push and email notifications'),
              value: _enableNotifications,
              onChanged: (value) {
                setState(() {
                  _enableNotifications = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Enable Analytics'),
              subtitle: const Text('Collect usage analytics'),
              value: _enableAnalytics,
              onChanged: (value) {
                setState(() {
                  _enableAnalytics = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _maxLoginAttempts.toString(),
              decoration: const InputDecoration(
                labelText: 'Max Login Attempts',
                hintText: 'Number of failed login attempts before lockout',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter max login attempts';
                }
                final intValue = int.tryParse(value);
                if (intValue == null || intValue < 1 || intValue > 10) {
                  return 'Enter a number between 1 and 10';
                }
                return null;
              },
              onSaved: (value) {
                _maxLoginAttempts = int.tryParse(value!) ?? 5;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _sessionTimeout.toString(),
              decoration: const InputDecoration(
                labelText: 'Session Timeout (minutes)',
                hintText: 'Session timeout in minutes',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter session timeout';
                }
                final intValue = int.tryParse(value);
                if (intValue == null || intValue < 30 || intValue > 1440) {
                  return 'Enter a number between 30 and 1440 minutes';
                }
                return null;
              },
              onSaved: (value) {
                _sessionTimeout = int.tryParse(value!) ?? 480;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _passwordMinLength.toString(),
              decoration: const InputDecoration(
                labelText: 'Minimum Password Length',
                hintText: 'Minimum required password length',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter password minimum length';
                }
                final intValue = int.tryParse(value);
                if (intValue == null || intValue < 6 || intValue > 50) {
                  return 'Enter a number between 6 and 50';
                }
                return null;
              },
              onSaved: (value) {
                _passwordMinLength = int.tryParse(value!) ?? 8;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _defaultValidityDays.toString(),
              decoration: const InputDecoration(
                labelText: 'Default Validity Period (days)',
                hintText: 'Default certificate validity in days',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter default validity days';
                }
                final intValue = int.tryParse(value);
                if (intValue == null || intValue < 1 || intValue > 3650) {
                  return 'Enter a number between 1 and 3650 days';
                }
                return null;
              },
              onSaved: (value) {
                _defaultValidityDays = int.tryParse(value!) ?? 365;
              },
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _maxValidityDays.toString(),
              decoration: const InputDecoration(
                labelText: 'Maximum Validity Period (days)',
                hintText: 'Maximum certificate validity in days',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maximum validity days';
                }
                final intValue = int.tryParse(value);
                if (intValue == null || intValue < 1 || intValue > 7300) {
                  return 'Enter a number between 1 and 7300 days';
                }
                return null;
              },
              onSaved: (value) {
                _maxValidityDays = int.tryParse(value!) ?? 3650;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileUploadSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'File Upload Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextFormField(
              initialValue: _maxFileSize.toString(),
              decoration: const InputDecoration(
                labelText: 'Maximum File Size (MB)',
                hintText: 'Maximum file upload size in MB',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maximum file size';
                }
                final doubleValue = double.tryParse(value);
                if (doubleValue == null || doubleValue < 0.1 || doubleValue > 100) {
                  return 'Enter a number between 0.1 and 100 MB';
                }
                return null;
              },
              onSaved: (value) {
                _maxFileSize = double.tryParse(value!) ?? 10.0;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SwitchListTile(
              title: const Text('Maintenance Mode'),
              subtitle: const Text('Restrict access to admins only'),
              value: _maintenanceMode,
              onChanged: (value) {
                setState(() {
                  _maintenanceMode = value;
                });
              },
              secondary: const Icon(Icons.build),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear Cache'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generateBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.infoColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Here you would save the settings to Firebase or your backend
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear the application cache?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performCacheClear();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _generateBackup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Backup'),
        content: const Text('Create a backup of the system data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performBackupGeneration();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCacheClear() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Clearing cache...'),
            ],
          ),
        ),
      );

      // Simulate cache clearing process
      await Future.delayed(const Duration(seconds: 2));

      // Clear shared preferences cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Clear Firebase cache if needed
      // await FirebaseAuth.instance.signOut(); // This would clear auth cache
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear cache: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _performBackupGeneration() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Creating backup...'),
            ],
          ),
        ),
      );

      // Use the backup service to create backup
      final backupService = ref.read(backupServiceProvider);
      await backupService.createFullBackup(
        initiatedBy: 'Admin',
        description: 'Manual backup from admin settings',
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create backup: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
} 