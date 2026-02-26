import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/constants/languages.dart';
import '../../domain/models/user_model.dart';

// ── Seoul 2027 Palette ────────────────────────────────────────────────────────






const _countries = [
  '🇦🇺 Australia', '🇦🇹 Austria', '🇧🇷 Brazil', '🇨🇦 Canada',
  '🇨🇱 Chile', '🇨🇳 China', '🇨🇴 Colombia', '🇨🇷 Costa Rica',
  '🇨🇿 Czech Republic', '🇩🇰 Denmark', '🇩🇴 Dominican Republic',
  '🇪🇨 Ecuador', '🇪🇬 Egypt', '🇸🇻 El Salvador', '🇫🇮 Finland',
  '🇫🇷 France', '🇩🇪 Germany', '🇬🇭 Ghana', '🇬🇷 Greece',
  '🇬🇹 Guatemala', '🇭🇳 Honduras', '🇭🇺 Hungary', '🇮🇳 India',
  '🇮🇩 Indonesia', '🇮🇪 Ireland', '🇮🇱 Israel', '🇮🇹 Italy',
  '🇯🇵 Japan', '🇰🇪 Kenya', '🇰🇷 South Korea', '🇲🇽 Mexico',
  '🇳🇱 Netherlands', '🇳🇿 New Zealand', '🇳🇬 Nigeria', '🇳🇴 Norway',
  '🇵🇦 Panama', '🇵🇾 Paraguay', '🇵🇪 Peru', '🇵🇭 Philippines',
  '🇵🇱 Poland', '🇵🇹 Portugal', '🇷🇴 Romania', '🇷🇺 Russia',
  '🇸🇬 Singapore', '🇿🇦 South Africa', '🇪🇸 Spain', '🇸🇪 Sweden',
  '🇨🇭 Switzerland', '🇹🇼 Taiwan', '🇹🇭 Thailand', '🇹🇷 Turkey',
  '🇺🇦 Ukraine', '🇬🇧 United Kingdom', '🇺🇸 United States',
  '🇺🇾 Uruguay', '🇻🇪 Venezuela', '🇻🇳 Vietnam',
];

final List<String> _languages = globalLanguages;

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
  'Military Ordinariate of Korea'
];

