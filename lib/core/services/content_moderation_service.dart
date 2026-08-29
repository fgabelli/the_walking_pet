/// Content moderation service for user-generated text.
/// Uses a multi-layered approach:
/// 1. Local profanity filter (instant, no API calls)
/// 2. Pattern detection (obfuscated words)
/// 3. Spam detection (repeated chars, all caps)
/// 4. User report system (community-driven moderation)
class ContentModerationService {
  
  // Italian profanity / vulgar words (comprehensive list)
  static final Set<String> _bannedWords = {
    // Vulgar/offensive Italian words
    'cazzo', 'minchia', 'coglione', 'coglioni', 'stronzo', 'stronza',
    'stronzi', 'stronze', 'merda', 'merde', 'vaffanculo', 'fanculo',
    'puttana', 'puttane', 'troia', 'troie', 'bastardo', 'bastarda',
    'bastardi', 'bastarde', 'fottiti', 'fottere', 'fottuto', 'fottuta',
    'cogliona', 'porco', 'porca', 'madonna', 'dio', 'cristo',
    'cazzi', 'cazzata', 'cazzate', 'minchione', 'minchioni',
    'culo', 'stocazzo', 'sticazzi', 'mignotta', 'mignotte',
    'pompino', 'pompini', 'scopare', 'scopata', 'scopate',
    'incazzato', 'incazzata', 'rompicoglioni', 'rompipalle',
    'cornuto', 'cornuta', 'cornuti',
    // Combined blasphemy patterns
    'porcodio', 'porcamadonna', 'diocane', 'dioporco', 'diobestia',
    'madonnatroia', 'cristodio', 'porcomadonna','porcatroia', 
    'porcaeva', 'madonnacane',
    // Racial / discriminatory slurs
    'negro', 'negra', 'negri', 'negre', 'terrone', 'terrona',
    'terroni', 'terrone', 'frocio', 'froci', 'frocia', 'finocchio',
    'ricchione', 'culattone', 'culattoni', 'lesbicona',
    // English profanity (international users)
    'fuck', 'fucking', 'shit', 'asshole', 'bitch', 'bastard',
    'dick', 'pussy', 'whore', 'slut', 'nigger', 'faggot',
    'damn', 'cunt', 'motherfucker', 'bullshit',
  };

  // Blasphemy combinations to detect (even with spaces)
  static final List<List<String>> _blasphemyCombinations = [
    ['porco', 'dio'],
    ['porca', 'madonna'],
    ['dio', 'cane'],
    ['dio', 'porco'],
    ['dio', 'bestia'],
    ['madonna', 'troia'],
    ['madonna', 'puttana'],
    ['cristo', 'dio'],
    ['porca', 'troia'],
    ['porca', 'eva'],
    ['madonna', 'cane'],
    ['dio', 'ladro'],
    ['dio', 'maiale'],
    ['porca', 'miseria'], // this one is borderline, keep for safety
  ];

