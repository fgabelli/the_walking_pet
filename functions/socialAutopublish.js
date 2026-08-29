/**
 * DOGZN — Cloud Function "socialAutopublish"
 * Pubblica una riga (3 tile) della griglia IG/FB, dal cloud, indipendente dal Mac.
 *
 * Schedulata ogni giorno alle 13:00 Europe/Rome. È il campo `date` di ogni riga
 * nel queue.json a decidere quando esce: la function pubblica la riga più vecchia
 * con date <= oggi non ancora pubblicata (dedup su Firestore coll. socialPublished).
 *
 * Sorgenti:
 *  - coda:       https://dogzn.com/img/social/queue.json
 *  - immagini:   https://dogzn.com/img/social/<file>
 *  - token Meta: Secret Manager -> secret META_TOKEN (system user token)
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

const API = "https://graph.facebook.com/v20.0";
const QUEUE_URL = "https://dogzn.com/img/social/queue.json";
const BASE_IMG = "https://dogzn.com/img/social/";

function todayRome() {
  return new Date().toLocaleDateString("en-CA", {timeZone: "Europe/Rome"});
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function getJson(url) {
  const r = await fetch(url, {cache: "no-store"});
  if (!r.ok) throw new Error(`GET ${url} -> ${r.status}`);
  return r.json();
}
async function headOk(url) {
  try {
    const r = await fetch(url, {method: "HEAD"});
    return r.ok;
  } catch (e) {
    return false;
  }
}
async function fbPost(ep, params) {
  const r = await fetch(`${API}/${ep}`, {method: "POST", body: new URLSearchParams(params)});
  const j = await r.json();
  if (!r.ok) throw new Error(`POST ${ep} -> ${r.status} ${JSON.stringify(j)}`);
  return j;
}
async function pageToken(systemToken, pageId) {
  const j = await getJson(`${API}/me/accounts?fields=id,access_token&access_token=${encodeURIComponent(systemToken)}`);
  const page = (j.data || []).find((p) => p.id === pageId) || (j.data || [])[0];
  if (!page || !page.access_token) throw new Error("page token non trovato");
  return page.access_token;
}

exports.socialAutopublish = functions
    .region("europe-west1")
    .runWith({secrets: ["META_TOKEN"], timeoutSeconds: 300, memory: "256MB"})
    .pubsub.schedule("0 13 * * *")
    .timeZone("Europe/Rome")
    .onRun(async () => {
      const db = admin.firestore();
      const today = todayRome();
      const token = process.env.META_TOKEN;
      if (!token) {
        console.error("[socialAutopublish] META_TOKEN mancante");
        return null;
      }

      const queue = await getJson(QUEUE_URL);
      const fbPage = queue.fb_page_id;
      const igId = queue.ig_account_id;
      const due = (queue.rows || [])
          .filter((r) => r.date <= today)
          .sort((a, b) => a.date.localeCompare(b.date));

      // prima riga dovuta non ancora pubblicata
      let target = null;
      for (const row of due) {
        const snap = await db.collection("socialPublished").doc(row.id).get();
        if (!snap.exists) {
          target = row;
          break;
        }
      }
      if (!target) {
        console.log(`[socialAutopublish] ${today}: nessuna riga dovuta`);
        return null;
      }

      // lock atomico: evita doppie esecuzioni
      const ref = db.collection("socialPublished").doc(target.id);
      try {
        await db.runTransaction(async (tx) => {
          const s = await tx.get(ref);
          if (s.exists) throw new Error("gia presa");
          tx.set(ref, {
            status: "publishing",
            date: target.date,
            startedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
      } catch (e) {
        console.log(`[socialAutopublish] riga ${target.id} gia in corso: ${e.message}`);
        return null;
      }

      const pageTok = await pageToken(token, fbPage);
      const results = [];
      for (const item of target.items) { // ordine: contest -> lo sapevi -> dal blog
        const url = BASE_IMG + item.file;
        if (!(await headOk(url))) {
          console.error(`[socialAutopublish] immagine non online: ${url}`);
          results.push({file: item.file, error: "not_online"});
          continue;
        }
        let fbId = "";
        let igMediaId = "";
        try {
          const fb = await fbPost(`${fbPage}/photos`, {url, message: item.caption, access_token: pageTok});
          fbId = fb.post_id || fb.id || "";
        } catch (e) {
          console.error("[socialAutopublish] FB err", item.file, e.message);
        }
        try {
          const cont = await fbPost(`${igId}/media`, {image_url: url, caption: item.caption, access_token: pageTok});
          await sleep(3000);
          const pub = await fbPost(`${igId}/media_publish`, {creation_id: cont.id, access_token: pageTok});
          igMediaId = pub.id || "";
        } catch (e) {
          console.error("[socialAutopublish] IG err", item.file, e.message);
        }
        results.push({file: item.file, fbId, igId: igMediaId});
        await sleep(5000);
      }

      await ref.set({
        status: "done",
        date: target.date,
        results,
        publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      console.log(`[socialAutopublish] riga ${target.id} OK`, JSON.stringify(results));
      return null;
    });
