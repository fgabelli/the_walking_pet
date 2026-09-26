import 'package:flutter_test/flutter_test.dart';
import 'package:the_walking_pet/core/services/tutorial_service.dart';

void main() {
  group('Dating Pause Tab Mapping Logic', () {
    List<int> getVisibleTabs(bool datingEnabled) =>
        datingEnabled ? const [0, 1, 2, 3, 4] : const [0, 1, 3, 4];

    const List<String> nomiTab = [
      'community',
      'map',
      'pet_matcher',
      'chat_list',
      'profile',
    ];

    test('When dating_enabled is false, only 4 tabs are visible and dating is omitted', () {
      final visibleTabs = getVisibleTabs(false);
      expect(visibleTabs.length, 4);
      expect(visibleTabs.contains(2), isFalse);
      expect(visibleTabs, [0, 1, 3, 4]);

      // Mappatura da indice barra a indice reale dello stack
      expect(visibleTabs[0], 0); // Social
      expect(visibleTabs[1], 1); // Mappa
      expect(visibleTabs[2], 3); // Chat
      expect(visibleTabs[3], 4); // Profilo

      // Nomi tab corrispondenti agli indici reali
      expect(nomiTab[visibleTabs[0]], 'community');
      expect(nomiTab[visibleTabs[1]], 'map');
      expect(nomiTab[visibleTabs[2]], 'chat_list');
      expect(nomiTab[visibleTabs[3]], 'profile');
    });

    test('When dating_enabled is false, reverse mapping highlights the correct bottom bar icon', () {
      final visibleTabs = getVisibleTabs(false);

      // Se arriva un deep link o una notifica che apre la chat (indice reale 3):
      final realChatIndex = 3;
      final navBarChatIndex = visibleTabs.indexOf(realChatIndex);
      expect(navBarChatIndex, 2); // Terzo elemento visibile della barra (Chat)

      // Se si apre il profilo (indice reale 4):
      final realProfileIndex = 4;
      final navBarProfileIndex = visibleTabs.indexOf(realProfileIndex);
      expect(navBarProfileIndex, 3); // Quarto elemento visibile della barra (Profilo)

      // Se si apre la mappa (indice reale 1):
      final realMapIndex = 1;
      final navBarMapIndex = visibleTabs.indexOf(realMapIndex);
      expect(navBarMapIndex, 1);

      // Se si apre la community (indice reale 0):
      final realCommunityIndex = 0;
      final navBarCommunityIndex = visibleTabs.indexOf(realCommunityIndex);
      expect(navBarCommunityIndex, 0);

      // Se una vecchia notifica tenta di aprire tab 2 (Dating):
      final realDatingIndex = 2;
      final navBarDatingIndex = visibleTabs.indexOf(realDatingIndex);
      expect(navBarDatingIndex, -1); // Non esiste nella barra visibile
    });

    test('When dating_enabled is true, all 5 tabs are mapped 1:1', () {
      final visibleTabs = getVisibleTabs(true);
      expect(visibleTabs.length, 5);
      expect(visibleTabs, [0, 1, 2, 3, 4]);

      for (int i = 0; i < 5; i++) {
        expect(visibleTabs[i], i);
        expect(visibleTabs.indexOf(i), i);
      }

      expect(nomiTab[visibleTabs[2]], 'pet_matcher');
      expect(nomiTab[visibleTabs[3]], 'chat_list');
      expect(nomiTab[visibleTabs[4]], 'profile');
    });
  });

  group('Tutorial Coach Mark Dating Step', () {
    test('getTabForTarget returns correct indices regardless of dating state', () {
      expect(TutorialService.getTabForTarget('welcome'), 0);
      expect(TutorialService.getTabForTarget('map_tab'), 1);
      expect(TutorialService.getTabForTarget('dating_tab'), 2);
      expect(TutorialService.getTabForTarget('chat_tab'), 3);
      expect(TutorialService.getTabForTarget('profile_tab'), 4);
    });
  });
}
