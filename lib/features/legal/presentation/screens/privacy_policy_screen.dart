import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informativa sulla Privacy',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Ultimo aggiornamento: 19 Maggio 2026 — Versione 1.3',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Benvenuto su DOGZN. La tua privacy è importante per noi. '
              'Questa Informativa spiega come raccogliamo, utilizziamo e proteggiamo i tuoi dati personali.\n\n'

              'Titolare del Trattamento: DOGZN — Vega Lab SRL\n'
              'Email Privacy: privacy@thewalkingpet.it\n\n'

              '1. Dati Raccolti\n\n'

              '1.1 Dati di Registrazione\n'
              'Nome, cognome, email, foto profilo, user ID, tipo di account (Personale/Business). '
              'Autenticazione tramite Google Sign-In, Apple Sign-In o email/password.\n\n'

              '1.2 Dati dell\'Animale Domestico\n'
              'Nome, razza, sesso, età, peso, foto, informazioni mediche (facoltativo).\n\n'

              '1.3 Dati di Geolocalizzazione\n'
              '• In primo piano: posizione sulla mappa durante l\'uso attivo\n'
              '• In background: tracciamento passeggiate tramite SDK nativo '
              'Transistor Software (flutter_background_geolocation). Il tracking in background '
              'richiede il permesso "Sempre" ed è attivo esclusivamente durante le sessioni di passeggiata.\n'
              '• Radar/SOS: condivisione posizione per emergenze e scoperta utenti\n'
              '• Condivisione: Radar Mode (posizione approssimativa), SOS (posizione esatta a 5km), Passeggiate (percorso GPS)\n'
              'Puoi disattivare la geolocalizzazione dalle impostazioni del dispositivo.\n\n'

              '1.4 Contenuti Generati dall\'Utente\n'
              'Post, commenti, foto, video, messaggi chat, annunci bacheca, like e interazioni.\n'
              'Tutti i contenuti vengono processati automaticamente da sistemi di intelligenza artificiale per la moderazione.\n\n'

              '1.5 Dati Business Claim\n'
              'Se richiedi il riscatto di un esercizio commerciale: nome, cognome, ruolo, telefono, '
              'email aziendale, P.IVA, foto di verifica. Revisionati manualmente dal team DOGZN.\n\n'

              '1.6 Dati Salute (Health Connect / Apple Health)\n'
              'Con consenso esplicito: passi, calorie, distanza, sessioni di allenamento. '
              'Non condivisi con terze parti, non usati per pubblicità.\n\n'

              '1.7 Dati Tecnici\n'
              'IDFA/AAID, modello dispositivo, versione OS, IP, crash reports (Firebase Crashlytics).\n\n'

              '1.8 Dati di Pagamento\n'
              'Gestiti da Apple/Google tramite RevenueCat. Non memorizziamo dati carta di credito.\n\n'

              '2. Finalità del Trattamento\n\n'

              '2.1 Fornitura del Servizio\n'
              'Account, funzionalità app, tracciamento passeggiate, notifiche push, abbonamenti.\n\n'

              '2.2 Moderazione Automatica con AI\n'
              '• Google Cloud Vision (SafeSearch): analisi immagini per contenuti inappropriati\n'
              '• Google Gemini (Vertex AI): analisi testi per hate speech, spam, profanità\n'
              'I risultati vengono archiviati nella collection moderation_log. '
              'Per chat bloccate, il testo originale viene conservato per revisione.\n\n'
              'Decisioni automatizzate (Art. 22 GDPR): sospensione automatica dopo 5 violazioni. '
              'Hai diritto a contestare contattando support@thewalkingpet.it.\n\n'

              '2.3 Notifiche di Prossimità\n'
              'La posizione viene usata esclusivamente lato server per inviare notifiche push: '
              'annunci bacheca (10 km), offerte business (10 km), SOS (5 km), pericoli (2 km). '
              'Non viene condivisa con altri utenti.\n\n'

              '2.4 Pubblicità\n'
              'Annunci personalizzati tramite Google AdMob con identificatori pubblicitari.\n\n'

              '3. Condivisione dei Dati\n\n'

              'NON vendiamo mai i tuoi dati. Condividiamo con:\n'
              '• Google Firebase: hosting, database, autenticazione, storage\n'
              '• Google Maps: mappe e geocoding\n'
              '• Transistor Software: tracciamento GPS in background (dati processati localmente sul dispositivo, '
              'nessun dato inviato a server Transistor)\n'
              '• RevenueCat: gestione abbonamenti\n'
              '• Google AdMob: pubblicità\n'
              '• Google Cloud Vision API: moderazione immagini\n'
              '• Google Gemini (Vertex AI): moderazione testi\n'
              '• Firebase Crashlytics: monitoraggio errori\n\n'

              'Dati condivisi con altri utenti:\n'
              '• Contenuti nella Community (pubblici)\n'
              '• Annunci Bacheca (visibili nella zona)\n'
              '• Radar Mode (posizione approssimativa)\n'
              '• Chat privata (solo destinatario)\n'
              '• SOS: telefono e posizione condivisi pubblicamente nell\'annuncio automatico\n\n'

              '4. Conservazione dei Dati\n'
              '• Account e pet: durata dell\'account\n'
              '• Chat: 2 anni\n'
              '• Post e annunci: fino a cancellazione\n'
              '• Geolocalizzazione: 30 giorni\n'
              '• Log moderazione AI: 12 mesi\n'
              '• Business Claims: durata dell\'account\n'
              '• Dati pagamento: 7 anni\n'
              'Dopo eliminazione account: cancellazione entro 30 giorni.\n\n'

              '5. I Tuoi Diritti GDPR\n'
              '• Accesso ai tuoi dati\n'
              '• Rettifica di dati inesatti\n'
              '• Cancellazione (dalle Impostazioni dell\'app)\n'
              '• Limitazione del trattamento\n'
              '• Portabilità dei dati\n'
              '• Opposizione al trattamento\n'
              'Per esercitare i tuoi diritti: privacy@thewalkingpet.it\n\n'

              '6. Sicurezza\n'
              'Crittografia SSL/TLS, autenticazione sicura, accesso limitato, backup automatici.\n\n'

              '7. Minori\n'
              'DOGZN non è indirizzata a minori di 13 anni.\n\n'

              '8. Trasferimenti Internazionali\n'
              'I dati vengono trasferiti negli USA (Google, RevenueCat) con Clausole Contrattuali Standard.\n\n'

              'Contattaci\n'
              'Privacy: privacy@thewalkingpet.it\n'
              'Supporto: support@thewalkingpet.it\n\n'
              '© 2026 Vega Lab SRL. Tutti i diritti riservati.\n'
              'DOGZN® è un marchio di Vega Lab SRL (registrazione in corso).',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
