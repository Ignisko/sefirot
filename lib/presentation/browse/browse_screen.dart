import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/matchmaking_provider.dart';

import '../admin/user_actions_helper.dart';

// ── Palette ───────────────────────────────────────────────────────────────────






const _border = Color(0x0F000000);

// ── Provider ──────────────────────────────────────────────────────────────────
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList());
});

// ── Filter state ──────────────────────────────────────────────────────────────
class _Filters {
  final String search;
  final String intent;    // 'All' | 'Pilgrim' | 'Volunteer'
  final String language;  // '' = any
  final String country;   // '' = any
  final bool verifiedOnly;

  const _Filters({
    this.search = '',
    this.intent = 'All',
    this.language = '',
    this.country = '',
    this.verifiedOnly = false,
  });

  _Filters copyWith({
    String? search, String? intent, String? language,
    String? country, bool? verifiedOnly,
  }) => _Filters(
    search: search ?? this.search,
    intent: intent ?? this.intent,
    language: language ?? this.language,
    country: country ?? this.country,
    verifiedOnly: verifiedOnly ?? this.verifiedOnly,
  );
}

// ── Root browse widget ────────────────────────────────────────────────────────
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  _Filters _f = const _Filters();
  bool _filtersOpen = false; // mobile filter drawer

  void _setFilters(_Filters f) => setState(() => _f = f);
  void _toggleFilters() => setState(() => _filtersOpen = !_filtersOpen);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ── Desktop: sidebar filters + 3-col grid ─────────────────────────────────
  Widget _wideLayout() {
    return Row(children: [
      // Filter sidebar
      Container(
        width: 236,
        color: Theme.of(context).cardColor,
        child: _FilterPanel(filters: _f, onChange: _setFilters),
      ),
      const VerticalDivider(width: 1, color: _border),
      // Main content
      Expanded(
        child: Column(children: [
          _TopBar(
            filters: _f,
            onChange: _setFilters,
            showFilterBtn: false,
          ),
          Expanded(child: _PilgrimGrid(filters: _f)),
        ]),
      ),
    ]);
  }

  // ── Mobile: top bar + vertical list ──────────────────────────────────────
  Widget _narrowLayout() {
    return Column(children: [
      _TopBar(
        filters: _f,
        onChange: _setFilters,
        showFilterBtn: true,
        onFilterTap: _toggleFilters,
      ),
      // Collapsible filter chips
      AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        child: _filtersOpen
            ? Container(
                color: Theme.of(context).cardColor,
                child: _FilterPanel(filters: _f, onChange: _setFilters, compact: true),
              )
            : const SizedBox.shrink(),
      ),
      const Divider(height: 1, color: _border),
      Expanded(child: _PilgrimGrid(filters: _f, columns: 1)),
    ]);
  }
}

