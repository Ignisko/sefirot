// Removed dart:html to fix Windows build crash
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/location_service.dart';
import 'package:path/path.dart' as p;
// Conditionally use web APIs only on web builds

import '../../core/providers/user_provider.dart';
import '../../domain/models/user_model.dart';
import '../../core/constants/languages.dart';
import '../../core/constants/countries.dart';

// ── Firebase Storage bucket ──────────────────────────────────────────────────
const _storageBucket = 'sefirot-ff9af.firebasestorage.app';

// ── Country list ─────────────────────────────────────────────────────────────
final List<String> _countries = globalCountries;

// ── Language list ─────────────────────────────────────────────────────────────
final List<String> _languages = globalLanguages;
const _maxLanguages = 7;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 7;

  // Step data
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = ''; // 'Male' | 'Female' | 'Other'
  String _selectedRole = 'pilgrim';
  
  // Photo
  File? _imageFile;
  Uint8List? _webImageBytes;
  
  // Location & Nationality
  String _selectedCountry = '';
  final _countryController = TextEditingController();
  String _city = '';
  double? _lat;
  double? _lng;
  bool _fetchingLocation = false;

  final List<String> _selectedLanguages = [];
  final _bioController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _nextStep() {
    // Validation
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your name');
        return;
      }
      final ageStr = _ageController.text.trim();
      if (ageStr.isEmpty || int.tryParse(ageStr) == null || int.parse(ageStr) < 13) {
        _showError('Please enter a valid age (13+)');
        return;
      }
    }
    if (_currentStep == 1 && _imageFile == null && _webImageBytes == null) {
      _showError('Please upload a photo of yourself');
      return;
    }
    if (_currentStep == 2 && _selectedGender.isEmpty) {
      _showError('Please select your gender');
      return;
    }
    if (_currentStep == 3 && _selectedCountry.isEmpty) {
      _showError('Please select your nationality');
      return;
    }
    if (_currentStep == 4 && _lat == null && _city.isEmpty) {
      _showError('Please allow location access or enter your city manually');
      return;
    }
    if (_currentStep == 5 && _bioController.text.trim().isEmpty) {
      _showError('Please write a short bio');
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade400,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<String?> _uploadProfileImage(String uid) async {
    if (_imageFile == null && _webImageBytes == null) return null;
    
    try {
      Uint8List? uploadBytes;
      String mimeType = 'image/jpeg';

      if (kIsWeb && _webImageBytes != null) {
         uploadBytes = _webImageBytes;
         mimeType = 'image/png';
      } else if (_imageFile != null) {
         uploadBytes = await _imageFile!.readAsBytes();
         final ext = p.extension(_imageFile!.path).toLowerCase();
         mimeType = (ext == '.png') ? 'image/png' : 'image/jpeg';
      }

      if (uploadBytes == null) return null;

      if (!kIsWeb && Platform.isWindows) {
        // Use REST API on Windows to avoid firebase_storage C++ SDK crash
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final bucket = _storageBucket;
        final path = Uri.encodeComponent('avatars/$uid');
        final url = Uri.parse('https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=$path');
        
        final client = HttpClient();
        final request = await client.postUrl(url);
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
          return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$path?alt=media&token=$downloadToken';
        } else {
          throw Exception('Upload failed: ${response.statusCode} $responseString');
        }
      } else {
        // Use standard putData on iOS/Android/Web to avoid native file path crashes
        final ref = FirebaseStorage.instance
            .ref()
            .child('avatars')
            .child(uid);

        await ref.putData(uploadBytes, SettableMetadata(contentType: mimeType));
        return await ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      throw Exception('Image upload failed: $e');
    }
  }

  Future<void> _submit(UserModel currentUser) async {
    setState(() => _isLoading = true);

    try {
      // 1. Upload photo
      String? photoUrl = currentUser.photoUrl;
      if (_imageFile != null || _webImageBytes != null) {
        final uploadedUrl = await _uploadProfileImage(currentUser.uid);
        if (uploadedUrl != null) photoUrl = uploadedUrl;
      }

      // 2. Update user document
      final updatedUser = currentUser.copyWith(
        displayName: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        photoUrl: photoUrl,
        accountType: _selectedRole,
        nationality: _selectedCountry,
        city: _city,
        lat: _lat,
        lng: _lng,
        languages: _selectedLanguages,
        bio: _bioController.text.trim(),
        gender: _selectedGender,
        isOnboarded: true,
      );
      
      await ref.read(userRepositoryProvider).updateUser(updatedUser);
      
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to save profile: $e');
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
                      _StepBasicInfo(nameController: _nameController, ageController: _ageController),
                      _StepPhoto(
                        imageFile: _imageFile,
                        webImageBytes: _webImageBytes,
                        onImageSelected: (file, bytes) {
                          setState(() {
                            _imageFile = file;
                            _webImageBytes = bytes;
                          });
                        },
                      ),
                      _StepRole(
                        selected: _selectedRole,
                        onChanged: (v) => setState(() => _selectedRole = v),
                      ),
                      _StepCountry(
                        controller: _countryController,
                        selected: _selectedCountry,
                        onSelected: (v) => setState(() => _selectedCountry = v),
                      ),
                      _StepLocation(
                        lat: _lat,
                        lng: _lng,
                        city: _city,
                        fetching: _fetchingLocation,
                        onLocationFetched: (lat, lng, city) {
                          setState(() {
                             _lat = lat;   // null when entered manually
                             _lng = lng;   // null when entered manually
                             _city = city;
                          });
                        },
                        setFetching: (val) => setState(() => _fetchingLocation = val),
                      ),
                      _StepBio(controller: _bioController, 
                        selectedLanguages: _selectedLanguages,
                        onLanguageToggle: (lang) {
                          setState(() {
                            if (_selectedLanguages.contains(lang)) {
                              _selectedLanguages.remove(lang);
                            } else if (_selectedLanguages.length < _maxLanguages) {
                              _selectedLanguages.add(lang);
                            }
                          });
                        }
                      ),
                      _StepGender(
                        selected: _selectedGender,
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),
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
        error: (e, _) => Center(child: Text('Error: \$e')),
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
          Row(
            children: List.generate(total, (index) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 6,
                  decoration: BoxDecoration(
                    color: index <= current 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Step 0: Basic Info ────────────────────────────────────────────────────────
class _StepBasicInfo extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController ageController;
  const _StepBasicInfo({required this.nameController, required this.ageController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to Pelegrin',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Let\'s start with the basics.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 40),
          
          Text('My first name is', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Name',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
            ),
          ),
          
          const SizedBox(height: 32),
          Text('My age is', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Age',
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Photo ─────────────────────────────────────────────────────────────
class _StepPhoto extends StatelessWidget {
  final File? imageFile;
  final Uint8List? webImageBytes;
  final Function(File?, Uint8List?) onImageSelected;
  
  const _StepPhoto({
    required this.imageFile,
    required this.webImageBytes,
    required this.onImageSelected,
  });

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        onImageSelected(null, bytes);
      } else {
        onImageSelected(File(pickedFile.path), null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = imageFile != null || webImageBytes != null;
    
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a photo',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Add a photo so other pilgrims can recognize you.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 48),
          
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 200,
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  image: hasImage 
                      ? (kIsWeb 
                          ? DecorationImage(image: MemoryImage(webImageBytes!), fit: BoxFit.cover)
                          : DecorationImage(image: FileImage(imageFile!), fit: BoxFit.cover))
                      : null,
                ),
                child: !hasImage 
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 48, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: 12),
                          Text('Upload photo', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            bottom: -10, right: -10,
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Role ──────────────────────────────────────────────────────────────
class _StepRole extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StepRole({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('I am a...',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Your role helps us match you better.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 40),
          _RoleCard(
            title: 'Pilgrim',
            subtitle: 'I am attending WYD as a pilgrim',
            selected: selected == 'pilgrim',
            onTap: () => onChanged('pilgrim'),
          ),
          const SizedBox(height: 16),
          _RoleCard(
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
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.title, required this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: selected ? Theme.of(context).colorScheme.primary : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.shade400, width: 2),
                color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              ),
              child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Country ───────────────────────────────────────────────────────────
class _StepCountry extends StatefulWidget {
  final TextEditingController controller;
  final String selected;
  final ValueChanged<String> onSelected;
  const _StepCountry({required this.controller, required this.selected, required this.onSelected});

  @override
  State<_StepCountry> createState() => _StepCountryState();
}

class _StepCountryState extends State<_StepCountry> {
  List<String> _filtered = _countries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where are you from?',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 24),
          TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: 'Search country...',
              filled: true,
              fillColor: Colors.grey.shade100,
              prefixIcon: const Icon(Icons.search, color: Colors.black38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (q) {
              setState(() {
                _filtered = _countries.where((c) => c.toLowerCase().contains(q.toLowerCase())).toList();
              });
            },
          ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.selected, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => widget.onSelected(''),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  )
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final country = _filtered[i];
                final isSelected = widget.selected == country;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(country, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 18, color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black87)),
                  trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
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

// ── Step 4: GPS Location ──────────────────────────────────────────────────────
class _StepLocation extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String city;
  final bool fetching;
  // lat and lng are null for manual city-only entries.
  final void Function(double? lat, double? lng, String city) onLocationFetched;
  final ValueChanged<bool> setFetching;

  const _StepLocation({
    required this.lat,
    required this.lng,
    required this.city,
    required this.fetching,
    required this.onLocationFetched,
    required this.setFetching,
  });

  @override
  State<_StepLocation> createState() => _StepLocationState();
}

class _StepLocationState extends State<_StepLocation> {
  final _manualCityCtrl = TextEditingController();
  bool _showManual = false;
  String? _errorMsg;

  @override
  void dispose() {
    _manualCityCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    widget.setFetching(true);
    setState(() => _errorMsg = null);
    try {
      final result = await LocationService.getLocation();
      
      if (result.hasError) {
        setState(() => _errorMsg = result.error);
        return;
      }
      
      widget.onLocationFetched(result.lat, result.lng, result.city);
    } catch (e) {
      setState(() => _errorMsg = 'An unexpected error occurred: ${e.toString()}');
    } finally {
      widget.setFetching(false);
    }
  }

  void _submitManual() {
    final city = _manualCityCtrl.text.trim();
    if (city.isEmpty) return;
    // Manual city entry: lat/lng remain null so the user is excluded from
    // distance sorting (they appear in Browse but with no distance shown).
    widget.onLocationFetched(null, null, city);
  }

  @override
  Widget build(BuildContext context) {
    final acquired = widget.lat != null && widget.lat != 0;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on, size: 64, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 32),
          Text('Where are you?',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),
          Text(
            'Share your location so pilgrims near you can find you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 32),

          // Location acquired / detected city
          if (acquired)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.city.isNotEmpty ? '📍 ${widget.city}' : '✅ Location saved',
                      style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // GPS button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: widget.fetching
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.my_location, color: Colors.white),
                label: Text(
                  widget.fetching ? 'Detecting…' : 'Use my GPS location',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: widget.fetching ? null : _getLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),

            // Error message
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMsg!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 16),

            // Manual entry toggle
            GestureDetector(
              onTap: () => setState(() => _showManual = !_showManual),
              child: Text(
                _showManual ? 'Hide manual entry' : "Can't use GPS? Enter city manually",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),

            if (_showManual) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _manualCityCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Pamplona',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Set', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }
}


// ── Step 5: Bio & Languages ───────────────────────────────────────────────────
class _StepBio extends StatelessWidget {
  final TextEditingController controller;
  final List<String> selectedLanguages;
  final ValueChanged<String> onLanguageToggle;
  
  const _StepBio({
    required this.controller, 
    required this.selectedLanguages,
    required this.onLanguageToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Almost done',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Add a short bio and languages.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 24),
          
          Text('Bio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'e.g. "I\'m a pilgrim from Poland..."',
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          
          const SizedBox(height: 24),
          Text('Languages', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _languages.map((lang) {
                  final isSelected = selectedLanguages.contains(lang);
                  final isDisabled = !isSelected && selectedLanguages.length >= _maxLanguages;
                  return FilterChip(
                    label: Text(lang),
                    selected: isSelected,
                    onSelected: isDisabled ? null : (_) => onLanguageToggle(lang),
                    selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isDisabled ? Colors.black26 : isSelected ? Theme.of(context).colorScheme.primary : Colors.black87,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300),
                    backgroundColor: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text('Back', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: isLoading ? null : (isLast ? onFinish : onNext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isLast ? 'Complete' : 'Continue',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 2.5: Gender ──────────────────────────────────────────────────────────
class _StepGender extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StepGender({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My gender is',
              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('This helps other pilgrims find you.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 40),
          _GenderCard(
            title: 'Male',
            icon: Icons.male,
            selected: selected == 'Male',
            onTap: () => onChanged('Male'),
          ),
          const SizedBox(height: 16),
          _GenderCard(
            title: 'Female',
            icon: Icons.female,
            selected: selected == 'Female',
            onTap: () => onChanged('Female'),
          ),
          const SizedBox(height: 16),
          _GenderCard(
            title: 'Other',
            icon: Icons.person_outline,
            selected: selected == 'Other',
            onTap: () => onChanged('Other'),
          ),
        ],
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderCard({required this.title, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.secondary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Theme.of(context).colorScheme.secondary : Colors.grey.shade600, size: 28),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: selected ? Theme.of(context).colorScheme.secondary : Colors.black87)),
            const Spacer(),
            if (selected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }
}
