import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/osm_service.dart';

class UsersTableWidget extends StatefulWidget {
  const UsersTableWidget({super.key});

  @override
  State<UsersTableWidget> createState() => _UsersTableWidgetState();
}

class _UsersTableWidgetState extends State<UsersTableWidget> {
  // Search & tab states
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showUsersTab = true;

  // Dual data collections
  List<DocumentSnapshot> _allUsers = [];
  List<DocumentSnapshot> _allDogs = [];
  bool _loadingUsers = true;
  bool _loadingDogs = true;
  StreamSubscription? _usersSub;
  StreamSubscription? _dogsSub;

  // User filters
  String _selectedGender = 'all'; // all, male, female, other
  String _selectedSubscription = 'all'; // all, free, premium
  String _selectedAccountType = 'all'; // all, personal, business

  // Common filters
  String _cityQuery = '';
  final _cityController = TextEditingController();

  // Pet filters
  String _selectedPetSpecies = 'all'; // all, dog, cat
  String _selectedPetGender = 'all'; // all, male, female
  String _selectedPetSize = 'all'; // all, small, medium, large, giant

  // Location migration / reverse geocoding queue variables
  Timer? _migrationTimer;
  bool _isMigrating = false;
  List<String> _migrationQueue = [];

  @override
  void initState() {
    super.initState();
    
    // Subscribe to users collection (without orderBy so documents without createdAt are included)
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .limit(1000)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final docs = List<DocumentSnapshot>.from(snapshot.docs);
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = (aData?['createdAt'] as Timestamp?)?.toDate();
          final bTime = (bData?['createdAt'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        setState(() {
          _allUsers = docs;
          _loadingUsers = false;
        });
        _startLocationMigration();
      }
    });

