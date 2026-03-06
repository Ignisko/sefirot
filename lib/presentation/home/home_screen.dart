// Removed dart:html to fix Windows build crash
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import '../../core/services/location_service.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/constants/languages.dart';
import '../../core/constants/countries.dart';

import '../../domain/models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Seoul 2027 Palette ────────────────────────────────────────────────────────






// ── Firebase Storage bucket ──────────────────────────────────────────────────
const _storageBucket = 'sefirot-ff9af.firebasestorage.app';

// ── Country list ──────────────────────────────────────────────────
final List<String> _countries = globalCountries;


const _dioceses = [
  'Archdiocese of Seoul',
  'Diocese of Daejeon',
  'Diocese of Suwon',
  'Diocese of Incheon',
  'Diocese of Chuncheon',
  'Diocese of Wonju',
  'Diocese of Uijeongbu',
  'Archdiocese of Daegu',
  'Diocese of Busan',
  'Diocese of Cheongju',
  'Diocese of Masan',
  'Diocese of Andong',
  'Archdiocese of Gwangju',
  'Diocese of Jeonju',
  'Diocese of Jeju',
];

// ── Root Shell ────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const HomeScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Banned state and Onboarding state are now handled securely by GoRouter in app_router.dart

    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    if (isWide) {
      return _DesktopShell(
        navigationShell: navigationShell,
      );
    }

    // Mobile: bottom nav
    final destinations = [
      const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      const NavigationDestination(icon: Icon(Icons.search_outlined), selectedIcon: Icon(Icons.search), label: 'Browse'),
      const NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
      const NavigationDestination(icon: Icon(Icons.info_outline), selectedIcon: Icon(Icons.info), label: 'About'),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) {
          navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          );
        },
        backgroundColor: Theme.of(context).cardColor,
        indicatorColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        destinations: destinations,
      ),
    );
  }
}

