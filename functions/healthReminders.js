/**
 * DOGZN — Cloud Function "checkHealthRecordReminders"
 * Invia notifiche push e in-app agli utenti 14 giorni prima della scadenza
 * dei richiami vaccinali e sanitari dei loro pet.
 *
 * Schedulata ogni giorno alle 09:00 Europe/Rome.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

/**
 * Pulisce i token FCM non più validi registrati sull'utente
 */
async function cleanupTokens(response, tokens, userId) {
  if (!response || response.failureCount === 0 || !tokens || !userId) return;

  const tokensToRemove = [];
  response.responses.forEach((result, index) => {
    if (!result.success && result.error) {
      const code = result.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(tokens[index]);
      }
    }
  });

  if (tokensToRemove.length > 0) {
    try {
      await admin.firestore().collection("users").doc(userId).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
      });
      console.log(`[HealthReminders] Rimossi ${tokensToRemove.length} token invalidi per utente ${userId}`);
    } catch (err) {
      console.error(`[HealthReminders] Errore rimozione token utente ${userId}:`, err);
    }
  }
}

/**
 * Salva una notifica in-app nel profilo dell'utente
 */
async function saveInAppNotification(userId, { type, title, body, data = {} }) {
  try {
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .add({
        type: type || "health_record",
        title: title || "Promemoria sanitario",
        body: body || "",
        data: data,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (e) {
    console.error(`[HealthReminders] Errore salvataggio notifica in-app per ${userId}:`, e);
  }
}

exports.checkHealthRecordReminders = functions
  .region("europe-west1")
  .pubsub.schedule("0 9 * * *")
  .timeZone("Europe/Rome")
  .onRun(async () => {
    const db = admin.firestore();
    const now = new Date();

    // Finestra a 14 giorni: da oggi + 13.5 giorni a oggi + 14.5 giorni (circa 24h)
    const targetMin = new Date(now.getTime() + 13.5 * 24 * 60 * 60 * 1000);
    const targetMax = new Date(now.getTime() + 14.5 * 24 * 60 * 60 * 1000);

    console.log(`[HealthReminders] Esecuzione promemoria 14 giorni. Finestra: ${targetMin.toISOString()} -> ${targetMax.toISOString()}`);

    try {
      const recordsSnapshot = await db.collection("health_records")
        .where("reminderEnabled", "==", true)
        .where("nextDueDate", ">=", admin.firestore.Timestamp.fromDate(targetMin))
        .where("nextDueDate", "<=", admin.firestore.Timestamp.fromDate(targetMax))
        .get();

      console.log(`[HealthReminders] Trovati ${recordsSnapshot.size} record candidati nella finestra temporale`);

      for (const recordDoc of recordsSnapshot.docs) {
        const record = recordDoc.data();

        // Evita re-invii
        if (record.reminder14dSent === true) {
          continue;
        }

        const petId = record.petId;
        if (!petId) continue;

        // Recupera dati del cane
        const dogDoc = await db.collection("dogs").doc(petId).get();
        if (!dogDoc.exists) continue;
        const dog = dogDoc.data();
        const dogName = dog.name || "il tuo amico a 4 zampe";
        const ownerId = dog.ownerId;
        if (!ownerId) continue;

        // Recupera proprietario
        const ownerDoc = await db.collection("users").doc(ownerId).get();
        if (!ownerDoc.exists) continue;
        const owner = ownerDoc.data();
        if (owner.isBanned === true) continue;

        const vaccineName = record.specificName || record.title || "richiamo sanitario";
        const title = "💉 Promemoria Richiamo Sanitario";
        const body = `Tra 14 giorni è previsto il richiamo di ${vaccineName} per ${dogName}. Prenota per tempo dal tuo veterinario!`;
        const payloadData = {
          type: "health_record",
          petId: petId,
          recordId: recordDoc.id,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        };

        // Invia notifica Push se ci sono token
        const tokens = owner.fcmTokens || [];
        if (Array.isArray(tokens) && tokens.length > 0) {
          const message = {
            notification: { title, body },
            data: payloadData,
            tokens: tokens,
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          try {
            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`[HealthReminders] Push inviata a ${tokens.length} token per ${dogName} (${recordDoc.id}): ${response.successCount} successi, ${response.failureCount} fallimenti`);
            await cleanupTokens(response, tokens, ownerId);
          } catch (pushErr) {
            console.error(`[HealthReminders] Errore invio push per record ${recordDoc.id}:`, pushErr);
          }
        }

        // Salva notifica in-app
        await saveInAppNotification(ownerId, {
          type: "health_record",
          title,
          body,
          data: payloadData,
        });

        // Contrassegna il record come inviato
        await recordDoc.ref.update({
          reminder14dSent: true,
          reminder14dSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log("[HealthReminders] Elaborazione promemoria 14 giorni completata con successo.");
    } catch (e) {
      console.error("[HealthReminders] Errore durante l'elaborazione dei promemoria:", e);
    }
  });
