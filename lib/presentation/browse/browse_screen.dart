import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/providers/matchmaking_provider.dart';
import '../../core/providers/chat_provider.dart';
import '../admin/user_actions_helper.dart';
import '../chat/chat_screen.dart';
import '../../core/constants/countries.dart';
import '../../core/constants/languages.dart';

// ── Palette ───────────────────────────────────────────────────────────────────






const _border = Color(0x0F000000);

// Filtered provider: excludes banned, ghost (no bio), and the viewer themselves
final allUsersProvider = StreamProvider.family<List<UserModel>, String>((ref, myUid) async* {
  // 1. Fetch current user first to get their age and target age preferences
  final myUserDoc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
  
  UserModel? myUser;
  if (myUserDoc.exists && myUserDoc.data() != null) {
      myUser = UserModel.fromMap(myUserDoc.data()!, myUserDoc.id);
  }
  
  final myAge = myUser?.age ?? 0;
  final myTargetMin = myUser?.targetMinAge ?? 18;
  final myTargetMax = myUser?.targetMaxAge ?? 100;
  // Admin check — rely on isAdmin flag only (Firestore rules block self-elevation)
  final isAdmin = myUser?.isAdmin == true;

  // 2. Yield the filtered stream of peers
  yield* FirebaseFirestore.instance
      .collection('users')
      .snapshots()
      .map((s) {
    debugPrint('[BROWSE] Fetched ${s.docs.length} raw docs from Firestore');
    final all = s.docs.map((d) {
      try {
        return UserModel.fromMap(d.data(), d.id);
      } catch (e) {
        debugPrint('[BROWSE] Error parsing user ${d.id}: $e');
        return null;
      }
    }).whereType<UserModel>().toList();
    
    final filtered = all
        .where((u) => u.uid != myUid)                       // hide yourself
        .where((u) => u.isBanned != true)                   // hide banned
        .where((u) {
          // Hide test accounts (mailinator, throwaway domains) from regular users
          if (!isAdmin && (
            u.email.contains('@mailinator.com') ||
            u.email.contains('@test.') ||
            u.displayName.toLowerCase() == 'testuser' ||
            u.displayName.toLowerCase().startsWith('test ')
          )) {
             return false;
          }

          // Mutual Age Filtering
          // 1. Peer's age must be within MY target range (ONLY if peer has set their age)
          final peerAge = u.age ?? 0;
          if (peerAge > 0) {
            if (peerAge < myTargetMin || peerAge > myTargetMax) return false;
          }
          
          // 2. MY age must be within PEER'S target range (ONLY if I have set my age)
          final peerTargetMin = u.targetMinAge ?? 18;
          final peerTargetMax = u.targetMaxAge ?? 100;
          if (myAge > 0) {
            if (myAge < peerTargetMin || myAge > peerTargetMax) return false;
          }
          
          return true;
        })
        .toList();
        
    debugPrint('[BROWSE] After initial filters (self/banned/age): ${filtered.length}');
    return filtered;
  });
});

// ── Filter state ──────────────────────────────────────────────────────────────
class _Filters {
  final String search;
  final String language;  // '' = any
  final String country;   // '' = any
  final String city;      // '' = any
  final String gender;    // '' = any | 'Male' | 'Female' | 'Other'
  final int? minAge;
  final int? maxAge;

  const _Filters({
    this.search = '',
    this.language = '',
    this.country = '',
    this.city = '',
    this.gender = '',
    this.minAge,
    this.maxAge,
  });

  _Filters copyWith({
    String? search, String? language,
    String? country, String? city, String? gender,
  }) => _Filters(
    search: search ?? this.search,
    language: language ?? this.language,
    country: country ?? this.country,
    city: city ?? this.city,
    gender: gender ?? this.gender,
    minAge: minAge,
    maxAge: maxAge,
  );
  
  _Filters copyWithAge({int? min, int? max, bool clearMin = false, bool clearMax = false}) => _Filters(
    search: search,
    language: language,
    country: country,
    city: city,
    gender: gender,
    minAge: clearMin ? null : (min ?? minAge),
    maxAge: clearMax ? null : (max ?? maxAge),
  );
}


// ── Root browse widget ────────────────────────────────────────────────────────
class BrowseScreen extends ConsumerStatefulWidget {
  final String? openProfileUid;
  const BrowseScreen({super.key, this.openProfileUid});
  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  _Filters _f = const _Filters();
  bool _showFilters = false;
  
