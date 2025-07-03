import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';

class TermsPrivacyPage extends ConsumerStatefulWidget {
  const TermsPrivacyPage({super.key});

  @override
  ConsumerState<TermsPrivacyPage> createState() => _TermsPrivacyPageState();
}

class _TermsPrivacyPageState extends ConsumerState<TermsPrivacyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsContent(),
          _buildPrivacyContent(),
        ],
      ),
    );
  }

  Widget _buildTermsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: _buildSectionHeader(
              'Terms of Service',
              'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildTermsSection('1. Acceptance of Terms', [
              'By accessing and using the Digital Certificate Repository ("the Service"), you accept and agree to be bound by the terms and provision of this agreement.',
              'If you do not agree to abide by the above, please do not use this service.',
              'This agreement is effective from the date you first use the Service.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildTermsSection('2. Description of Service', [
              'The Digital Certificate Repository is a secure platform for managing digital certificates and academic credentials for Universiti Putra Malaysia (UPM).',
              'The Service allows users to create, verify, share, and manage digital certificates.',
              'Access to certain features requires a valid UPM email address and authentication.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildTermsSection('3. User Responsibilities', [
              'You are responsible for maintaining the confidentiality of your account and password.',
              'You agree to provide accurate, current, and complete information about yourself.',
              'You agree not to use the Service for any unlawful or prohibited activities.',
              'You are responsible for all activities that occur under your account.',
              'You must notify us immediately of any unauthorized use of your account.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildTermsSection('4. Certificate Authenticity and Verification', [
              'Users are responsible for the accuracy of all certificate information they provide.',
              'Certificate Authorities must verify all information before issuing certificates.',
              'False or misleading information may result in account suspension or termination.',
              'All certificates are digitally signed and can be independently verified.',
              'UPM reserves the right to revoke any certificate found to contain false information.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildTermsSection('5. Intellectual Property Rights', [
              'The Service and its original content, features, and functionality are owned by UPM.',
              'Users retain ownership of their uploaded content and certificate data.',
              'You grant UPM a license to use, store, and display your content as necessary to provide the Service.',
              'You may not modify, distribute, or create derivative works based on the Service.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: _buildTermsSection('6. Privacy and Data Protection', [
              'Your privacy is important to us. Please review our Privacy Policy for details.',
              'We collect and process personal data in accordance with applicable data protection laws.',
              'You have the right to access, modify, or delete your personal information.',
              'We implement appropriate security measures to protect your data.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: _buildTermsSection('7. Service Availability and Limitations', [
              'We strive to maintain 99.9% uptime but do not guarantee uninterrupted service.',
              'Scheduled maintenance will be announced in advance when possible.',
              'We reserve the right to modify or discontinue the Service with notice.',
              'Some features may have usage limits or restrictions based on your account type.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 900),
            child: _buildTermsSection('8. Limitation of Liability', [
              'The Service is provided "as is" without warranties of any kind.',
              'UPM shall not be liable for any indirect, incidental, or consequential damages.',
              'Our total liability is limited to the amount paid for the Service, if any.',
              'Some jurisdictions do not allow the exclusion of certain warranties or limitations.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1000),
            child: _buildTermsSection('9. Governing Law and Disputes', [
              'These terms are governed by the laws of Malaysia.',
              'Any disputes shall be resolved through the courts of Malaysia.',
              'We encourage resolving disputes through direct communication first.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1100),
            child: _buildTermsSection('10. Changes to Terms', [
              'We reserve the right to modify these terms at any time.',
              'Material changes will be notified to users via email or in-app notification.',
              'Continued use of the Service constitutes acceptance of modified terms.',
              'You can always access the current terms on this page.',
            ]),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1200),
            child: _buildContactSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: _buildSectionHeader(
              'Privacy Policy',
              'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildPrivacySection('1. Information We Collect', [
              'Personal Information: Name, email address, student/staff ID, department information',
              'Account Information: Login credentials, profile settings, preferences',
              'Certificate Data: Academic records, professional certifications, achievement details',
              'Technical Information: IP address, browser type, device information, usage patterns',
              'Communication Data: Support requests, feedback, correspondence with us',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildPrivacySection('2. How We Use Your Information', [
              'To provide and maintain the Digital Certificate Repository service',
              'To verify your identity and manage your account',
              'To issue, validate, and manage digital certificates',
              'To communicate with you about service updates and important notices',
              'To improve our services and user experience',
              'To comply with legal obligations and institutional requirements',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildPrivacySection('3. Information Sharing and Disclosure', [
              'We do not sell, trade, or rent your personal information to third parties.',
              'We may share information with UPM departments for academic and administrative purposes.',
              'Certificate information may be shared with authorized verifiers when you provide consent.',
              'We may disclose information if required by law or to protect our legal rights.',
              'Aggregated, non-personally identifiable data may be used for research and analytics.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildPrivacySection('4. Data Security and Storage', [
              'We implement industry-standard security measures to protect your data.',
              'All data is encrypted in transit and at rest using AES-256 encryption.',
              'Access to personal data is restricted to authorized personnel only.',
              'We regularly monitor and audit our security practices.',
              'Data is stored on secure servers with redundant backups.',
              'We retain your data only as long as necessary to provide our services.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildPrivacySection('5. Your Privacy Rights', [
              'Access: You can request a copy of your personal data we hold.',
              'Correction: You can update or correct your personal information.',
              'Deletion: You can request deletion of your account and associated data.',
              'Portability: You can request your data in a portable format.',
              'Objection: You can object to certain types of data processing.',
              'Withdrawal: You can withdraw consent for data processing where applicable.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: _buildPrivacySection('6. Cookies and Tracking Technologies', [
              'We use cookies to enhance your experience and maintain your session.',
              'Essential cookies are necessary for the service to function properly.',
              'Analytics cookies help us understand how users interact with our service.',
              'You can control cookie settings through your browser preferences.',
              'Some features may not work properly if cookies are disabled.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: _buildPrivacySection('7. Third-Party Services', [
              'We use Firebase (Google) for authentication and data storage.',
              'Google Analytics may be used to analyze service usage (anonymized data).',
              'Third-party services have their own privacy policies which we encourage you to read.',
              'We carefully select service providers that meet our security and privacy standards.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 900),
            child: _buildPrivacySection('8. International Data Transfers', [
              'Your data may be transferred to and stored in countries outside Malaysia.',
              'We ensure appropriate safeguards are in place for international transfers.',
              'Data transfers comply with applicable data protection laws.',
              'You consent to such transfers by using our service.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1000),
            child: _buildPrivacySection('9. Children\'s Privacy', [
              'Our service is not intended for users under 13 years of age.',
              'We do not knowingly collect personal information from children under 13.',
              'If we become aware of such collection, we will delete the information promptly.',
              'Parents or guardians can contact us if they believe their child has provided personal information.',
            ]),
          ),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1100),
            child: _buildPrivacySection('10. Changes to Privacy Policy', [
              'We may update this privacy policy from time to time.',
              'Significant changes will be notified via email or prominent notice in the app.',
              'The date of the last update is shown at the top of this policy.',
              'Your continued use indicates acceptance of the updated policy.',
            ]),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 1200),
            child: _buildPrivacyContactSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            subtitle,
            style: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(String title, List<String> points) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingL),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: AppTheme.infoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.infoColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: const BoxDecoration(
                    color: AppTheme.infoColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    point,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.contact_support,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Contact Us',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'If you have any questions about these Terms of Service, please contact us:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildContactItem(Icons.email, 'Email', 'legal@upm.edu.my'),
          _buildContactItem(Icons.phone, 'Phone', '+603-9769 1000'),
          _buildContactItem(Icons.location_on, 'Address', 
              '${AppConfig.universityName}\nSerdang, 43400 Selangor, Malaysia'),
        ],
      ),
    );
  }

  Widget _buildPrivacyContactSection() {
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
                Icons.privacy_tip,
                color: AppTheme.infoColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Privacy Contact',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.infoColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'For privacy-related questions or to exercise your rights, please contact our Data Protection Officer:',
            style: AppTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.spacingS),
          _buildContactItem(Icons.email, 'Privacy Email', 'privacy@upm.edu.my'),
          _buildContactItem(Icons.phone, 'Privacy Hotline', '+603-9769 1234'),
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
                    'We will respond to your privacy requests within 30 days as required by law.',
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

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '$label: ',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (icon == Icons.email) {
                  final uri = Uri.parse('mailto:$value');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                } else if (icon == Icons.phone) {
                  final uri = Uri.parse('tel:$value');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                }
              },
              child: Text(
                value,
                style: AppTheme.bodySmall.copyWith(
                  color: icon == Icons.email || icon == Icons.phone 
                      ? AppTheme.primaryColor 
                      : AppTheme.textPrimary,
                  decoration: icon == Icons.email || icon == Icons.phone 
                      ? TextDecoration.underline 
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 