import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../providers/matcher_provider.dart';

class MatcherFiltersSheet extends ConsumerStatefulWidget {
  const MatcherFiltersSheet({super.key});

  @override
  ConsumerState<MatcherFiltersSheet> createState() => _MatcherFiltersSheetState();
}

class _MatcherFiltersSheetState extends ConsumerState<MatcherFiltersSheet> {
  late List<PetSpecies> _selectedSpecies;
  late List<DogGender> _selectedGenders;
  late double _maxDistance;
  late bool? _isSterilized;

  @override
  void initState() {
    super.initState();
    final matcherState = ref.read(matcherProvider);
    _selectedSpecies = List.from(matcherState.speciesFilter);
    _selectedGenders = List.from(matcherState.genderFilter);
    _maxDistance = matcherState.maxDistanceFilter;
    _isSterilized = matcherState.isSterilizedFilter;
  }

  void _toggleSpecies(PetSpecies species) {
    setState(() {
      if (_selectedSpecies.contains(species)) {
        if (_selectedSpecies.length > 1) {
          _selectedSpecies.remove(species);
        }
      } else {
        _selectedSpecies.add(species);
      }
    });
  }

  void _toggleGender(DogGender gender) {
    setState(() {
      if (_selectedGenders.contains(gender)) {
        if (_selectedGenders.length > 1) {
          _selectedGenders.remove(gender);
        }
      } else {
        _selectedGenders.add(gender);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Filtri di ricerca',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 24),

          // Species Filter
          const Text(
            'Mostrami',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: PetSpecies.values.map((species) {
              final isSelected = _selectedSpecies.contains(species);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(
                    species == PetSpecies.dog ? 'Cani 🐶' : 'Gatti 🐱',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant.withOpacity(0.5),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => _toggleSpecies(species),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Gender Filter
          const Text(
            'Sesso del pet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: DogGender.values.map((gender) {
              final isSelected = _selectedGenders.contains(gender);
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(
                    gender.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant.withOpacity(0.5),
                  checkmarkColor: Colors.white,
                  onSelected: (_) => _toggleGender(gender),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Distance Filter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distanza massima',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_maxDistance.round()} km',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceVariant,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.12),
              valueIndicatorColor: AppColors.primary,
              trackHeight: 4,
            ),
            child: Slider(
              value: _maxDistance,
              min: 2,
              max: 100,
              divisions: 49,
              onChanged: (value) {
                setState(() {
                  _maxDistance = value;
                });
              },
            ),
          ),
          const SizedBox(height: 28),

          // Sterilized Filter
          const Text(
            'Sterilizzato / Castrato',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(
                    'Sì',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isSterilized == true ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  selected: _isSterilized == true,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant.withOpacity(0.5),
                  checkmarkColor: Colors.white,
                  onSelected: (_) {
                    setState(() {
                      _isSterilized = _isSterilized == true ? null : true;
                    });
                  },
                ),
              ),
              ChoiceChip(
                label: Text(
                  'No',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _isSterilized == false ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: _isSterilized == false,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant.withOpacity(0.5),
                checkmarkColor: Colors.white,
                onSelected: (_) {
                  setState(() {
                    _isSterilized = _isSterilized == false ? null : false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Action buttons
          ElevatedButton(
            onPressed: () {
              ref.read(matcherProvider.notifier).updateFilters(
                    species: _selectedSpecies,
                    genders: _selectedGenders,
                    maxDistance: _maxDistance,
                    isSterilized: _isSterilized,
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Applica Filtri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