  void _setFilters(_Filters f) {
    setState(() => _f = f);
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 860;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  // ── Desktop Layout ──────────────────────────────────────────────────────────
  Widget _wideLayout() {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    return Column(children: [
      _TopBar(
        filters: _f,
        onChange: _setFilters,
        showFilterBtn: true,
        onFilterTap: _toggleFilters,
      ),
      if (_showFilters)
        Container(
          color: Theme.of(context).cardColor,
          constraints: const BoxConstraints(maxHeight: 300),
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: _FilterPanel(filters: _f, onChange: _setFilters),
              ),
              const Divider(height: 1, color: _border),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _setFilters(const _Filters()),
                      child: const Text('Clear Filters'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _toggleFilters,
                      child: const Text('Apply'),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      Expanded(child: _PilgrimGrid(filters: _f, myUid: myUid, openProfileUid: widget.openProfileUid)),
    ]);
  }

  // ── Mobile Layout ───────────────────────────────────────────────────────────
  Widget _narrowLayout() {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid ?? '';
    return Column(children: [
      _TopBar(
        filters: _f,
        onChange: _setFilters,
        showFilterBtn: true,
        onFilterTap: _toggleFilters,
      ),
      const Divider(height: 1, color: _border),
      if (_showFilters)
        Container(
          color: Theme.of(context).cardColor,
          constraints: const BoxConstraints(maxHeight: 300),
          width: double.infinity,
          child: Column(
            children: [
              Expanded(
                child: _FilterPanel(filters: _f, onChange: _setFilters),
              ),
              const Divider(height: 1, color: _border),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _setFilters(const _Filters()),
                      child: const Text('Clear Filters'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _toggleFilters,
                      child: const Text('Apply'),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      Expanded(child: _PilgrimGrid(filters: _f, columns: 1, myUid: myUid, openProfileUid: widget.openProfileUid)),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _ctrl,
              onChanged: (v) =>
                  widget.onChange(widget.filters.copyWith(search: v)),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search pilgrims...',
                hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black38),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        if (widget.showFilterBtn) ...[ 
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              height: 44, width: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(Icons.tune, size: 20, color: Theme.of(context).colorScheme.secondary)),
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

  const _FilterPanel({
    required this.filters,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Age
          _FilterSection(
            label: 'Age Range',
            child: Column(
              children: [
                RangeSlider(
                  values: RangeValues(
                    (filters.minAge ?? 18).toDouble().clamp(18, 99),
                    (filters.maxAge ?? 100).toDouble().clamp(18, 99),
                  ),
                  min: 18,
                  max: 99,
                  divisions: 81,
                  labels: RangeLabels(
                    '${filters.minAge ?? 18}',
                    '${filters.maxAge ?? 100}',
                  ),
                  activeColor: Theme.of(context).colorScheme.secondary,
                  onChanged: (values) {
                    onChange(filters.copyWithAge(
                      min: values.start.round(),
                      max: values.end.round(),
                    ));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${filters.minAge ?? 18} y/o', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                      Text('${filters.maxAge ?? 100} y/o', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Country
          _FilterSection(
            label: 'Country',
            child: _SearchablePicker(
              value: filters.country,
              hint: 'Any country',
              items: globalCountries,
              onChanged: (v) => onChange(filters.copyWith(country: v)),
            ),
          ),

          const SizedBox(height: 20),

          // Language
          _FilterSection(
            label: 'Language',
            child: _SearchablePicker(
              value: filters.language,
              hint: 'Any language',
              items: globalLanguages,
              onChanged: (v) => onChange(filters.copyWith(language: v)),
            ),
          ),

          const SizedBox(height: 20),

          // City
          _FilterSection(
            label: 'City',
            child: _TextFilter(
              value: filters.city,
              hint: 'Any city',
              onChanged: (v) => onChange(filters.copyWith(city: v)),
            ),
          ),

          const SizedBox(height: 20),

          // Gender
          _FilterSection(
            label: 'Gender',
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: ['', 'Male', 'Female', 'Other'].map((g) {
                final label = g.isEmpty ? 'Any' : g;
                final sel = filters.gender == g;
                return GestureDetector(
                  onTap: () => onChange(filters.copyWith(gender: g)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                      border: Border.all(color: sel ? Theme.of(context).colorScheme.secondary : Colors.black12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: sel ? Theme.of(context).cardColor : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),
          // Reset
          Center(
            child: TextButton.icon(
              onPressed: () => onChange(const _Filters()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset all filters',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchablePicker extends StatelessWidget {
  final String value;
  final String hint;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _SearchablePicker({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showSearch<String>(
          context: context,
          delegate: _PickerSearchDelegate(items: items),
        );
        if (result != null) onChanged(result == 'Any' ? '' : result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(
                  fontSize: 13,
                  color: value.isEmpty ? Colors.black38 : Colors.black87,
                ),
              ),
            ),
            const Icon(Icons.search, size: 16, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _PickerSearchDelegate extends SearchDelegate<String> {
  final List<String> items;
  _PickerSearchDelegate({required this.items});

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => 
    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered = query.isEmpty 
      ? items 
      : items.where((i) => i.toLowerCase().contains(query.toLowerCase())).toList();
    
    return ListView.builder(
      itemCount: filtered.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return ListTile(
            title: const Text('Any / Universal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            onTap: () => close(context, 'Any'),
          );
        }
        final item = filtered[i - 1];
        return ListTile(
          title: Text(item),
          onTap: () => close(context, item),
        );
      },
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
            style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: Colors.black38, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}



class _TextFilter extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  const _TextFilter({required this.value, required this.hint, required this.onChanged});

  @override
  State<_TextFilter> createState() => _TextFilterState();
}

class _TextFilterState extends State<_TextFilter> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: widget.hint,
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
class _PilgrimGrid extends ConsumerStatefulWidget {
  final _Filters filters;
  final int columns;
  final String myUid;
  final String? openProfileUid;
  const _PilgrimGrid({required this.filters, this.columns = 3, required this.myUid, this.openProfileUid});

  @override
  ConsumerState<_PilgrimGrid> createState() => _PilgrimGridState();
}

class _PilgrimGridState extends ConsumerState<_PilgrimGrid> {
  bool _hasOpenedProfile = false;

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider(widget.myUid));
    final myUserAsync = ref.watch(currentUserModelProvider);
    final myUser = myUserAsync.value;

    // Watch chats to check for existing conversations
    final chatsAsync = ref.watch(userChatsProvider(widget.myUid));
    final existingChatPeerUids = chatsAsync.value?.expand((c) {
      return c.participants.where((p) => p != widget.myUid);
    }).where((uid) => uid.isNotEmpty).toSet() ?? {};

// Check if current user has a complete enough profile to connect
    final myProfileComplete = myUser != null &&
        myUser.bio.isNotEmpty &&
        myUser.nationality.isNotEmpty;

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (myUser != null && myUser.photoUrl.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_person, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                const Text('Profile Photo Required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text('Please upload a profile photo to browse other pilgrims and join the community.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Go to My Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }

        // Auto-open deep link profile if requested and not yet opened
        if (widget.openProfileUid != null && !_hasOpenedProfile) {
          final target = all.where((u) => u.uid == widget.openProfileUid).firstOrNull;
          if (target != null) {
            _hasOpenedProfile = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) showProfileDetail(context, target);
            });
          }
        }

        final q = widget.filters.search.toLowerCase();

        final users = all.where((u) {
          // Filter blocked users
          if (myUser?.blockedUids.contains(u.uid) == true || u.blockedUids.contains(widget.myUid)) {
            return false;
          }

          if (widget.filters.minAge != null) {
            final age = u.age ?? 0;
            if (age < widget.filters.minAge!) return false;
          }
          if (widget.filters.maxAge != null) {
            final age = u.age ?? 0;
            if (age > widget.filters.maxAge!) return false;
          }
          
          if (widget.filters.language.isNotEmpty &&
              !u.languages.any((l) =>
                  l.toLowerCase().contains(widget.filters.language.toLowerCase()))) {
            return false;
          }
          
          if (widget.filters.country.isNotEmpty &&
              !u.nationality.toLowerCase().contains(widget.filters.country.toLowerCase())) {
            return false;
          }
          
          if (widget.filters.city.isNotEmpty &&
              !u.city.toLowerCase().contains(widget.filters.city.toLowerCase())) {
            return false;
          }

          if (widget.filters.gender.isNotEmpty && u.gender != widget.filters.gender) {
            return false;
          }
          
          if (q.isNotEmpty) {
            final match = u.displayName.toLowerCase().contains(q) ||
                u.nationality.toLowerCase().contains(q) ||
                u.city.toLowerCase().contains(q) ||
                u.bio.toLowerCase().contains(q) ||
                u.languages.any((l) => l.toLowerCase().contains(q));
            if (!match) return false;
          }
          return true;
        }).toList();
        
        debugPrint('[BROWSE] Final users to show: ${users.length}');

        // ── Nearby Sorting ──────────────────────────────────────────
        if (myUser?.lat != null && myUser?.lng != null) {
          users.sort((a, b) {
            final hasA = a.lat != null && a.lng != null;
            final hasB = b.lat != null && b.lng != null;
            
            if (!hasA && hasB) return 1;
            if (hasA && !hasB) return -1;
            if (!hasA && !hasB) return 0;
            
            final distA = _dist(myUser!.lat!, myUser.lng!, a.lat!, a.lng!);
            final distB = _dist(myUser.lat!, myUser.lng!, b.lat!, b.lng!);
            return distA.compareTo(distB);
          });
        }

        if (users.isEmpty && myProfileComplete) {
          return const _EmptyState(message: 'No pilgrims found matching your filters.\nTry widening your search.');
        } else if (users.isEmpty && !myProfileComplete) {
          return _IncompleteProfilePrompt();
        }

        final effectiveCols =
            widget.columns == 1 ? 1 : (MediaQuery.of(context).size.width > 1100 ? 3 : 2);

        return CustomScrollView(
          slivers: [
            if (!myProfileComplete)
              SliverToBoxAdapter(child: _IncompleteProfilePrompt()),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final user = users[i];
                    final hasChat = existingChatPeerUids.contains(user.uid);
                    return effectiveCols == 1
                        ? _PilgrimRowCard(user: user, myProfileComplete: myProfileComplete, myUid: widget.myUid, myUser: myUser, hasChat: hasChat)
                        : _PilgrimGridCard(user: user, myProfileComplete: myProfileComplete, myUid: widget.myUid, myUser: myUser, hasChat: hasChat);
                  },
                  childCount: users.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: effectiveCols,
                  childAspectRatio: effectiveCols == 1 ? 3.2 : 0.72,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Grid card (desktop) ───────────────────────────────────────────────────────
class _PilgrimGridCard extends StatelessWidget {
  final UserModel user;
  final bool myProfileComplete;
  final String myUid;
  final UserModel? myUser;
  final bool hasChat;
  const _PilgrimGridCard({required this.user, this.myProfileComplete = true, this.myUid = '', this.myUser, this.hasChat = false});

  @override
  Widget build(BuildContext context) {
    final name = _name(user);
    final initials = _initials(user);
    final isVolunteer = user.accountType == 'volunteer';
    final roleColor = isVolunteer
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;

    return GestureDetector(
      onTap: () => showProfileDetail(context, user),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo area
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: user.photoUrl.isNotEmpty
                    ? Image.network(user.photoUrl, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _initAvatar(initials, roleColor))
                    : _initAvatar(initials, roleColor),
              ),
            ),

            // Info area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name + role badge
                  Row(children: [
                    Expanded(
                      child: Text(
                        user.age != null ? '$name, ${user.age}' : name,
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _RolePill(isVolunteer: isVolunteer),
                  ]),

                  // Location
                  if (user.nationality.isNotEmpty || user.city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.black26),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [user.city, user.nationality]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Distance
                  if (myUser?.lat != null &&
                      myUser?.lng != null &&
                      user.lat != null &&
                      user.lng != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_dist(myUser!.lat!, myUser!.lng!, user.lat!, user.lng!).toStringAsFixed(1)} km away',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                  // Languages
                  if (user.languages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _LangPills(languages: user.languages),
                  ],

                  const SizedBox(height: 16),

                  // Connect button
                  _ConnectButton(
                    user: user,
                    full: true,
                    myProfileComplete: myProfileComplete,
                    hasChat: hasChat,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initAvatar(String initials, Color color) => Container(
        color: color.withValues(alpha: 0.08),
        child: Center(
          child: Text(initials,
              style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      );
}


// ── Row card (mobile) ─────────────────────────────────────────────────────────
class _PilgrimRowCard extends StatelessWidget {
  final UserModel user;
  final bool myProfileComplete;
  final String myUid;
  final UserModel? myUser;
  final bool hasChat;
  const _PilgrimRowCard({required this.user, this.myProfileComplete = true, this.myUid = '', this.myUser, this.hasChat = false});

  @override
  Widget build(BuildContext context) {
    final name = _name(user);
    final initials = _initials(user);
    final isVolunteer = user.accountType == 'volunteer';
    final roleColor = isVolunteer ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showProfileDetail(context, user),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 70, height: 70,
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
                        child: Text(
                            user.age != null ? '$name, ${user.age}' : name,
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 4),
                      _RolePill(isVolunteer: isVolunteer, small: true),
                    ]),
                    const SizedBox(height: 2),
                    if (user.nationality.isNotEmpty || user.city.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 10, color: Colors.black26),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                                [user.city, user.nationality].where((s) => s.isNotEmpty).join(', '),
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    if (myUser?.lat != null && myUser?.lng != null && user.lat != null && user.lng != null)
                      Text('${_dist(myUser!.lat!, myUser!.lng!, user.lat!, user.lng!).toStringAsFixed(1)} km away',
                          style: GoogleFonts.outfit(fontSize: 10, color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w700)),
                    if (user.languages.isNotEmpty) ...[ 
                      const SizedBox(height: 6),
                      _LangPills(languages: user.languages, max: 2),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Connect
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _ConnectButton(user: user, myProfileComplete: myProfileComplete, hasChat: hasChat),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Connect button (shows match modal on press) ───────────────────────────────
class _ConnectButton extends StatelessWidget {
  final UserModel user;
  final bool full;
  final bool myProfileComplete;
  final bool hasChat;
  const _ConnectButton({required this.user, this.full = false, this.myProfileComplete = true, this.hasChat = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: full ? double.infinity : null,
      height: 34,
      child: ElevatedButton(
        onPressed: () {
          if (!myProfileComplete) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Complete your profile first'),
                content: const Text(
                  'To protect our community from spam, you need to add a bio and your nationality before connecting with other pilgrims.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            return;
          }
          _showMatchModal(context, user);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasChat ? Colors.transparent : Theme.of(context).colorScheme.secondary,
          padding: EdgeInsets.symmetric(horizontal: full ? 0 : 14, vertical: 0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: hasChat ? BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5) : BorderSide.none),
          elevation: 0,
        ),
        child: Text(hasChat ? 'Message' : 'Connect',
            style: TextStyle(
                color: hasChat ? Theme.of(context).colorScheme.secondary : Theme.of(context).cardColor, 
                fontSize: 13, 
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── 🕊️ Pax button — light "peace greeting" with no pressure ───────────────────
// Called "Pax" (Latin: peace), the traditional Franciscan greeting "Pax et Bonum".
// It's a soft signal of interest — less commitment than Connect.
class _PaxButton extends ConsumerStatefulWidget {
  final String myUid;
  final String toUid;
  const _PaxButton({required this.myUid, required this.toUid});


  @override
  ConsumerState<_PaxButton> createState() => _PaxButtonState();
}

class _PaxButtonState extends ConsumerState<_PaxButton>
    with SingleTickerProviderStateMixin {
  bool _sent = false;
  late final AnimationController _scale;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _anim = Tween<double>(begin: 1.0, end: 1.35)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_scale);
    _checkExisting();
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('paxes')
          .doc('${widget.myUid}_${widget.toUid}')
          .get();
      if (mounted) setState(() => _sent = doc.exists);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    final paxId = '${widget.myUid}_${widget.toUid}';
    final ref = FirebaseFirestore.instance.collection('paxes').doc(paxId);
    final wasSet = _sent;
    setState(() => _sent = !_sent);
    _scale.forward().then((_) => _scale.reverse());
    try {
      if (wasSet) {
        await ref.delete();
      } else {
        await ref.set({
          'fromUid': widget.myUid,
          'toUid': widget.toUid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (mounted) setState(() => _sent = wasSet); // rollback on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _sent
        ? Theme.of(context).colorScheme.secondary
        : Colors.black26;
    return GestureDetector(
      onTap: _toggle,
      child: ScaleTransition(
        scale: _anim,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, color: color, size: 24),

            const SizedBox(height: 2),
            Text('Pax',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
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
    const color = Color(0xFF0047A0); // Pilgrim Blue
    const label = 'Pilgrim';

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
        const SnackBar(content: Text('Please add a short message first')),
      );
      return;
    }

    setState(() => _sending = true);
    final myUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (myUid == null) return;

    final peerUid = widget.user.uid;

    try {
      final matchRepo = ref.read(matchmakingRepositoryProvider);

      // createChat uses merge:true — idempotent, safe to always call
      await matchRepo.createChat([myUid, peerUid]);

      // Send first message into the chat
      final sortedIds = [myUid, peerUid]..sort();
      final chatId = sortedIds.join('_');
      await matchRepo.sendMessage(chatId, myUid, text);

      // Background spam check (don't await — don't block UX)
      _checkSpam(myUid);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peer: widget.user)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent to ${_name(widget.user)}'),
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
        // Auto-flag: write reporterUid as the real UID to satisfy Firestore rules,
        // and mark isAutoFlag=true so admins can distinguish system-generated reports.
        await FirebaseFirestore.instance.collection('reports').add({
          'reporterUid': myUid,
          'reportedUid': myUid,
          'reason': 'Suspicious Speed: Created >10 chats in 1 hour',
          'isAutoFlag': true,
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
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final name = _name(widget.user);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    bool hasChat = false;
    if (myUid != null) {
      final chatsAsync = ref.watch(userChatsProvider(myUid));
      hasChat = chatsAsync.whenOrNull(
        data: (chats) => chats.any((c) => c.participants.contains(widget.user.uid)),
      ) ?? false;
    }

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
                Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.black12),
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
              Text(hasChat ? 'See message history' : 'Connect with $name?',
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (!hasChat)
                Text(
                  'Send $name a message.\nThey\'ll be notified and can reply.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black45, height: 1.5),
                ),
              if (!hasChat) const SizedBox(height: 24),

              // Message Input
              if (!hasChat)
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
              if (!hasChat) const SizedBox(height: 16),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _sending 
                    ? null 
                    : () {
                        if (hasChat) {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(peer: widget.user)));
                        } else {
                          _sendReq();
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(hasChat ? 'Go to chat' : 'Send request',
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
void showProfileDetail(BuildContext context, UserModel user, {bool hideConnectButton = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).cardColor,
    constraints: const BoxConstraints(maxWidth: 500),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ProfileDetailSheet(user: user, hideConnectButton: hideConnectButton),
  );
}

class ProfileDetailSheet extends ConsumerWidget {
  final UserModel user;
  final bool hideConnectButton;
  const ProfileDetailSheet({super.key, required this.user, this.hideConnectButton = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myUid = ref.watch(authRepositoryProvider).currentUser?.uid;
    final chatsAsync = ref.watch(userChatsProvider(myUid ?? ''));
    final hasChat = chatsAsync.whenOrNull(data: (chats) => 
        chats.any((c) => c.participants.contains(user.uid))) ?? false;

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

          // Empty State if nothing is filled
          if (user.bio.isEmpty && user.languages.isEmpty && user.interests.isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Text("This pilgrim hasn't added any details yet.",
                  style: TextStyle(color: Colors.black45, fontStyle: FontStyle.italic, fontSize: 13)),
            ),
            const SizedBox(height: 32),
          ],

          // Connect
          if (!hideConnectButton)
            Row(
              children: [
                if (myUid != null && myUid.isNotEmpty) ...[
                  _PaxButton(myUid: myUid, toUid: user.uid),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: SizedBox(
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
                      child: Text(hasChat ? 'Go to chat' : 'Connect',
                          style: TextStyle(
                              color: Theme.of(context).cardColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                ),
              ],
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
  final String? message;
  const _EmptyState({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.public_rounded, size: 52, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('No pilgrims found',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(
            message ?? 'Try adjusting your filters or\nbe the first to complete your profile!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black38, fontSize: 14, height: 1.5),
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

// ── Helpers ───────────────────────────────────────────────────────────────────
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var p = 0.017453292519943295;
  var c = math.cos;
  var a = 0.5 - c((lat2 - lat1) * p)/2 + 
      c(lat1 * p) * c(lat2 * p) * 
      (1 - c((lon2 - lon1) * p))/2;
  return (12742 * math.asin(math.sqrt(a))).toDouble();
}

double _dist(double lat1, double lon1, double lat2, double lon2) => _calculateDistance(lat1, lon1, lat2, lon2);

// ── Incomplete Profile Prompt ─────────────────────────────────────────────────
class _IncompleteProfilePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Complete your profile!',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'To see other pilgrims and get better matches, please fill out your bio and location in your profile.',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                context.go('/profile');
              },
              icon: const Icon(Icons.person, size: 18),
              label: const Text('Complete Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary, backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
