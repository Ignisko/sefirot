import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/user_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/constants/languages.dart';

// ── Country list ─────────────────────────────────────────────────────────────
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
  '🇵🇰 Pakistan', '🇵🇦 Panama', '🇵🇾 Paraguay', '🇵🇪 Peru',
  '🇵🇭 Philippines', '🇵🇱 Poland', '🇵🇹 Portugal', '🇷🇴 Romania',
  '🇷🇺 Russia', '🇸🇬 Singapore', '🇿🇦 South Africa', '🇪🇸 Spain',
  '🇸🇪 Sweden', '🇨🇭 Switzerland', '🇹🇼 Taiwan', '🇹🇿 Tanzania',
  '🇹🇭 Thailand', '🇹🇷 Turkey', '🇺🇦 Ukraine', '🇬🇧 United Kingdom',
  '🇺🇸 United States', '🇺🇾 Uruguay', '🇻🇪 Venezuela', '🇻🇳 Vietnam',
];

// ── Language list ─────────────────────────────────────────────────────────────
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

const _maxLanguages = 7;



class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5; // Added Diocese step

  // Step data
  String _selectedRole = 'pilgrim';
  String _selectedCountry = '';
  final _countryController = TextEditingController();
  String _selectedDiocese = '';
  final List<String> _selectedLanguages = [];
  final _bioController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1 && _selectedCountry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your country')),
      );
      return;
    }
    // Diocese is optional, so no check here for _currentStep == 2
    if (_currentStep == 3 && _selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one language')),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit(UserModel currentUser) async {
    setState(() => _isLoading = true);

    // Strip flag emoji prefix from country (e.g. "🇰🇷 South Korea" → "South Korea")
    final cleanCountry = _selectedCountry.contains(' ')
        ? _selectedCountry.substring(_selectedCountry.indexOf(' ') + 1)
        : _selectedCountry;

    try {
      final updatedUser = currentUser.copyWith(
        accountType: _selectedRole,
        nationality: cleanCountry,
        diocese: _selectedDiocese,
        languages: _selectedLanguages,
        bio: _bioController.text.trim(),
        isOnboarded: true,
      );
      await ref.read(userRepositoryProvider).updateUser(updatedUser);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: CircularProgressIndicator());
          return SafeArea(
            child: Column(
              children: [
                _ProgressHeader(current: _currentStep, total: _totalSteps),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StepRole(
                        selected: _selectedRole,
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                      _StepCountry(
                        controller: _countryController,
                        selected: _selectedCountry,
                        onSelected: (v) => setState(() => _selectedCountry = v),
                      ),
                      _StepDiocese(
                        selected: _selectedDiocese,
                        onSelected: (v) => setState(() => _selectedDiocese = v),
                      ),
                      _StepLanguages(
                        selected: _selectedLanguages,
                        onToggle: (lang) {
                          setState(() {
                            if (_selectedLanguages.contains(lang)) {
                              _selectedLanguages.remove(lang);
                            } else if (_selectedLanguages.length < _maxLanguages) {
                              _selectedLanguages.add(lang);
                            }
                          });
                        },
                      ),
                      _StepBio(controller: _bioController),
                    ],
                  ),
                ),
                _NavButtons(
                  currentStep: _currentStep,
                  totalSteps: _totalSteps,
                  isLoading: _isLoading,
                  onBack: _prevStep,
                  onNext: _nextStep,
                  onFinish: () => _submit(user),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

// ── Progress header ───────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressHeader({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${current + 1} of $total',
            style: const TextStyle(color: Colors.black38, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current + 1) / total,
              backgroundColor: Colors.black12,
              color: Theme.of(context).colorScheme.secondary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Role ──────────────────────────────────────────────────────────────
class _StepRole extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StepRole({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What is your role?',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Your role helps us match you better.',
              style: TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 40),
          _RoleCard(
            icon: '🙏',
            title: 'Pilgrim',
            subtitle: 'I am attending WYD as a pilgrim',
            selected: selected == 'pilgrim',
            onTap: () => onChanged('pilgrim'),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            icon: '🤝',
            title: 'Volunteer',
            subtitle: 'I am serving as a volunteer at WYD',
            selected: selected == 'volunteer',
            onTap: () => onChanged('volunteer'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String icon, title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.secondary : Colors.black12,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: selected ? Theme.of(context).colorScheme.secondary : Colors.black87,
                      )),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Country ───────────────────────────────────────────────────────────
class _StepCountry extends StatefulWidget {
  final TextEditingController controller;
  final String selected;
  final ValueChanged<String> onSelected;
  const _StepCountry({
    required this.controller,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_StepCountry> createState() => _StepCountryState();
}

class _StepCountryState extends State<_StepCountry> {
  List<String> _filtered = _countries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where are you from?',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Select your country of origin.',
              style: TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 24),
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: 'Search country...',
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.08),
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary)),
            ),
            onChanged: (q) {
              setState(() {
                _filtered = _countries
                    .where((c) => c.toLowerCase().contains(q.toLowerCase()))
                    .toList();
              });
            },
          ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).colorScheme.secondary),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary, size: 18),
                  const SizedBox(width: 8),
                  Text(widget.selected,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final country = _filtered[i];
                final isSelected = widget.selected == country;
                return ListTile(
                  dense: true,
                  title: Text(country,
                      style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.black87)),
                  trailing: isSelected
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.secondary, size: 18)
                      : null,
                  onTap: () {
                    widget.onSelected(country);
                    widget.controller.clear();
                    setState(() => _filtered = _countries);
                    FocusScope.of(context).unfocus();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2.5: Diocese ────────────────────────────────────────────────────────
class _StepDiocese extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _StepDiocese({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target Diocese',
              style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Which diocese are you focusing on for WYD Seoul 2027? (Optional)',
              style: TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _dioceses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final diocese = _dioceses[i];
                final isSelected = selected == diocese;
                return Material(
                  color: isSelected
                      ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onSelected(isSelected ? '' : diocese),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.black12,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              diocese,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded,
                                color: Theme.of(context).colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Languages ─────────────────────────────────────────────────────────
class _StepLanguages extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<String> onToggle;
  const _StepLanguages({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Languages you speak',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Select up to 7.',
                  style: TextStyle(color: Colors.black54, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: selected.length >= _maxLanguages
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${selected.length} / $_maxLanguages',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected.length >= _maxLanguages ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _languages.map((lang) {
                  final isSelected = selected.contains(lang);
                  final isDisabled = !isSelected && selected.length >= _maxLanguages;
                  return FilterChip(
                    label: Text(lang),
                    selected: isSelected,
                    onSelected: isDisabled ? null : (_) => onToggle(lang),
                    selectedColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                    checkmarkColor: Theme.of(context).colorScheme.secondary,
                    labelStyle: TextStyle(
                      color: isDisabled
                          ? Colors.black26
                          : isSelected ? Theme.of(context).colorScheme.secondary : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected ? Theme.of(context).colorScheme.secondary : Colors.black12,
                    ),
                    disabledColor: Colors.grey.withValues(alpha: 0.05),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Bio ───────────────────────────────────────────────────────────────
class _StepBio extends StatelessWidget {
  final TextEditingController controller;
  const _StepBio({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you',
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          const Text('Optional — write a short intro so other pilgrims can get to know you.',
              style: TextStyle(color: Colors.black54, fontSize: 15)),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            maxLines: 6,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'e.g. "I\'m a pilgrim from Poland, love worship music and hiking..."',
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.secondary)),
            ),
            style: const TextStyle(color: Colors.black87),
          ),
          const Spacer(),
          const Center(
            child: Text(
              'You can edit your profile anytime from the dashboard.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation buttons ────────────────────────────────────────────────────────
class _NavButtons extends StatelessWidget {
  final int currentStep, totalSteps;
  final bool isLoading;
  final VoidCallback onBack, onNext, onFinish;

  const _NavButtons({
    required this.currentStep,
    required this.totalSteps,
    required this.isLoading,
    required this.onBack,
    required this.onNext,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back',
                    style: TextStyle(color: Colors.black54, fontSize: 16)),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : (isLast ? onFinish : onNext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isLast ? 'Complete Profile 🙏' : 'Continue →',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
