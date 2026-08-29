import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../constants/tutorial_keys.dart';

class TutorialService {
  static const String _onboardingKey = 'dogzn_onboarding_completed';

  /// Check if the onboarding tutorial has been completed
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Mark onboarding as completed
  static Future<void> markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Start the full onboarding tutorial.
  /// [tabSwitcher] is a callback to change the active tab (0-4).
  static void startOnboarding({
    required BuildContext context,
    required void Function(int tabIndex) tabSwitcher,
  }) {
    final targets = _buildTargets(tabSwitcher);

    // Track the current tab so we know when a switch is needed
    int currentTab = 0;

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF1A1A2E),
      opacityShadow: 0.85,
      textSkip: 'SALTA',
      textStyleSkip: const TextStyle(
        color: Colors.white70,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
      paddingFocus: 8,
      focusAnimationDuration: const Duration(milliseconds: 400),
      unFocusAnimationDuration: const Duration(milliseconds: 400),
      // beforeFocus is called BEFORE each target is focused.
      // It's async — the library waits for the Future to complete
      // before proceeding to find and highlight the target widget.
      // This is the correct place to switch tabs so the widget tree
      // is fully built before the library tries to locate the GlobalKey.
      beforeFocus: (target) async {
        final identify = target.identify as String?;
        if (identify == null) return;

        final targetTab = getTabForTarget(identify);
        if (targetTab != null && targetTab != currentTab) {
          tabSwitcher(targetTab);
          currentTab = targetTab;
          // Wait for the new tab's widget tree to be fully built and rendered.
          // addPostFrameCallback ensures the frame is committed,
          // then the additional delay ensures layout is complete.
          await Future.delayed(const Duration(milliseconds: 450));
        }
      },
      onFinish: () {
        markOnboardingCompleted();
      },
      onSkip: () {
        markOnboardingCompleted();
        return true;
      },
    );

