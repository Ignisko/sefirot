import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/report_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../domain/models/report_model.dart';
// ── Providers ──────────────────────────────────────────────────────────
final _userCountProvider = StreamProvider.autoDispose<int>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((s) => s.docs.length);
});

// ── Admin Dashboard ───────────────────────────────────────────────────
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(pendingReportsProvider);
    final usersAsync = ref.watch(_userCountProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text('Admin Dashboard',
            style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row
            Row(children: [
              _StatCard(title: 'Total Users', value: usersAsync.whenOrNull(data: (v) => '$v') ?? '...'),
              const SizedBox(width: 16),
              _StatCard(title: 'Pending Reports', value: '${reportsAsync.whenOrNull(data: (v) => v.length) ?? '...'}'),
            ]),
            const SizedBox(height: 32),
            
            Text('Pending Reports',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),

            reportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (reports) {
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('All clear! No pending reports 😇'),
                  );
                }
                return Column(
                  children: reports.map((r) => _ReportCard(report: r)).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.black45)),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  final ReportModel report;
  const _ReportCard({required this.report});

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(userRepositoryProvider).dismissReport(report.id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report dismissed')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _banUser(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ban User?'),
        content: const Text('This will immediately lock the user out of the app. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final adminUid = ref.read(authRepositoryProvider).currentUser?.uid ?? '';
      await ref.read(userRepositoryProvider).banUser(adminUid, report.reportedUid, report.id);

      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User Banned')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ts = report.timestamp;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('Reason: ${report.reason}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold))),
              const Spacer(),
              if (ts != null) Text('${ts.month}/${ts.day} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ],
          ),
          const SizedBox(height: 12),
          Text('Reported UID: ${report.reportedUid}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          Text('Reporter UID: ${report.reporterUid}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black45)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _dismiss(context, ref),
                child: const Text('Dismiss', style: TextStyle(color: Colors.black54)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _banUser(context, ref),
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, elevation: 0),
                child: const Text('Ban User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
