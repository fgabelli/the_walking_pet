import 'dart:convert';
import 'package:http/http.dart' as http;

class OSMPlace {
  final String displayName;
  final double latitude;
  final double longitude;
  final String city;
  final String province;
  final String region;
  final String country;

  OSMPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.province,
    required this.region,
    required this.country,
  });

  factory OSMPlace.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? '';
    final province = address['county'] ?? '';
    final region = address['state'] ?? '';
    final country = address['country'] ?? '';

    return OSMPlace(
      displayName: json['display_name'] ?? '',
      latitude: double.parse(json['lat'] ?? '0.0'),
      longitude: double.parse(json['lon'] ?? '0.0'),
      city: city,
      province: province,
      region: region,
      country: country,
    );
  }
}

class OSMService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  Future<List<OSMPlace>> searchAddress(String query) async {
    if (query.length < 3) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=it',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TheWalkingPet/1.0', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => OSMPlace.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load suggestions');
      }
    } catch (e) {
      print('Error searching address: $e');
      return [];
    }
  }

  /// Reverse geocode coordinates using OpenStreetMap Nominatim
  Future<Map<String, String>?> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?lat=$lat&lon=$lon&format=json&addressdetails=1&accept-language=it',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TheWalkingPet/1.0', // Required by Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>? ?? {};
        
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? '';
        final province = address['county'] ?? '';
        final region = address['state'] ?? '';
        final country = address['country'] ?? '';

        return {
          'city': city,
          'province': province,
          'region': region,
          'country': country,
        };
      }
    } catch (e) {
      print('Error reverse geocoding in OSMService: $e');
    }
    return null;
  }
}
