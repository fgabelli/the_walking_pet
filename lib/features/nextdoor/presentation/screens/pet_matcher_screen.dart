import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/matcher_provider.dart';
import '../widgets/matcher_filters_sheet.dart';
import '../widgets/swipe_card.dart';

import '../../../profile/presentation/screens/my_pets_screen.dart';
import '../../../profile/presentation/screens/pet_profile_screen.dart';
import '../../../ads/presentation/widgets/unified_ad_card.dart';

class PetMatcherScreen extends ConsumerStatefulWidget {
  const PetMatcherScreen({super.key});

  @override
  ConsumerState<PetMatcherScreen> createState() => _PetMatcherScreenState();
}

class _PetMatcherScreenState extends ConsumerState<PetMatcherScreen> {
  final SwipeCardController _swipeController = SwipeCardController();
  int _swipeCounter = 0;
  bool _showAdCard = false;

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MatcherFiltersSheet(),
    );
  }

  void _showLikesHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return _LikesHistorySheet(scrollController: scrollController);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matcherState = ref.watch(matcherProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Dating',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: _buildActivePetSelector(matcherState),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
            onPressed: () => _showLikesHistory(context),
            tooltip: 'I tuoi Like',
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.textPrimary),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Body
          if (matcherState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (matcherState.error != null)
            Center(child: Text('Errore: ${matcherState.error}'))
          else if (matcherState.userPets.isEmpty)
            _buildNoPetsState()
          else if (matcherState.availablePets.isEmpty)
            _buildEmptyDeckState()
          else
            _buildCardDeck(matcherState),

          // Match Overlay
          if (matcherState.lastMatch != null)
            _buildMatchOverlay(matcherState.lastMatch!),
        ],
      ),
    );
  }

  Widget _buildActivePetSelector(MatcherState matcherState) {
    if (matcherState.userPets.isEmpty) return const SizedBox.shrink();

    final selectedPet = matcherState.selectedPet;
    if (selectedPet == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: PopupMenuButton<DogModel>(
        offset: const Offset(0, 40),
        onSelected: (pet) {
          ref.read(matcherProvider.notifier).selectPet(pet);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: selectedPet.photoUrl != null && selectedPet.photoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(selectedPet.photoUrl!)
                  : null,
              child: selectedPet.photoUrl == null || selectedPet.photoUrl!.isEmpty
                  ? const Icon(Icons.pets, size: 14, color: AppColors.primary)
                  : null,
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary, size: 20),
          ],
        ),
        itemBuilder: (context) {
          return matcherState.userPets.map((pet) {
            final isSelected = pet.id == selectedPet.id;
            return PopupMenuItem<DogModel>(
              value: pet,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(pet.photoUrl!)
                        : null,
                    child: pet.photoUrl == null || pet.photoUrl!.isEmpty
                        ? const Icon(Icons.pets, size: 10)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pet.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildNoPetsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.pets_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nessun pet registrato',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Per poter incontrare altri animali domestici nelle vicinanze, devi prima aggiungere un cane o gatto al tuo profilo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
            settings: const RouteSettings(name: 'my_pets'),builder: (context) => const MyPetsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Aggiungi un Pet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDeckState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 24),
            const Text(
              'Nessun pet nelle vicinanze',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Abbiamo cercato ovunque, ma non ci sono altri cani o gatti che corrispondono ai tuoi filtri in questa zona.\nProva ad allargare la distanza massima di ricerca!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showFilters,
              icon: const Icon(Icons.tune),
              label: const Text('Modifica Filtri'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDeck(MatcherState matcherState) {
    final pets = matcherState.availablePets;
    final topPet = pets.first;
    final topDistance = matcherState.petDistances[topPet.id] ?? 0.0;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Stack(
              children: [
                if (_showAdCard) ...[
                  // Render top pet as background preview
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Transform.scale(
                        scale: 0.96,
                        child: Opacity(
                          opacity: 0.6,
                          child: SwipeCard(
                            key: ValueKey('bg_top_${topPet.id}'),
                            pet: topPet,
                            distanceKm: topDistance,
                            onSwipe: (_) {},
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Render Ad card on top
                  Positioned.fill(
                    child: SwipeCard(
                      key: const ValueKey('dating_ad_card'),
                      isAd: true,
                      adWidget: const UnifiedAdCard(zone: 'dating_deck'),
                      controller: _swipeController,
                      onSwipe: (isLike) {
                        setState(() {
                          _showAdCard = false;
                        });
                      },
                    ),
                  ),
                ] else ...[
                  // Render a background preview card if there's more than one pet
                  if (pets.length > 1)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Transform.scale(
                          scale: 0.96,
                          child: Opacity(
                            opacity: 0.6,
                            child: SwipeCard(
                              key: ValueKey('bg_${pets[1].id}'),
                              pet: pets[1],
                              distanceKm: matcherState.petDistances[pets[1].id] ?? 0.0,
                              onSwipe: (_) {},
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Top card
                  Positioned.fill(
                    child: SwipeCard(
                      key: ValueKey('top_${topPet.id}'),
                      pet: topPet,
                      distanceKm: topDistance,
                      controller: _swipeController,
                      onSwipe: (isLike) {
                        ref.read(matcherProvider.notifier).swipe(
                              targetPetId: topPet.id,
                              isLike: isLike,
                            );
                        setState(() {
                          _swipeCounter++;
                          if (_swipeCounter == 1 || (_swipeCounter > 1 && (_swipeCounter - 1) % 5 == 0)) {
                            _showAdCard = true;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Action Buttons Row
        Padding(
          padding: const EdgeInsets.only(bottom: 28.0, top: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pass Button (Dislike)
              _buildGradientActionButton(
                icon: Icons.close_rounded,
                gradientColors: [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)],
                size: 62,
                iconSize: 30,
                onTap: () => _swipeController.swipe(false),
              ),
              const SizedBox(width: 20),
              // DM Button (smaller, subtle)
              _buildGradientActionButton(
                icon: Icons.send_rounded,
                gradientColors: _showAdCard
                    ? [Colors.grey.shade300, Colors.grey.shade400]
                    : [const Color(0xFF74B9FF), const Color(0xFF0984E3)],
                size: 48,
                iconSize: 20,
                onTap: _showAdCard ? () {} : () => _sendDirectMessage(matcherState, topPet),
              ),
              const SizedBox(width: 20),
              // Like Button
              _buildGradientActionButton(
                icon: Icons.favorite_rounded,
                gradientColors: [const Color(0xFF55EFC4), const Color(0xFF00B894)],
                size: 62,
                iconSize: 30,
                onTap: () => _swipeController.swipe(true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientActionButton({
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    double size = 62,
    double iconSize = 28,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: gradientColors.last.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendDirectMessage(MatcherState matcherState, DogModel topPet) async {
    final owner = matcherState.petOwners[topPet.ownerId];
    if (owner == null) return;

    final chatController = ref.read(chatControllerProvider.notifier);
    final chatId = await chatController.createChat(owner.uid);

    if (chatId != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            settings: const RouteSettings(name: 'chat'),
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUser: owner,
          ),
        ),
      );
    }
  }

  Widget _buildMatchOverlay(MatchResult match) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Spark/Trophy title
              const Text(
                'È un Match! 🐾',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${match.userPet.name} e ${match.targetPet.name} hanno fiutato un\'intesa! 🐾',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),

              // Overlapping avatars
              SizedBox(
                height: 150,
                width: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // User Pet Avatar (Left)
                    Positioned(
                      left: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: match.userPet.photoUrl != null && match.userPet.photoUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(match.userPet.photoUrl!)
                              : null,
                          child: match.userPet.photoUrl == null || match.userPet.photoUrl!.isEmpty
                              ? const Icon(Icons.pets, size: 40)
                              : null,
                        ),
                      ),
                    ),

                    // Target Pet Avatar (Right)
                    Positioned(
                      right: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage: match.targetPet.photoUrl != null && match.targetPet.photoUrl!.isNotEmpty
                              ? CachedNetworkImageProvider(match.targetPet.photoUrl!)
                              : null,
                          child: match.targetPet.photoUrl == null || match.targetPet.photoUrl!.isEmpty
                              ? const Icon(Icons.pets, size: 40)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Action buttons
              ElevatedButton(
                onPressed: () async {
                  final notifier = ref.read(matcherProvider.notifier);
                  final chatController = ref.read(chatControllerProvider.notifier);
                  
                  // Chat already auto-created on match — just find and navigate
                  final chatId = await chatController.createChat(match.targetOwner.uid);
                  
                  notifier.clearMatch();
                  
                  if (chatId != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
            settings: const RouteSettings(name: 'chat'),
                        builder: (context) => ChatScreen(
                          chatId: chatId,
                          otherUser: match.targetOwner,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Invia un messaggio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Keep Swiping button
              TextButton(
                onPressed: () {
                  ref.read(matcherProvider.notifier).clearMatch();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: const Text(
                  'Continua a scorrere',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with tabbed view for given & received likes
class _LikesHistorySheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _LikesHistorySheet({required this.scrollController});

  @override
  ConsumerState<_LikesHistorySheet> createState() => _LikesHistorySheetState();
}

class _LikesHistorySheetState extends ConsumerState<_LikesHistorySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite, size: 16),
                      SizedBox(width: 6),
                      Text('Like dati'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volunteer_activism, size: 16),
                      SizedBox(width: 6),
                      Text('Like ricevuti'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLikesList(
                  future: ref.read(matcherProvider.notifier).getLikedPets(),
                  emptyIcon: Icons.favorite_border,
                  emptyTitle: 'Nessun Like dato',
                  emptySubtitle: 'Inizia a scorrere per mettere Like!',
                ),
                _buildLikesList(
                  future: ref.read(matcherProvider.notifier).getReceivedLikes(),
                  emptyIcon: Icons.volunteer_activism_outlined,
                  emptyTitle: 'Nessun Like ricevuto',
                  emptySubtitle: 'I Like che ricevi appariranno qui',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesList({
    required Future<List<DogModel>> future,
    required IconData emptyIcon,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    return FutureBuilder<List<DogModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final pets = snapshot.data ?? [];
        if (pets.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  emptyTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emptySubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: pets.length,
          itemBuilder: (context, index) {
            final pet = pets[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 4,
              ),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage:
                    pet.photoUrl != null && pet.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(pet.photoUrl!)
                        : null,
                child: pet.photoUrl == null || pet.photoUrl!.isEmpty
                    ? const Icon(Icons.pets, size: 20)
                    : null,
              ),
              title: Text(
                pet.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                '${pet.breed} • ${pet.age} anni • ${pet.gender.displayName}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
            settings: const RouteSettings(name: 'pet_profile'),
                    builder: (_) => PetProfileScreen(dog: pet),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
