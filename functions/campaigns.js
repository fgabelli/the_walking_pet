/**
 * Modulo Campagne Push Parametrizzate per The Walking Pet (DOGZN)
 * 
 * Supporta:
 * - Invio mirato con payload di deep link e tracciamento campaignId
 * - Segmentazione dinamica (es. utenti orfani iOS senza firstName)
 * - Modalità dryRun predefinita (true) per validazione token senza invio reale
 * - Rilevamento e pulizia automatica token UNREGISTERED (disinstallazioni)
 * - Reportistica automatica salvata su Firestore (collection: campaign_reports)
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

const ADMIN_EMAILS = [
  "f.gabelli@gmail.com",
  "sviluppo@revan.it",
];

/**
 * Estrae i token per il segmento specificato
 * @param {string} segment - Nome del segmento ('orphaned_users_ios', 'custom_tokens', 'internal_test')
 * @param {string[]} customTokens - Array di token per invii di test interni
 * @returns {Promise<Array<{uid: string, token: string}>>}
 */
async function getSegmentRecipients(segment, customTokens = []) {
  if (segment === "custom_tokens" || segment === "internal_test") {
    if (!Array.isArray(customTokens) || customTokens.length === 0) {
      throw new Error("Per il segmento '" + segment + "' è necessario fornire almeno un customToken valido.");
    }
    return customTokens.map((token, index) => ({
      uid: "test_target_" + index,
      token: token.trim(),
    }));
  }

  if (segment === "orphaned_users_ios") {
    const db = admin.firestore();
    console.log("🔍 Scansione collection 'users' per segmento 'orphaned_users_ios'...");
    
    const snapshot = await db.collection("users").get();
    const recipients = [];

    snapshot.forEach((doc) => {
      const data = doc.data() || {};
      const firstName = data.firstName;
      const isFirstNameMissing = firstName == null || String(firstName).trim().length === 0;
      
      const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
      const platform = data.tokenPlatform || "";

      // Target: assenza di firstName, token presenti e piattaforma iOS (o non specificata Android)
      if (isFirstNameMissing && tokens.length > 0 && platform !== "android") {
        for (const token of tokens) {
          if (token && typeof token === "string" && token.trim().length > 10) {
            recipients.push({
              uid: doc.id,
              token: token.trim(),
            });
          }
        }
      }
    });

    console.log(`✅ Trovati ${recipients.length} token per ${snapshot.size} documenti analizzati.`);
    return recipients;
  }

  throw new Error(`Segmento sconosciuto: '${segment}'. Valori supportati: 'orphaned_users_ios', 'internal_test', 'custom_tokens'.`);
}

/**
 * Esegue l'invio della campagna push con gestione dryRun e chunking FCM
 * @param {object} params
 * @param {string} params.title - Titolo della notifica
 * @param {string} params.body - Corpo del messaggio
 * @param {string} [params.deepLink] - Deep link di atterraggio (default: '/resume-onboarding')
 * @param {string} params.campaignId - ID univoco della campagna (es. 'recovery_orphans_ios_v1')
 * @param {string} [params.segment] - Segmento ('orphaned_users_ios', 'internal_test', 'custom_tokens')
 * @param {string[]} [params.customTokens] - Token per invio di test
 * @param {boolean} [params.dryRun=true] - Se true, esegue solo simulazione APNs/FCM senza invio effettivo
 * @returns {Promise<object>} Report dell'operazione
 */
