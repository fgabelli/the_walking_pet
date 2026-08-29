const functions = require("firebase-functions");
const admin = require("firebase-admin");
const path = require("path");
const os = require("os");
const fs = require("fs");
const ffmpegInstaller = require("@ffmpeg-installer/ffmpeg");
const ffmpeg = require("fluent-ffmpeg");

// Point fluent-ffmpeg to the bundled static binary
ffmpeg.setFfmpegPath(ffmpegInstaller.path);

const bucket = admin.storage().bucket();

/**
 * Extracts the Firebase Storage path from a full download URL.
 * Handles both firebasestorage.googleapis.com and storage.googleapis.com URLs.
 * @param {string} url - The full Firebase Storage URL
 * @return {string} The decoded storage path (e.g. "reels/userId/123.mp4")
 */
function extractStoragePath(url) {
  // Format: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/ENCODED_PATH?...
  const match = url.match(/\/o\/(.+?)(\?|$)/);
  if (!match) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Impossibile estrarre il path dallo storage URL."
    );
  }
  return decodeURIComponent(match[1]);
}

/**
 * watermarkVideo — Callable Cloud Function (v1 onCall)
 *
 * Downloads a video from Firebase Storage, overlays a branded watermark
 * ("🐾 DOGZN" + "@username") in the bottom-right corner, uploads the
 * result to watermarked_reels/, and returns a signed download URL.
 *
 * Input: { videoUrl: string, username: string, type: "reel" | "post" }
 * Output: { downloadUrl: string }
 */
