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
              'Ultimo aggiornamento: 8 Dicembre 2025',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Benvenuto su The Walking Pet. La tua privacy è importante per noi. '
              'Questa Informativa sulla Privacy spiega come raccogliamo, utilizziamo, divulghiamo e proteggiamo le tue informazioni quando utilizzi la nostra applicazione mobile.\n\n'
              '1. Raccolta delle Informazioni\n'
              'Raccogliamo le informazioni che ci fornisci direttamente, come quando crei un account, aggiorni il tuo profilo o comunichi con noi. '
              'Queste informazioni possono includere il tuo nome, indirizzo email, data di nascita, genere e informazioni sul tuo animale domestico.\n\n'
              '2. Utilizzo delle Informazioni\n'
              'Utilizziamo le informazioni raccolte per fornire, mantenere e migliorare i nostri servizi, per comunicare con te e per personalizzare la tua esperienza.\n\n'
              '3. Condivisione delle Informazioni\n'
              'Non condividiamo le tue informazioni personali con terze parti, eccetto nei casi descritti in questa informativa o con il tuo consenso.\n\n'
              '4. Sicurezza dei Dati\n'
              'Adottiamo misure ragionevoli per proteggere le tue informazioni da perdita, furto, uso improprio e accesso non autorizzato.\n\n'
              '5. I Tuoi Diritti\n'
              'Hai il diritto di accedere, correggere o cancellare le tue informazioni personali in qualsiasi momento attraverso le impostazioni dell\'app.\n\n'
              'Contattaci\n'
              'Se hai domande su questa Informativa sulla Privacy, contattaci all\'indirizzo support@thewalkingpet.it.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
