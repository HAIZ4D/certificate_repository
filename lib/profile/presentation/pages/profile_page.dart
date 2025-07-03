import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../auth/providers/auth_providers.dart';
import '../widgets/avatar_upload_dialog.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/change_password_dialog.dart';
import '../widgets/privacy_settings_dialog.dart';
import '../pages/terms_privacy_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _pushNotifications = true;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final authNotifier = ref.read(authNotifierProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Please log in to view your profile'),
            );
          }
          return _buildProfileContent(
              user, authNotifier, themeMode, themeModeNotifier);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: AppTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      // FAB at bottom right
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDonationUrl(context),
        label: const Text('Donate'),
        icon: const Icon(Icons.favorite),
        backgroundColor: Colors.pinkAccent,
      ),
    );
  }

  Widget _buildProfileContent(UserModel user, authNotifier, ThemeMode themeMode,
      ThemeModeNotifier themeModeNotifier) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(user),
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              FadeInUp(
                duration: const Duration(milliseconds: 300),
                child: _buildUserInfoCard(user),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: _buildAccountSection(user),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildNotificationSettings(),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: _buildAppSettings(themeMode, themeModeNotifier),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: _buildSupportSection(),
              ),
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: _buildSignOutSection(authNotifier),
              ),
              const SizedBox(height: AppTheme.spacingXL),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(UserModel user) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Profile',
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.textOnPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => _showAvatarUploadDialog(user),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : 'U',
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.textOnPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                user.displayName,
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.textOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                user.roleDisplayName,
                style: AppTheme.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow(Icons.email, 'Email', user.email),
            _buildInfoRow(Icons.person, 'Display Name', user.displayName),
            _buildInfoRow(Icons.badge, 'Role', user.roleDisplayName),
            _buildInfoRow(Icons.business, 'Organization',
                user.organizationId ?? 'Universiti Putra Malaysia'),

            // Additional profile information
            if (user.profile['department'] != null &&
                (user.profile['department'] as String? ?? '').isNotEmpty)
              _buildInfoRow(Icons.school, 'Department',
                  user.profile['department'] as String),
            if (user.profile['phoneNumber'] != null &&
                (user.profile['phoneNumber'] as String? ?? '').isNotEmpty)
              _buildInfoRow(
                  Icons.phone, 'Phone', user.profile['phoneNumber'] as String),
            if (user.profile['address'] != null &&
                (user.profile['address'] as String? ?? '').isNotEmpty)
              _buildInfoRow(Icons.location_on, 'Address',
                  user.profile['address'] as String),

            _buildInfoRow(
                Icons.verified_user, 'Status', user.statusDisplayName),
            if (user.lastLoginAt != null)
              _buildInfoRow(Icons.access_time, 'Last Login',
                  _formatDateTime(user.lastLoginAt!)),
            _buildInfoRow(Icons.calendar_today, 'Member Since',
                _formatDateTime(user.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(UserModel user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Management',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildActionTile(
              Icons.edit,
              'Edit Profile',
              'Update your personal information',
              () => _showEditProfileDialog(user),
            ),
            _buildActionTile(
              Icons.photo_camera,
              'Change Profile Picture',
              'Update your avatar image',
              () => _showAvatarUploadDialog(user),
            ),
            _buildActionTile(
              Icons.lock,
              'Change Password',
              'Update your account password',
              () => _showChangePasswordDialog(),
            ),
            _buildActionTile(
              Icons.security,
              'Privacy Settings',
              'Manage your privacy preferences',
              () => _showPrivacySettings(),
            ),
            if (user.isAdmin)
              _buildActionTile(
                Icons.admin_panel_settings,
                'Admin Panel',
                'Access administrative functions',
                () => context.go('/admin'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notification Settings',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildSwitchTile(
              'Enable Notifications',
              'Receive notifications about your certificates',
              _notificationsEnabled,
              (value) => setState(() => _notificationsEnabled = value),
            ),
            _buildSwitchTile(
              'Email Notifications',
              'Receive notifications via email',
              _emailNotifications,
              (value) => setState(() => _emailNotifications = value),
            ),
            _buildSwitchTile(
              'Push Notifications',
              'Receive push notifications on your device',
              _pushNotifications,
              (value) => setState(() => _pushNotifications = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSettings(
      ThemeMode themeMode, ThemeModeNotifier themeModeNotifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Settings',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),

            // Theme Mode Setting
            _buildThemeModeTile(themeMode, themeModeNotifier),

            _buildActionTile(
              Icons.language,
              'Language',
              'English (Default)',
              () => _showLanguageDialog(),
            ),
            _buildActionTile(
              Icons.download,
              'Download Data',
              'Export your certificates and data',
              () => _downloadUserData(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeTile(
      ThemeMode themeMode, ThemeModeNotifier themeModeNotifier) {
    return ListTile(
      leading: Icon(
        _getThemeIcon(themeMode),
        color: AppTheme.primaryColor,
      ),
      title: Text(
        'Appearance',
        style: AppTheme.bodyLarge,
      ),
      subtitle: Text(
        _getThemeDisplayName(themeMode),
        style: AppTheme.bodySmall,
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _showThemeDialog(themeMode, themeModeNotifier),
    );
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getThemeDisplayName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemeDialog(
      ThemeMode currentTheme, ThemeModeNotifier themeModeNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              'System Default',
              'Follow system setting',
              Icons.brightness_auto,
              ThemeMode.system,
              currentTheme,
              themeModeNotifier,
            ),
            _buildThemeOption(
              'Light Mode',
              'Light appearance',
              Icons.light_mode,
              ThemeMode.light,
              currentTheme,
              themeModeNotifier,
            ),
            _buildThemeOption(
              'Dark Mode',
              'Dark appearance',
              Icons.dark_mode,
              ThemeMode.dark,
              currentTheme,
              themeModeNotifier,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    String title,
    String subtitle,
    IconData icon,
    ThemeMode themeMode,
    ThemeMode currentTheme,
    ThemeModeNotifier themeModeNotifier,
  ) {
    final isSelected = currentTheme == themeMode;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryColor : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: AppTheme.primaryColor,
            )
          : null,
      onTap: () async {
        themeModeNotifier.setThemeMode(themeMode);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Theme changed to $title'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  Widget _buildSupportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support & Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildActionTile(
              Icons.help,
              'Help Center',
              'Get help and support',
              () => _openHelpCenter(),
            ),
            _buildActionTile(
              Icons.feedback,
              'Send Feedback',
              'Share your feedback with us',
              () => _sendFeedback(),
            ),
            _buildActionTile(
              Icons.info,
              'About',
              'App version and information',
              () => _showAboutDialog(),
            ),
            _buildActionTile(
              Icons.article,
              'Terms & Privacy',
              'Read our terms and privacy policy',
              () => _showTermsAndPrivacy(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutSection(authNotifier) {
    return Card(
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.logout,
              color: AppTheme.errorColor,
              size: 32,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Sign Out',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Sign out of your account',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showSignOutDialog(authNotifier),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title, style: AppTheme.bodyLarge),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: AppTheme.bodyLarge),
      subtitle: Text(subtitle, style: AppTheme.bodySmall),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showEditProfileDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => const PrivacySettingsDialog(),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.language, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Select Language'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸'),
              title: const Text('English'),
              subtitle: const Text('Default'),
              trailing: const Icon(Icons.check, color: AppTheme.primaryColor),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Text('🇲🇾'),
              title: const Text('Bahasa Malaysia'),
              subtitle: const Text('Available in future updates'),
              enabled: false,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Bahasa Malaysia localization will be available in a future update'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
            ListTile(
              leading: const Text('🇨🇳'),
              title: const Text('Chinese (Simplified)'),
              subtitle: const Text('Available in future updates'),
              enabled: false,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Chinese localization will be available in a future update'),
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _downloadUserData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Download Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose what data to export:'),
            const SizedBox(height: 16),
            const CheckboxListTile(
              title: Text('Profile Information'),
              subtitle: Text('Personal details and settings'),
              value: true,
              onChanged: null,
              activeColor: AppTheme.primaryColor,
            ),
            CheckboxListTile(
              title: const Text('Certificates'),
              subtitle: const Text('All your certificates and documents'),
              value: true,
              onChanged: (value) {},
              activeColor: AppTheme.primaryColor,
            ),
            CheckboxListTile(
              title: const Text('Activity History'),
              subtitle: const Text('Login history and activities'),
              value: false,
              onChanged: (value) {},
              activeColor: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.primaryColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data will be exported as JSON/PDF format',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.info, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Data export will be available soon'),
                    ],
                  ),
                  backgroundColor: AppTheme.primaryColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Export Data'),
          ),
        ],
      ),
    );
  }

  void _openHelpCenter() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Help Center'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.article, color: AppTheme.primaryColor),
              title: const Text('User Guide'),
              subtitle: const Text('Learn how to use the app'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl('https://upm.edu.my/help/user-guide');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.video_library, color: AppTheme.primaryColor),
              title: const Text('Video Tutorials'),
              subtitle: const Text('Watch step-by-step tutorials'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl('https://upm.edu.my/help/tutorials');
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_support,
                  color: AppTheme.primaryColor),
              title: const Text('Contact Support'),
              subtitle: const Text('Get help from our team'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl('mailto:support@upm.edu.my');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.bug_report, color: AppTheme.primaryColor),
              title: const Text('Report a Problem'),
              subtitle: const Text('Report bugs or issues'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl('https://upm.edu.my/help/report-issue');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _sendFeedback() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.feedback, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Send Feedback'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Help us improve the Digital Certificate Repository:'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.thumb_up, color: AppTheme.successColor),
              title: const Text('General Feedback'),
              subtitle: const Text('Share your thoughts and suggestions'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl('mailto:feedback@upm.edu.my?subject=App Feedback');
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.orange),
              title: const Text('Rate the App'),
              subtitle: const Text('Rate your experience'),
              onTap: () {
                Navigator.of(context).pop();
                _showRatingDialog();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.lightbulb, color: AppTheme.primaryColor),
              title: const Text('Feature Request'),
              subtitle: const Text('Suggest new features'),
              onTap: () {
                Navigator.of(context).pop();
                _launchUrl(
                    'mailto:features@upm.edu.my?subject=Feature Request');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    int rating = 5;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Your Experience'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate this app?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                _getRatingText(rating),
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Thank you for your $rating-star rating!'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Good';
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open $url'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Digital Certificate Repository',
      applicationVersion: '1.0.0',
      applicationIcon:
          const Icon(Icons.security, size: 64, color: AppTheme.primaryColor),
      children: [
        const Text('A secure digital certificate management system for UPM.'),
        const SizedBox(height: 16),
        const Text('Developed for SSE3401 Mobile Application Development.'),
      ],
    );
  }

  void _showTermsAndPrivacy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TermsPrivacyPage(),
      ),
    );
  }

  void _showSignOutDialog(authNotifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                Navigator.of(context).pop(); // Close dialog first

                // Show loading state
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 16),
                        Text('Signing out...'),
                      ],
                    ),
                    duration: Duration(seconds: 1),
                  ),
                );

                // Execute sign out operation
                await authNotifier.signOut();

                // Clear SnackBar (routing system will automatically handle redirection)
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign out failed: $e'),
                      backgroundColor: AppTheme.errorColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showAvatarUploadDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AvatarUploadDialog(
        currentAvatarUrl: user.photoURL,
      ),
    );
  }

  void _openDonationUrl(BuildContext context) async {
    const donationUrl = 'https://buymeacoffee.com/hafiy';
    final uri = Uri.parse(donationUrl);

    if (await canLaunchUrl(uri)) {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        _showError(context);
      }
    } else {
      _showError(context);
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open donation link'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
