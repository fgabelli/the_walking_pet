import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] as String,
      placeId: json['place_id'] as String,
    );
  }
}

class GooglePlacesService {
  final String apiKey;

  GooglePlacesService(this.apiKey);

  Future<List<PlacePrediction>> search(String input) async {
    if (input.isEmpty) return [];

    // Basic Autocomplete API call
    final request = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&language=it&components=country:it';
    
    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final predictions = data['predictions'] as List;
          return predictions.map((p) => PlacePrediction.fromJson(p)).toList();
        }
        print('Google Places Error: ${data['status']}');
      }
    } catch (e) {
      print('Google Places Network Error: $e');
    }
    return [];
  }
}
