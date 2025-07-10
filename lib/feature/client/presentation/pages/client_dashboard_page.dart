import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../certificates/providers/certificate_providers.dart';

class ClientDashboardPage extends ConsumerStatefulWidget {
  const ClientDashboardPage({super.key});

  @override
  ConsumerState<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends ConsumerState<ClientDashboardPage> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(draftCertificatesProvider);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🎓 Pending Certificates'),
        backgroundColor: Colors.deepPurple.shade700,
        elevation: 8,
        shadowColor: Colors.black54,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: () => ref.refresh(draftCertificatesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'More Settings',
            onPressed: () {
              _showExtraSettings(context);
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFE1BEE7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildWelcomeBanner(),
            _buildSearchBar(),
            _buildStatsBanner(),
            Expanded(
              child: draftAsync.when(
                data: (certs) {
                  final filtered = certs
                      .where((c) => c.title.toLowerCase().contains(searchQuery.toLowerCase()))
                      .toList();
                  if (filtered.isEmpty) {
                    return _buildEmptyView();
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildCertificateCard(context, ref, filtered[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMockCertificate,
        icon: const Icon(Icons.add),
        label: const Text("Add Mock"),
        backgroundColor: Colors.deepPurple.shade400,
        elevation: 6,
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Colors.deepPurple.shade50,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, size: 32, color: Colors.deepPurple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Welcome back! Review and approve pending certificates below.",
                  style: TextStyle(fontSize: 16, color: Colors.deepPurple.shade900),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard("Total", Icons.description, Colors.indigo, 12),
          _buildStatCard("Approved", Icons.check_circle, Colors.green, 5),
          _buildStatCard("Pending", Icons.hourglass_empty, Colors.orange, 7),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, IconData icon, Color color, int count) {
    return Column(
      children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 4),
        Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Search by title or recipient...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            fillColor: Colors.white,
            filled: true,
          ),
          onChanged: (value) => setState(() => searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
              ),
            ),
            child: Center(
              child: Text(
                '🎓 Client Menu',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _drawerItem(Icons.dashboard, 'Dashboard', () => Navigator.pop(context)),
          _drawerItem(Icons.history, 'Activity Logs', () {}),
          _drawerItem(Icons.notifications, 'Notifications', () {}),
          _drawerItem(Icons.settings, 'Account Settings', () {}),
          _drawerItem(Icons.logout, 'Logout', () {
            Navigator.pop(context);
            _showLogoutDialog(context);
          }),
        ],
      ),
    );
  }


  
  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurple),
      title: Text(title),
      onTap: onTap,
      hoverColor: Colors.deepPurple.shade50,
    );
  }


  
  Widget _buildCertificateCard(BuildContext context, WidgetRef ref, CertificateModel cert) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurple.shade100,
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cert.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Recipient: ${cert.recipientName}',
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.flag, size: 18, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Status: ${cert.status}',
                        style: TextStyle(
                            fontSize: 14,
                            color: cert.status == CertificateStatus.issued.name
                                ? Colors.green
                                : Colors.orange)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _approveCertificate(context, ref, cert.id),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _showCertificateDetails(context, cert),
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Details'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.inbox, size: 80, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No draft certificates found.',
            style: TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ],
      ),
    );
  }
  Future<void> _approveCertificate(BuildContext context, WidgetRef ref, String certId) async {
    try {
      final user = ref.read(currentUserProvider).value!;
      await FirebaseFirestore.instance
          .collection(AppConfig.certificatesCollection)
          .doc(certId)
          .update({
        'status': CertificateStatus.issued.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': user.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Certificate approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to approve: $err'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCertificateDetails(BuildContext context, CertificateModel cert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(cert.recipientName),
              subtitle: const Text('Recipient'),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: Text(cert.description ?? "No description"),
              subtitle: const Text('Description'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: Text(cert.status),
              subtitle: const Text('Status'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }




  
  void _createMockCertificate() {
    final random = Random();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final cert = CertificateModel(
      id: id,
      title: 'Mock Certificate ${random.nextInt(1000)}',
      recipientName: 'User ${random.nextInt(100)}',
      status: CertificateStatus.draft,
      description: 'Generated mock certificate for testing.',
    );
    FirebaseFirestore.instance
        .collection(AppConfig.certificatesCollection)
        .doc(id)
        .set(cert.toJson());
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Add actual logout logic here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showExtraSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🔧 Extra Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Theme Settings'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Security Preferences'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Check for Updates'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & Feedback'),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }


    Widget _buildRecentActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildActionItem('Approved Certificate 101', '2 minutes ago'),
          _buildActionItem('Viewed Certificate 88', '5 minutes ago'),
          _buildActionItem('Generated Mock Certificate', '10 minutes ago'),
        ],
      ),
    );
  }

  Widget _buildActionItem(String action, String timeAgo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.deepPurple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              action,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            timeAgo,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.deepPurple.shade100),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.shade50,
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📅 Certificate Timeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTimelineItem('Draft Created', 'July 1, 2025', Icons.edit_document),
          _buildTimelineItem('Viewed by Admin', 'July 2, 2025', Icons.visibility),
          _buildTimelineItem('Approved', 'July 3, 2025', Icons.verified),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String label, String date, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.deepPurple.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            date,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFakeGraphCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade100.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Center(
        child: Text(
          '📈 Chart Placeholder\n(Coming Soon)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.deepPurple.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLongTextFiller() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus efficitur neque a erat pulvinar '
        'tempor. Sed blandit, justo eget commodo ullamcorper, turpis ligula fringilla ex, sed vestibulum libero '
        'tortor a orci. Curabitur eget imperdiet massa. Vestibulum sodales, nunc nec hendrerit tempus, metus '
        'metus tincidunt nulla, sit amet eleifend enim sapien id erat. Pellentesque nec erat tellus. Morbi et '
        'libero metus. Proin ac purus justo. Suspendisse eu rutrum sem. Donec gravida, velit eget tempor finibus, '
        'eros nulla bibendum neque, ut lacinia velit ipsum ac arcu. Etiam imperdiet nibh nec mi lacinia fermentum. '
        'Nulla imperdiet purus vel nulla accumsan, sit amet vehicula sem tempor. Morbi fermentum tellus et augue '
        'interdum volutpat.',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      ),
    );
  }





