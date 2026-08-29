import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/dog_model.dart';

/// Generates and shares a "Figurina DOGZN" — a fun collectible-style pet trading card.
/// Uses a full-screen route (NOT a Dialog) so that Share.shareXFiles can present
class PetTradingCardShare {
  static void showAndShare(BuildContext context, DogModel dog) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PetTradingCard(dog: dog),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  Fun Data Generator — all client-side, zero AI
// ══════════════════════════════════════════════════

class _PetCardData {
  /// Generates a stable "card number" from pet ID
  static String cardNumber(DogModel dog) {
    final hash = dog.id.hashCode.abs() % 9999;
    return '#${hash.toString().padLeft(4, '0')}';
  }

  /// "Tipo" (element) based on energy + size
  static ({String label, String emoji, Color color}) creatureType(DogModel dog) {
    final energy = dog.energyLevel;
    final size = dog.size;

    if (energy >= 4 && size == DogSize.small) return (label: 'FULMINE', emoji: '⚡', color: Colors.amber);
    if (energy >= 4 && size == DogSize.giant) return (label: 'VULCANO', emoji: '🌋', color: Colors.deepOrange);
    if (energy >= 4) return (label: 'FUOCO', emoji: '🔥', color: Colors.orange);
    if (energy <= 2 && size == DogSize.giant) return (label: 'MONTAGNA', emoji: '🏔️', color: Colors.blueGrey);
    if (energy <= 2) return (label: 'DIVANO', emoji: '🛋️', color: Colors.purple);
    if (size == DogSize.small) return (label: 'BISCOTTO', emoji: '🍪', color: Colors.brown);
    if (size == DogSize.large || size == DogSize.giant) return (label: 'GIARDINO', emoji: '🌿', color: Colors.green);
    return (label: 'FANGO', emoji: '💧', color: Colors.blue);
  }

  /// Epic title from traits
  static String epicTitle(DogModel dog) {
    final traits = dog.character.map((t) => t.toLowerCase()).toList();
    final energy = dog.energyLevel;
    final isCat = dog.species == PetSpecies.cat;

    // Combo-based titles (check combos first)
    if (_has(traits, ['protettivo', 'coraggioso']) || _has(traits, ['guardiano'])) {
      return isCat ? 'Il Guardiano Silenzioso' : 'Il Guardiano del Divano';
    }
    if (_has(traits, ['socievole', 'energico']) || _has(traits, ['vivace', 'amichevole'])) {
      return isCat ? 'L\'Uragano di Fusa' : 'L\'Uragano delle Coccole';
    }
    if (_has(traits, ['coccolone', 'pigro']) || _has(traits, ['dolce']) && energy <= 2) {
      return isCat ? 'Maestro del Termosifone' : 'Maestro del Pisolino';
    }
    if (_has(traits, ['curioso', 'avventuroso']) || _has(traits, ['esploratore'])) {
      return isCat ? 'L\'Esploratore di Scatole' : 'L\'Esploratore di Pozzanghere';
    }
    if (_has(traits, ['giocherellone'])) {
      return isCat ? 'Il Distruttore di Tende' : 'Il Distruttore di Calzini';
    }
    if (_has(traits, ['affettuoso']) || _has(traits, ['coccolone'])) {
      return isCat ? 'Il Re delle Fusa' : 'Il Re delle Coccole';
    }
    if (energy >= 4) {
      return isCat ? 'Pila Atomica Felina' : 'Pila Atomica a 4 Zampe';
    }
    if (energy <= 2) {
      return isCat ? 'Professionista del Riposo' : 'Campione Olimpico di Nanna';
    }

    // Fallback by size
    switch (dog.size) {
      case DogSize.giant: return isCat ? 'La Tigre del Salotto' : 'Il Colosso Gentile';
      case DogSize.large: return isCat ? 'Il Felino Regale' : 'L\'Atleta Peloso';
      case DogSize.small: return isCat ? 'La Piccola Peste' : 'Tascabile ma Letale';
      case DogSize.medium: return isCat ? 'Il Gatto Misterioso' : 'Il Simpaticone';
    }
  }

  /// Funny superpowers based on traits
  static List<({String label, int value})> funnyStats(DogModel dog) {
    final traits = dog.character.map((t) => t.toLowerCase()).toList();
    final energy = dog.energyLevel;
    final isCat = dog.species == PetSpecies.cat;

    return [
      (
        label: isCat ? '😼 Sguardo di Superiorità' : '🥺 Sguardo da Biscotto',
        value: _has(traits, ['dolce', 'affettuoso', 'coccolone']) ? 9 : (energy <= 2 ? 8 : 5),
      ),
      (
        label: isCat ? '🧶 Distruzione Gomitoli' : '🧦 Distruzione Calzini',
        value: _has(traits, ['giocherellone', 'vivace', 'energico']) ? 8 : (energy >= 4 ? 7 : 3),
      ),
      (
        label: '🛁 Resistenza al Bagno',
        value: isCat ? 1 : (_has(traits, ['avventuroso']) ? 6 : 3),
      ),
      (
        label: isCat ? '📦 Entrare nelle Scatole' : '🍕 Elemosinare Cibo',
        value: isCat ? 10 : (energy >= 3 ? 9 : 7),
      ),
    ];
  }

