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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Certificates'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.refresh(draftCertificatesProvider);
            },
          )
        ],
      ),
      drawer: _buildDrawer(context),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.purpleAccent],
          ),
        ),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: draftAsync.when(
                data: (certs) {
                  final filtered = certs.where((c) => c.title.toLowerCase().contains(searchQuery.toLowerCase())).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No draft certificates match your search.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final cert = filtered[i];
                      return _buildCertificateCard(context, ref, cert);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createMockCertificate,
        child: const Icon(Icons.add),
        backgroundColor: Colors.deepPurple,
        tooltip: 'Add Mock Certificate',
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search by title...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text('Client Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(BuildContext context, WidgetRef ref, CertificateModel cert) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cert.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Recipient: ${cert.recipientName}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text('Status: ${cert.status}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _approveCertificate(context, ref, cert.id),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showCertificateDetails(context, cert),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Details'),
                  )
                ],
              )
            ],
          ),
        ),
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
        const SnackBar(content: Text('Certificate approved')),
      );
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $err')),
      );
    }
  }

  void _showCertificateDetails(BuildContext context, CertificateModel cert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cert.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Recipient: ${cert.recipientName}'),
            Text('Status: ${cert.status}'),
            const SizedBox(height: 12),
            Text('Description: ${cert.description ?? "N/A"}'),
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
      description: 'This is a mock certificate generated for testing.',
    );
    FirebaseFirestore.instance
        .collection(AppConfig.certificatesCollection)
        .doc(id)
        .set(cert.toJson());
  }
}
