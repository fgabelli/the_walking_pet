import 'package:flutter/material.dart';
import '../../core/services/google_places_service.dart';

class AddressSearchDelegate extends SearchDelegate<PlacePrediction?> {
  final GooglePlacesService placesService;

  AddressSearchDelegate(this.placesService) : super(searchFieldLabel: 'Cerca indirizzo');

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSuggestions();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSuggestions();
  }
  
  Widget _buildSuggestions() {
    if (query.length < 3) {
      return const Center(child: Text('Digita almeno 3 caratteri...'));
    }

    return FutureBuilder<List<PlacePrediction>>(
      future: placesService.search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Errore: ${snapshot.error}'));
        }
        
        final predictions = snapshot.data ?? [];
        if (predictions.isEmpty) {
          return const Center(child: Text('Nessun risultato trovato.'));
        }

        return ListView.builder(
          itemCount: predictions.length,
          itemBuilder: (context, index) {
            final p = predictions[index];
            return ListTile(
              leading: const Icon(Icons.location_on),
              title: Text(p.description),
              onTap: () {
                close(context, p);
              },
            );
          },
        );
      },
    );
  }
}
