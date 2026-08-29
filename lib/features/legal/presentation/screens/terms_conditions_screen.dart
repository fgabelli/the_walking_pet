import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termini e Condizioni'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Termini e Condizioni di Utilizzo',
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
              'Benvenuto su DOGZN. Questi Termini e Condizioni costituiscono un accordo vincolante tra te '
              '("Utente") e Vega Lab SRL ("DOGZN", "noi" o "nostro").\n\n'

              '1. Accettazione dei Termini\n'
              'Accedendo e utilizzando la Piattaforma, inclusa l\'applicazione mobile, accetti di essere vincolato da questi '
              'Termini. Se non accetti tutti i Termini, non puoi utilizzare l\'app.\n\n'

              '2. Account Utente\n'
              'Puoi creare un account tramite Google Sign-In, Apple Sign-In o email/password. '
              'Sei responsabile della riservatezza della tua password e di tutte le attività che avvengono sotto il tuo account. '
              'Tipi di account disponibili: Personale e Business.\n\n'

              '3. Contenuto dell\'Utente\n'
              'Mantieni la piena proprietà di tutto il Contenuto che carichi. Concedi a DOGZN una licenza mondiale, non esclusiva, '
              'royalty-free per archiviare, visualizzare e distribuire il tuo Contenuto. '
              'Sei responsabile del Contenuto che carichi e garantisci che non violi diritti di terzi.\n\n'

              '4. Moderazione Automatica del Contenuto (AI)\n'
              'DOGZN utilizza sistemi automatizzati di intelligenza artificiale per moderare i contenuti:\n'
              '• Google Cloud Vision (SafeSearch): analisi automatica delle immagini\n'
              '• Google Gemini (Vertex AI): analisi testuale per hate speech, spam, profanità\n'
              'Contenuti soggetti a moderazione: post, commenti, annunci, messaggi chat, profilo utente.\n'
              'Azioni: approvato, segnalato (revisione manuale), bloccato (rimosso + notifica).\n'
              'Sistema sanzionatorio: avviso a 3 violazioni, sospensione automatica a 5 violazioni '
              '(decisione automatizzata ai sensi dell\'Art. 22 GDPR — puoi contestarla a support@thewalkingpet.it).\n\n'

              '5. Funzionalità Specifiche\n\n'

              '5.1 Radar Mode\n'
              'Mostra la tua posizione approssimativa ad altri utenti. Puoi disattivarlo in qualsiasi momento.\n\n'

              '5.2 SOS Network\n'
              'Se il tuo animale si perde, puoi attivare un allarme SOS. La tua posizione viene inviata a utenti nel raggio di 5km. '
              'Un annuncio automatico viene creato sulla Bacheca Locale con nome del pet, numero di telefono e posizione approssimativa. '
              'Il numero di telefono e la posizione vengono condivisi pubblicamente.\n\n'

              '5.3 Passeggiate (Walks)\n'
              'Tracciamento GPS del percorso tramite SDK professionale Transistor Software, '
              'integrazione con Apple Health (solo iOS), Walk Card condivisibile. '
              'Il tracciamento in background richiede il permesso "Sempre" per la posizione '
              'ed è attivo solo durante le sessioni di passeggiata.\n\n'

              '5.4 Notifiche di Prossimità\n'
              'DOGZN invia notifiche push basate sulla posizione: annunci bacheca (10 km), offerte business (10 km), '
              'SOS (5 km), segnalazioni pericolo (2 km). La posizione è usata solo lato server.\n\n'

              '5.5 Riscatto Esercizi Commerciali (Business Claim)\n'
              'Puoi richiedere il riscatto di un esercizio commerciale fornendo: nome, ruolo, telefono, email, P.IVA e foto di verifica. '
              'Richiede abbonamento Business Pro. La richiesta viene revisionata manualmente dal team DOGZN.\n\n'

              '5.6 Offerte e Promozioni\n'
              'Offerte da partner commerciali con notifiche push nel raggio di 10 km. '
              'DOGZN non è responsabile per prodotti o servizi acquistati.\n\n'

              '6. Abbonamenti e Pagamenti\n'
              '• Premium: zero pubblicità, badge Premium, cronologia illimitata\n'
              '• Business: profilo in evidenza, promozioni localizzate\n'
              '• Business Pro: tutte le funzionalità Business + riscatto attività\n'
              'Pagamenti gestiti da Apple/Google tramite RevenueCat. Rinnovo automatico.\n\n'

              '7. Limitazione di Responsabilità\n'
              'L\'APP È FORNITA "COSÌ COM\'È". DOGZN non è responsabile per danni indiretti, '
              'perdita di profitti, lesioni o smarrimento dell\'animale. '
              'La responsabilità massima non supera l\'importo pagato negli ultimi 12 mesi o €100.\n\n'

              '8. Modifiche ai Termini\n'
              'Ci riserviamo il diritto di modificare questi Termini. Le modifiche saranno comunicate via email o notifica in-app.\n\n'

              '9. Legge Applicabile\n'
              'Questi Termini sono regolati dalle leggi dell\'Italia.\n\n'

              'Contattaci\n'
              'Per domande: legal@thewalkingpet.it\n'
              'Per supporto: support@thewalkingpet.it\n\n'
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
