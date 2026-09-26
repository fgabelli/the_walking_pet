/**
 * Dry-run script per verificare la Cloud Function checkHealthRecordReminders
 * sui dati esistenti in Firestore (thewalkingpet-a1578).
 *
 * Utilizzo: node functions/dryrun_health_reminders.js
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

async function dryRunReminders() {
  console.log("=== DRY RUN: checkHealthRecordReminders ===");
  console.log(`Progetto: ${PROJECT_ID}`);
  
  const now = new Date();
  const targetMin = new Date(now.getTime() + 13.5 * 24 * 60 * 60 * 1000);
  const targetMax = new Date(now.getTime() + 14.5 * 24 * 60 * 60 * 1000);

  console.log(`Finestra target 14 giorni: ${targetMin.toISOString()} -> ${targetMax.toISOString()}`);

  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/health_records`;
  const res = await fetchWithAuth(url);
  if (!res.ok) {
    const errText = await res.text();
    console.error("Errore fetch health_records:", errText);
    return;
  }

  const data = await res.json();
  const documents = data.documents || [];
  console.log(`\nTotale record sanitari trovati nel DB: ${documents.length}`);

  let candidatesCount = 0;

  for (const doc of documents) {
    const fields = doc.fields || {};
    const title = fields.title?.stringValue || "Senza titolo";
    const reminderEnabled = fields.reminderEnabled?.booleanValue || false;
    const nextDueDateStr = fields.nextDueDate?.timestampValue;
    const isCompleted = fields.isCompleted?.booleanValue || false;

    console.log(`\n• Documento: ${doc.name.split("/").pop()}`);
    console.log(`  Titolo: ${title}`);
    console.log(`  Completato: ${isCompleted}`);
    console.log(`  reminderEnabled: ${reminderEnabled}`);
    console.log(`  nextDueDate: ${nextDueDateStr || "null"}`);

    if (reminderEnabled && nextDueDateStr) {
      const dueDate = new Date(nextDueDateStr);
      if (dueDate >= targetMin && dueDate <= targetMax) {
        console.log(`  🚨 CANDIDATO A NOTIFICA: Data nella finestra a 14gg!`);
        candidatesCount++;
      } else {
        console.log(`  ℹ️ Data fuori dalla finestra dei 14gg (dueDate: ${dueDate.toISOString()})`);
      }
    } else {
      console.log(`  ✅ Non attivo per reminder (reminderEnabled: false o nextDueDate null)`);
    }
  }

  console.log(`\n========================================`);
  console.log(`Risultato Dry Run: ${candidatesCount} notifiche verrebbero inviate.`);
  if (candidatesCount === 0) {
    console.log("SUCCESSO: Nessuna notifica a vuoto o non voluta verrebbe inviata.");
  }
}

dryRunReminders().catch((err) => {
  console.error("Errore durante l'esecuzione del dry run:", err);
  process.exit(1);
});