// ── Desktop Shell (sidebar layout) ───────────────────────────────────────────
class _DesktopShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const _DesktopShell({required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          // ── Left sidebar ─────────────────────────────────────────
          Container(
            width: 260,
            color: Theme.of(context).cardColor,
            child: userAsync.when(
              data: (user) => user == null
                  ? const SizedBox()
                  : _Sidebar(
                      user: user,
                      currentTab: navigationShell.currentIndex,
                      onTabChange: (i) => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ),

          // ── Divider ──────────────────────────────────────────────
          Container(width: 1, color: Colors.black.withValues(alpha: 0.06)),

          // ── Main content ─────────────────────────────────────────
          Expanded(
            child: navigationShell,
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends ConsumerWidget {
  final UserModel user;
  final int currentTab;
  final ValueChanged<int> onTabChange;
  const _Sidebar({required this.user, required this.currentTab, required this.onTabChange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            Container(width: 6, height: 22, color: Theme.of(context).colorScheme.primary, margin: const EdgeInsets.only(right: 4)),
            Container(width: 6, height: 22, color: Theme.of(context).colorScheme.secondary, margin: const EdgeInsets.only(right: 8)),
            Text('PELEGRIN',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Theme.of(context).colorScheme.onSurface)),
          ]),
        ),
        const Divider(height: 1),

        // Profile mini card
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTabChange(3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _SmallAvatar(user: user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _firstName(user),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.accountType == 'volunteer'
                              ? 'Volunteer'
                              : 'Pilgrim',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Divider(),

        // Navigation items
        _NavItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selected: currentTab == 0,
            onTap: () => onTabChange(0)),
        _NavItem(
            label: 'Browse',
            icon: Icons.people_outline,
            selected: currentTab == 1,
            onTap: () => onTabChange(1)),
        _NavItem(
            label: 'Messages',
            icon: Icons.chat_bubble_outline,
            selected: currentTab == 2,
            onTap: () => onTabChange(2)),
        _NavItem(
            label: 'My Profile',
            icon: Icons.person_outline,
            selected: currentTab == 3,
            onTap: () => onTabChange(3)),
        _NavItem(
            label: 'About',
            icon: Icons.info_outline,
            selected: currentTab == 4,
            onTap: () => onTabChange(4)),

        const Spacer(),
      ],
    );
  }

  String _firstName(UserModel u) {
    if (u.displayName.isNotEmpty) return u.displayName.split(' ').first;
    return u.email.split('@').first;
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.secondary
        : Colors.black54;

    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile Pane ──────────────────────────────────────────────────────────────
class ProfilePane extends ConsumerWidget {
  const ProfilePane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text('My Profile',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: false,
        // Only shown on mobile (desktop has sidebar)
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Sign out',
                style: TextStyle(color: Colors.black45, fontSize: 13)),
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          return _ProfileContent(user: user);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  final UserModel user;
  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                _BigAvatar(user: user),
                const SizedBox(height: 16),
                Text(
                  user.displayName.isNotEmpty
                      ? user.displayName
                      : user.email.split('@').first,
                  style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // ── EDIT PROFILE SECTION ─────────────────────────────────
          Text('EDIT PROFILE',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.black38)),
          const SizedBox(height: 16),
          _EditCard(
            title: 'ABOUT ME',
            onEdit: () => _openEdit(context, user, _EditField.bio),
            child: Text(
              user.bio.isEmpty ? 'No bio yet. Tap to add one!' : user.bio,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          _EditCard(
            title: 'ROLE & DIOCESE',
            onEdit: () => _openEdit(context, user, _EditField.roleNatDioc),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(
                    label: user.accountType == 'volunteer'
                        ? 'Volunteer'
                        : 'Pilgrim',
                    color: user.accountType == 'volunteer' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary),
                if (user.nationality.isNotEmpty)
                  _Badge(label: user.nationality, color: Colors.black54),
                if (user.diocese.isNotEmpty)
                  _Badge(label: user.diocese, color: const Color(0xFF2E7D32)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _EditCard(
            title: 'LANGUAGES',
            onEdit: () => _openEdit(context, user, _EditField.languages),
            child: user.languages.isEmpty
                ? const Text('Add languages you speak...',
                    style: TextStyle(color: Colors.black38, fontSize: 14))
                : Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: user.languages
                        .map((l) => _Badge(label: l, color: Theme.of(context).colorScheme.secondary))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _EditCard(
            title: 'LOCATION',
            onEdit: () => _openEdit(context, user, _EditField.location),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: Colors.black38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.city.isNotEmpty ? user.city : 'Set your city...',
                    style: TextStyle(
                        color: user.city.isNotEmpty ? Colors.black87 : Colors.black38,
                        fontSize: 14),
                  ),
                ),
                if (user.lat != null && user.lng != null)
                  _Badge(label: 'Fixed Location', color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // ── SETTINGS SECTION ─────────────────────────────────────
          Text('PREFERENCES',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.black38)),
          const SizedBox(height: 16),
          _EditCard(
            title: 'AGE PREFERENCES',
            onEdit: () => _openEdit(context, user, _EditField.agePreferences),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 16, color: Colors.black38),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Looking for pilgrims between ${(user.targetMinAge ?? 18)} and ${(user.targetMaxAge ?? 100)}',
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          Text('SETTINGS',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.black38)),
          const SizedBox(height: 16),
          
          // Footer Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://pelegrin.cloud/terms'), mode: LaunchMode.externalApplication),
                child: const Text('Terms', style: TextStyle(fontSize: 13, color: Colors.black45)),
              ),
              const Text('•', style: TextStyle(color: Colors.black12)),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://pelegrin.cloud/privacy'), mode: LaunchMode.externalApplication),
                child: const Text('Privacy', style: TextStyle(fontSize: 13, color: Colors.black45)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Delete Account Link
          Center(
            child: TextButton(
              onPressed: () => _confirmDeleteAccount(context, ref, user),
              child: const Text(
                'Delete Account',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext ctx, WidgetRef ref, UserModel user) async {
    final deleteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is PERMANENT and cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Your profile will be erased\n• Your messages will be deleted\n• Your matches will be removed',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            const Text('Please type "DELETE" below to confirm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: deleteCtrl,
              decoration: InputDecoration(
                hintText: 'DELETE',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: deleteCtrl,
            builder: (context, value, child) {
              final isMatch = value.text.trim().toUpperCase() == 'DELETE';
              return TextButton(
                onPressed: isMatch ? () => Navigator.pop(c, true) : null,
                child: Text('Delete Permanently', 
                  style: TextStyle(
                    color: isMatch ? Colors.red : Colors.grey, 
                    fontWeight: FontWeight.bold
                  )
                ),
              );
            }
          ),
        ],
      ),
    );
    
    deleteCtrl.dispose();
    if (confirmed != true) return;
    try {
      // 1. Delete avatar from Firebase Storage (best effort)
      try {
        await FirebaseStorage.instance.ref('avatars/${user.uid}').delete();
      } catch (_) {
        // Avatar may not exist — ignore storage errors
      }
      // 2. Delete Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
      // 3. Delete Firebase Auth account
      await FirebaseAuth.instance.currentUser?.delete();
      // Note: chat records and messages require a Cloud Function for full cascade deletion.
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Deletion failed: $e. Please re-login and try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEdit(BuildContext ctx, UserModel user, _EditField field) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditSheet(user: user, field: field),
    );
  }
}

// ── Big Avatar with upload ────────────────────────────────────────────────────
class _BigAvatar extends ConsumerStatefulWidget {
  final UserModel user;
  const _BigAvatar({required this.user});

  @override
  ConsumerState<_BigAvatar> createState() => _BigAvatarState();
}

class _BigAvatarState extends ConsumerState<_BigAvatar> {
  bool _uploading = false;

  Future<void> _pick() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1000,
    );
    if (pickedFile == null) return;
    setState(() => _uploading = true);
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars/${widget.user.uid}');

      debugPrint('[PHOTO] Starting upload to avatars/${widget.user.uid}');
      
      String? url;
      
      final uploadBytes = await pickedFile.readAsBytes();
      final ext = p.extension(pickedFile.path).toLowerCase();
      final mimeType = (ext == '.png') ? 'image/png' : 'image/jpeg';

      if (!kIsWeb && Platform.isWindows) {
        // Use REST API on Windows to avoid firebase_storage C++ SDK crash
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final bucket = _storageBucket;
        final path = Uri.encodeComponent('avatars/${widget.user.uid}');
        final restUrl = Uri.parse('https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$path');

        final client = HttpClient();
        try {
          final request = await client.postUrl(restUrl);
          if (token != null) {
            request.headers.set('Authorization', 'Bearer $token');
          }
          request.headers.set('Content-Type', mimeType);
          request.add(uploadBytes);

          final response = await request.close();
          final responseString = await response.transform(utf8.decoder).join();

          if (response.statusCode == 200) {
            final js = jsonDecode(responseString);
            final downloadToken = js['downloadTokens'];
            url = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media&token=$downloadToken';
          } else {
            throw Exception('Upload failed: ${response.statusCode} $responseString');
          }
        } finally {
          client.close(); // Always close to prevent resource leak
        }
      } else {
        // Safe putData on all other platforms
        await storageRef.putData(uploadBytes, SettableMetadata(contentType: mimeType));
        url = await storageRef.getDownloadURL();
      }
      debugPrint('[PHOTO] Upload complete');
      await ref.read(userRepositoryProvider).updateUser(widget.user.copyWith(photoUrl: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated! ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.user.photoUrl;
    final initials = _init(widget.user);
    return GestureDetector(
      onTap: _pick,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
            backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
            child: url.isEmpty
                ? Text(initials,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary))
                : null,
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary, shape: BoxShape.circle),
              child: _uploading
                  ? SizedBox(
                      width: 10, height: 10,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                            color: Theme.of(context).cardColor, strokeWidth: 1.5)))
                  : Center(
                      child: Text('+',
                          style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold))),
            ),
          ),
        ],
      ),
    );
  }

  String _init(UserModel u) {
    if (u.displayName.isNotEmpty) {
      final p = u.displayName.trim().split(' ');
      return p.length >= 2
          ? '${p[0][0]}${p[1][0]}'.toUpperCase()
          : p[0][0].toUpperCase();
    }
    return u.email[0].toUpperCase();
  }
}

