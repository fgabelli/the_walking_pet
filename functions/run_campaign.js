/**
 * CLI Tool per l'esecuzione sicura e parametrizzata delle campagne push su The Walking Pet (DOGZN).
 *
 * Funziona nativamente da terminale Mac usando il token gcloud autenticato,
 * interfacciandosi direttamente con le API REST di Firestore e FCM v1.
 *
 * Di DEFAULT è SEMPRE in modalità --dry-run (validazione simulata con APNs senza invio reale).
 * Per eseguire un invio reale è TASSATIVO specificare esplicitamente il flag --execute.
 *
 * Esempi di utilizzo:
 *
 * 1. Test su un singolo device interno:
 *    node functions/run_campaign.js --test-token <FCM_TOKEN> \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "test_interno_01" \
 *      --execute
 *
 * 2. Dry run sul segmento completo utenti orfani iOS (validazione token senza invio):
 *    node functions/run_campaign.js --segment orphaned_users_ios \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "recovery_orphans_ios_v1" \
 *      --dry-run
 *
 * 3. Invio effettivo finale sul segmento utenti orfani iOS:
 *    node functions/run_campaign.js --segment orphaned_users_ios \
 *      --title "Bentornato su DOGZN!" \
 *      --body "Completa il tuo profilo per trovare nuovi compagni di passeggiata" \
 *      --campaign-id "recovery_orphans_ios_v1" \
 *      --execute
 */

const { execSync } = require("child_process");

const PROJECT_ID = "thewalkingpet-a1578";

function getAccessToken() {
  try {
    return execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
  } catch (e) {
    throw new Error("Impossibile ottenere il token da gcloud. Assicurati che gcloud sia configurato.");
  }
}

async function fetchWithAuth(url, options = {}) {
  const token = getAccessToken();
  const headers = {
    Authorization: `Bearer ${token}`,
    "x-goog-user-project": PROJECT_ID,
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };

  const res = await fetch(url, { ...options, headers });
  return res;
}

function getArgValue(flag) {
  const index = process.argv.indexOf(flag);
  if (index !== -1 && process.argv[index + 1] && !process.argv[index + 1].startsWith("--")) {
    return process.argv[index + 1];
  }
  return null;
}

async function getOrphanedRecipients() {
  let documents = [];
  let nextPageToken = null;

  do {
    let url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?pageSize=300`;
    if (nextPageToken) {
      url += `&pageToken=${encodeURIComponent(nextPageToken)}`;
    }

    const res = await fetchWithAuth(url);
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Errore caricamento Firestore (${res.status}): ${errText}`);
    }

    const data = await res.json();
    if (data.documents) {
      documents = documents.concat(data.documents);
    }
    nextPageToken = data.nextPageToken || null;
  } while (nextPageToken);

  const recipients = [];
  for (const doc of documents) {
    const fields = doc.fields || {};
    const uid = doc.name.split("/").pop();

    const firstNameVal = fields.firstName ? fields.firstName.stringValue : null;
    const isFirstNameMissing = firstNameVal == null || firstNameVal.trim().length === 0;

    const tokensVal = fields.fcmTokens && fields.fcmTokens.arrayValue ? fields.fcmTokens.arrayValue.values || [] : [];
    const tokens = tokensVal.map(v => v.stringValue).filter(Boolean);
    const platform = fields.tokenPlatform ? fields.tokenPlatform.stringValue : "";

    if (isFirstNameMissing && tokens.length > 0 && platform !== "android") {
      for (const t of tokens) {
        recipients.push({ uid, token: t.trim() });
      }
    }
  }

  return recipients;
}

