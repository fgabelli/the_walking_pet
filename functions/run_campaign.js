/**
 * CLI Tool per l'esecuzione sicura e parametrizzata delle campagne push su The Walking Pet (DOGZN).
 *
 * Di DEFAULT è SEMPRE in modalità --dry-run (validazione simulata con APNs senza invio reale).
 * Per eseguire un invio reale è TASSATIVO specificare esplicitamente il flag --execute.
 *
 * Esempi di utilizzo:
 *
 * 1. Test su un singolo device interno:
 *    node run_campaign.js --test-token <FCM_TOKEN> \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "test_interno_01" \
 *      --execute
 *
 * 2. Dry run sul segmento completo utenti orfani iOS (validazione token senza invio):
 *    node run_campaign.js --segment orphaned_users_ios \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "recovery_orphans_ios_v1" \
 *      --dry-run
 *
 * 3. Invio effettivo finale sul segmento utenti orfani iOS:
 *    node run_campaign.js --segment orphaned_users_ios \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "recovery_orphans_ios_v1" \
 *      --execute
 */

const admin = require("firebase-admin");
const { executeCampaign } = require("./campaigns");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "thewalkingpet-a1578",
  });
}

function getArgValue(flag) {
  const index = process.argv.indexOf(flag);
  if (index !== -1 && process.argv[index + 1] && !process.argv[index + 1].startsWith("--")) {
    return process.argv[index + 1];
  }
  return null;
}

async function main() {
  const hasHelp = process.argv.includes("--help") || process.argv.includes("-h");
  if (hasHelp) {
    console.log(`
Uso: node run_campaign.js [opzioni]

Opzioni obbligatorie per l'invio:
  --title <testo>          Titolo della notifica push
  --body <testo>           Testo del messaggio push
  --campaign-id <id>       ID univoco della campagna (es. recovery_orphans_ios_v1)

Opzioni opzionali:
  --segment <nome>         Segmento target (default: 'orphaned_users_ios')
  --deep-link <link>       Deep link di atterraggio (default: '/resume-onboarding')
  --test-token <token>     Invia solo a questo specifico token di prova
  --dry-run                Simula l'invio e valida i token senza recapitare la notifica (PREDEFINITO)
  --execute                Esegue l'invio reale (richiede conferma esplicita)
    `);
    process.exit(0);
  }

  const title = getArgValue("--title");
  const body = getArgValue("--body");
  const campaignId = getArgValue("--campaign-id");
  const deepLink = getArgValue("--deep-link") || "/resume-onboarding";
  const testToken = getArgValue("--test-token");
  let segment = getArgValue("--segment") || "orphaned_users_ios";

  const isExecute = process.argv.includes("--execute");
  const isDryRun = !isExecute; // Se non c'è --execute, è sempre dry-run di sicurezza

  let customTokens = [];
  if (testToken) {
    segment = "internal_test";
    customTokens = [testToken];
  }

  if (!title || !body || !campaignId) {
    console.error("❌ Parametri mancanti obbligatori: --title, --body e --campaign-id sono richiesti.");
    console.log("Esegui 'node run_campaign.js --help' per la guida completa.");
    process.exit(1);
  }

  if (!isExecute) {
    console.log("\n⚠️ ATTENZIONE: Esecuzione in modalità DRY-RUN (simulazione). Nessuna push verrà inviata.");
    console.log("Per effettuare l'invio reale, aggiungi il flag '--execute'.\n");
  } else {
    console.log("\n🔴 ATTENZIONE: ESECUZIONE REALE CONSEGNA NOTIFICHE IN CORSO...\n");
  }

  try {
    const report = await executeCampaign({
      title,
      body,
      deepLink,
      campaignId,
      segment,
      customTokens,
      dryRun: isDryRun,
    });

    console.log("\n==========================================");
    console.log("📋 REPORT FINALE ESECUZIONE CAMPAGNA");
    console.log("==========================================");
    console.log(`- Campagna ID: ${report.campaignId}`);
    console.log(`- Segmento: ${report.segment}`);
    console.log(`- Modalità: ${report.dryRun ? "DRY-RUN (Simulazione)" : "REALE (Inviato)"}`);
    console.log(`- Token destinatari totali: ${report.totalTokensTarget}`);
    console.log(`- Token univoci (device distinti): ${report.uniqueTokensTarget}`);
    console.log(`- Notifiche consegnate ad APNs: ${report.deliveredCount}`);
    console.log(`- Token UNREGISTERED (app disinstallata): ${report.unregisteredCount}`);
    console.log(`- Errori non gestiti: ${report.failedCount - report.unregisteredCount}`);
    if (report.reportId) {
      console.log(`- Report salvato su Firestore: campaign_reports/${report.reportId}`);
    }
    console.log("==========================================\n");

    if (report.unregisteredCount > 0) {
      console.log(`ℹ️ I ${report.unregisteredCount} token disinstallati sono stati censiti.`);
      if (!report.dryRun) {
        console.log("   I profili corrispondenti in Firestore sono stati contrassegnati e ripuliti dai token obsoleti.");
      }
    }

  } catch (error) {
    console.error("\n❌ Errore durante l'esecuzione della campagna:", error.message);
    process.exit(1);
  }
}

main();