class _SmallAvatar extends ConsumerWidget {
  final UserModel user;
  const _SmallAvatar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = user.photoUrl;
    final init = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : user.email[0].toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(init,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, fontSize: 14))
          : null,
    );
  }
}

// ── Edit card — whole card is tappable ───────────────────────────────────────
class _EditCard extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onEdit;

  const _EditCard(
      {required this.title, required this.child, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black38,
                        letterSpacing: 0.8)),
                const Spacer(),
                Text('Edit',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Theme.of(context).colorScheme.secondary),
              ]),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}


// ── Edit field enum + bottom sheet ───────────────────────────────────────────
enum _EditField { bio, roleNatDioc, languages, location, agePreferences }

class _EditSheet extends ConsumerStatefulWidget {
  final UserModel user;
  final _EditField field;
  const _EditSheet({required this.user, required this.field});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _countrySearch;
  late TextEditingController _langSearch;
  late String _role;
  late String _nationality;
  late String _diocese;
  late List<String> _langs;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _ageCtrl;
  late double _targetMinAge;
  late double _targetMaxAge;
  String _gender = '';
  double? _lat;
  double? _lng;
  bool _saving = false;
  bool _refreshingLocation = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _countrySearch = TextEditingController();
    _langSearch = TextEditingController();
    _role = widget.user.accountType;
    _nationality = widget.user.nationality;
    _diocese = widget.user.diocese;
    _langs = List.from(widget.user.languages);
    _cityCtrl = TextEditingController(text: widget.user.city);
    _ageCtrl = TextEditingController(text: widget.user.age?.toString() ?? '');
    _targetMinAge = (widget.user.targetMinAge ?? 18).toDouble();
    _targetMaxAge = (widget.user.targetMaxAge ?? 100).toDouble();
    if (_targetMinAge < 18) _targetMinAge = 18;
    if (_targetMaxAge > 100) _targetMaxAge = 100;
    if (_targetMinAge > _targetMaxAge) _targetMinAge = _targetMaxAge;
    _gender = widget.user.gender;
    _lat = widget.user.lat;
    _lng = widget.user.lng;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _countrySearch.dispose();
    _langSearch.dispose();
    _cityCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateUser(widget.user.copyWith(
            displayName: _nameCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
            accountType: _role,
            nationality: _nationality,
            diocese: _diocese,
            languages: _langs,
            city: _cityCtrl.text.trim(),
            age: int.tryParse(_ageCtrl.text),
            targetMinAge: _targetMinAge.toInt(),
            targetMaxAge: _targetMaxAge.toInt(),
            gender: _gender,
            lat: _lat,
            lng: _lng,
          ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final titles = {
      _EditField.bio: 'Edit About',
      _EditField.roleNatDioc: 'Role, Nationality & Diocese',
      _EditField.languages: 'Languages',
      _EditField.location: 'Location & City',
      _EditField.agePreferences: 'Age preferences',
    };

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(titles[widget.field]!,
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 20),

          if (widget.field == _EditField.bio) ...[
            _inp(_nameCtrl, 'Display Name', Icons.person_outline),
            const SizedBox(height: 12),
            _inp(_ageCtrl, 'Age', Icons.calendar_today_outlined),
            const SizedBox(height: 12),
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: _dec('Your bio'),
            ),
            const SizedBox(height: 20),
            const _Label('Gender'),
            const SizedBox(height: 8),
            Row(children: [
              _RoleToggle(
                  label: 'Male',
                  selected: _gender == 'Male',
                  onTap: () => setState(() => _gender = 'Male')),
              const SizedBox(width: 10),
              _RoleToggle(
                  label: 'Female',
                  selected: _gender == 'Female',
                  onTap: () => setState(() => _gender = 'Female')),
              const SizedBox(width: 10),
              _RoleToggle(
                  label: 'Other',
                  selected: _gender == 'Other',
                  onTap: () => setState(() => _gender = 'Other')),
            ]),
          ],

          if (widget.field == _EditField.roleNatDioc) ...[
            const _Label('Role'),
            const SizedBox(height: 8),
            Row(children: [
              _RoleToggle(
                  label: 'Pilgrim',
                  selected: _role == 'pilgrim',
                  onTap: () => setState(() => _role = 'pilgrim')),
              const SizedBox(width: 10),
              _RoleToggle(
                  label: 'Volunteer',
                  selected: _role == 'volunteer',
                  onTap: () => setState(() => _role = 'volunteer')),
            ]),
            const SizedBox(height: 16),
            const _Label('Target Diocese (Seoul 2027)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _dioceses.map((d) {
                final sel = _diocese == d;
                return ChoiceChip(
                  label: Text(d, style: TextStyle(fontSize: 12, color: sel ? Theme.of(context).cardColor : Theme.of(context).colorScheme.onSurface)),
                  selected: sel,
                  onSelected: (b) => setState(() => _diocese = b ? d : ''),
                  selectedColor: const Color(0xFF2E7D32),
                  backgroundColor: Colors.black.withValues(alpha: 0.04),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Nationality'),
            const SizedBox(height: 8),
            if (_nationality.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3))),
                child: Row(children: [
                  Expanded(
                      child: Text(_nationality,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600))),
                  GestureDetector(
                    onTap: () => setState(() => _nationality = ''),
                    child: Icon(Icons.close, color: Theme.of(context).colorScheme.secondary, size: 16),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            TextField(
                controller: _countrySearch,
                decoration: _dec('Search country...')
                    .copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38)),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 4),
            SizedBox(
              height: 150,
              child: ListView(
                children: _countries
                    .where((c) => c.toLowerCase().contains(_countrySearch.text.toLowerCase()))
                    .map((c) => ListTile(
                          dense: true,
                          title: Text(c,
                              style: TextStyle(
                                  color: _nationality == c ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: _nationality == c
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 13)),
                          trailing: _nationality == c
                              ? Icon(Icons.check, color: Theme.of(context).colorScheme.secondary, size: 16)
                              : null,
                          onTap: () => setState(() {
                            _nationality = c;
                            _countrySearch.clear();
                            FocusScope.of(context).unfocus();
                          }),
                        ))
                    .toList(),
              ),
            ),
          ],

          if (widget.field == _EditField.languages) ...[
            Row(children: [
              const Expanded(
                  child: Text('Select up to 7',
                      style: TextStyle(color: Colors.black45, fontSize: 13))),
              _Badge(
                  label: '${_langs.length}/7',
                  color: _langs.length >= 7 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: _langSearch,
                decoration: _dec('Search language...')
                    .copyWith(prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38)),
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: globalLanguages
                      .where((l) => l.toLowerCase().contains(_langSearch.text.toLowerCase()))
                      .map((lang) {
                    final sel = _langs.contains(lang) || _langs.any((oldL) => lang.startsWith('$oldL ('));
                    final disabled = !sel && _langs.length >= 7;
                    return FilterChip(
                      label: Text(lang,
                          style: TextStyle(
                              fontSize: 12,
                              color: disabled
                                  ? Colors.black26
                                  : sel
                                      ? Theme.of(context).colorScheme.secondary
                                      : Theme.of(context).colorScheme.onSurface,
                              fontWeight: sel
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      selected: sel,
                      onSelected: disabled
                          ? null
                          : (_) => setState(() {
                                if (sel) {
                                  _langs.remove(lang);
                                  _langs.removeWhere((oldL) => lang.startsWith('$oldL ('));
                                } else {
                                  _langs.add(lang);
                                }
                              }),
                      selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
                      checkmarkColor: Theme.of(context).colorScheme.secondary,
                      side: BorderSide(
                          color: sel ? Theme.of(context).colorScheme.secondary : Colors.black12),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          if (widget.field == _EditField.location) ...[
            _inp(_cityCtrl, 'Chosen City', Icons.location_city),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  OutlinedButton.icon(
                    onPressed: _refreshingLocation ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() => _refreshingLocation = true);
                      final result = await LocationService.getLocation();
                      
                      if (!mounted) return;
                      
                      if (result.hasError) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(result.error!)),
                        );
                      } else {
                        setState(() {
                          _lat = result.lat;
                          _lng = result.lng;
                          if (result.city.isNotEmpty && result.city != 'Unknown') {
                            _cityCtrl.text = result.city;
                          }
                        });
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Precise location updated')),
                        );
                      }
                      
                      if (mounted) {
                        setState(() => _refreshingLocation = false);
                      }
                    },
                    icon: _refreshingLocation 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 16),
                    label: Text(_refreshingLocation ? 'Finding you...' : 'Refresh Precise Location'),
                  ),
                    if (_lat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Coordinates: ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
          ],

          if (widget.field == _EditField.agePreferences) ...[
            Text('Looking for pilgrims between ${_targetMinAge.toInt()} and ${_targetMaxAge.toInt()}', style: const TextStyle(color: Colors.black87, fontSize: 14)),
            const SizedBox(height: 24),
            RangeSlider(
              values: RangeValues(_targetMinAge, _targetMaxAge),
              min: 18,
              max: 100,
              divisions: 82,
              labels: RangeLabels('${_targetMinAge.toInt()}', '${_targetMaxAge.toInt()}'),
              activeColor: Theme.of(context).colorScheme.secondary,
              inactiveColor: Colors.black12,
              onChanged: (RangeValues values) {
                setState(() {
                  _targetMinAge = values.start;
                  _targetMaxAge = values.end;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Theme.of(context).cardColor, strokeWidth: 2))
                  : Text('Save Changes',
                      style: TextStyle(
                          color: Theme.of(context).cardColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _inp(TextEditingController c, String hint, IconData icon) =>
      TextField(
          controller: c,
          decoration: _dec(hint).copyWith(
              prefixIcon: Icon(icon, size: 18, color: Colors.black38)));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary)),
      );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54));
}

class _RoleToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Theme.of(context).colorScheme.secondary : Colors.black26, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Theme.of(context).cardColor : Colors.black54,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}
