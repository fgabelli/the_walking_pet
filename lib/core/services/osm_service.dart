import 'dart:convert';
import 'package:http/http.dart' as http;

class OSMPlace {
  final String displayName;
  final double latitude;
  final double longitude;

  OSMPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory OSMPlace.fromJson(Map<String, dynamic> json) {
    return OSMPlace(
      displayName: json['display_name'] ?? '',
      latitude: double.parse(json['lat']),
      longitude: double.parse(json['lon']),
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
}