  /// Result of content moderation check
  static ModerationResult moderateText(String text) {
    if (text.trim().isEmpty) {
      return ModerationResult(
        isClean: false,
        reason: 'Il commento non può essere vuoto.',
      );
    }

    // 1. Minimum length check
    if (text.trim().length < 3) {
      return ModerationResult(
        isClean: false,
        reason: 'Il commento è troppo corto.',
      );
    }

    // 2. Maximum length
    if (text.trim().length > 1000) {
      return ModerationResult(
        isClean: false,
        reason: 'Il commento è troppo lungo (max 1000 caratteri).',
      );
    }

    final normalized = _normalize(text);
    final words = normalized.split(RegExp(r'\s+'));

    // 3. Direct banned word check
    for (final word in words) {
      final cleaned = word.replaceAll(RegExp(r'[^a-zA-Zàèéìòù]'), '');
      if (cleaned.length >= 3 && _bannedWords.contains(cleaned)) {
        return ModerationResult(
          isClean: false,
          reason: 'Il commento contiene linguaggio inappropriato.',
          flaggedWord: cleaned,
        );
      }
    }

    // 4. Blasphemy combination check (words might be separated by spaces/punctuation)
    for (final combo in _blasphemyCombinations) {
      if (_containsCombination(normalized, combo)) {
        return ModerationResult(
          isClean: false,
          reason: 'Il commento contiene linguaggio inappropriato.',
        );
      }
    }

    // 5. Obfuscation detection (c4zz0, str0nz0, etc.)
    final deobfuscated = _deobfuscate(normalized);
    if (deobfuscated != normalized) {
      for (final word in deobfuscated.split(RegExp(r'\s+'))) {
        final cleaned = word.replaceAll(RegExp(r'[^a-zA-Zàèéìòù]'), '');
        if (cleaned.length >= 3 && _bannedWords.contains(cleaned)) {
          return ModerationResult(
            isClean: false,
            reason: 'Il commento contiene linguaggio mascherato inappropriato.',
            flaggedWord: cleaned,
          );
        }
      }
    }

    // 6. Spam detection
    if (_isSpam(text)) {
      return ModerationResult(
        isClean: false,
        reason: 'Il commento sembra spam. Scrivi una recensione utile.',
      );
    }

    // 7. All caps detection (shouting)
    final alphaOnly = text.replaceAll(RegExp(r'[^a-zA-Z]'), '');
    if (alphaOnly.length > 10 && alphaOnly == alphaOnly.toUpperCase()) {
      return ModerationResult(
        isClean: false,
        reason: 'Evita di scrivere tutto in maiuscolo.',
      );
    }

    // Passed all checks
    return ModerationResult(isClean: true);
  }

  /// Normalize text for comparison
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:\-_(){}\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Deobfuscate leet-speak style replacements
  static String _deobfuscate(String text) {
    return text
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('!', 'i');
  }

  /// Check if text contains a word combination (blasphemy patterns)
  static bool _containsCombination(String text, List<String> words) {
    if (words.length < 2) return false;
    
    // Check concatenated version  
    final concat = words.join('');
    if (text.contains(concat)) return true;
    
    // Check if words appear near each other (within 3 words distance)
    final textWords = text.split(RegExp(r'\s+'));
    for (var i = 0; i < textWords.length; i++) {
      final cleaned = textWords[i].replaceAll(RegExp(r'[^a-zA-Zàèéìòù]'), '');
      if (cleaned == words[0]) {
        // Look ahead for second word
        for (var j = i + 1; j < textWords.length && j <= i + 3; j++) {
          final cleaned2 = textWords[j].replaceAll(RegExp(r'[^a-zA-Zàèéìòù]'), '');
          if (cleaned2 == words[1]) return true;
        }
      }
    }
    
    return false;
  }

  /// Detect spam patterns
  static bool _isSpam(String text) {
    // Repeated characters (e.g., "aaaaaaa")
    if (RegExp(r'(.)\1{5,}').hasMatch(text)) return true;
    
    // Repeated words
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    if (words.length >= 3) {
      final uniqueWords = words.toSet();
      if (uniqueWords.length == 1 && words.length > 2) return true;
    }

    // Excessive special characters
    final specialCount = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').length;
    if (text.length > 5 && specialCount / text.length > 0.5) return true;

    // URL spam
    if (RegExp(r'https?://|www\.|\.com|\.it|\.net|\.org', caseSensitive: false).hasMatch(text)) {
      return true;
    }

    return false;
  }

  /// Censor a word (keep first and last letter)
  static String censor(String word) {
    if (word.length <= 2) return '*' * word.length;
    return '${word[0]}${'*' * (word.length - 2)}${word[word.length - 1]}';
  }
}

/// Result of a moderation check
class ModerationResult {
  final bool isClean;
  final String? reason;
  final String? flaggedWord;

  ModerationResult({
    required this.isClean,
    this.reason,
    this.flaggedWord,
  });
}
