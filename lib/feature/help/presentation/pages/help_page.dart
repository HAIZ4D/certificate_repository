import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Help & Support',
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.contact_support),
            onPressed: _showContactSupport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFAQTab(),
                _buildGuidesTab(), 
                _buildTutorialsTab(),
                _buildContactTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      color: AppTheme.surfaceColor,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search help articles...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: const OutlineInputBorder(
            borderRadius: AppTheme.mediumRadius,
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.backgroundColor,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'FAQ', icon: Icon(Icons.quiz_outlined)),
          Tab(text: 'Guides', icon: Icon(Icons.book_outlined)),
          Tab(text: 'Tutorials', icon: Icon(Icons.play_circle_outline)),
          Tab(text: 'Contact', icon: Icon(Icons.contact_support_outlined)),
        ],
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondary,
        indicatorColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildFAQTab() {
    final faqs = _filteredFAQs;
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: _buildFAQItem(faqs[index]),
        );
      },
    );
  }

  Widget _buildFAQItem(Map<String, String> faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ExpansionTile(
        title: Text(
          faq['question']!,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Text(
              faq['answer']!,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidesTab() {
    final guides = _filteredGuides;
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: guides.length,
      itemBuilder: (context, index) {
        return FadeInUp(
          delay: Duration(milliseconds: index * 100),
          child: _buildGuideItem(guides[index]),
        );
      },
    );
  }

  Widget _buildGuideItem(Map<String, dynamic> guide) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(
            guide['icon'] as IconData,
            color: AppTheme.primaryColor,
          ),
        ),
        title: Text(
          guide['title']!,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          guide['description']!,
          style: AppTheme.bodySmall,
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _showGuideDetails(guide),
      ),
    );
  }

  Widget _buildTutorialsTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        _buildTutorialSection('Getting Started', [
          {'title': 'Account Setup', 'duration': '5 min', 'type': 'video'},
          {'title': 'First Login', 'duration': '3 min', 'type': 'article'},
          {'title': 'Profile Configuration', 'duration': '7 min', 'type': 'video'},
        ]),
        _buildTutorialSection('For Certificate Authorities', [
          {'title': 'CA Registration Process', 'duration': '10 min', 'type': 'video'},
          {'title': 'Creating Certificates', 'duration': '8 min', 'type': 'article'},
          {'title': 'Managing Templates', 'duration': '12 min', 'type': 'video'},
        ]),
        _buildTutorialSection('For Administrators', [
          {'title': 'User Management', 'duration': '15 min', 'type': 'video'},
          {'title': 'System Configuration', 'duration': '20 min', 'type': 'article'},
          {'title': 'Analytics & Reports', 'duration': '10 min', 'type': 'video'},
        ]),
      ],
    );
  }

  Widget _buildTutorialSection(String title, List<Map<String, String>> tutorials) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
          child: Text(
            title,
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...tutorials.map((tutorial) => _buildTutorialItem(tutorial)),
        const SizedBox(height: AppTheme.spacingL),
      ],
    );
  }

  Widget _buildTutorialItem(Map<String, String> tutorial) {
    final isVideo = tutorial['type'] == 'video';
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isVideo 
              ? Colors.red.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1),
          child: Icon(
            isVideo ? Icons.play_circle_outline : Icons.article_outlined,
            color: isVideo ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          tutorial['title']!,
          style: AppTheme.titleSmall.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${tutorial['duration']!} • ${tutorial['type']!}',
          style: AppTheme.bodySmall,
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _openTutorial(tutorial),
      ),
    );
  }

  Widget _buildContactTab() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      children: [
        FadeInUp(
          child: _buildContactSection(
            'Technical Support',
            Icons.build_outlined,
            'Get help with technical issues and troubleshooting',
            [
              {'label': 'Email Support', 'value': 'support@upm.edu.my', 'type': 'email'},
              {'label': 'Phone Support', 'value': '+603-9769-1000', 'type': 'phone'},
              {'label': 'Live Chat', 'value': 'Available 9AM-5PM', 'type': 'chat'},
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        FadeInUp(
          delay: const Duration(milliseconds: 200),
          child: _buildContactSection(
            'Administrative Support',
            Icons.admin_panel_settings_outlined,
            'Account management and administrative assistance',
            [
              {'label': 'Admin Email', 'value': 'admin@upm.edu.my', 'type': 'email'},
              {'label': 'Office Hours', 'value': 'Mon-Fri 8AM-5PM', 'type': 'info'},
              {'label': 'Emergency', 'value': '+603-9769-1111', 'type': 'phone'},
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingL),
        FadeInUp(
          delay: const Duration(milliseconds: 400),
          child: _buildContactSection(
            'Certificate Authority Support',
            Icons.verified_user_outlined,
            'Specialized support for Certificate Authorities',
            [
              {'label': 'CA Support', 'value': 'ca-support@upm.edu.my', 'type': 'email'},
              {'label': 'Documentation', 'value': 'View CA Guidelines', 'type': 'link'},
              {'label': 'Training', 'value': 'Schedule Training', 'type': 'calendar'},
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingXL),
        FadeInUp(
          delay: const Duration(milliseconds: 600),
          child: _buildFeedbackSection(),
        ),
      ],
    );
  }

  Widget _buildContactSection(
    String title,
    IconData icon,
    String description,
    List<Map<String, String>> contacts,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
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
                        description,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...contacts.map((contact) => _buildContactItem(contact)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(Map<String, String> contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              contact['label']!,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _handleContactAction(contact),
              child: Text(
                contact['value']!,
                style: AppTheme.bodySmall.copyWith(
                  color: _getContactActionColor(contact['type']!),
                  decoration: _shouldUnderline(contact['type']!) 
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

  Widget _buildFeedbackSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.feedback_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingM),
                Text(
                  'Send Feedback',
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Help us improve by sharing your thoughts and suggestions.',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showFeedbackDialog,
                    icon: const Icon(Icons.rate_review),
                    label: const Text('Rate App'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showSuggestionDialog,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Suggest Feature'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Data and Helper Methods
  List<Map<String, String>> get _filteredFAQs {
    final faqs = [
      {
        'question': 'How do I register as a Certificate Authority?',
        'answer': 'To register as a CA, you need to sign up with your UPM email address, select "Certificate Authority" as your user type, and wait for admin approval. The process typically takes 1-3 business days.',
      },
      {
        'question': 'What document formats are supported?',
        'answer': 'We support PDF, DOC, DOCX, TXT, JPG, PNG, and other common document formats. The maximum file size is 10MB per document.',
      },
      {
        'question': 'How do I verify a certificate?',
        'answer': 'You can verify a certificate by entering the verification code on the public verification page. No login is required for verification.',
      },
      {
        'question': 'Can I revoke a certificate after issuing it?',
        'answer': 'Yes, Certificate Authorities can revoke certificates they have issued. Revoked certificates will show as invalid during verification.',
      },
      {
        'question': 'How do I reset my password?',
        'answer': 'Click "Forgot Password" on the login page and enter your email address. You will receive a password reset link via email.',
      },
      {
        'question': 'What browsers are supported?',
        'answer': 'We support all modern browsers including Chrome, Firefox, Safari, and Edge. For the best experience, please use the latest version.',
      },
      {
        'question': 'How do I download my certificates?',
        'answer': 'You can download your certificates from the Certificates page. Click on any certificate and select "Download" from the actions menu.',
      },
      {
        'question': 'Is my data secure?',
        'answer': 'Yes, we use industry-standard encryption and security practices. All data is stored securely and access is controlled through role-based permissions.',
      },
    ];

    if (_searchQuery.isEmpty) return faqs;
    
    return faqs.where((faq) =>
      faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  List<Map<String, dynamic>> get _filteredGuides {
    final guides = [
      {
        'title': 'Getting Started Guide',
        'description': 'Complete setup and first steps',
        'icon': Icons.play_arrow,
      },
      {
        'title': 'Certificate Management',
        'description': 'Create, manage, and revoke certificates',
        'icon': Icons.card_membership,
      },
      {
        'title': 'Document Upload Guide',
        'description': 'How to upload and organize documents',
        'icon': Icons.upload_file,
      },
      {
        'title': 'Verification Process',
        'description': 'Verify certificates and documents',
        'icon': Icons.verified,
      },
      {
        'title': 'Account Security',
        'description': 'Keep your account safe and secure',
        'icon': Icons.security,
      },
      {
        'title': 'Mobile App Usage',
        'description': 'Use the mobile application effectively',
        'icon': Icons.phone_android,
      },
    ];

    if (_searchQuery.isEmpty) return guides;
    
    return guides.where((guide) =>
      (guide['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (guide['description'] as String).toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Color _getContactActionColor(String type) {
    switch (type) {
      case 'email':
      case 'phone':
      case 'link':
      case 'calendar':
        return AppTheme.primaryColor;
      default:
        return AppTheme.textPrimary;
    }
  }

  bool _shouldUnderline(String type) {
    return ['email', 'phone', 'link', 'calendar'].contains(type);
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Help'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Search keywords',
            hintText: 'Enter search terms...',
          ),
          onSubmitted: (value) {
            Navigator.of(context).pop();
            setState(() => _searchQuery = value);
            _searchController.text = value;
          },
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

  void _showContactSupport() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact Support',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@upm.edu.my'),
              onTap: () => _launchEmail('support@upm.edu.my'),
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone Support'),
              subtitle: const Text('+603-9769-1000'),
              onTap: () => _launchPhone('+603-9769-1000'),
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 9AM-5PM'),
              onTap: () => _showChatDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuideDetails(Map<String, dynamic> guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide['title']!),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(guide['description']!),
            const SizedBox(height: AppTheme.spacingM),
            const Text(
              'This guide will walk you through the process step by step. '
              'For the full interactive guide, please visit our documentation portal.',
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
              _openFullGuide(guide);
            },
            child: const Text('Open Full Guide'),
          ),
        ],
      ),
    );
  }

  void _openTutorial(Map<String, String> tutorial) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening tutorial: ${tutorial['title']}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Open tutorial in external browser or show tutorial content
            _openExternalLink('https://docs.upm.edu.my/certificates/tutorials/${tutorial['title'].toString().toLowerCase().replaceAll(' ', '-')}');
          },
        ),
      ),
    );
  }

  void _openFullGuide(Map<String, dynamic> guide) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening guide: ${guide['title']}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Open full guide in external browser or dedicated guide viewer
            _openExternalLink('https://docs.upm.edu.my/certificates/guides/${guide['title'].toString().toLowerCase().replaceAll(' ', '-')}');
          },
        ),
      ),
    );
  }

  void _handleContactAction(Map<String, String> contact) {
    switch (contact['type']) {
      case 'email':
        _launchEmail(contact['value']!);
        break;
      case 'phone':
        _launchPhone(contact['value']!);
        break;
      case 'chat':
        _showChatDialog();
        break;
      case 'link':
        _openExternalLink(contact['value']!);
        break;
      case 'calendar':
        _showScheduleDialog();
        break;
    }
  }

  void _launchEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=UPM Digital Certificate Support',
    );
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch email client';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch email client for $email')),
      );
    }
  }

  void _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch phone dialer';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone dialer for $phone')),
      );
    }
  }

  void _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open link';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $url')),
      );
    }
  }

  void _showChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: const Text(
          'Live chat is available Monday to Friday, 9AM to 5PM. '
          'For assistance outside these hours, please send us an email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchEmail('support@upm.edu.my');
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Training'),
        content: const Text(
          'To schedule CA training, please contact our administrative team. '
          'Training sessions are available for new Certificate Authorities.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchEmail('admin@upm.edu.my');
            },
            child: const Text('Contact Admin'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();
    int rating = 5;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Our App'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate your experience?'),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => rating = index + 1),
                    icon: Icon(
                      Icons.star,
                      color: index < rating ? Colors.amber : Colors.grey,
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextField(
                controller: feedbackController,
                decoration: const InputDecoration(
                  labelText: 'Additional feedback (optional)',
                  hintText: 'Tell us what you think...',
                ),
                maxLines: 3,
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
                _submitFeedback(rating, feedbackController.text);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuggestionDialog() {
    final TextEditingController suggestionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggest a Feature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What feature would you like to see?'),
            const SizedBox(height: AppTheme.spacingM),
            TextField(
              controller: suggestionController,
              decoration: const InputDecoration(
                labelText: 'Feature suggestion',
                hintText: 'Describe your idea...',
              ),
              maxLines: 4,
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
              _submitSuggestion(suggestionController.text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback(int rating, String feedback) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final feedbackData = {
        'userId': user?.uid ?? 'anonymous',
        'userName': user?.displayName ?? user?.email ?? 'Anonymous',
        'rating': rating,
        'feedback': feedback.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'version': '1.0.0', // You can get this from package_info_plus
      };

      await FirebaseFirestore.instance
          .collection('user_feedback')
          .add(feedbackData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for your $rating-star rating!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit feedback: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _submitSuggestion(String suggestion) async {
    if (suggestion.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a suggestion'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      final suggestionData = {
        'userId': user?.uid ?? 'anonymous',
        'userName': user?.displayName ?? user?.email ?? 'Anonymous',
        'suggestion': suggestion.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'submitted',
        'platform': Platform.isAndroid ? 'Android' : 'iOS',
        'version': '1.0.0',
      };

      await FirebaseFirestore.instance
          .collection('feature_suggestions')
          .add(suggestionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your suggestion! We\'ll review it.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit suggestion: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
} 