exports.watermarkVideo = functions
  .region("europe-west1")
  .runWith({ memory: "2GB", timeoutSeconds: 300 })
  .https.onCall(async (data, context) => {
    // ── 1. Auth check ──
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Devi essere autenticato per usare questa funzione."
      );
    }

    // ── 2. Validate input ──
    const { videoUrl, username, type } = data;

    if (!videoUrl || typeof videoUrl !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "videoUrl è obbligatorio e deve essere una stringa."
      );
    }
    if (!username || typeof username !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "username è obbligatorio e deve essere una stringa."
      );
    }
    if (type && !["reel", "post"].includes(type)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "type deve essere 'reel' o 'post'."
      );
    }

    // ── 3. Derive paths ──
    const storagePath = extractStoragePath(videoUrl);
    const originalFileName = path.basename(storagePath);
    const tmpInput = path.join(os.tmpdir(), `input_${originalFileName}`);
    const tmpLogo = path.join(os.tmpdir(), "dogzn_logo.png");
    const tmpOutput = path.join(os.tmpdir(), `wm_${originalFileName}`);
    const destinationPath = `watermarked_reels/${originalFileName}`;

    try {
      // ── 4. Download source video ──
      console.log(`[watermarkVideo] Downloading ${storagePath}`);
      await bucket.file(storagePath).download({ destination: tmpInput });

      // ── 4b. Download DOGZN logo ──
      const logoPath = "brand_assets/dogzn_splash_logo.png";
      try {
        await bucket.file(logoPath).download({ destination: tmpLogo });
      } catch (logoErr) {
        console.warn(`[watermarkVideo] Logo not found at ${logoPath}, using text-only fallback`);
      }

      const logoExists = fs.existsSync(tmpLogo);

      // ── 5. Apply watermark with ffmpeg ──
      console.log(`[watermarkVideo] Applying watermark for @${username}`);
      await new Promise((resolve, reject) => {
        const cmd = ffmpeg(tmpInput);

        if (logoExists) {
          // Logo overlay (scaled to 12% of video width) + @username text
          cmd
            .input(tmpLogo)
            .complexFilter([
              // Scale logo to 12% of video width, maintain aspect ratio
              "[1:v]scale=iw*0.12:-1[logo]",
              // Overlay logo bottom-right with padding
              "[0:v][logo]overlay=W-w-20:H-h-50[watermarked]",
              // Add @username text below the logo
              {
                filter: "drawtext",
                options: {
                  text: `@${username}`,
                  fontsize: 18,
                  fontcolor: "white@0.85",
                  x: "(w-text_w-24)",
                  y: "(h-30)",
                },
                inputs: "watermarked",
                outputs: "final",
              },
            ])
            .outputOptions(["-map", "[final]", "-map", "0:a?", "-c:a", "copy"]);
        } else {
          // Text-only fallback
          cmd.videoFilters([
            {
              filter: "drawtext",
              options: {
                text: "DOGZN",
                fontsize: 22,
                fontcolor: "white",
                box: 1,
                boxcolor: "black@0.45",
                boxborderw: 6,
                x: "(w-text_w-20)",
                y: "(h-text_h*2-50)",
              },
            },
            {
              filter: "drawtext",
              options: {
                text: `@${username}`,
                fontsize: 18,
                fontcolor: "white@0.85",
                box: 1,
                boxcolor: "black@0.45",
                boxborderw: 6,
                x: "(w-text_w-20)",
                y: "(h-text_h-20)",
              },
            },
          ]).outputOptions(["-c:a", "copy"]);
        }

        cmd
          .output(tmpOutput)
          .on("end", resolve)
          .on("error", (err) => {
            console.error("[watermarkVideo] ffmpeg error:", err.message);
            reject(err);
          })
          .run();
      });

      // ── 6. Upload watermarked video ──
      const expireAfter = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
      const downloadToken = require("crypto").randomBytes(16).toString("hex");

      console.log(`[watermarkVideo] Uploading to ${destinationPath}`);
      await bucket.upload(tmpOutput, {
        destination: destinationPath,
        metadata: {
          contentType: "video/mp4",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            expireAfter: expireAfter,
            originalPath: storagePath,
            watermarkedBy: context.auth.uid,
          },
        },
      });

      // ── 7. Construct public download URL ──
      const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destinationPath)}?alt=media&token=${downloadToken}`;

      console.log(`[watermarkVideo] Done. File: ${destinationPath}`);
      return { downloadUrl };

    } catch (err) {
      // Re-throw HttpsErrors as-is
      if (err instanceof functions.https.HttpsError) throw err;

      console.error("[watermarkVideo] Unexpected error:", err);
      throw new functions.https.HttpsError(
        "internal",
        "Errore durante la creazione del watermark."
      );

    } finally {
      // ── 8. Cleanup temp files ──
      try { if (fs.existsSync(tmpInput)) fs.unlinkSync(tmpInput); } catch (_) {}
      try { if (fs.existsSync(tmpLogo)) fs.unlinkSync(tmpLogo); } catch (_) {}
      try { if (fs.existsSync(tmpOutput)) fs.unlinkSync(tmpOutput); } catch (_) {}
    }
  });

/**
 * cleanupWatermarkedVideos — Scheduled Cloud Function
 *
 * Runs daily and deletes all files under watermarked_reels/ whose
 * custom metadata `expireAfter` timestamp is in the past.
 */
exports.cleanupWatermarkedVideos = functions
  .region("europe-west1")
  .pubsub.schedule("every 24 hours")
  .onRun(async () => {
    console.log("[cleanupWatermarkedVideos] Starting cleanup...");

    const [files] = await bucket.getFiles({ prefix: "watermarked_reels/" });
    const now = Date.now();
    let deleted = 0;

    const promises = files.map(async (file) => {
      try {
        const [metadata] = await file.getMetadata();
        const expireAfter = metadata.metadata && metadata.metadata.expireAfter;

        if (!expireAfter) {
          // No expiry metadata — delete as a safety measure (orphan file)
          console.log(`[cleanup] Deleting orphan file: ${file.name}`);
          await file.delete();
          deleted++;
          return;
        }

        const expireDate = new Date(expireAfter).getTime();
        if (expireDate <= now) {
          console.log(`[cleanup] Expired: ${file.name} (expired ${expireAfter})`);
          await file.delete();
          deleted++;
        }
      } catch (err) {
        console.error(`[cleanup] Error processing ${file.name}:`, err.message);
      }
    });

    await Promise.all(promises);
    console.log(`[cleanupWatermarkedVideos] Done. Deleted ${deleted}/${files.length} files.`);
    return null;
  });
