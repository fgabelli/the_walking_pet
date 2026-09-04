import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/pet_business_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../features/subscriptions/presentation/screens/paywall_screen.dart';
import '../providers/map_provider.dart';
import '../screens/pet_search_screen.dart';

class MapFilterBottomSheet extends ConsumerStatefulWidget {
  const MapFilterBottomSheet({super.key});

  @override
  ConsumerState<MapFilterBottomSheet> createState() => _MapFilterBottomSheetState();
}

class _MapFilterBottomSheetState extends ConsumerState<MapFilterBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _currentRadius;
  late TextEditingController _breedController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final mapState = ref.read(mapControllerProvider);
    _currentRadius = mapState.radiusInKm;
    final initialBreed = mapState.filterDogBreeds.isNotEmpty
        ? mapState.filterDogBreeds.first
        : '';
    _breedController = TextEditingController(text: initialBreed);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  void _resetAllFilters() {
    final notifier = ref.read(mapControllerProvider.notifier);
    notifier.clearFilters();
    notifier.clearDogFilters();
    notifier.setPetSpeciesFilter([]);
    notifier.setBusinessCategoryFilter([]);
    notifier.setSearchRadius(10.0);

    setState(() {
      _currentRadius = 10.0;
      _breedController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final isPremium = userAsync.value?.isPremium ?? false;
    final mapState = ref.watch(mapControllerProvider);

    final hasFilters = mapState.filterPetSpecies.isNotEmpty ||
        mapState.filterDogSizes.isNotEmpty ||
        mapState.filterDogGenders.isNotEmpty ||
        mapState.filterDogBreeds.isNotEmpty ||
        mapState.filterIsSterilized != null ||
        mapState.filterBusinessCategories.isNotEmpty ||
        mapState.radiusInKm != 10.0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Cerca sulla Mappa',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (hasFilters)
                    TextButton(
                      onPressed: _resetAllFilters,
                      child: const Text('Resetta', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs: Persone | Attività
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people, size: 18),
                          SizedBox(width: 6),
                          Text('Persone & Pet'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.store, size: 18),
                          SizedBox(width: 6),
                          Text('Attività'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tab content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB 1: Persone & Pet
                  _buildPeopleTab(mapState, isPremium),
                  // TAB 2: Attività commerciali
                  _buildBusinessTab(mapState),
                ],
              ),
            ),

            // Radius slider (always visible)
            _buildRadiusSection(mapState),

            // Bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: Persone & Pet ──
  Widget _buildPeopleTab(MapState mapState, bool isPremium) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Specie
          const Text(
            'Tipo di Pet',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSpeciesChip(mapState, PetSpecies.dog, '🐶', 'Cani'),
              const SizedBox(width: 10),
              _buildSpeciesChip(mapState, PetSpecies.cat, '🐱', 'Gatti'),
            ],
          ),
          const SizedBox(height: 24),

          // Premium filters
          if (!isPremium) ...[
            _buildPremiumBanner(),
            const SizedBox(height: 16),
          ],

          Opacity(
            opacity: isPremium ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !isPremium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Taglia
                  const Text(
                    'Taglia',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: DogSize.values.map((size) {
                      final isSelected = mapState.filterDogSizes.contains(size);
                      return _buildFilterChip(
                        label: size.displayName,
                        isSelected: isSelected,
                        onTap: () {
                          final newSizes = List<DogSize>.from(mapState.filterDogSizes);
                          isSelected ? newSizes.remove(size) : newSizes.add(size);
                          ref.read(mapControllerProvider.notifier).setDogFilters(sizes: newSizes);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Sesso
                  const Text(
                    'Sesso',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: DogGender.values.map((gender) {
                      final isSelected = mapState.filterDogGenders.contains(gender);
                      return _buildFilterChip(
                        label: gender.displayName,
                        isSelected: isSelected,
                        onTap: () {
                          final newGenders = List<DogGender>.from(mapState.filterDogGenders);
                          isSelected ? newGenders.remove(gender) : newGenders.add(gender);
                          ref.read(mapControllerProvider.notifier).setDogFilters(genders: newGenders);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Razza
                  const Text(
                    'Razza',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _breedController,
                    decoration: InputDecoration(
                      hintText: 'Cerca razza (es. Labrador)...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _breedController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _breedController.clear();
                                ref.read(mapControllerProvider.notifier).setDogFilters(breeds: []);
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (value) {
                      setState(() {});
                      final list = value.trim().isEmpty ? <String>[] : [value.trim()];
                      ref.read(mapControllerProvider.notifier).setDogFilters(breeds: list);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Sterilizzato/Castrato
                  const Text(
                    'Sterilizzato / Castrato',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Sì',
                        isSelected: mapState.filterIsSterilized == true,
                        onTap: () {
                          final newVal = mapState.filterIsSterilized == true ? null : true;
                          ref.read(mapControllerProvider.notifier).setDogFilters(isSterilized: newVal);
                        },
                      ),
                      _buildFilterChip(
                        label: 'No',
                        isSelected: mapState.filterIsSterilized == false,
                        onTap: () {
                          final newVal = mapState.filterIsSterilized == false ? null : false;
                          ref.read(mapControllerProvider.notifier).setDogFilters(isSterilized: newVal);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Search button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
            settings: const RouteSettings(name: 'pet_search'),builder: (_) => const PetSearchScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text(
                'Cerca persone e pet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── TAB 2: Attività ──
  Widget _buildBusinessTab(MapState mapState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mostra attività pet sulla mappa',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: mapState.showPetBusinesses ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ),
              Switch.adaptive(
                value: mapState.showPetBusinesses,
                onChanged: (value) {
                  ref.read(mapControllerProvider.notifier).togglePetBusinesses(value);
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (mapState.showPetBusinesses) ...[
            const Text(
              'Categorie',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: PetBusinessCategory.values
                  .where((c) => c != PetBusinessCategory.other)
                  .map((category) {
                final isSelected = mapState.filterBusinessCategories.contains(category);
                return GestureDetector(
                  onTap: () {
                    final current = List<PetBusinessCategory>.from(mapState.filterBusinessCategories);
                    isSelected ? current.remove(category) : current.add(category);
                    ref.read(mapControllerProvider.notifier).setBusinessCategoryFilter(current);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey[200]!,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.icon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : Colors.black87,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check, size: 16, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            if (mapState.filterBusinessCategories.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  ref.read(mapControllerProvider.notifier).setBusinessCategoryFilter([]);
                },
                child: Text(
                  'Mostra tutte le categorie',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.store_mall_directory, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Attiva il toggle per vedere\nveterinari, pet shop e altro',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── RADIUS SECTION ──
  Widget _buildRadiusSection(MapState mapState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Raggio di ricerca',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentRadius.toInt()} km',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: Colors.grey[200],
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.1),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _currentRadius,
              min: 1,
              max: 50,
              divisions: 49,
              onChanged: (value) {
                setState(() => _currentRadius = value);
              },
              onChangeEnd: (value) {
                ref.read(mapControllerProvider.notifier).setSearchRadius(value);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              Text('50 km', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  // ── HELPERS ──

  Widget _buildSpeciesChip(MapState state, PetSpecies species, String emoji, String label) {
    final isSelected = state.filterPetSpecies.contains(species);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          final newList = List<PetSpecies>.from(state.filterPetSpecies);
          isSelected ? newList.remove(species) : newList.add(species);
          ref.read(mapControllerProvider.notifier).setPetSpeciesFilter(newList);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 15,
                  color: isSelected ? AppColors.primary : Colors.black87,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, size: 18, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[200]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(
            settings: const RouteSettings(name: 'paywall'),builder: (_) => const PaywallScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade100, Colors.amber.shade50],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filtri avanzati Premium',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    'Taglia, sesso, razza',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.amber),
          ],
        ),
      ),
    );
  }
}