  /// Famous quote from the pet
  static String famousQuote(DogModel dog) {
    final traits = dog.character.map((t) => t.toLowerCase()).toList();
    final energy = dog.energyLevel;
    final isCat = dog.species == PetSpecies.cat;

    if (isCat) {
      if (_has(traits, ['pigro', 'coccolone'])) return '"Ti concedo il privilegio di accarezzarmi."';
      if (_has(traits, ['curioso', 'avventuroso'])) return '"Ho esplorato il piano di sopra. È mio."';
      if (_has(traits, ['giocherellone'])) return '"Quel vaso era brutto, ti ho fatto un favore."';
      if (energy >= 4) return '"Sono le 4 di notte. È ora di correre."';
      if (energy <= 2) return '"Non mi muovo. Per niente. Mai."';
      return '"Questo divano è mio. Anche quello."';
    }

    if (_has(traits, ['socievole', 'amichevole'])) return '"PERSONA! PERSONA NUOVA! CIAO! CIAO! CIAO!"';
    if (_has(traits, ['protettivo', 'coraggioso'])) return '"Ho abbaiato al postino. Di niente."';
    if (_has(traits, ['coccolone', 'affettuoso'])) return '"Se non mi dai il biscotto, ti fisso finché non cedi."';
    if (_has(traits, ['giocherellone'])) return '"Ho trovato un calzino. Oggi è il giorno più bello."';
    if (_has(traits, ['curioso', 'avventuroso'])) return '"Quella pozzanghera non si esplora da sola."';
    if (energy >= 4) return '"PASSEGGIATA? HAI DETTO PASSEGGIATA?!"';
    if (energy <= 2) return '"Dammi 5 minuti. Anzi 5 ore."';

    switch (dog.size) {
      case DogSize.giant: return '"Sono un cane da grembo. Il grembo è piccolo, il problema è tuo."';
      case DogSize.small: return '"Sono piccolo ma il mio ego no."';
      default: return '"La vita è bella. Soprattutto con i biscotti."';
    }
  }

  static bool _has(List<String> traits, List<String> keywords) {
    return keywords.any((k) => traits.any((t) => t.contains(k)));
  }
}

// ══════════════════════════════════════════════════
//  The Trading Card Widget
// ══════════════════════════════════════════════════

class _PetTradingCard extends StatelessWidget {
  final DogModel dog;

  const _PetTradingCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    final emoji = dog.species == PetSpecies.cat ? '🐱' : '🐶';
    final type = _PetCardData.creatureType(dog);
    final funStats = _PetCardData.funnyStats(dog);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header badge ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.accent.withValues(alpha: 0.8), AppColors.primary.withValues(alpha: 0.8)],
                ),
              ),
              child: Row(
                children: [
                  const Text('FIGURINA', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2)),
                  const SizedBox(width: 6),
                  Text(
                    _PetCardData.cardNumber(dog),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('DOGZN $emoji', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ],
              ),
            ),

            // ── Pet photo ──
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey.shade800,
                image: dog.photoUrl != null
                    ? DecorationImage(image: NetworkImage(dog.photoUrl!), fit: BoxFit.cover)
                    : null,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
              ),
              child: dog.photoUrl == null
                  ? Center(child: Icon(Icons.pets, size: 64, color: Colors.white.withValues(alpha: 0.3)))
                  : null,
            ),

            // ── Name + Type badge + Rarity ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dog.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dog.breed,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Rarity
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade600]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRarityLabel(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: type.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: type.color.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${type.emoji} ${type.label}',
                          style: TextStyle(color: type.color, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Epic Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [type.color.withValues(alpha: 0.12), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🏅 ${_PetCardData.epicTitle(dog)}',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
                ),
              ),
            ),

            // ── Funny Stats ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                children: funStats.map((stat) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: _FunStatBar(label: stat.label, value: stat.value),
                )).toList(),
              ),
            ),

            // ── Famous Quote ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  _PetCardData.famousQuote(dog),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  Text(
                    '${dog.age} anni • ${dog.gender.displayName} • ${dog.size.displayName}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 10),
                  ),
                  const Spacer(),
                  Text(
                    'dogzn.com',
                    style: TextStyle(color: AppColors.accent.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _sizeToValue() {
    switch (dog.size) {
      case DogSize.small: return 1;
      case DogSize.medium: return 2;
      case DogSize.large: return 4;
      case DogSize.giant: return 5;
    }
  }

  int _socialScore() {
    final socialTraits = ['socievole', 'amichevole', 'affettuoso', 'giocherellone', 'dolce', 'coccolone'];
    int score = 2;
    for (final trait in dog.character) {
      if (socialTraits.any((s) => trait.toLowerCase().contains(s))) score++;
    }
    return score.clamp(1, 5);
  }

  int _adventureScore() {
    final adventureTraits = ['avventuroso', 'attivo', 'energico', 'curioso', 'esploratore', 'vivace'];
    int score = dog.energyLevel > 3 ? 3 : 2;
    for (final trait in dog.character) {
      if (adventureTraits.any((s) => trait.toLowerCase().contains(s))) score++;
    }
    return score.clamp(1, 5);
  }

  String _getRarityLabel() {
    final total = dog.energyLevel + _sizeToValue() + _socialScore() + _adventureScore();
    if (total >= 17) return '⭐ LEGGENDARIO';
    if (total >= 14) return '💎 EPICO';
    if (total >= 10) return '✨ RARO';
    return '🌟 COMUNE';
  }
}

/// Fun stat bar with emoji-filled progress
class _FunStatBar extends StatelessWidget {
  final String label;
  final int value; // 1-10

  const _FunStatBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(1, 10);
    final barColor = clamped >= 8
        ? Colors.amber
        : clamped >= 5
            ? Colors.cyan
            : Colors.redAccent;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 4,
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped / 10,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [barColor.withValues(alpha: 0.6), barColor]),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 28,
          child: Text(
            '$clamped/10',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
