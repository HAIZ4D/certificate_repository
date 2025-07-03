import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../certificates/providers/certificate_providers.dart';

class ClientDashboardPage extends ConsumerWidget {
  const ClientDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(draftCertificatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Certificates')),
      body: draftAsync.when(
        data: (certs) {
          if (certs.isEmpty) {
            return const Center(child: Text('No draft certificates.'));
          }
          return ListView.builder(
            itemCount: certs.length,
            itemBuilder: (_, i) {
              final cert = certs[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(cert.title),
                  subtitle: Text('Recipient: ${cert.recipientName}'),
                  trailing: ElevatedButton(
                    onPressed: () =>
                        _approveCertificate(context, ref, cert.id),
                    child: const Text('Approve'),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _approveCertificate(
      BuildContext context, WidgetRef ref, String certId) async {
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
}
