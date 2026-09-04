import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Punto unico di invio degli eventi di prodotto a Firebase Analytics (GA4).
///
/// Regole tenute qui dentro, per non doverle ricordare nei punti di chiamata:
/// - i nomi degli eventi sono in snake_case e non superano i 40 caratteri;
/// - i parametri accettano solo String o num, mai oggetti o null;
/// - nessun dato personale (email, nome, telefono) finisce nei parametri;
/// - un errore di invio non deve mai far fallire l'operazione dell'utente,
///   quindi ogni chiamata e' racchiusa in un try/catch silenzioso.
///
/// Gli eventi vanno agganciati nei service, dove l'operazione riesce davvero,
/// e non nelle schermate: cosi' non partono se il salvataggio fallisce.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('[Analytics] invio fallito per "$name": $e');
    }
  }

  /// Schermata mostrata. Serve per le tab dentro l'IndexedStack di
  /// MainScreen, che non passano dal Navigator e quindi non verrebbero mai
  /// registrate dal FirebaseAnalyticsObserver montato in app.dart.
  static Future<void> schermataVista(String nome) async {
    try {
      await _analytics.logScreenView(screenName: nome);
    } catch (e) {
      debugPrint('[Analytics] screen_view fallito per "$nome": $e');
    }
  }

  /// Registrazione andata a buon fine. [metodo] vale 'email', 'google' o 'apple'.
  /// Da inviare solo per gli utenti nuovi, non a ogni accesso.
  static Future<void> registrazioneCompletata({required String metodo}) =>
      _log('registrazione_completata', {'metodo': metodo});

  /// Primo passo di attivazione vero: senza un pet l'app resta vuota.
  static Future<void> petProfiloCreato({
    required String taglia,
    required int eta,
    required String specie,
  }) =>
      _log('pet_profilo_creato', {
        'taglia': taglia,
        'eta': eta,
        'specie': specie,
      });

  static Future<void> passeggiataAvviata() => _log('passeggiata_avviata');

  /// Distinto dall'avvio: il rapporto fra i due dice se la registrazione GPS
  /// regge fino in fondo o si interrompe per strada.
  static Future<void> passeggiataCompletata({
    required int durataMin,
    required double distanzaKm,
    required int passi,
  }) =>
      _log('passeggiata_completata', {
        'durata_min': durataMin,
        'distanza_km': distanzaKm,
        'passi': passi,
      });

  /// [tipo] arriva da PostType: photo, story, walkCard, video.
  static Future<void> postPubblicato({required String tipo}) =>
      _log('post_pubblicato', {'tipo': tipo});

  /// Solo il match reciproco, non ogni swipe.
  static Future<void> matchOttenuto() => _log('match_ottenuto');

  /// Solo all'apertura di una nuova conversazione, non a ogni messaggio.
  static Future<void> chatAvviata() => _log('chat_avviata');

  static Future<void> annuncioPubblicato({required String categoria}) =>
      _log('annuncio_pubblicato', {'categoria': categoria});

  /// [origine] dice da dove si e' arrivati al paywall, per capire quale
  /// funzione spinge davvero verso l'abbonamento.
  static Future<void> paywallVisto({required String origine}) =>
      _log('paywall_visto', {'origine': origine});

  /// Usa l'evento standard `purchase` invece di un nome inventato: e' l'unico
  /// modo perche' GA4 calcoli il fatturato da solo, senza configurazione.
  static Future<void> abbonamentoAttivato({
    required String pacchetto,
    required double prezzo,
    required String valuta,
  }) async {
    try {
      await _analytics.logPurchase(
        currency: valuta,
        value: prezzo,
        parameters: {'pacchetto': pacchetto},
      );
    } catch (e) {
      debugPrint('[Analytics] invio fallito per "purchase": $e');
    }
  }
}
