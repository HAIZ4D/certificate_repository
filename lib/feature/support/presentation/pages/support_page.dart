import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/contact_support_dialog.dart';
import '../widgets/feature_request_dialog.dart';
import '../widgets/faq_section.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({super.key});

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showContactSupport(context),
            icon: const Icon(Icons.support_agent),
            tooltip: 'Contact Support',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildWelcomeSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildSearchSection(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _buildQuickActions(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildFAQSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.support,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'How can we help you?',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Find answers to common questions or get in touch with our support team.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search Help Articles',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for help articles...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.chat,
                title: 'Contact Support',
                description: 'Get help from our team',
                onTap: () => _showContactSupport(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildActionCard(
                icon: Icons.bug_report,
                title: 'Report Bug',
                description: 'Report a technical issue',
                onTap: () => _showReportBug(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.lightbulb,
                title: 'Feature Request',
                description: 'Suggest new features',
                onTap: () => _showFeatureRequest(context),
              ),
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: _buildActionCard(
                icon: Icons.book,
                title: 'User Guide',
                description: 'Learn how to use the app',
                onTap: () => _openUserGuide(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: AppTheme.primaryColor,
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
                description,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequently Asked Questions',
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingM),
        FAQSection(searchQuery: _searchQuery),
      ],
    );
  }

  void _showContactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ContactSupportDialog(),
    );
  }

  void _showReportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ContactSupportDialog(
        initialSubject: 'Bug Report',
        initialCategory: 'Technical Issue',
      ),
    );
  }

  void _showFeatureRequest(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FeatureRequestDialog(),
    );
  }

  void _openUserGuide() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User guide would open here'),
      ),
    );
  }
} 