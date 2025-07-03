import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';

class FAQSection extends StatefulWidget {
  final String? searchQuery;
  
  const FAQSection({
    super.key,
    this.searchQuery,
  });

  @override
  State<FAQSection> createState() => _FAQSectionState();
}

class _FAQSectionState extends State<FAQSection> {
  int? _expandedIndex;

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I create a new certificate?',
      'answer': 'To create a new certificate:\n1. Go to the Dashboard\n2. Click "Create Certificate"\n3. Fill in the required information\n4. Upload supporting documents\n5. Submit for approval\n\nOnce approved, your certificate will be available for download and sharing.',
    },
    {
      'question': 'How can I verify the authenticity of a certificate?',
      'answer': 'You can verify certificates in several ways:\n\n• Use the public verification portal with the certificate ID\n• Scan the QR code on the certificate\n• Check the digital signature\n• Contact the issuing authority directly\n\nAll certificates are cryptographically signed for authenticity.',
    },
    {
      'question': 'What file formats are supported for documents?',
      'answer': 'We support the following file formats:\n\n• PDF (.pdf)\n• Microsoft Word (.doc, .docx)\n• Text files (.txt)\n• Images (.jpg, .jpeg, .png, .gif, .webp)\n\nMaximum file size is 20MB per document.',
    },
    {
      'question': 'How do I share my certificate securely?',
      'answer': 'You can share certificates securely by:\n\n• Generating a secure share link with expiration\n• Setting access passwords for sensitive certificates\n• Sharing the public verification link\n• Downloading and sending the PDF directly\n\nAll sharing methods maintain the certificate\'s integrity and authenticity.',
    },
    {
      'question': 'What should I do if I forgot my password?',
      'answer': 'If you forgot your password:\n\n1. Go to the login page\n2. Click "Forgot Password"\n3. Enter your UPM email address\n4. Check your email for reset instructions\n5. Follow the link to create a new password\n\nFor additional help, contact our support team.',
    },
    {
      'question': 'How long are certificates valid?',
      'answer': 'Certificate validity depends on the type:\n\n• Academic certificates: Permanent\n• Professional certifications: As specified by the issuing body\n• Training certificates: Typically 1-3 years\n• Custom certificates: As set by the issuer\n\nYou can check the expiration date on each certificate.',
    },
    {
      'question': 'Can I download my certificates offline?',
      'answer': 'Yes, you can download certificates as PDF files for offline use. Downloaded certificates include:\n\n• All certificate information\n• QR code for online verification\n• Digital signature for authenticity\n• UPM branding and security features\n\nDownloaded certificates remain valid and verifiable.',
    },
    {
      'question': 'Who can access my certificates?',
      'answer': 'Certificate access is controlled by privacy settings:\n\n• You always have full access to your certificates\n• Public verification is available for authenticity checks\n• Authorized personnel can view based on your permissions\n• Shared links provide temporary access to specific certificates\n\nYou control who can see your certificates through privacy settings.',
    },
    {
      'question': 'How do I update my profile information?',
      'answer': 'To update your profile:\n\n1. Go to Profile settings\n2. Click "Edit Profile"\n3. Update your information\n4. Save changes\n\nSome information may require verification for security purposes.',
    },
    {
      'question': 'What happens if my account is suspended?',
      'answer': 'If your account is suspended:\n\n• You\'ll receive an email notification\n• Your certificates remain secure but inaccessible\n• Contact support for assistance\n• Provide required documentation for reactivation\n\nSuspensions are typically temporary and can be resolved by contacting support.',
    },
  ];

  List<Map<String, String>> get _filteredFAQs {
    if (widget.searchQuery == null || widget.searchQuery!.isEmpty) {
      return _faqs;
    }
    
    final query = widget.searchQuery!.toLowerCase();
    return _faqs.where((faq) {
      return faq['question']!.toLowerCase().contains(query) ||
             faq['answer']!.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFAQs = _filteredFAQs;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Text(
              'Frequently Asked Questions',
              style: AppTheme.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          FadeInDown(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Find answers to commonly asked questions about the Digital Certificate Repository.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXL),
          
          if (filteredFAQs.isEmpty) ...[
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No FAQs found matching "${widget.searchQuery}"',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...List.generate(filteredFAQs.length, (index) {
              return FadeInUp(
                delay: Duration(milliseconds: 200 + (index * 100)),
                child: _buildFAQItem(index, filteredFAQs[index]),
              );
            }),
          ],
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: Duration(milliseconds: 200 + (filteredFAQs.length * 100)),
            child: _buildContactSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(int index, Map<String, String> faq) {
    final isExpanded = _expandedIndex == index;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: isExpanded 
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.dividerColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppTheme.mediumRadius,
        child: ExpansionTile(
          title: Text(
            faq['question']!,
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isExpanded ? AppTheme.primaryColor : AppTheme.textPrimary,
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isExpanded 
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : AppTheme.textSecondary.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
            ),
            child: Icon(
              Icons.help_outline,
              color: isExpanded ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: isExpanded ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedIndex = expanded ? index : null;
            });
          },
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: isExpanded 
                    ? AppTheme.primaryColor.withValues(alpha: 0.05)
                    : AppTheme.surfaceColor,
              ),
              child: Text(
                faq['answer']!,
                style: AppTheme.bodyMedium.copyWith(
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.secondaryColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: AppTheme.mediumRadius,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.smallRadius,
                ),
                child: const Icon(
                  Icons.contact_support,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Still have questions?',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXS),
                    Text(
                      'Can\'t find what you\'re looking for? Our support team is here to help.',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Open contact support dialog
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to help center
                  },
                  icon: const Icon(Icons.help_center),
                  label: const Text('Help Center'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    foregroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 