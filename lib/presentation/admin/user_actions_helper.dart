import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/user_provider.dart';

class UserActionsHelper {
  /// Shows a bottom sheet with options to Block or Report the given user.
  static void showOptions(BuildContext context, WidgetRef ref, UserModel targetUser) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.black87),
              title: Text('Block ${_name(targetUser)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('You won\'t see them, and they won\'t see you.'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmBlock(context, ref, targetUser);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text('Report ${_name(targetUser)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Flag this profile for review by admins.'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context, ref, targetUser);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmBlock(BuildContext context, WidgetRef ref, UserModel targetUser) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${_name(targetUser)}?'),
        content: const Text('Once blocked, you will no longer see this user in your Browse queue or Messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Block', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myUid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(myUid).update({
        'blockedUids': FieldValue.arrayUnion([targetUser.uid]),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_name(targetUser)} blocked.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block: $e')),
        );
      }
    }
  }

  static void _showReportDialog(BuildContext context, WidgetRef ref, UserModel targetUser) {
    String selectedReason = 'Spam / Fake Profile';
    final reasons = [
      'Spam / Fake Profile',
      'Inappropriate Behavior / Harassment',
      'Off-Topic / Not a Pilgrim',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Report ${_name(targetUser)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Why are you reporting this user?', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              ...reasons.map((r) => RadioListTile<String>(
                    title: Text(r, style: const TextStyle(fontSize: 14)),
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (val) => setState(() => selectedReason = val!),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
                if (myUid == null) return;
                
                Navigator.pop(ctx);
                try {
                  await ref.read(userRepositoryProvider).reportUser(myUid, targetUser.uid, selectedReason);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Report submitted. Thank you for keeping the community safe.'),
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit report: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
              child: const Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static String _name(UserModel u) =>
      u.displayName.isNotEmpty ? u.displayName : u.email.split('@').first;
}
