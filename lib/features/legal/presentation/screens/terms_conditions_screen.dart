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
              'Ultimo aggiornamento: 8 Dicembre 2025',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Benvenuto su The Walking Pet. Utilizzando la nostra app, accetti di essere vincolato dai seguenti termini e condizioni.\n\n'
              '1. Accettazione dei Termini\n'
              'Accedendo o utilizzando l\'applicazione, accetti di rispettare questi Termini. Se non sei d\'accordo con una qualsiasi parte dei termini, non potrai accedere al servizio.\n\n'
              '2. Account Utente\n'
              'Quando crei un account con noi, devi fornirci informazioni accurate, complete e aggiornate. Il mancato rispetto di ciò costituisce una violazione dei Termini.\n\n'
              '3. Comportamento dell\'Utente\n'
              'Sei responsabile per tutte le attività che avvengono sotto il tuo account. Accetti di non utilizzare il servizio per scopi illegali o non autorizzati.\n\n'
              '4. Proprietà Intellettuale\n'
              'Il servizio e il suo contenuto originale, le caratteristiche e le funzionalità sono e rimarranno di proprietà esclusiva di The Walking Pet e dei suoi licenziatari.\n\n'
              '5. Limitazione di Responsabilità\n'
              'In nessun caso The Walking Pet sarà responsabile per danni indiretti, incidentali, speciali, consequenziali o punitivi derivanti dal tuo utilizzo del servizio.\n\n'
              '6. Modifiche ai Termini\n'
              'Ci riserviamo il diritto di modificare o sostituire questi Termini in qualsiasi momento. Continuando ad accedere o utilizzare il nostro servizio dopo che tali revisioni diventano effettive, accetti di essere vincolato dai termini modificati.\n\n'
              'Contattaci\n'
              'Se hai domande su questi Termini, contattaci all\'indirizzo support@thewalkingpet.com.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
