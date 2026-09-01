/**
 * Script ad alte prestazioni: rileva ed elimina da Firebase Auth tutti gli utenti "orfani"
 * (account Auth registrati che NON hanno un corrispondente documento in Firestore users/{uid}).
 *
 * 1. Scarica tutti gli ID presenti in Firestore (users) in un Set in memoria.
 * 2. Scarica tutti gli utenti da Firebase Auth.
 * 3. Identifica gli orfani in millisecondi.
 *
 * Uso:
 *   node cleanup_orphan_auth_users.js --dry-run   (Scansione e report)
 *   node cleanup_orphan_auth_users.js             (Eliminazione effettiva)
 */

const { execSync } = require("child_process");

const PROJECT_ID = "thewalkingpet-a1578";
const PROTECTED_EMAILS = [
  "f.gabelli@gmail.com",
  "sviluppo@revan.it",
];

const DRY_RUN = process.argv.includes("--dry-run");

function getAccessToken() {
  return execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
}

async function fetchWithAuth(url, options = {}) {
  const token = getAccessToken();
  const headers = {
    "Authorization": `Bearer ${token}`,
    "x-goog-user-project": PROJECT_ID,
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };

  const res = await fetch(url, { ...options, headers });
  return res;
}

// Scarica tutti gli UID degli utenti validi da Firestore (collection: users)
async function getAllFirestoreUserIds() {
  console.log("📥 Caricamento lista profili da Firestore (collection: users)...");
  const userIds = new Set();
  let nextPageToken = null;

  do {
    let url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/users?pageSize=300&mask.fieldPaths=__name__`;
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
      for (const doc of data.documents) {
        // doc.name ha formato: projects/.../databases/(default)/documents/users/{uid}
        const parts = doc.name.split("/");
        const uid = parts[parts.length - 1];
        userIds.add(uid);
      }
    }
    nextPageToken = data.nextPageToken;
  } while (nextPageToken);

  console.log(`✅ Trovati ${userIds.size} profili completi in Firestore.\n`);
  return userIds;
}

// Elimina account da Firebase Auth via REST API
async function deleteAuthUser(uid) {
  const url = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:delete`;
  const res = await fetchWithAuth(url, {
    method: "POST",
    body: JSON.stringify({ localId: uid }),
  });
  if (res.status === 200) return true;
  const text = await res.text();
  throw new Error(`Errore cancellazione Auth ${uid} (status ${res.status}): ${text}`);
}

async function main() {
  console.log(`\n===========================================================`);
  console.log(`🔍 SCANSIONE UTENTI FIREBASE AUTH (Progetto: ${PROJECT_ID})`);
  console.log(`===========================================================\n`);
  if (DRY_RUN) {
    console.log("⚠️  MODALITÀ DRY-RUN: Nessuna modifica verrà applicata.\n");
  }

  // 1. Carica tutti i profili Firestore
  const firestoreUserIds = await getAllFirestoreUserIds();

  // 2. Carica tutti gli utenti Auth
  console.log("📥 Caricamento account da Firebase Authentication...");
  let nextPageToken = null;
  let totalAuthUsers = 0;
  const orphans = [];
  const validUsers = [];
  const protectedUsers = [];

  do {
    let url = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}/accounts:batchGet?maxResults=100`;
    if (nextPageToken) {
      url += `&nextPageToken=${encodeURIComponent(nextPageToken)}`;
    }

    const res = await fetchWithAuth(url);
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Errore lista utenti Auth (${res.status}): ${errText}`);
    }

    const data = await res.json();
    const users = data.users || [];
    totalAuthUsers += users.length;

    for (const u of users) {
      const uid = u.localId;
      const email = (u.email || "").toLowerCase();
      const providers = (u.providerUserInfo || []).map(p => p.providerId).join(", ") || "email/password";
      const createdAt = u.createdAt ? new Date(parseInt(u.createdAt, 10)).toISOString() : "unknown";
      const lastLoginAt = u.lastLoginAt ? new Date(parseInt(u.lastLoginAt, 10)).toISOString() : "never";

      if (PROTECTED_EMAILS.includes(email)) {
        protectedUsers.push({ uid, email, providers });
        continue;
      }

      if (firestoreUserIds.has(uid)) {
        validUsers.push({ uid, email, providers });
      } else {
        orphans.push({
          uid,
          email: email || "(private-relay / no email)",
          providers,
          createdAt,
          lastLoginAt,
        });
      }
    }

    nextPageToken = data.nextPageToken;
  } while (nextPageToken);

  console.log(`-----------------------------------------------------------`);
  console.log(`📊 RISULTATI SCANSIONE:`);
  console.log(`   - Totale account su Firebase Auth:   ${totalAuthUsers}`);
  console.log(`   - Utenti REALI (con profilo in DB):  ${validUsers.length}`);
  console.log(`   - Account protetti (Admin):          ${protectedUsers.length}`);
  console.log(`   - Account ORFANI (senza profilo):    ${orphans.length}`);
  console.log(`-----------------------------------------------------------\n`);

  if (orphans.length === 0) {
    console.log("✨ Nessun account orfano trovato! Firebase Auth è già pulito.\n");
    return;
  }

  console.log(`📋 DETTAGLIO ACCOUNT ORFANI (${orphans.length}):`);
  orphans.forEach((o, i) => {
    console.log(`  ${(i + 1).toString().padStart(3, " ")}. [${o.providers.padEnd(12, " ")}] ${o.email.padEnd(36, " ")} | Creato: ${o.createdAt} | Ultimo login: ${o.lastLoginAt}`);
  });

  if (DRY_RUN) {
    console.log(`\n⚠️  [DRY-RUN] Nessun account è stato eliminato.`);
    console.log(`   Esegui senza --dry-run per eliminare questi ${orphans.length} account orfani.\n`);
    return;
  }

  console.log(`\n🗑️  ELIMINAZIONE IN CORSO di ${orphans.length} account orfani...`);
  let deletedCount = 0;
  let failCount = 0;

  for (const o of orphans) {
    try {
      await deleteAuthUser(o.uid);
      deletedCount++;
      console.log(`  ✅ Eliminato: ${o.email} (${o.uid})`);
    } catch (err) {
      failCount++;
      console.error(`  ❌ Fallito: ${o.email} (${o.uid}) -> ${err.message}`);
    }
  }

  console.log(`\n===========================================================`);
  console.log(`🎉 PULIZIA COMPLETATA: ${deletedCount} eliminati, ${failCount} errori.`);
  console.log(`===========================================================\n`);
}

main().catch(err => {
  console.error("❌ ERRORE:", err);
  process.exit(1);
});