async function sendFcmV1Message(token, { title, body, deepLink, campaignId, isDryRun }) {
  const url = `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`;
  
  const payload = {
    validate_only: isDryRun,
    message: {
      token: token,
      notification: {
        title: title.trim(),
        body: body.trim(),
      },
      data: {
        type: "resume_onboarding",
        deepLink: deepLink.trim(),
        campaignId: campaignId.trim(),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    },
  };

  const res = await fetchWithAuth(url, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  if (res.ok) {
    return { success: true };
  } else {
    const errText = await res.text();
    let errCode = "UNKNOWN";
    try {
      const errJson = JSON.parse(errText);
      const details = errJson.error?.details || [];
      for (const det of details) {
        if (det.errorCode) errCode = det.errorCode;
      }
      if (errCode === "UNKNOWN" && res.status === 404) errCode = "UNREGISTERED";
    } catch (_) {}

    return {
      success: false,
      status: res.status,
      code: errCode,
      raw: errText,
    };
  }
}

async function main() {
  const hasHelp = process.argv.includes("--help") || process.argv.includes("-h");
  if (hasHelp) {
    console.log(`
Uso: node functions/run_campaign.js [opzioni]

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

  if (!title || !body || !campaignId) {
    console.error("❌ Parametri mancanti obbligatori: --title, --body e --campaign-id sono richiesti.");
    console.log("Esegui 'node functions/run_campaign.js --help' per la guida completa.");
    process.exit(1);
  }

  console.log(`\n========================================`);
  console.log(`🚀 AVVIO CAMPAGNA PUSH: ${campaignId}`);
  console.log(`Modalità: ${isDryRun ? "🛡️ DRY-RUN (Nessuna notifica inviata)" : "🔴 INVIO EFFETTIVO"}`);
  console.log(`Segmento: ${testToken ? "internal_test" : segment}`);
  console.log(`Deep Link: ${deepLink}`);
  console.log(`========================================\n`);

  let recipients = [];
  if (testToken) {
    recipients = [{ uid: "test_device", token: testToken.trim() }];
  } else {
    console.log("🔍 Estrazione destinatari da Firestore...");
    recipients = await getOrphanedRecipients();
  }

  // Deduplica token: mappa token -> lista uid
  const tokenToUids = new Map();
  for (const { uid, token } of recipients) {
    if (!tokenToUids.has(token)) {
      tokenToUids.set(token, []);
    }
    tokenToUids.get(token).push(uid);
  }

  const uniqueTokens = Array.from(tokenToUids.keys());
  console.log(`Destinatari: ${recipients.length} profili target, ${uniqueTokens.length} token UNICI da contattare.`);

  let deliveredCount = 0;
  let unregisteredCount = 0;
  let otherErrorsCount = 0;
  const unregisteredTokens = [];

  console.log(`\nElaborazione ${uniqueTokens.length} token in corso...`);
  for (let i = 0; i < uniqueTokens.length; i++) {
    const tok = uniqueTokens[i];
    const res = await sendFcmV1Message(tok, {
      title,
      body,
      deepLink,
      campaignId,
      isDryRun,
    });

    if (res.success) {
      deliveredCount++;
    } else {
      if (res.code === "UNREGISTERED" || res.status === 404 || res.code === "INVALID_ARGUMENT") {
        unregisteredCount++;
        unregisteredTokens.push({
          token: tok,
          uids: tokenToUids.get(tok) || [],
          code: res.code,
        });
      } else {
        otherErrorsCount++;
      }
    }
  }

  console.log("\n==========================================");
  console.log("📋 REPORT FINALE ESECUZIONE CAMPAGNA");
  console.log("==========================================");
  console.log(`- Campagna ID: ${campaignId}`);
  console.log(`- Modalità: ${isDryRun ? "DRY-RUN (Simulazione APNs)" : "REALE (Consegnato ad APNs)"}`);
  console.log(`- Profili target orfani: ${recipients.length}`);
  console.log(`- Token UNICI (device distinti): ${uniqueTokens.length}`);
  console.log(`- Consegnati / Validi: ${deliveredCount}`);
  console.log(`- Token UNREGISTERED (disinstallati): ${unregisteredCount}`);
  console.log(`- Altri errori: ${otherErrorsCount}`);
  console.log("==========================================\n");

  if (unregisteredCount > 0) {
    console.log(`ℹ️ I ${unregisteredCount} token disinstallati sono stati identificati.`);
  }

  if (isDryRun) {
    console.log("🛡️ Dry-run completato. Nessuna notifica reale inviata.");
  }
}

main().catch((err) => {
  console.error("Errore durante l'esecuzione:", err);
  process.exit(1);
});
