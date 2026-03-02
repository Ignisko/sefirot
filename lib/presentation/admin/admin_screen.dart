import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../domain/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final myUserAsync = ref.watch(currentUserModelProvider);

    return myUserAsync.when(
      data: (myUser) {
        if (myUser == null || !myUser.isAdmin) {
          return const Scaffold(
            body: Center(child: Text('Access Denied. Admins only.')),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            title: Text('Admin Control Panel',
                style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            actions: [
               Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Text('ADMIN MODE',
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              _buildStats(context),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search all users...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(child: _UserList(searchQuery: _searchQuery)),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildStats(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final users = snapshot.data!.docs;
        final total = users.length;
        final onboarded = users.where((d) => (d.data() as Map)['isOnboarded'] == true).length;
        final banned = users.where((d) => (d.data() as Map)['isBanned'] == true).length;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: 'Total Users', value: '$total'),
              _StatItem(label: 'Onboarded', value: '$onboarded'),
              _StatItem(label: 'Banned', value: '$banned', color: Colors.red),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color ?? Theme.of(context).colorScheme.onSurface)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }
}

class _UserList extends ConsumerWidget {
  final String searchQuery;
  const _UserList({required this.searchQuery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        
        final docs = snapshot.data!.docs;
        final users = docs.map((d) => UserModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .where((u) => u.displayName.toLowerCase().contains(searchQuery) || u.email.toLowerCase().contains(searchQuery))
            .toList();

        if (users.isEmpty) {
          return const Center(child: Text('No users matching search.'));
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, i) {
            final user = users[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                child: user.photoUrl.isEmpty ? Text(user.displayName.isNotEmpty ? user.displayName[0] : '?') : null,
              ),
              title: Text(user.displayName.isNotEmpty ? user.displayName : user.email,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('${user.accountType} • ${user.city.isNotEmpty ? user.city : "No city"}',
                  style: const TextStyle(fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.isAdmin)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.verified_user, color: Colors.blue, size: 16),
                    ),
                  Switch(
                    value: user.isBanned,
                    activeColor: Colors.red,
                    onChanged: (val) async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(val ? 'Ban User?' : 'Unban User?'),
                          content: Text('Are you sure you want to ${val ? 'ban' : 'unban'} ${user.displayName}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: val ? Colors.red : Colors.green),
                              child: Text(val ? 'Ban' : 'Unban'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        FirebaseFirestore.instance.collection('users').doc(user.uid).update({'isBanned': val});
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