// ── Root Shell ────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const HomeScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserModelProvider);
    final isAdmin = userAsync.value?.isAdmin ?? false;

    // Banned state and Onboarding state are now handled securely by GoRouter in app_router.dart

    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    if (isWide) {
      return _DesktopShell(
        navigationShell: navigationShell,
        isAdmin: isAdmin,
      );
    }

    // Mobile: bottom nav
    final destinations = [
      const NavigationDestination(icon: Text('🏠', style: TextStyle(fontSize: 18)), label: 'Home'),
      const NavigationDestination(icon: Text('🔍', style: TextStyle(fontSize: 18)), label: 'Browse'),
      const NavigationDestination(icon: Text('💬', style: TextStyle(fontSize: 18)), label: 'Messages'),
      const NavigationDestination(icon: Text('👤', style: TextStyle(fontSize: 18)), label: 'Profile'),
      if (isAdmin) const NavigationDestination(icon: Text('🛡️', style: TextStyle(fontSize: 18)), label: 'Admin'),
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
  final bool isAdmin;
  const _DesktopShell({required this.navigationShell, required this.isAdmin});

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
                      isAdmin: isAdmin,
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
  final bool isAdmin;
  const _Sidebar({required this.user, required this.currentTab, required this.onTabChange, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completionTasks = [
      ('Add a profile photo', user.photoUrl.isNotEmpty),
      ('Write your bio', user.bio.isNotEmpty),
      ('Set your nationality', user.nationality.isNotEmpty),
      ('Add languages', user.languages.isNotEmpty),
    ];
    final done = completionTasks.where((t) => t.$2).length;
    final isComplete = done == completionTasks.length;

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
        Padding(
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
                          ? 'Volunteer 🤝'
                          : 'Pilgrim 🙏',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Profile completion
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isComplete ? 'Profile Complete 🎉' : 'Complete your profile',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isComplete ? const Color(0xFF2E7D32) : Colors.black38,
                      letterSpacing: 0.8)),
              if (!isComplete) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: done / completionTasks.length,
                    color: Theme.of(context).colorScheme.secondary,
                    backgroundColor: Colors.black12,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                ...completionTasks.map((t) => _CheckItem(
                    label: t.$1, 
                    done: t.$2,
                    onTap: t.$2 ? null : () => onTabChange(3),
                )),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),

        // Navigation items
        _NavItem(
            label: 'Dashboard',
            selected: currentTab == 0,
            onTap: () => onTabChange(0)),
        _NavItem(
            label: 'Browse Pilgrims',
            selected: currentTab == 1,
            onTap: () => onTabChange(1)),
        _NavItem(
            label: 'Messages',
            selected: currentTab == 2,
            onTap: () => onTabChange(2)),
        _NavItem(
            label: 'My Profile',
            selected: currentTab == 3,
            onTap: () => onTabChange(3)),
        if (isAdmin) ...[
          _NavItem(
              label: 'Admin Dashboard',
              selected: currentTab == 4,
              onTap: () => onTabChange(4)),
        ],

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
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
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

class _CheckItem extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback? onTap;
  const _CheckItem({required this.label, required this.done, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                border: Border.all(
                    color: done ? Theme.of(context).colorScheme.secondary : Colors.black26, width: 1.5),
              ),
              child: done
                  ? Center(
                      child: Text('✓',
                          style: TextStyle(
                              color: Theme.of(context).cardColor, fontSize: 8,
                              fontWeight: FontWeight.bold)))
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: done ? Colors.black45 : Theme.of(context).colorScheme.secondary,
                      fontWeight: done ? FontWeight.normal : FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null)),
            ),
            if (!done)
               const Icon(Icons.arrow_forward_ios, size: 8, color: Colors.black26),
          ],
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
          // ── Header card ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                _BigAvatar(user: user),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName.isNotEmpty
                            ? user.displayName
                            : user.email.split('@').first,
                        style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Badge(
                              label: user.accountType == 'volunteer'
                                  ? 'Volunteer'
                                  : 'Pilgrim',
                              color: user.accountType == 'volunteer'
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.secondary),
                          if (user.nationality.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('· ${user.nationality}',
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.black45)),
                          ],
                        ],
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(user.bio,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.4)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Edit sections ─────────────────────────────────────────
          _EditCard(
            title: 'About',
            onEdit: () => _openEdit(context, user, _EditField.bio),
            child: user.bio.isNotEmpty
                ? Text(user.bio,
                    style: const TextStyle(
                        color: Colors.black87, fontSize: 14, height: 1.5))
                : const Text('Add a bio to help pilgrims find you...',
                    style: TextStyle(color: Colors.black38, fontSize: 14)),
          ),
          const SizedBox(height: 12),
          _EditCard(
            title: 'Role, Nationality & Diocese',
            onEdit: () =>
                _openEdit(context, user, _EditField.roleNatDioc),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Badge(
                    label: user.accountType == 'volunteer'
                        ? 'Volunteer 🤝'
                        : 'Pilgrim 🙏',
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
            title: 'Languages  ${user.languages.length}/7',
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
          const SizedBox(height: 24),

          // ── Stats row ─────────────────────────────────────────────
          Row(children: const [
            _StatCard(label: 'Connections', value: '0', emoji: '🤝'),
            SizedBox(width: 12),
            _StatCard(label: 'Messages', value: '0', emoji: '💬'),
            SizedBox(width: 12),
            _StatCard(label: 'Matches', value: '0', emoji: '✨'),
          ]),
          const SizedBox(height: 24),

          // ── Settings ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w500)),
              secondary: Icon(
                  ref.watch(themeProvider) == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(context).colorScheme.primary),
              value: ref.watch(themeProvider) == ThemeMode.dark,
              onChanged: (val) {
                ref.read(themeProvider.notifier).toggleTheme(val);
              },
            ),
          ),
        ],
      ),
    );
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
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery, 
      imageQuality: 75,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('avatars/${widget.user.uid}');
      await storageRef.putData(bytes, SettableMetadata(contentType: mimeType));
      final url = await storageRef.getDownloadURL();
      await ref.read(userRepositoryProvider).updateUser(widget.user.copyWith(photoUrl: url));
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
                Text('Edit →',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600)),
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

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, emoji;
  const _StatCard({required this.label, required this.value, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Colors.black38)),
          ],
        ),
      ),
    );
  }
}

// ── Edit field enum + bottom sheet ───────────────────────────────────────────
enum _EditField { bio, roleNatDioc, languages }

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
  late String _role;
  late String _nationality;
  late String _diocese;
  late List<String> _langs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName);
    _bioCtrl = TextEditingController(text: widget.user.bio);
    _countrySearch = TextEditingController();
    _role = widget.user.accountType;
    _nationality = widget.user.nationality;
    _diocese = widget.user.diocese;
    _langs = List.from(widget.user.languages);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _countrySearch.dispose();
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
    };

    return Padding(
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
            TextField(
              controller: _bioCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: _dec('Your bio'),
            ),
          ],

          if (widget.field == _EditField.roleNatDioc) ...[
            const _Label('Role'),
            const SizedBox(height: 8),
            Row(children: [
              _RoleToggle(
                  label: 'Pilgrim 🙏',
                  selected: _role == 'pilgrim',
                  onTap: () => setState(() => _role = 'pilgrim')),
              const SizedBox(width: 10),
              _RoleToggle(
                  label: 'Volunteer 🤝',
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
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _languages.map((lang) {
                    final sel = _langs.contains(lang);
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
                                sel ? _langs.remove(lang) : _langs.add(lang);
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