// ── Top bar: search + sort ────────────────────────────────────────────────────
class _TopBar extends StatefulWidget {
  final _Filters filters;
  final ValueChanged<_Filters> onChange;
  final bool showFilterBtn;
  final VoidCallback? onFilterTap;
  const _TopBar({
    required this.filters,
    required this.onChange,
    required this.showFilterBtn,
    this.onFilterTap,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.filters.search);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _ctrl,
              onChanged: (v) =>
                  widget.onChange(widget.filters.copyWith(search: v)),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search pilgrims...',
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text('🔍', style: TextStyle(fontSize: 15)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        if (widget.showFilterBtn) ...[ 
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              height: 40, width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('⚙️', style: TextStyle(fontSize: 18))),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Filter panel ──────────────────────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final _Filters filters;
  final ValueChanged<_Filters> onChange;
  final bool compact;

  const _FilterPanel({
    required this.filters,
    required this.onChange,
    this.compact = false,
  });

  static const _intents = ['All', 'Pilgrim', 'Volunteer'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[ 
            Text('Filters',
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 20),
          ],

          // Intent
          _FilterSection(
            label: 'Type',
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: _intents.map((t) {
                final sel = filters.intent == t;
                return GestureDetector(
                  onTap: () => onChange(filters.copyWith(intent: t)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                      border: Border.all(color: sel ? Theme.of(context).colorScheme.secondary : Colors.black26),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(t,
                        style: TextStyle(
                            fontSize: 12,
                            color: sel ? Theme.of(context).cardColor : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Language
          _FilterSection(
            label: 'Language',
            child: _DropdownFilter(
              value: filters.language,
              hint: 'Any language',
              items: const [
                'English', 'Spanish', 'Portuguese', 'French', 'Italian',
                'German', 'Polish', 'Korean', 'Japanese', 'Mandarin Chinese',
                'Arabic', 'Hindi', 'Russian', 'Dutch',
              ],
              onChanged: (v) => onChange(filters.copyWith(language: v ?? '')),
            ),
          ),

          const SizedBox(height: 16),

          // Country
          _FilterSection(
            label: 'Country',
            child: _TextFilter(
              value: filters.country,
              hint: 'Any country',
              onChanged: (v) => onChange(filters.copyWith(country: v)),
            ),
          ),

          const SizedBox(height: 16),

          // Verified only
          _FilterSection(
            label: 'Trust',
            child: Row(children: [
              GestureDetector(
                onTap: () => onChange(
                    filters.copyWith(verifiedOnly: !filters.verifiedOnly)),
                child: Container(
                  width: 36, height: 20,
                  decoration: BoxDecoration(
                    color: filters.verifiedOnly ? Theme.of(context).colorScheme.secondary : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 180),
                    alignment: filters.verifiedOnly
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 16, height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                          color: Theme.of(context).cardColor, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Verified only',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),

          if (!compact) ...[ 
            const SizedBox(height: 24),
            // Reset
            GestureDetector(
              onTap: () => onChange(const _Filters()),
              child: Text('Reset filters',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _FilterSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold,
                color: Colors.black38, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownFilter({
    required this.value, required this.hint,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      hint: Text(hint, style: const TextStyle(fontSize: 12, color: Colors.black38)),
      isDense: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any', style: TextStyle(fontSize: 12))),
        ...items.map((l) => DropdownMenuItem(
            value: l, child: Text(l, style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
    );
  }
}

class _TextFilter extends StatelessWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  const _TextFilter({required this.value, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.black38),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5)),
      ),
    );
  }
}

// ── Pilgrim grid / list ───────────────────────────────────────────────────────
class _PilgrimGrid extends ConsumerWidget {
  final _Filters filters;
  final int columns;
  const _PilgrimGrid({required this.filters, this.columns = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        final myUser = all.firstWhere((u) => u.uid == myUid, 
          orElse: () => UserModel(uid: myUid, email: '', displayName: '', photoUrl: '', accountType: 'pilgrim', bio: '', interests: [], languages: [], events: [], isOnboarded: true));
        final q = filters.search.toLowerCase();

        final users = all.where((u) {
          if (u.uid == myUid) return false;
          // Filtering blocked users
          if (myUser.blockedUids.contains(u.uid) || u.blockedUids.contains(myUid)) {
            return false;
          }
          if (filters.intent != 'All' &&
              u.accountType.toLowerCase() != filters.intent.toLowerCase()) {
            return false;
          }
          if (filters.language.isNotEmpty &&
              !u.languages.any((l) =>
                  l.toLowerCase().contains(filters.language.toLowerCase()))) {
            return false;
          }
          if (filters.country.isNotEmpty &&
              !u.nationality.toLowerCase().contains(filters.country.toLowerCase())) {
            return false;
          }
          if (q.isNotEmpty) {
            final match = u.displayName.toLowerCase().contains(q) ||
                u.nationality.toLowerCase().contains(q) ||
                u.bio.toLowerCase().contains(q) ||
                u.languages.any((l) => l.toLowerCase().contains(q));
            if (!match) return false;
          }
          return true;
        }).toList();

        if (users.isEmpty) {
          return _EmptyState();
        }

        final effectiveCols =
            columns == 1 ? 1 : (MediaQuery.of(context).size.width > 1100 ? 3 : 2);

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCols,
            childAspectRatio: effectiveCols == 1 ? 3.2 : 0.72,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: users.length,
          itemBuilder: (ctx, i) => effectiveCols == 1
              ? _PilgrimRowCard(user: users[i])
              : _PilgrimGridCard(user: users[i]),
        );
      },
    );
  }
}

// ── Grid card (desktop) ───────────────────────────────────────────────────────
class _PilgrimGridCard extends StatelessWidget {
  final UserModel user;
  const _PilgrimGridCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = _name(user);
    final initials = _initials(user);
    final isVolunteer = user.accountType == 'volunteer';
    final roleColor = isVolunteer ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, user),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo area
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: user.photoUrl.isNotEmpty
                      ? Image.network(user.photoUrl, fit: BoxFit.cover)
                      : Container(
                          color: roleColor.withValues(alpha: 0.08),
                          child: Center(
                            child: Text(initials,
                                style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor)),
                          ),
                        ),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + badge
                      Row(children: [
                        Expanded(
                          child: Text(name,
                              style: GoogleFonts.outfit(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                        ),
                        _RolePill(isVolunteer: isVolunteer),
                      ]),
                      // Location
                      if (user.nationality.isNotEmpty) ...[ 
                        const SizedBox(height: 2),
                        Text(user.nationality,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ],
                      // Bio
                      if (user.bio.isNotEmpty) ...[ 
                        const SizedBox(height: 6),
                        Text(user.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54, height: 1.4)),
                      ],
                      // Languages
                      if (user.languages.isNotEmpty) ...[ 
                        const SizedBox(height: 8),
                        _LangPills(languages: user.languages),
                      ],
                      const Spacer(),
                      // Connect button
                      _ConnectButton(user: user, full: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row card (mobile) ─────────────────────────────────────────────────────────
class _PilgrimRowCard extends StatelessWidget {
  final UserModel user;
  const _PilgrimRowCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = _name(user);
    final initials = _initials(user);
    final isVolunteer = user.accountType == 'volunteer';
    final roleColor = isVolunteer ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, user),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64, height: 64,
                child: user.photoUrl.isNotEmpty
                    ? Image.network(user.photoUrl, fit: BoxFit.cover)
                    : Container(
                        color: roleColor.withValues(alpha: 0.1),
                        alignment: Alignment.center,
                        child: Text(initials,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: roleColor)),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis),
                    ),
                    _RolePill(isVolunteer: isVolunteer, small: true),
                  ]),
                  if (user.nationality.isNotEmpty)
                    Text(user.nationality,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                  if (user.bio.isNotEmpty) ...[ 
                    const SizedBox(height: 3),
                    Text(user.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54)),
                  ],
                  if (user.languages.isNotEmpty) ...[ 
                    const SizedBox(height: 5),
                    _LangPills(languages: user.languages, max: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Connect
            _ConnectButton(user: user),
          ]),
        ),
      ),
    );
  }
}

// ── Connect button (shows match modal on press) ───────────────────────────────
class _ConnectButton extends StatelessWidget {
  final UserModel user;
  final bool full;
  const _ConnectButton({required this.user, this.full = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: full ? double.infinity : null,
      height: 34,
      child: ElevatedButton(
        onPressed: () => _showMatchModal(context, user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          padding: EdgeInsets.symmetric(horizontal: full ? 0 : 14, vertical: 0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text('Connect',
            style: TextStyle(
                color: Theme.of(context).cardColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Language pills ────────────────────────────────────────────────────────────
class _LangPills extends StatelessWidget {
  final List<String> languages;
  final int max;
  const _LangPills({required this.languages, this.max = 4});

  @override
  Widget build(BuildContext context) {
    final shown = languages.take(max).toList();
    final extra = languages.length - shown.length;
    return Wrap(
      spacing: 4, runSpacing: 4,
      children: [
        ...shown.map((l) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(l.length > 6 ? l.substring(0, 6) : l,
              style: TextStyle(
                  fontSize: 10, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600)),
        )),
        if (extra > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('+$extra',
                style: const TextStyle(fontSize: 10, color: Colors.black45)),
          ),
      ],
    );
  }
}

// ── Role pill ─────────────────────────────────────────────────────────────────
class _RolePill extends StatelessWidget {
  final bool isVolunteer, small;
  const _RolePill({required this.isVolunteer, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = isVolunteer ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
    final label = isVolunteer ? 'Volunteer' : 'Pilgrim';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: small ? 9 : 10,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}

// ── Match modal ───────────────────────────────────────────────────────────────
void _showMatchModal(BuildContext context, UserModel user) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _MatchDialog(user: user),
  );
}

class _MatchDialog extends ConsumerStatefulWidget {
  final UserModel user;
  const _MatchDialog({required this.user});

  @override
  ConsumerState<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends ConsumerState<_MatchDialog> {
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReq() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a short message first 👀')),
      );
      return;
    }

    setState(() => _sending = true);
    final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myUid == null) return;

    final peerUid = widget.user.uid;
    final sortedIds = [myUid, peerUid]..sort();
    final chatId = sortedIds.join('_');

    try {
      final matchRepo = ref.read(matchmakingRepositoryProvider);
      
      // 1. Ensure chat exists
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
      final snap = await chatRef.get();
      if (!snap.exists) {
        await matchRepo.createChat([myUid, peerUid]);
        _checkSpam(myUid);
      }

      // 2. Send message
      await matchRepo.sendMessage(chatId, myUid, text);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent to ${_name(widget.user)} 🙏'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkSpam(String myUid) async {
    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      
      final recentChatsSnap = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: myUid)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourAgo))
          .count()
          .get();
          
      final recentChats = recentChatsSnap.count ?? 0;
      
      if (recentChats > 10) {
        // Flag user automatically
        await FirebaseFirestore.instance.collection('reports').add({
          'reporterUid': 'SYSTEM_BOT',
          'reportedUid': myUid,
          'reason': 'Suspicious Speed: Created >10 chats in 1 hour',
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Spam check failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name(widget.user);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 32, 28, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatars
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ModalAvatar(user: widget.user),
                const SizedBox(width: 12),
                const Text('→',
                    style: TextStyle(fontSize: 20, color: Colors.black26)),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                  child: Text('You',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary)),
                ),
              ]),
              const SizedBox(height: 24),
              Text('Connect with $name?',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Send $name a message.\\nThey\'ll be notified and can reply.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black45, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Message Input
              TextField(
                controller: _msgCtrl,
                maxLines: 3,
                minLines: 2,
                maxLength: 140,
                decoration: InputDecoration(
                  hintText: 'Introduce yourself (e.g. "I see we have similar dates for Seoul!")',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _sending ? null : _sendReq,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Theme.of(context).cardColor, strokeWidth: 2))
                      : Text('Send request',
                          style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe later',
                    style: TextStyle(color: Colors.black38, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalAvatar extends StatelessWidget {
  final UserModel user;
  const _ModalAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);
    final isVol = user.accountType == 'volunteer';
    final color = isVol ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;
    return CircleAvatar(
      radius: 28,
      backgroundColor: color.withValues(alpha: 0.12),
      backgroundImage:
          user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
      child: user.photoUrl.isEmpty
          ? Text(initials,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 18))
          : null,
    );
  }
}

// ── Profile detail sheet ──────────────────────────────────────────────────────
void _showDetail(BuildContext context, UserModel user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _DetailSheet(user: user),
  );
}

class _DetailSheet extends ConsumerWidget {
  final UserModel user;
  const _DetailSheet({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = _name(user);
    final initials = _initials(user);
    final isVol = user.accountType == 'volunteer';
    final color = isVol ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle & Options Row
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.black45),
                  onPressed: () => UserActionsHelper.showOptions(context, ref, user),
                ),
              ),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12, borderRadius: BorderRadius.circular(2)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Header
          Center(
            child: Column(children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: color.withValues(alpha: 0.1),
                backgroundImage: user.photoUrl.isNotEmpty
                    ? NetworkImage(user.photoUrl)
                    : null,
                child: user.photoUrl.isEmpty
                    ? Text(initials,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold, color: color))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(name,
                  style: GoogleFonts.outfit(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _RolePill(isVolunteer: isVol),
              if (user.nationality.isNotEmpty) ...[ 
                const SizedBox(height: 4),
                Text(user.nationality,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black45)),
              ],
            ]),
          ),
          const SizedBox(height: 28),

          // Bio
          if (user.bio.isNotEmpty) ...[ 
            const _SectionLabel('About'),
            const SizedBox(height: 8),
            Text(user.bio,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87, height: 1.55)),
            const SizedBox(height: 24),
          ],

          // Languages
          if (user.languages.isNotEmpty) ...[ 
            const _SectionLabel('Languages'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: user.languages
                  .map((l) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Text(l,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Interests / Intent
          if (user.interests.isNotEmpty) ...[ 
            const _SectionLabel('Interests'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: user.interests
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],

          // Connect
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showMatchModal(context, user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Connect',
                  style: TextStyle(
                      color: Theme.of(context).cardColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.black38,
            letterSpacing: 1.2),
      );
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🌍', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 16),
          Text('No pilgrims found',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or\nbe the first to complete your profile!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black38, fontSize: 14, height: 1.5),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _name(UserModel u) =>
    u.displayName.isNotEmpty ? u.displayName : u.email.split('@').first;

String _initials(UserModel u) {
  if (u.displayName.isNotEmpty) {
    final p = u.displayName.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : p[0][0].toUpperCase();
  }
  return u.email[0].toUpperCase();
}