    // Subscribe to dogs/pets collection
    _dogsSub = FirebaseFirestore.instance
        .collection('dogs')
        .orderBy('createdAt', descending: true)
        .limit(1000)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _allDogs = snapshot.docs;
          _loadingDogs = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _usersSub?.cancel();
    _dogsSub?.cancel();
    _migrationTimer?.cancel();
    super.dispose();
  }

  void _startLocationMigration() {
    if (_isMigrating) return;
    
    // Find all users who have lat/lon but no city field
    final usersToMigrate = _allUsers.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final hasCoords = data['homeLatitude'] != null && data['homeLongitude'] != null;
      final missingCity = data['city'] == null || (data['city'] as String).trim().isEmpty;
      return hasCoords && missingCity;
    }).toList();

    if (usersToMigrate.isEmpty) return;

    _migrationQueue = usersToMigrate.map((doc) => doc.id).toList();
    _isMigrating = true;
    _processNextMigration();
  }

  void _processNextMigration() {
    if (!mounted || _migrationQueue.isEmpty) {
      _isMigrating = false;
      return;
    }

    final uid = _migrationQueue.removeAt(0);
    
    // Find the user document in memory to get coords
    final userDocs = _allUsers.where((doc) => doc.id == uid);
    if (userDocs.isEmpty) {
      _processNextMigration();
      return;
    }
    
    final userDoc = userDocs.first;
    final data = userDoc.data() as Map<String, dynamic>? ?? {};
    final latNum = data['homeLatitude'];
    final lonNum = data['homeLongitude'];
    
    if (latNum == null || lonNum == null) {
      _processNextMigration();
      return;
    }
    
    final lat = (latNum as num).toDouble();
    final lon = (lonNum as num).toDouble();

    // Set a timer to do the actual call and update, then schedule next (respecting OSM 1s rule)
    _migrationTimer = Timer(const Duration(seconds: 1), () async {
      try {
        final osmService = OSMService();
        final locData = await osmService.reverseGeocode(lat, lon);
        if (locData != null && locData['city'] != null && locData['city']!.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'city': locData['city'],
            'province': locData['province'],
            'region': locData['region'],
            'country': locData['country'],
          });
          print('Successfully auto-migrated location for user $uid (${locData['city']})');
        }
      } catch (e) {
        print('Error migrating location for user $uid: $e');
      }

      if (mounted) {
        _processNextMigration();
      }
    });
  }

  Widget _buildLocationCell(Map<String, dynamic> data) {
    final address = data['address'] ?? '';
    final zone = data['zone'] ?? '';
    final city = data['city'] ?? '';
    final province = data['province'] ?? '';
    final region = data['region'] ?? '';
    final country = data['country'] ?? '';

    String mainLocation = '';
    String subLocation = '';

    if (city.isNotEmpty) {
      final provSuffix = province.isNotEmpty ? ' ($province)' : '';
      mainLocation = '$city$provSuffix';
      
      final List<String> details = [];
      if (region.isNotEmpty) details.add(region);
      if (country.isNotEmpty) details.add(country);
      if (zone.isNotEmpty) details.add('Zona: $zone');
      subLocation = details.join(' • ');
    } else {
      mainLocation = zone.isNotEmpty ? zone : (address.isNotEmpty ? address : '—');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mainLocation,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0A2342),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subLocation.isNotEmpty)
              Text(
                subLocation,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedGender = 'all';
      _selectedSubscription = 'all';
      _selectedAccountType = 'all';
      _cityQuery = '';
      _cityController.clear();
      _selectedPetSpecies = 'all';
      _selectedPetGender = 'all';
      _selectedPetSize = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUsers || _loadingDogs) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply User Filters
    List<DocumentSnapshot> filteredUsers = _allUsers;
    if (_searchQuery.isNotEmpty) {
      filteredUsers = filteredUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final firstName = (data['firstName'] ?? '').toString().toLowerCase();
        final lastName = (data['lastName'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final fullName = '$firstName $lastName';
        return fullName.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }
    if (_selectedGender != 'all') {
      filteredUsers = filteredUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['gender'] == _selectedGender;
      }).toList();
    }
    if (_selectedSubscription != 'all') {
      filteredUsers = filteredUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final isPremium = data['isPremium'] == true;
        return _selectedSubscription == 'premium' ? isPremium : !isPremium;
      }).toList();
    }
    if (_selectedAccountType != 'all') {
      filteredUsers = filteredUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['accountType'] == _selectedAccountType;
      }).toList();
    }
    if (_cityQuery.isNotEmpty) {
      filteredUsers = filteredUsers.where((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final zone = (data['zone'] ?? '').toString().toLowerCase();
        final address = (data['address'] ?? '').toString().toLowerCase();
        final city = (data['city'] ?? '').toString().toLowerCase();
        final province = (data['province'] ?? '').toString().toLowerCase();
        final region = (data['region'] ?? '').toString().toLowerCase();
        final country = (data['country'] ?? '').toString().toLowerCase();
        return zone.contains(_cityQuery) || 
               address.contains(_cityQuery) ||
               city.contains(_cityQuery) ||
               province.contains(_cityQuery) ||
               region.contains(_cityQuery) ||
               country.contains(_cityQuery);
      }).toList();
    }

    // Apply Pet Filters
    List<DocumentSnapshot> filteredDogs = _allDogs;
    if (_searchQuery.isNotEmpty) {
      filteredDogs = filteredDogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final breed = (data['breed'] ?? '').toString().toLowerCase();
        return name.contains(_searchQuery) || breed.contains(_searchQuery);
      }).toList();
    }
    if (_selectedPetSpecies != 'all') {
      filteredDogs = filteredDogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['species'] == _selectedPetSpecies;
      }).toList();
    }
    if (_selectedPetGender != 'all') {
      filteredDogs = filteredDogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['gender'] == _selectedPetGender;
      }).toList();
    }
    if (_selectedPetSize != 'all') {
      filteredDogs = filteredDogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['size'] == _selectedPetSize;
      }).toList();
    }
    if (_cityQuery.isNotEmpty) {
      filteredDogs = filteredDogs.where((doc) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final ownerId = data['ownerId'];
        
        // Find owner to filter by location
        DocumentSnapshot? ownerDoc;
        for (var u in _allUsers) {
          if (u.id == ownerId) {
            ownerDoc = u;
            break;
          }
        }
        if (ownerDoc == null) return false;
        final ownerData = ownerDoc.data() as Map<String, dynamic>? ?? {};
        final zone = (ownerData['zone'] ?? '').toString().toLowerCase();
        final address = (ownerData['address'] ?? '').toString().toLowerCase();
        final city = (ownerData['city'] ?? '').toString().toLowerCase();
        final province = (ownerData['province'] ?? '').toString().toLowerCase();
        final region = (ownerData['region'] ?? '').toString().toLowerCase();
        final country = (ownerData['country'] ?? '').toString().toLowerCase();
        return zone.contains(_cityQuery) || 
               address.contains(_cityQuery) ||
               city.contains(_cityQuery) ||
               province.contains(_cityQuery) ||
               region.contains(_cityQuery) ||
               country.contains(_cityQuery);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Selector Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTabButton(
                    title: 'Utenti Registrati',
                    isActive: _showUsersTab,
                    icon: Icons.people,
                    onTap: () {
                      setState(() {
                        _showUsersTab = true;
                        _resetFilters();
                      });
                    },
                  ),
                  _buildTabButton(
                    title: 'Pet / Animali',
                    isActive: !_showUsersTab,
                    icon: Icons.pets,
                    onTap: () {
                      setState(() {
                        _showUsersTab = false;
                        _resetFilters();
                      });
                    },
                  ),
                ],
              ),
            ),
            if (_searchQuery.isNotEmpty ||
                _cityQuery.isNotEmpty ||
                _selectedGender != 'all' ||
                _selectedSubscription != 'all' ||
                _selectedAccountType != 'all' ||
                _selectedPetSpecies != 'all' ||
                _selectedPetGender != 'all' ||
                _selectedPetSize != 'all')
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Azzera filtri'),
                style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // KPI Counters Block
        _buildKPICards(filteredUsers.length, filteredDogs.length),
        const SizedBox(height: 28),

        // Filters Header
        const Text(
          'Filtri e Ricerca',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2342)),
        ),
        const SizedBox(height: 12),

        // Filters Row / Wrap
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Search Input
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _showUsersTab ? 'Cerca utente per nome o email...' : 'Cerca pet per nome o razza...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              ),
            ),

            // City / Zone Input
            SizedBox(
              width: 200,
              child: TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  hintText: 'Città o Zona...',
                  prefixIcon: const Icon(Icons.location_on, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[300]!)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (val) => setState(() => _cityQuery = val.toLowerCase()),
              ),
            ),

            // User-Specific Dropdowns
            if (_showUsersTab) ...[
              _buildDropdown(
                label: 'Genere',
                value: _selectedGender,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutti i generi')),
                  DropdownMenuItem(value: 'male', child: Text('Uomini')),
                  DropdownMenuItem(value: 'female', child: Text('Donne')),
                  DropdownMenuItem(value: 'other', child: Text('Altri')),
                ],
                onChanged: (val) => setState(() => _selectedGender = val ?? 'all'),
              ),
              _buildDropdown(
                label: 'Abbonamento',
                value: _selectedSubscription,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutti i piani')),
                  DropdownMenuItem(value: 'free', child: Text('Solo Free')),
                  DropdownMenuItem(value: 'premium', child: Text('Solo Premium (PRO)')),
                ],
                onChanged: (val) => setState(() => _selectedSubscription = val ?? 'all'),
              ),
              _buildDropdown(
                label: 'Tipo Account',
                value: _selectedAccountType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutti i tipi')),
                  DropdownMenuItem(value: 'personal', child: Text('Personali')),
                  DropdownMenuItem(value: 'business', child: Text('Business')),
                ],
                onChanged: (val) => setState(() => _selectedAccountType = val ?? 'all'),
              ),
            ],

            // Pet-Specific Dropdowns
            if (!_showUsersTab) ...[
              _buildDropdown(
                label: 'Specie',
                value: _selectedPetSpecies,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutte le specie')),
                  DropdownMenuItem(value: 'dog', child: Text('Cani 🐶')),
                  DropdownMenuItem(value: 'cat', child: Text('Gatti 🐱')),
                ],
                onChanged: (val) => setState(() => _selectedPetSpecies = val ?? 'all'),
              ),
              _buildDropdown(
                label: 'Genere Pet',
                value: _selectedPetGender,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Entrambi i generi')),
                  DropdownMenuItem(value: 'male', child: Text('Maschi ♂️')),
                  DropdownMenuItem(value: 'female', child: Text('Femmine ♀️')),
                ],
                onChanged: (val) => setState(() => _selectedPetGender = val ?? 'all'),
              ),
              _buildDropdown(
                label: 'Taglia Pet',
                value: _selectedPetSize,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tutte le taglie')),
                  DropdownMenuItem(value: 'small', child: Text('Piccola')),
                  DropdownMenuItem(value: 'medium', child: Text('Media')),
                  DropdownMenuItem(value: 'large', child: Text('Grande')),
                  DropdownMenuItem(value: 'giant', child: Text('Gigante')),
                ],
                onChanged: (val) => setState(() => _selectedPetSize = val ?? 'all'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Count summary
        Text(
          _showUsersTab
              ? 'Trovati ${filteredUsers.length} utenti su ${_allUsers.length}'
              : 'Trovati ${filteredDogs.length} pet su ${_allDogs.length}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 8),

        // Data Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _showUsersTab
                  ? _buildUsersTable(filteredUsers)
                  : _buildPetsTable(filteredDogs),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF0A2342) : Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? const Color(0xFF0A2342) : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICards(int filteredUsersCount, int filteredDogsCount) {
    if (_showUsersTab) {
      final total = _allUsers.length;
      final premium = _allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['isPremium'] == true).length;
      final business = _allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['accountType'] == 'business').length;
      
      final male = _allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['gender'] == 'male').length;
      final female = _allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['gender'] == 'female').length;
      final other = _allUsers.where((doc) => (doc.data() as Map<String, dynamic>)['gender'] == 'other').length;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildCard(
            title: 'TOTALE UTENTI',
            value: '$total',
            icon: Icons.people,
            color: Colors.blue,
            subtitle: 'Utenti registrati in totale',
          ),
          _buildCard(
            title: 'ACCOUNT PREMIUM',
            value: '$premium',
            icon: Icons.star,
            color: Colors.amber,
            subtitle: '${total > 0 ? ((premium / total) * 100).toStringAsFixed(1) : 0}% degli utenti',
          ),
          _buildCard(
            title: 'ACCOUNT BUSINESS',
            value: '$business',
            icon: Icons.storefront,
            color: Colors.indigo,
            subtitle: '${total > 0 ? ((business / total) * 100).toStringAsFixed(1) : 0}% degli utenti',
          ),
          _buildCard(
            title: 'GENERE UTENTI',
            value: '$male / $female / $other',
            icon: Icons.wc,
            color: Colors.purple,
            subtitle: 'Uomini / Donne / Altri',
          ),
        ],
      );
    } else {
      final total = _allDogs.length;
      final dogs = _allDogs.where((doc) => (doc.data() as Map<String, dynamic>)['species'] == 'dog').length;
      final cats = _allDogs.where((doc) => (doc.data() as Map<String, dynamic>)['species'] == 'cat').length;
      
      final male = _allDogs.where((doc) => (doc.data() as Map<String, dynamic>)['gender'] == 'male').length;
      final female = _allDogs.where((doc) => (doc.data() as Map<String, dynamic>)['gender'] == 'female').length;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildCard(
            title: 'TOTALE PET',
            value: '$total',
            icon: Icons.pets,
            color: Colors.teal,
            subtitle: 'Pet registrati in totale',
          ),
          _buildCard(
            title: 'CANI 🐶',
            value: '$dogs',
            icon: Icons.pets,
            color: Colors.orange,
            subtitle: '${total > 0 ? ((dogs / total) * 100).toStringAsFixed(1) : 0}% sul totale',
          ),
          _buildCard(
            title: 'GATTI 🐱',
            value: '$cats',
            icon: Icons.pets,
            color: Colors.cyan,
            subtitle: '${total > 0 ? ((cats / total) * 100).toStringAsFixed(1) : 0}% sul totale',
          ),
          _buildCard(
            title: 'GENERE PET',
            value: '$male M / $female F',
            icon: Icons.wc,
            color: Colors.pink,
            subtitle: 'Maschi / Femmine',
          ),
        ],
      );
    }
  }

  Widget _buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0A2342),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: Color(0xFF0A2342), fontWeight: FontWeight.w500),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildUsersTable(List<DocumentSnapshot> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nessun utente corrisponde ai filtri', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 14,
          horizontalMargin: 8,
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Utente', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Città / Zona', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Genere', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Premium', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Registrato', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: users.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final firstName = data['firstName'] ?? '';
            final lastName = data['lastName'] ?? '';
            final fullName = '$firstName $lastName'.trim();
            final displayName = fullName.isNotEmpty ? fullName : '—';
            final email = data['email'] ?? '—';
            
            final genderVal = data['gender'] ?? '—';
            final genderStr = genderVal == 'male' 
                ? 'Uomo' 
                : genderVal == 'female' 
                    ? 'Donna' 
                    : genderVal == 'other' 
                        ? 'Altro' 
                        : '—';

            final isPremium = data['isPremium'] == true;
            final isBanned = data['isBanned'] == true;
            final accountType = data['accountType'] ?? 'personal';
            final createdAt = data['createdAt'] as Timestamp?;
            final dateStr = createdAt != null
                ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                : '—';
            final photoUrl = data['photoUrl'] as String?;

            return DataRow(
              color: isBanned ? WidgetStateProperty.all(Colors.red[50]) : null,
              cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey[200],
                      child: photoUrl == null || photoUrl.isEmpty ? Icon(Icons.person, size: 16, color: Colors.grey[400]) : null,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              decoration: isBanned ? TextDecoration.lineThrough : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isBanned)
                            Text('BANNATO', style: TextStyle(fontSize: 9, color: Colors.red[600], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                )),
                DataCell(Container(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
                DataCell(_buildLocationCell(data)),
                DataCell(Text(genderStr, style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: accountType == 'business' ? Colors.indigo[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    accountType == 'business' ? '🏪 Business' : '👤 Personale',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accountType == 'business' ? Colors.indigo[700] : Colors.grey[600]),
                  ),
                )),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isPremium ? Colors.amber[50] : Colors.grey[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPremium ? '⭐ PRO' : 'Free',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPremium ? Colors.amber[800] : Colors.grey[500]),
                  ),
                )),
                DataCell(Text(dateStr, style: TextStyle(fontSize: 11.5, color: Colors.grey[500]))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isBanned)
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Banna utente',
                        onPressed: () => _confirmBan(context, doc.id, displayName),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.lock_open, color: Colors.green, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Rimuovi ban',
                        onPressed: () => _unban(context, doc.id, displayName),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Invia messaggio chat',
                      onPressed: () => _showSendAdminMessageDialog(context, doc.id, displayName),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download_outlined, color: Colors.blue, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Esporta dati GDPR',
                      onPressed: () => _exportUserDataAdmin(context, doc.id, displayName),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Elimina utente permanentemente',
                      onPressed: () => _confirmDeleteUser(context, doc.id, displayName),
                    ),
                  ],
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPetsTable(List<DocumentSnapshot> dogs) {
    if (dogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pets, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Nessun pet corrisponde ai filtri', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          horizontalMargin: 8,
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Pet', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Specie / Razza', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Genere / Età', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Taglia / Peso', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Proprietario', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Città / Zona (Owner)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Registrato', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Azioni', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: dogs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? '—';
            final breed = data['breed'] ?? '—';
            final age = data['age'] ?? 0;
            final weight = data['weight'] ?? '—';
            
            final speciesVal = data['species'] ?? 'dog';
            final speciesStr = speciesVal == 'cat' ? 'Gatto 🐱' : 'Cane 🐶';

            final genderVal = data['gender'] ?? 'male';
            final genderStr = genderVal == 'female' ? 'Femmina ♀️' : 'Maschio ♂️';

            final sizeVal = data['size'] ?? 'medium';
            final sizeStr = sizeVal == 'small' 
                ? 'Piccola' 
                : sizeVal == 'medium' 
                    ? 'Media' 
                    : sizeVal == 'large' 
                        ? 'Grande' 
                        : sizeVal == 'giant' 
                            ? 'Gigante' 
                            : 'Media';

            final createdAt = data['createdAt'] as Timestamp?;
            final dateStr = createdAt != null
                ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                : '—';

            final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
            final photoUrl = mediaUrls.isNotEmpty ? mediaUrls.first : data['photoUrl'] as String?;

            // Retrieve owner details
            final ownerId = data['ownerId'];
            DocumentSnapshot? ownerDoc;
            for (var u in _allUsers) {
              if (u.id == ownerId) {
                ownerDoc = u;
                break;
              }
            }

            String ownerName = 'Sconosciuto';
            String ownerEmail = '—';
            String ownerLocation = '—';

            if (ownerDoc != null) {
              final ownerData = ownerDoc.data() as Map<String, dynamic>;
              final fName = ownerData['firstName'] ?? '';
              final lName = ownerData['lastName'] ?? '';
              final full = '$fName $lName'.trim();
              if (full.isNotEmpty) ownerName = full;
              ownerEmail = ownerData['email'] ?? '—';

              final addr = ownerData['address'] ?? '';
              final zn = ownerData['zone'] ?? '';
              ownerLocation = zn.isNotEmpty ? zn : (addr.isNotEmpty ? addr : '—');
            }

            return DataRow(
              cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey[200],
                      child: photoUrl == null || photoUrl.isEmpty ? Icon(Icons.pets, size: 16, color: Colors.grey[400]) : null,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )),
                DataCell(Container(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(speciesStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(
                        breed,
                        style: TextStyle(fontSize: 10.5, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )),
                DataCell(Text('$genderStr • $age ${age == 1 ? 'anno' : 'anni'}', style: const TextStyle(fontSize: 12))),
                DataCell(Text('$sizeStr • $weight kg', style: const TextStyle(fontSize: 12))),
                DataCell(Container(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ownerName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        ownerEmail,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )),
                DataCell(
                  ownerDoc != null
                      ? _buildLocationCell(ownerDoc.data() as Map<String, dynamic>? ?? {})
                      : const Text('—', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                DataCell(Text(dateStr, style: TextStyle(fontSize: 11.5, color: Colors.grey[500]))),
                DataCell(IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Elimina pet permanentemente',
                  onPressed: () => _confirmDeletePet(context, doc.id, name),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _confirmBan(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Ban'),
        content: Text('Vuoi bannare "$name"? L\'utente non potrà più accedere all\'app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Banna'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'isBanned': true});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name è stato bannato.')));
      }
    }
  }

  Future<void> _unban(BuildContext context, String uid, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'isBanned': false});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ban rimosso per $name.')));
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context, String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Utente'),
        content: Text('Sei sicuro di voler eliminare permanentemente l\'utente "$name" e tutti i suoi pet associati? Questa azione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // 1. Delete user document
        batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
        
        // 2. Fetch and delete user's pets
        final petsQuery = await FirebaseFirestore.instance
            .collection('dogs')
            .where('ownerId', isEqualTo: uid)
            .get();
            
        for (var doc in petsQuery.docs) {
          batch.delete(doc.reference);
        }
        
        // Commit batch
        await batch.commit();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Utente "$name" e tutti i pet associati eliminati con successo.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
          );
        }
      }
    }
  }

  void _showSendAdminMessageDialog(BuildContext context, String targetUid, String targetName) {
    final textController = TextEditingController();
    bool sending = false;
    final systemUid = 'DOGZN';
    final participants = [systemUid, targetUid]..sort();
    final chatId = participants.join('_');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.support_agent, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chat di Supporto: $targetName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Identità Mittente: DOGZN (Sistema)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 450,
                child: Column(
                  children: [
                    // Chat History
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .collection('messages')
                              .orderBy('timestamp', descending: true)
                              .limit(50)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Center(child: Text('Errore: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                            }
                            final docs = snapshot.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 8),
                                    Text('Nessun messaggio precedente', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              reverse: true, // Show most recent messages at the bottom
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final text = data['text'] ?? '';
                                final senderId = data['senderId'] ?? '';
                                final isMe = senderId == systemUid;
                                final timestamp = data['timestamp'] as Timestamp?;
                                final timeStr = timestamp != null
                                    ? '${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                                    : '';

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppColors.primary : Colors.grey[300],
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(12),
                                        topRight: const Radius.circular(12),
                                        bottomLeft: Radius.circular(isMe ? 12 : 0),
                                        bottomRight: Radius.circular(isMe ? 0 : 12),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          text,
                                          style: TextStyle(
                                            color: isMe ? Colors.white : Colors.black87,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              color: isMe ? Colors.white60 : Colors.black45,
                                              fontSize: 9,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Input Area
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: textController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: 'Scrivi un messaggio...',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          color: AppColors.primary,
                          icon: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          onPressed: sending
                              ? null
                              : () async {
                                  final text = textController.text.trim();
                                  if (text.isEmpty) return;

                                  setState(() => sending = true);

                                  try {
                                    final adminUid = FirebaseAuth.instance.currentUser?.uid;
                                    if (adminUid == null) {
                                      throw Exception('Devi aver effettuato l\'accesso come Admin.');
                                    }

                                    // Call HTTPS Callable Cloud Function in europe-west1
                                    await FirebaseFunctions.instanceFor(region: 'europe-west1')
                                        .httpsCallable('adminContactUser')
                                        .call({
                                      'targetUid': targetUid,
                                      'messageText': text,
                                    });

                                    textController.clear();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Errore: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } finally {
                                    setState(() => sending = false);
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Chiudi'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportUserDataAdmin(BuildContext context, String uid, String name) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Generazione export GDPR in corso...')),
          ],
        ),
      ),
    );

    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('exportUserData')
          .call({'userId': uid});

      if (context.mounted) Navigator.pop(context);

      final data = result.data;
      if (data == null) {
        throw Exception('Nessun dato restituito.');
      }

      const encoder = JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(data);

      final uri = Uri.dataFromString(
        jsonString,
        mimeType: 'application/json',
        encoding: utf8,
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Esportazione GDPR per $name completata con successo.')),
          );
        }
      } else {
        throw Exception('Impossibile scaricare il file.');
      }

    } catch (e) {
      try {
        if (context.mounted) Navigator.pop(context);
      } catch (_) {}

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Errore Esportazione'),
            content: Text('Impossibile completare l\'esportazione dati per $name: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _confirmDeletePet(BuildContext context, String petId, String petName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Pet'),
        content: Text('Sei sicuro di voler eliminare permanentemente il pet "$petName"? Questa azione è irreversibile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('dogs').doc(petId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pet "$petName" eliminato con successo.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore durante l\'eliminazione: $e')),
          );
        }
      }
    }
  }
}