async function executeCampaign({
  title,
  body,
  deepLink = "/resume-onboarding",
  campaignId,
  segment = "orphaned_users_ios",
  customTokens = [],
  dryRun = true,
}) {
  if (!title || typeof title !== "string" || title.trim().length === 0) {
    throw new Error("Il parametro 'title' è obbligatorio e non può essere vuoto.");
  }
  if (!body || typeof body !== "string" || body.trim().length === 0) {
    throw new Error("Il parametro 'body' è obbligatorio e non può essere vuoto.");
  }
  if (!campaignId || typeof campaignId !== "string" || campaignId.trim().length === 0) {
    throw new Error("Il parametro 'campaignId' è obbligatorio per il tracciamento.");
  }

  const isDryRun = dryRun !== false; // Sicurezza: di default SEMPRE true a meno che esplicitamente false

  console.log(`\n========================================`);
  console.log(`🚀 AVVIO CAMPAGNA PUSH: ${campaignId}`);
  console.log(`Modalità: ${isDryRun ? "🛡️ DRY-RUN (Nessuna notifica inviata)" : "🔴 INVIO EFFETTIVO"}`);
  console.log(`Segmento: ${segment}`);
  console.log(`Deep Link: ${deepLink}`);
  console.log(`========================================\n`);

  const recipients = await getSegmentRecipients(segment, customTokens);

  if (recipients.length === 0) {
    return {
      success: true,
      message: "Nessun destinatario trovato per il segmento specificato.",
      campaignId,
      segment,
      dryRun: isDryRun,
      totalTokens: 0,
    };
  }

  // Deduplica token mantenendo mappa token -> lista uid
  const tokenToUids = new Map();
  for (const { uid, token } of recipients) {
    if (!tokenToUids.has(token)) {
      tokenToUids.set(token, []);
    }
    tokenToUids.get(token).push(uid);
  }

  const uniqueTokens = Array.from(tokenToUids.keys());
  console.log(`Destinatari: ${recipients.length} riferimenti token, ${uniqueTokens.length} token univoci.`);

  const messaging = admin.messaging();
  const db = admin.firestore();

  let totalDelivered = 0;
  let totalFailed = 0;
  const unregisteredTokens = [];
  const otherErrors = [];

  // Invio a lotti da max 500 token (limite FCM per sendEachForMulticast)
  const CHUNK_SIZE = 500;
  for (let i = 0; i < uniqueTokens.length; i += CHUNK_SIZE) {
    const chunkTokens = uniqueTokens.slice(i, i + CHUNK_SIZE);

    const message = {
      tokens: chunkTokens,
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
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
    };

    console.log(`Invio chunk ${Math.floor(i / CHUNK_SIZE) + 1} (${chunkTokens.length} token)... [dryRun=${isDryRun}]`);
    
    const response = await messaging.sendEachForMulticast(message, isDryRun);

    response.responses.forEach((resp, idx) => {
      const token = chunkTokens[idx];
      if (resp.success) {
        totalDelivered++;
      } else {
        totalFailed++;
        const errorCode = resp.error ? resp.error.code : "unknown";
        const errorMessage = resp.error ? resp.error.message : "Errore non specificato";

        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token" ||
          errorCode === "messaging/invalid-argument"
        ) {
          unregisteredTokens.push({
            token,
            uids: tokenToUids.get(token) || [],
            code: errorCode,
          });
        } else {
          otherErrors.push({
            token,
            code: errorCode,
            message: errorMessage,
          });
        }
      }
    });
  }

  console.log(`\n📊 Risultato elaborazione:`);
  console.log(`- Token totali target: ${recipients.length}`);
  console.log(`- Token univoci: ${uniqueTokens.length}`);
  console.log(`- Consegnati / Validi: ${totalDelivered}`);
  console.log(`- Errori totali: ${totalFailed}`);
  console.log(`- Token disinstallati (UNREGISTERED): ${unregisteredTokens.length}`);

  // Se è un invio reale (NON dryRun), gestisci pulizia token e persistenza report
  let reportId = null;
  if (!isDryRun) {
    // 1. Pulizia automatica token disinstallati in Firestore
    if (unregisteredTokens.length > 0) {
      console.log(`🧹 Pulizia in corso di ${unregisteredTokens.length} token disinstallati da Firestore...`);
      const batchLimit = 400;
      let currentBatch = db.batch();
      let opCount = 0;

      for (const item of unregisteredTokens) {
        for (const uid of item.uids) {
          const userRef = db.collection("users").doc(uid);
          currentBatch.update(userRef, {
            fcmTokens: admin.firestore.FieldValue.arrayRemove(item.token),
            tokenStatus: "unregistered",
            tokenCleanedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          opCount++;

          if (opCount >= batchLimit) {
            await currentBatch.commit();
            currentBatch = db.batch();
            opCount = 0;
          }
        }
      }

      if (opCount > 0) {
        await currentBatch.commit();
      }
      console.log(`✅ Pulizia token completata.`);
    }

    // 2. Persistenza Report Campagna su Firestore
    reportId = `${campaignId}_${Date.now()}`;
    await db.collection("campaign_reports").doc(reportId).set({
      campaignId,
      title,
      body,
      deepLink,
      segment,
      dryRun: false,
      totalTokensTarget: recipients.length,
      uniqueTokensTarget: uniqueTokens.length,
      deliveredCount: totalDelivered,
      failedCount: totalFailed,
      unregisteredCount: unregisteredTokens.length,
      unregisteredTokensSummary: unregisteredTokens.map(u => ({
        tokenSnippet: u.token.substring(0, 15) + "...",
        code: u.code,
        uids: u.uids,
      })),
      otherErrorsCount: otherErrors.length,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`📄 Report salvato su Firestore: campaign_reports/${reportId}`);
  }

  return {
    success: true,
    campaignId,
    segment,
    dryRun: isDryRun,
    reportId,
    totalTokensTarget: recipients.length,
    uniqueTokensTarget: uniqueTokens.length,
    deliveredCount: totalDelivered,
    failedCount: totalFailed,
    unregisteredCount: unregisteredTokens.length,
    unregisteredTokens: unregisteredTokens.map(u => ({
      tokenSnippet: u.token.substring(0, 15) + "...",
      uids: u.uids,
      code: u.code,
    })),
    otherErrorsSummary: otherErrors.slice(0, 10),
  };
}

/**
 * Callable Cloud Function per invio campagna (protetta per soli amministratori)
 */
exports.sendTargetedCampaignPush = functions
  .region("europe-west1")
  .runWith({ timeoutSeconds: 300, memory: "512MB" })
  .https.onCall(async (data, context) => {
    // 1. Verifica autenticazione
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utente deve essere autenticato per eseguire questa funzione."
      );
    }

    const callerUid = context.auth.uid;
    const db = admin.firestore();

    // 2. Verifica privilegi amministratore
    const callerDoc = await db.collection("users").doc(callerUid).get();
    const callerData = callerDoc.exists ? callerDoc.data() : {};
    const isAdmin =
      callerData.isAdmin === true ||
      ADMIN_EMAILS.includes(callerData.email || "") ||
      ADMIN_EMAILS.includes(context.auth.token.email || "");

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Operazione riservata esclusivamente agli amministratori."
      );
    }

    // 3. Esecuzione campagna
    try {
      return await executeCampaign({
        title: data.title,
        body: data.body,
        deepLink: data.deepLink,
        campaignId: data.campaignId,
        segment: data.segment,
        customTokens: data.customTokens,
        dryRun: data.dryRun !== false, // Default SEMPRE true se non specificato
      });
    } catch (err) {
      console.error("[sendTargetedCampaignPush] Errore:", err);
      throw new functions.https.HttpsError("internal", err.message);
    }
  });

exports.executeCampaign = executeCampaign;
exports.getSegmentRecipients = getSegmentRecipients;
