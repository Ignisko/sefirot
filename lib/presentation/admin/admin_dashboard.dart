import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/report_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../domain/models/report_model.dart';
import '../../domain/models/user_model.dart';

// ── Providers ──────────────────────────────────────────────────────────
final _userStatsProvider = StreamProvider.autoDispose<Map<String, int>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((s) {
    int total = s.docs.length;
    int onboarded = 0;
    int banned = 0;
    for (var doc in s.docs) {
      final data = doc.data();
      if (data['isOnboarded'] == true) onboarded++;
      if (data['isBanned'] == true) banned++;
    }
    return {
      'total': total,
      'onboarded': onboarded,
      'banned': banned,
    };
  });
});

// ── Admin Dashboard ───────────────────────────────────────────────────
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _userSearch = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myUserAsync = ref.watch(currentUserModelProvider);
    
    return myUserAsync.when(
      data: (myUser) {
        if (myUser == null || !myUser.isAdmin) {
          return const Scaffold(body: Center(child: Text('Access Denied.')));
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            title: Text('Admin Panel',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            bottom: TabBar(
              controller: _tabCtrl,
              labelColor: Theme.of(context).colorScheme.secondary,
              unselectedLabelColor: Colors.black38,
              indicatorColor: Theme.of(context).colorScheme.secondary,
              tabs: const [
                Tab(text: 'Reports & Metrics'),
                Tab(text: 'Users'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _ReportsTab(),
              _UsersTab(searchQuery: _userSearch, onSearch: (v) => setState(() => _userSearch = v)),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(pendingReportsProvider);
    final statsAsync = ref.watch(_userStatsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('Platform Metrics', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              _StatCard(title: 'Total Users', value: statsAsync.whenOrNull(data: (s) => '${s['total']}') ?? '...'),
              const SizedBox(width: 12),
              _StatCard(title: 'Fully Onboarded', value: statsAsync.whenOrNull(data: (s) => '${s['onboarded']}') ?? '...'),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _StatCard(title: 'Banned Users', value: statsAsync.whenOrNull(data: (s) => '${s['banned']}') ?? '...', iconColor: Colors.red),
              const SizedBox(width: 12),
              _StatCard(title: 'Pending Reports', value: '${reportsAsync.whenOrNull(data: (v) => v.length) ?? '...'}', iconColor: Colors.orange),
            ]),
            const SizedBox(height: 16),
            // Seed button only shown in debug builds — never ship this to production
            if (kDebugMode)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _seedData(context),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Seed Test Users (Debug Only)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
          const SizedBox(height: 32),
          Text('Report Queue',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (reports) {
              if (reports.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('All clear! No pending reports 😇', style: TextStyle(color: Colors.black38))),
                );
              }
              return Column(
                children: reports.map((r) => _ReportCard(report: r)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _seedData(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final users = [
        {
          'displayName': 'Thomas (Test)',
          'email': 'thomas@test.com',
          'accountType': 'pilgrim',
          'nationality': 'Germany',
          'city': 'Berlin',
          'bio': 'Test user for pilgrims browse. Looking forward to Seoul 2027!',
          'isOnboarded': true,
          'age': 25,
          'isBanned': false,
          'languages': ['English', 'German'],
        },
        {
          'displayName': 'Maria (Test)',
          'email': 'maria@test.com',
          'accountType': 'volunteer',
          'nationality': 'Poland',
          'city': 'Krakow',
          'bio': 'Volunteer from Poland. I can help with directions!',
          'isOnboarded': true,
          'age': 30,
          'isBanned': false,
          'languages': ['Polish', 'English', 'Italian'],
        },
        {
          'displayName': 'John (Test)',
          'email': 'john@test.com',
          'accountType': 'pilgrim',
          'nationality': 'USA',
          'city': 'New York',
          'bio': 'Planning my first pilgrimage. Would love to join a group.',
          'isOnboarded': true,
          'age': 22,
          'isBanned': false,
          'languages': ['English', 'Spanish'],
        }
      ];

      for (var u in users) {
        final id = 'test_${u['displayName'].toString().replaceAll(' ', '_').toLowerCase().replaceAll('_(test)', '')}';
        batch.set(FirebaseFirestore.instance.collection('users').doc(id), {
          ...u,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': id,
          'photoUrl': '',
          'blockedUids': [],
          'lat': 52.52 + (users.indexOf(u) * 0.1),
          'lng': 13.40 + (users.indexOf(u) * 0.1),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Test users seeded successfully!')));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Seeding failed: $e')));
    }
  }
}

class _UsersTab extends ConsumerWidget {
  final String searchQuery;
  final ValueChanged<String> onSearch;
  const _UsersTab({required this.searchQuery, required this.onSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => onSearch(v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search email or name...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              final users = docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
                  .where((u) => u.displayName.toLowerCase().contains(searchQuery) || u.email.toLowerCase().contains(searchQuery))
                  .toList();

              return ListView.builder(
                itemCount: users.length,
                padding: const EdgeInsets.only(bottom: 20),
                itemBuilder: (context, i) {
                  final user = users[i];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                      child: user.photoUrl.isEmpty ? Text(user.displayName.isNotEmpty ? user.displayName[0] : '?') : null,
                    ),
                    title: Text(user.displayName.isNotEmpty ? user.displayName : user.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('${user.accountType} • ${user.city.isNotEmpty ? user.city : "No city"}', style: const TextStyle(fontSize: 11)),
                    trailing: Switch(
                      value: user.isBanned,
                      activeThumbColor: Colors.red,
                      onChanged: (val) async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(val ? 'Ban User?' : 'Unban User?'),
                            content: Text('Confirm ${val ? 'banning' : 'unbanning'} ${user.displayName}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isBanned': val});
                        }
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value;
  final Color? iconColor;
  const _StatCard({required this.title, required this.value, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.secondary;
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
            Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ban User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
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
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Text('Reason: ${report.reason}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold))),
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
