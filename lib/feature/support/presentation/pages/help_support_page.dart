import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../widgets/faq_section.dart';
import '../widgets/contact_support_dialog.dart';
import '../widgets/feature_request_dialog.dart';

class HelpSupportPage extends ConsumerStatefulWidget {
  const HelpSupportPage({super.key});

  @override
  ConsumerState<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends ConsumerState<HelpSupportPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  final ScrollController _scrollController = ScrollController();
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showContactDialog,
            icon: const Icon(Icons.contact_support),
            tooltip: 'Contact Support',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: _buildTabContent(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('Help Center', 0, Icons.help_center),
                  _buildTab('FAQ', 1, Icons.quiz),
                  _buildTab('Contact', 2, Icons.contact_support),
                  _buildTab('Tutorials', 3, Icons.play_circle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTheme.bodyMedium.copyWith(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildHelpCenter();
      case 1:
        return _buildFAQ();
      case 2:
        return _buildContact();
      case 3:
        return _buildTutorials();
      default:
        return _buildHelpCenter();
    }
  }

  Widget _buildHelpCenter() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: _buildWelcomeSection(),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildQuickActions(),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildGettingStarted(),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildCommonTasks(),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Help Center',
                      style: AppTheme.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Find answers, tutorials, and get support for the Digital Certificate Repository.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppTheme.spacingM,
          mainAxisSpacing: AppTheme.spacingM,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              'Search Help',
              'Find specific topics',
              Icons.search,
              AppTheme.primaryColor,
              () => _showSearchDialog(),
            ),
            _buildActionCard(
              'Report Issue',
              'Report bugs or problems',
              Icons.bug_report,
              AppTheme.errorColor,
              () => _showReportDialog(),
            ),
            _buildActionCard(
              'Feature Request',
              'Suggest new features',
              Icons.lightbulb,
              AppTheme.warningColor,
              () => _showFeatureRequestDialog(),
            ),
            _buildActionCard(
              'Contact Support',
              'Get help from our team',
              Icons.headset_mic,
              AppTheme.successColor,
              () => _showContactDialog(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              title,
              style: AppTheme.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              subtitle,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGettingStarted() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Getting Started',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildHelpSection('Account Setup', [
          'Creating your UPM account',
          'Verifying your email address',
          'Setting up your profile',
          'Understanding user roles',
        ], Icons.person_add),
        const SizedBox(height: AppTheme.spacingM),
        _buildHelpSection('First Steps', [
          'Navigating the dashboard',
          'Understanding the interface',
          'Basic security practices',
          'Customizing your preferences',
        ], Icons.explore),
      ],
    );
  }

  Widget _buildCommonTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Common Tasks',
          style: AppTheme.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        _buildHelpSection('Certificate Management', [
          'Creating a new certificate',
          'Uploading supporting documents',
          'Sharing certificates securely',
          'Downloading certificates',
          'Verifying certificate authenticity',
        ], Icons.verified),
        const SizedBox(height: AppTheme.spacingM),
        _buildHelpSection('Document Handling', [
          'Uploading documents',
          'Organizing your files',
          'Document verification process',
          'Supported file formats',
        ], Icons.folder),
      ],
    );
  }

  Widget _buildHelpSection(String title, List<String> topics, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor, size: 24),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                title,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          ...topics.map((topic) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
            child: InkWell(
              onTap: () => _showTopicDetails(topic),
              borderRadius: AppTheme.smallRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        topic,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFAQ() {
    return const FAQSection();
  }

  Widget _buildContact() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Contact Support',
              style: AppTheme.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildContactOption(
              'Email Support',
              'Get help via email within 24 hours',
              Icons.email,
              AppTheme.primaryColor,
              () => _launchUrl('mailto:support@upm.edu.my?subject=Digital Certificate Repository Support'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildContactOption(
              'Phone Support',
              'Call our support team (Mon-Fri 9AM-5PM)',
              Icons.phone,
              AppTheme.successColor,
              () => _launchUrl('tel:+60397691000'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildContactOption(
              'Live Chat',
              'Chat with our support team in real-time',
              Icons.chat,
              AppTheme.infoColor,
              () => _showLiveChatInfo(),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildContactOption(
              'Visit Us',
              'Visit our office at UPM campus',
              Icons.location_on,
              AppTheme.warningColor,
              () => _showOfficeInfo(),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildSupportHours(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    subtitle,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportHours() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule,
                color: AppTheme.infoColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Support Hours',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.infoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSupportHourItem('Monday - Friday', '9:00 AM - 5:00 PM'),
          _buildSupportHourItem('Saturday', '9:00 AM - 1:00 PM'),
          _buildSupportHourItem('Sunday & Holidays', 'Closed'),
          const SizedBox(height: AppTheme.spacingM),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppTheme.warningColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For urgent issues outside business hours, please email us and we\'ll respond as soon as possible.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportHourItem(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            hours,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorials() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Video Tutorials',
              style: AppTheme.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildTutorialCategory('Getting Started', [
              'Account Setup and Profile Configuration',
              'Understanding the Dashboard',
              'Basic Navigation and Features',
              'Security Best Practices',
            ]),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildTutorialCategory('Certificate Management', [
              'Creating Your First Certificate',
              'Uploading Supporting Documents',
              'Certificate Approval Process',
              'Sharing and Downloading Certificates',
              'Verifying Certificate Authenticity',
            ]),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildTutorialCategory('Advanced Features', [
              'Bulk Certificate Operations',
              'Custom Certificate Templates',
              'Advanced Security Settings',
              'Integration with External Systems',
            ]),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_library,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need a specific tutorial?',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Contact us to request tutorials for specific features.',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _showFeatureRequestDialog,
                    child: const Text('Request'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialCategory(String title, List<String> tutorials) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                title,
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...tutorials.map((tutorial) => _buildTutorialItem(tutorial)),
        ],
      ),
    );
  }

  Widget _buildTutorialItem(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: () => _playTutorial(title),
        borderRadius: AppTheme.smallRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 16,
                  color: AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Action methods
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Help'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'What are you looking for?',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (query) {
                Navigator.of(context).pop();
                _searchHelp(query);
              },
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

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Report Issue'),
          ],
        ),
        content: const Text(
          'Please email us at support@upm.edu.my with:\n\n'
          '• Detailed description of the issue\n'
          '• Steps to reproduce the problem\n'
          '• Screenshots (if applicable)\n'
          '• Your device and browser information\n\n'
          'We\'ll investigate and respond as soon as possible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl('mailto:support@upm.edu.my?subject=Bug Report - Digital Certificate Repository');
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showFeatureRequestDialog() {
    showDialog(
      context: context,
      builder: (context) => const FeatureRequestDialog(),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => const ContactSupportDialog(),
    );
  }

  void _showLiveChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.chat, color: AppTheme.infoColor),
            SizedBox(width: 8),
            Text('Live Chat'),
          ],
        ),
        content: const Text(
          'Live chat is available during business hours:\n\n'
          'Monday - Friday: 9:00 AM - 5:00 PM\n'
          'Saturday: 9:00 AM - 1:00 PM\n\n'
          'For immediate assistance outside these hours, please email us at support@upm.edu.my',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // In a real app, this would open the live chat widget
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live chat feature will be available soon!'),
                ),
              );
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _showOfficeInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.warningColor),
            SizedBox(width: 8),
            Text('Visit Our Office'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Digital Certificate Repository Support',
              style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              '${AppConfig.universityName}\n'
              'IT Services Building\n'
              'Serdang, 43400 Selangor\n'
              'Malaysia',
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Office Hours:',
              style: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spacingS),
            const Text(
              'Monday - Friday: 9:00 AM - 5:00 PM\n'
              'Saturday: 9:00 AM - 1:00 PM\n'
              'Sunday & Holidays: Closed',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl('https://maps.google.com/?q=Universiti+Putra+Malaysia+Serdang');
            },
            child: const Text('Get Directions'),
          ),
        ],
      ),
    );
  }

  void _searchHelp(String query) {
    LoggerService.info('Help search query: $query');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Searching for: $query'),
        action: SnackBarAction(
          label: 'View Results',
          onPressed: () {
            // In a real app, this would show search results
          },
        ),
      ),
    );
  }

  void _showTopicDetails(String topic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(topic),
        content: Text(
          'Detailed help content for "$topic" would be displayed here.\n\n'
          'This would include step-by-step instructions, screenshots, '
          'and links to related topics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl('https://upm.edu.my/help/topics/${topic.toLowerCase().replaceAll(' ', '-')}');
            },
            child: const Text('View Full Guide'),
          ),
        ],
      ),
    );
  }

  void _playTutorial(String tutorial) {
    LoggerService.info('Playing tutorial: $tutorial');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $tutorial'),
        action: SnackBarAction(
          label: 'Watch',
          onPressed: () {
            _launchUrl('https://upm.edu.my/tutorials/${tutorial.toLowerCase().replaceAll(' ', '-')}');
          },
        ),
      ),
    );
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
      LoggerService.error('Error launching URL: $url', error: e);
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
} 