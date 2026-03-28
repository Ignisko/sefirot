import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double lat;
  final double lng;
  final String city;
  final String? error;

  LocationResult({
    required this.lat,
    required this.lng,
    required this.city,
    this.error,
  });

  bool get hasError => error != null;
}

class LocationService {
  /// Reverse-geocode lat/lng → city name using OpenStreetMap Nominatim (free, no key needed).
  /// Returns 'Unknown' on web or on any error (dart:io is not available on web).
  static Future<String> _reverseGeocode(double lat, double lng) async {
    // dart:io HttpClient is not available on web — skip geocoding there.
    if (kIsWeb) return 'Unknown';

    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
      );
      final req = await client.getUrl(uri);
      req.headers.set('User-Agent', 'Pelegrin-App/1.0 (contact@pelegrin.cloud)');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final addr = json['address'] as Map<String, dynamic>? ?? {};
        return (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['county'] ??
                addr['state'] ??
                'Unknown') as String;
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse Geocode Error: $e');
    } finally {
      client.close(); // Always close to prevent resource leak
    }
    return 'Unknown';
  }

  /// Gets the precise GPS coordinates and reverse geocodes the city name.
  /// Seamlessly handles both kIsWeb (browser API) and Native (Geolocator).
  static Future<LocationResult> getLocation() async {
    try {
      double lat, lng;

      // Native mobile/desktop and Web — use geolocator plugin
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(lat: 0, lng: 0, city: '', error: 'Location services are disabled.');
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          return LocationResult(lat: 0, lng: 0, city: '', error: 'Location permission denied.');
        }
      }

      if (perm == LocationPermission.deniedForever) {
        return LocationResult(
          lat: 0,
          lng: 0,
          city: '',
          error: 'Location permission permanently denied. Please enable it in system settings.',
        );
      }

      // Add a 10-second timeout to avoid hanging indefinitely if GPS is unavailable.
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw TimeoutException('GPS signal timed out. Please ensure you have a clear view of the sky or are near a window.'),
      );
      lat = pos.latitude;
      lng = pos.longitude;

      // Reverse geocode with Nominatim
      // Wrapped in a timeout to ensure it doesn't block the UI if Nominatim is slow
      final city = await _reverseGeocode(lat, lng).timeout(
        const Duration(seconds: 5),
        onTimeout: () => 'Unknown',
      );

      final roundedLat = double.parse(lat.toStringAsFixed(3));
      final roundedLng = double.parse(lng.toStringAsFixed(3));

      return LocationResult(lat: roundedLat, lng: roundedLng, city: city);

    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('minified:') || msg.contains('GeolocationPositionError') || msg.contains('User denied')) {
        msg = 'Location permission denied or unavailable. Please enable location access in your browser or system settings.';
      } else if (msg.contains('TimeoutException')) {
        msg = 'Location retrieval timed out. Please try again or enter your city manually.';
      } else if (msg.contains('ServiceDisabledException')) {
        msg = 'Location services are disabled on your device.';
      }
      debugPrint('[LocationService] Error: $e');
      return LocationResult(lat: 0, lng: 0, city: '', error: msg);
    }
  }
}