    // Delay slightly to let the first screen render fully
    Future.delayed(const Duration(milliseconds: 800), () {
      tutorial.show(context: context);
    });
  }

  static List<TargetFocus> _buildTargets(void Function(int) tabSwitcher) {
    return [
      // ═══════════════════════════════════════════
      // STEP 1: Welcome overlay (no specific target)
      // ═══════════════════════════════════════════
      TargetFocus(
        identify: 'welcome',
        targetPosition: TargetPosition(
          const Size(1, 1),
          const Offset(-100, -100),
        ),
        shape: ShapeLightFocus.Circle,
        radius: 0,
        enableOverlayTab: true,
        enableTargetTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(top: 200),
            builder: (context, controller) => _buildWelcomeCard(
              icon: '🐾',
              title: 'Benvenuto su DOGZN!',
              body: 'Ti guideremo alla scoperta dell\'app in pochi secondi.\nTocca ovunque per continuare.',
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════
      // TAB 0 — SOCIAL
      // ═══════════════════════════════════════════

      // STEP 2: Feed tab "Per te"
      TargetFocus(
        identify: 'feed_tab',
        keyTarget: TutorialKeys.feedTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.dynamic_feed,
              title: 'Il tuo Feed',
              body: 'Qui trovi post e foto della community.\nScorri per scoprire nuovi contenuti!',
            ),
          ),
        ],
      ),

      // STEP 3: Reels tab
      TargetFocus(
        identify: 'reels_tab',
        keyTarget: TutorialKeys.reelsTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.play_circle_outline,
              title: 'Reels',
              body: 'Video brevi dalla community.\nGuarda e condividi i momenti migliori!',
            ),
          ),
        ],
      ),

      // STEP 4: Bacheca tab
      TargetFocus(
        identify: 'bacheca_tab',
        keyTarget: TutorialKeys.bachecaTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.campaign,
              title: 'Bacheca Annunci',
              body: 'Cerca dog sitter, accessori, servizi e pubblica i tuoi annunci.\nPerfetto anche per i professionisti!',
            ),
          ),
        ],
      ),

      // STEP 5: Create post button
      TargetFocus(
        identify: 'create_post',
        keyTarget: TutorialKeys.createPostKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.add_photo_alternate,
              title: 'Crea Contenuti',
              body: 'Condividi foto e reels con la community DOGZN.',
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════
      // TAB 1 — MAPPA (auto-switch)
      // ═══════════════════════════════════════════

      // STEP 6: Map tab (bottom nav) — triggers tab switch
      TargetFocus(
        identify: 'map_tab',
        keyTarget: TutorialKeys.mapTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildCard(
              icon: Icons.map,
              title: 'La Mappa',
              body: 'Esplora! Qui trovi utenti, professionisti e attività vicino a te.',
            ),
          ),
        ],
        focusAnimationDuration: const Duration(milliseconds: 500),
      ),

      // STEP 7: Map filter button
      TargetFocus(
        identify: 'map_filter',
        keyTarget: TutorialKeys.mapFilterKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.tune,
              title: 'Filtra la Mappa',
              body: 'Cerca per razza, taglia e tipo.\nFiltra anche i professionisti per categoria!',
            ),
          ),
        ],
      ),

      // STEP 8: Start walk button
      TargetFocus(
        identify: 'start_walk',
        keyTarget: TutorialKeys.mapStartWalkKey,
        enableOverlayTab: true,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.pets,
              title: 'Passeggiata Tracking',
              body: 'Avvia il GPS e traccia percorso, distanza e passi della tua passeggiata.',
            ),
          ),
        ],
      ),

      // STEP 9: Activities/Events FAB
      TargetFocus(
        identify: 'activities_fab',
        keyTarget: TutorialKeys.activitiesFabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) => _buildCard(
              icon: Icons.diversity_3,
              title: 'Eventi e Attività',
              body: 'Scopri passeggiate di gruppo, eventi dog-friendly e raduni vicino a te.',
            ),
          ),
        ],
      ),

      // STEP 10: Safety FAB
      TargetFocus(
        identify: 'safety_fab',
        keyTarget: TutorialKeys.mapSafetyFabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.left,
            builder: (context, controller) => _buildCard(
              icon: Icons.warning_amber_rounded,
              title: 'Segnala Pericoli',
              body: 'Aiuta la community segnalando zone pericolose per i nostri amici a 4 zampe.',
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════
      // TAB 2 — DATING (auto-switch)
      // ═══════════════════════════════════════════

      // STEP 11: Dating tab
      TargetFocus(
        identify: 'dating_tab',
        keyTarget: TutorialKeys.datingTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildCard(
              icon: Icons.favorite,
              title: 'Pet Dating',
              body: 'Trova compagni di gioco e amici per il tuo pet con lo swipe!',
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════
      // TAB 3 — CHAT (auto-switch)
      // ═══════════════════════════════════════════

      // STEP 12: Chat tab
      TargetFocus(
        identify: 'chat_tab',
        keyTarget: TutorialKeys.chatTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildCard(
              icon: Icons.chat_bubble,
              title: 'Chat',
              body: 'Messaggia con altri proprietari, organizza incontri e resta in contatto!',
            ),
          ),
        ],
      ),

      // ═══════════════════════════════════════════
      // TAB 4 — PROFILO (auto-switch)
      // ═══════════════════════════════════════════

      // STEP 13: Profile tab
      TargetFocus(
        identify: 'profile_tab',
        keyTarget: TutorialKeys.profileTabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildCard(
              icon: Icons.person,
              title: 'Il tuo Profilo',
              body: 'Gestisci il tuo profilo, i tuoi pet e le impostazioni.',
            ),
          ),
        ],
      ),

      // STEP 14: Add pet button
      TargetFocus(
        identify: 'add_pet',
        keyTarget: TutorialKeys.addPetKey,
        enableOverlayTab: true,
        shape: ShapeLightFocus.Circle,
        alignSkip: Alignment.bottomCenter,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildCard(
              icon: Icons.pets,
              title: 'Aggiungi il tuo Pet! 🐶',
              body: 'Questo è il primo passo!\nAggiungi il tuo amico a 4 zampe per sbloccare tutte le funzionalità.',
              highlight: true,
            ),
          ),
        ],
      ),

      // STEP 15: Business profile
      TargetFocus(
        identify: 'business_profile',
        keyTarget: TutorialKeys.businessProfileKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topCenter,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) => _buildCard(
              icon: Icons.storefront,
              title: 'Sei un Professionista? 💼',
              body: 'Veterinari, dog sitter, toelettatori: attiva il profilo business per farti trovare sulla mappa e ricevere clienti!',
            ),
          ),
        ],
      ),

      // STEP 16: Finale
      TargetFocus(
        identify: 'finale',
        targetPosition: TargetPosition(
          const Size(1, 1),
          const Offset(-100, -100),
        ),
        shape: ShapeLightFocus.Circle,
        radius: 0,
        enableOverlayTab: true,
        enableTargetTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.custom,
            customPosition: CustomTargetContentPosition(top: 200),
            builder: (context, controller) => _buildWelcomeCard(
              icon: '🎉',
              title: 'Tutto pronto!',
              body: 'Inizia aggiungendo il tuo pet e scopri tutto quello che DOGZN ha da offrirti.\n\nBuona passeggiata! 🐾',
            ),
          ),
        ],
      ),
    ];
  }

  /// Determines which tab index a target belongs to,
  /// so MainScreen can switch tabs before showing it.
  static int? getTabForTarget(String identify) {
    switch (identify) {
      case 'welcome':
      case 'feed_tab':
      case 'reels_tab':
      case 'bacheca_tab':
      case 'create_post':
        return 0; // Social
      case 'map_tab':
      case 'map_filter':
      case 'start_walk':
      case 'activities_fab':
      case 'safety_fab':
        return 1; // Mappa
      case 'dating_tab':
        return 2; // Dating
      case 'chat_tab':
        return 3; // Chat
      case 'profile_tab':
      case 'add_pet':
      case 'business_profile':
      case 'finale':
        return 4; // Profilo
      default:
        return null;
    }
  }

  // ═══════════════════════════════════════════
  // UI BUILDERS
  // ═══════════════════════════════════════════

  static Widget _buildCard({
    required IconData icon,
    required String title,
    required String body,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFF6B4A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (highlight ? const Color(0xFFFF6B4A) : Colors.black).withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlight
                      ? Colors.white.withOpacity(0.2)
                      : const Color(0xFFFF6B4A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: highlight ? Colors.white : const Color(0xFFFF6B4A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: highlight ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: highlight ? Colors.white.withOpacity(0.9) : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Tocca per continuare →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: highlight ? Colors.white70 : const Color(0xFFFF6B4A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildWelcomeCard({
    required String icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B4A).withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Tocca per continuare',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
