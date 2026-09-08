/**
 * Utility per estrazione e ispezione del segmento utenti orfani su thewalkingpet-a1578
 * 
 * Funziona nativamente su Mac usando il token gcloud autenticato, senza dipendere da ADC file.
 *
 * Esecuzione:
 *   node functions/extract_orphan_segment.js              (Stampa statistiche e controprova 109)
 *   node functions/extract_orphan_segment.js --list       (Stampa lista uid e conteggio token)
 *   node functions/extract_orphan_segment.js --export-json segment_export.json (Salva file locale ignorato da git)
 */

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const PROJECT_ID = "thewalkingpet-a1578";

function getAccessToken() {
  try {
    return execSync("gcloud auth print-access-token", { encoding: "utf8" }).trim();
  } catch (e) {
    throw new Error("Impossibile ottenere il token da gcloud. Esegui 'gcloud auth login'.");
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

async function run() {
  console.log("📥 Caricamento documenti dalla collection 'users' via Firestore REST API...");

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

  console.log(`Totale documenti caricati: ${documents.length}`);

  let countWithFirstName = 0;
  let countWithoutFirstName = 0;
  const orphanedSegment = [];
  const tokenSet = new Set();
  const platformBreakdown = {};

  for (const doc of documents) {
    const fields = doc.fields || {};
    const uid = doc.name.split("/").pop();

    const firstNameVal = fields.firstName ? fields.firstName.stringValue : null;
    const hasFirstName = firstNameVal != null && firstNameVal.trim().length > 0;

    const tokensVal = fields.fcmTokens && fields.fcmTokens.arrayValue ? fields.fcmTokens.arrayValue.values || [] : [];
    const tokens = tokensVal.map(v => v.stringValue).filter(Boolean);
    const platform = fields.tokenPlatform ? fields.tokenPlatform.stringValue : "non_specificata";

    if (hasFirstName) {
      countWithFirstName++;
    } else {
      countWithoutFirstName++;
      if (tokens.length > 0) {
        orphanedSegment.push({
          uid,
          tokenCount: tokens.length,
          tokens,
          platform,
        });

        platformBreakdown[platform] = (platformBreakdown[platform] || 0) + 1;
        for (const t of tokens) {
          tokenSet.add(t);
        }
      }
    }
  }

  console.log("\n==========================================");
  console.log("📊 REPORT SEGMENTAZIONE ORPHANED USERS");
  console.log("==========================================");
  console.log(`- Totale documenti users: ${documents.length}`);
  console.log(`- Controprova con firstName: ${countWithFirstName} (Target atteso: 109)`);
  console.log(`- Senza firstName (orfani): ${countWithoutFirstName}`);
  console.log(`- Segmento raggiungibile via Push: ${orphanedSegment.length} utenti`);
  console.log(`- Token totali nel segmento: ${orphanedSegment.reduce((acc, u) => acc + u.tokenCount, 0)}`);
  console.log(`- Token univoci (device distinti): ${tokenSet.size}`);
  console.log(`- Ripartizione piattaforme:`, JSON.stringify(platformBreakdown, null, 2));
  console.log("==========================================\n");

  if (process.argv.includes("--list")) {
    console.log("Elenco utenti nel segmento (UID, platform, tokens):");
    orphanedSegment.forEach((u, idx) => {
      console.log(`[${idx + 1}] UID: ${u.uid} | Piattaforma: ${u.platform} | Token: ${u.tokenCount}`);
    });
  }

  const exportIndex = process.argv.indexOf("--export-json");
  if (exportIndex !== -1 && process.argv[exportIndex + 1]) {
    const filename = process.argv[exportIndex + 1];
    const outPath = path.resolve(__dirname, filename);
    const exportData = {
      timestamp: new Date().toISOString(),
      totalUsers: documents.length,
      countWithFirstName,
      countWithoutFirstName,
      segmentTargetCount: orphanedSegment.length,
      uniqueTokensCount: tokenSet.size,
      segment: orphanedSegment.map(u => ({
        uid: u.uid,
        tokens: u.tokens,
        platform: u.platform,
      })),
    };
    fs.writeFileSync(outPath, JSON.stringify(exportData, null, 2));
    console.log(`💾 Segmento esportato con successo in: ${outPath}`);
  }
}

run().catch((err) => {
  console.error("Errore durante l'estrazione:", err);
  process.exit(1);
});
