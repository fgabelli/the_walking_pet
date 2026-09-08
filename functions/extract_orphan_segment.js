/**
 * Utility per estrazione e ispezione del segmento utenti orfani su thewalkingpet-a1578
 * 
 * Esecuzione:
 *   node extract_orphan_segment.js              (Stampa statistiche e controprova 109)
 *   node extract_orphan_segment.js --list       (Stampa lista uid e conteggio token)
 *   node extract_orphan_segment.js --export-json segment_export.json (Salva file locale ignorato da git)
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: "thewalkingpet-a1578",
  });
}

async function run() {
  const db = admin.firestore();
  console.log("📥 Caricamento documenti dalla collection 'users'...");

  const snapshot = await db.collection("users").get();
  console.log(`Totale documenti caricati: ${snapshot.size}`);

  let countWithFirstName = 0;
  let countWithoutFirstName = 0;
  const orphanedSegment = [];
  const tokenSet = new Set();
  const platformBreakdown = {};

  snapshot.forEach((doc) => {
    const data = doc.data() || {};
    const firstName = data.firstName;
    const hasFirstName = firstName != null && String(firstName).trim().length > 0;
    const tokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
    const platform = data.tokenPlatform || "non_specificata";

    if (hasFirstName) {
      countWithFirstName++;
    } else {
      countWithoutFirstName++;
      if (tokens.length > 0) {
        orphanedSegment.push({
          uid: doc.id,
          tokenCount: tokens.length,
          tokens: tokens,
          platform: platform,
          email: data.email || null,
          createdAt: data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate().toISOString() : data.createdAt) : null,
        });

        platformBreakdown[platform] = (platformBreakdown[platform] || 0) + 1;
        for (const t of tokens) {
          if (t && typeof t === "string") tokenSet.add(t);
        }
      }
    }
  });

  console.log("\n==========================================");
  console.log("📊 REPORT SEGMENTAZIONE ORPHANED USERS");
  console.log("==========================================");
  console.log(`- Totale documenti users: ${snapshot.size}`);
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
      totalUsers: snapshot.size,
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
