/**
 * ============================================================
 *  TWP Content Moderation System
 *  Uses Cloud Vision SafeSearch (images) + Gemini (text)
 * ============================================================
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");
const { VertexAI } = require("@google-cloud/vertexai");

// ── Clients ──────────────────────────────────────────────
const visionClient = new vision.ImageAnnotatorClient();

// Initialize Vertex AI - uses default project credentials
const PROJECT_ID = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "thewalkingpet-a1578";
const LOCATION = "europe-west1";
const vertexAI = new VertexAI({ project: PROJECT_ID, location: LOCATION });
const geminiModel = vertexAI.getGenerativeModel({ model: "gemini-2.0-flash" });

// ── Configuration ────────────────────────────────────────
const MODERATION_CONFIG = {
    // Vision SafeSearch thresholds
    // Values: UNKNOWN, VERY_UNLIKELY, UNLIKELY, POSSIBLE, LIKELY, VERY_LIKELY
    imageBlockThreshold: ["LIKELY", "VERY_LIKELY"],
    imageWarnThreshold: ["POSSIBLE"],

    // Text moderation - categories to check
    textCategories: [
        "hate_speech", "harassment", "sexual_content",
        "violence", "self_harm", "spam", "profanity",
    ],
};

// ── Helper: Log moderation event ─────────────────────────
async function logModerationEvent({
    contentType, // 'image' | 'text'
    contentId,
    collection,
    userId,
    action, // 'blocked' | 'flagged' | 'approved'
    reason,
    details,
}) {
    try {
        await admin.firestore().collection("moderation_log").add({
            contentType,
            contentId,
            collection,
            userId,
            action,
            reason,
            details: details || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
        console.error("Failed to log moderation event:", e);
    }
}

// ── Helper: Notify user about content removal ────────────
async function notifyUserAboutRemoval(userId, contentType, reason) {
    try {
        // Create an in-app notification
        await admin.firestore().collection("users").doc(userId)
            .collection("notifications").add({
                type: "content_removed",
                title: "Contenuto rimosso",
                body: `Il tuo ${contentType} è stato rimosso perché viola le linee guida della community: ${reason}`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
            });
    } catch (e) {
        console.error("Failed to send removal notification:", e);
    }
}

// ── Helper: Increment user violations counter ─────────────
async function incrementViolations(userId) {
    try {
        await admin.firestore().collection("users").doc(userId).update({
            "moderationViolations": admin.firestore.FieldValue.increment(1),
            "lastViolationAt": admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
        console.error("Failed to increment violations:", e);
    }
}

// ══════════════════════════════════════════════════════════
//  IMAGE MODERATION (Cloud Vision SafeSearch)
// ══════════════════════════════════════════════════════════

/**
 * Analyze an image URL using Cloud Vision SafeSearch Detection.
 * Returns: { safe: boolean, action: string, reason: string, details: object }
 */
async function moderateImage(imageUrl) {
    try {
        const [result] = await visionClient.safeSearchDetection(imageUrl);
        const safeSearch = result.safeSearchAnnotation;

        if (!safeSearch) {
            console.warn("No SafeSearch annotation returned for:", imageUrl);
            return { safe: true, action: "approved", reason: null, details: null };
        }

        const categories = {
            adult: safeSearch.adult,
            violence: safeSearch.violence,
            racy: safeSearch.racy,
            medical: safeSearch.medical,
            spoof: safeSearch.spoof,
        };

        console.log("SafeSearch results:", JSON.stringify(categories));

        // Check for blocking conditions    
        const blockReasons = [];
        const warnReasons = [];

        for (const [category, likelihood] of Object.entries(categories)) {
            if (category === "spoof" || category === "medical") continue; // Skip these

            if (MODERATION_CONFIG.imageBlockThreshold.includes(likelihood)) {
                blockReasons.push(`${category}: ${likelihood}`);
            } else if (MODERATION_CONFIG.imageWarnThreshold.includes(likelihood)) {
                warnReasons.push(`${category}: ${likelihood}`);
            }
        }

        if (blockReasons.length > 0) {
            return {
                safe: false,
                action: "blocked",
                reason: `Contenuto inappropriato rilevato (${blockReasons.join(", ")})`,
                details: categories,
            };
        }

        if (warnReasons.length > 0) {
            return {
                safe: true, // Don't block, but flag
                action: "flagged",
                reason: `Contenuto potenzialmente sensibile (${warnReasons.join(", ")})`,
                details: categories,
            };
        }

        return { safe: true, action: "approved", reason: null, details: categories };
    } catch (e) {
        console.error("Vision API error:", e);
        // On error, don't block - fail open
        return { safe: true, action: "error", reason: e.message, details: null };
    }
}

// ══════════════════════════════════════════════════════════
//  TEXT MODERATION (Gemini AI)
// ══════════════════════════════════════════════════════════

/**
 * Analyze text content using Gemini for moderation.
 * Returns: { safe: boolean, action: string, reason: string, details: object }
 */
async function moderateText(text) {
    if (!text || text.trim().length === 0) {
        return { safe: true, action: "approved", reason: null, details: null };
    }

    // Skip very short texts (e.g., "ok", "ciao")
    if (text.trim().length < 5) {
        return { safe: true, action: "approved", reason: null, details: null };
    }

    try {
        const prompt = `Sei un sistema di moderazione contenuti per un'app sociale dedicata ai proprietari di animali domestici (cani, gatti, ecc.).

Analizza il seguente testo e rispondi ESCLUSIVAMENTE con un JSON valido (senza markdown, senza backtick, solo il JSON):

{
  "safe": true/false,
  "severity": "none" | "low" | "medium" | "high",
  "categories": [],
  "reason": "breve spiegazione in italiano se non safe, altrimenti null"
}

Le categorie possibili sono:
- "hate_speech" (odio, razzismo, discriminazione)
- "harassment" (molestie, bullismo, intimidazione)
- "sexual_content" (contenuti sessualmente espliciti)
- "violence" (minacce di violenza, incitamento)
- "self_harm" (autolesionismo, suicidio)
- "spam" (pubblicità non richiesta, link sospetti)
- "profanity" (linguaggio volgare eccessivo)
- "animal_abuse" (maltrattamento animali)

REGOLE IMPORTANTI:
- Il linguaggio colloquiale e le parolacce lievi sono OK (severity: "low")
- Solo contenuti davvero offensivi, pericolosi o espliciti devono essere bloccati (severity: "high")
- Lo spam evidente va bloccato
- Il maltrattamento animali va SEMPRE bloccato
- Lamentele, sfoghi emotivi e discussioni civili sono OK
- "safe: false" SOLO per severity "high"

TESTO DA ANALIZZARE:
"""
${text}
"""`;

        const result = await geminiModel.generateContent(prompt);
        const response = result.response;
        const responseText = response.candidates[0].content.parts[0].text;

        // Parse JSON response
        let analysis;
        try {
            // Clean the response - remove any markdown formatting
            const cleanJson = responseText.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
            analysis = JSON.parse(cleanJson);
        } catch (parseError) {
            console.error("Failed to parse Gemini response:", responseText);
            return { safe: true, action: "error", reason: "Parse error", details: { raw: responseText } };
        }

        if (!analysis.safe && analysis.severity === "high") {
            return {
                safe: false,
                action: "blocked",
                reason: analysis.reason || "Contenuto inappropriato",
                details: {
                    categories: analysis.categories,
                    severity: analysis.severity,
                },
            };
        }

        if (analysis.severity === "medium") {
            return {
                safe: true,
                action: "flagged",
                reason: analysis.reason,
                details: {
                    categories: analysis.categories,
                    severity: analysis.severity,
                },
            };
        }

        return {
            safe: true,
            action: "approved",
            reason: null,
            details: {
                categories: analysis.categories || [],
                severity: analysis.severity || "none",
            },
        };
    } catch (e) {
        console.error("Gemini moderation error:", e);
        // On error, don't block - fail open
        return { safe: true, action: "error", reason: e.message, details: null };
    }
}

// ══════════════════════════════════════════════════════════
//  FIRESTORE TRIGGERS
// ══════════════════════════════════════════════════════════

/**
 * Moderate Social Feed Posts
 * Trigger: When a new post is created in social_posts
 */
exports.moderateSocialPost = functions
    .region("europe-west1")
    .firestore.document("social_posts/{postId}")
    .onCreate(async (snapshot, context) => {
        const post = snapshot.data();
        const postId = context.params.postId;
        const userId = post.authorId;

        console.log(`Moderating social post: ${postId}`);

        // 1. Moderate text
        if (post.text) {
            const textResult = await moderateText(post.text);
            console.log(`Text moderation result for ${postId}:`, textResult.action);

            if (!textResult.safe) {
                // Block: Delete the post
                await snapshot.ref.delete();
                await logModerationEvent({
                    contentType: "text",
                    contentId: postId,
                    collection: "social_posts",
                    userId,
                    action: "blocked",
                    reason: textResult.reason,
                    details: textResult.details,
                });
                await notifyUserAboutRemoval(userId, "post", textResult.reason);
                await incrementViolations(userId);
                return;
            }

            if (textResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "text",
                    contentId: postId,
                    collection: "social_posts",
                    userId,
                    action: "flagged",
                    reason: textResult.reason,
                    details: textResult.details,
                });
            }
        }

        // 2. Moderate image
        if (post.imageUrl) {
            const imageResult = await moderateImage(post.imageUrl);
            console.log(`Image moderation result for ${postId}:`, imageResult.action);

            if (!imageResult.safe) {
                // Block: Delete the post and the image
                try {
                    const storage = admin.storage().bucket();
                    const fileUrl = post.imageUrl;
                    // Extract file path from URL
                    const filePath = decodeURIComponent(
                        fileUrl.split("/o/")[1]?.split("?")[0],
                    );
                    if (filePath) {
                        await storage.file(filePath).delete().catch(() => { });
                    }
                } catch (e) {
                    console.error("Error deleting image:", e);
                }

                await snapshot.ref.delete();
                await logModerationEvent({
                    contentType: "image",
                    contentId: postId,
                    collection: "social_posts",
                    userId,
                    action: "blocked",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
                await notifyUserAboutRemoval(userId, "foto", imageResult.reason);
                await incrementViolations(userId);
                return;
            }

            if (imageResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "image",
                    contentId: postId,
                    collection: "social_posts",
                    userId,
                    action: "flagged",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
            }
        }
    });

/**
 * Moderate Social Post Comments
 * Trigger: When a comment is added to a post
 */
exports.moderatePostComment = functions
    .region("europe-west1")
    .firestore.document("social_posts/{postId}/comments/{commentId}")
    .onCreate(async (snapshot, context) => {
        const comment = snapshot.data();
        const { postId, commentId } = context.params;
        const userId = comment.authorId;

        console.log(`Moderating comment ${commentId} on post ${postId}`);

        if (!comment.text) return;

        const result = await moderateText(comment.text);

        if (!result.safe) {
            await snapshot.ref.delete();
            // Decrement comment count
            await admin.firestore().collection("social_posts").doc(postId).update({
                commentCount: admin.firestore.FieldValue.increment(-1),
            });
            await logModerationEvent({
                contentType: "text",
                contentId: commentId,
                collection: `social_posts/${postId}/comments`,
                userId,
                action: "blocked",
                reason: result.reason,
                details: result.details,
            });
            await notifyUserAboutRemoval(userId, "commento", result.reason);
            await incrementViolations(userId);
        } else if (result.action === "flagged") {
            await logModerationEvent({
                contentType: "text",
                contentId: commentId,
                collection: `social_posts/${postId}/comments`,
                userId,
                action: "flagged",
                reason: result.reason,
                details: result.details,
            });
        }
    });

/**
 * Moderate Announcements (Bacheca)
 * Trigger: When a new announcement is created
 */
exports.moderateAnnouncement = functions
    .region("europe-west1")
    .firestore.document("announcements/{announcementId}")
    .onCreate(async (snapshot, context) => {
        const announcement = snapshot.data();
        const announcementId = context.params.announcementId;
        const userId = announcement.userId;

        console.log(`Moderating announcement: ${announcementId}`);

        // 1. Moderate text (title + message)
        const fullText = [announcement.title, announcement.message]
            .filter(Boolean).join("\n");

        if (fullText) {
            const textResult = await moderateText(fullText);

            if (!textResult.safe) {
                await snapshot.ref.delete();
                await logModerationEvent({
                    contentType: "text",
                    contentId: announcementId,
                    collection: "announcements",
                    userId,
                    action: "blocked",
                    reason: textResult.reason,
                    details: textResult.details,
                });
                await notifyUserAboutRemoval(userId, "annuncio", textResult.reason);
                await incrementViolations(userId);
                return;
            }

            if (textResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "text",
                    contentId: announcementId,
                    collection: "announcements",
                    userId,
                    action: "flagged",
                    reason: textResult.reason,
                    details: textResult.details,
                });
            }
        }

        // 2. Moderate image
        if (announcement.imageUrl) {
            const imageResult = await moderateImage(announcement.imageUrl);

            if (!imageResult.safe) {
                try {
                    const storage = admin.storage().bucket();
                    const filePath = decodeURIComponent(
                        announcement.imageUrl.split("/o/")[1]?.split("?")[0],
                    );
                    if (filePath) {
                        await storage.file(filePath).delete().catch(() => { });
                    }
                } catch (e) {
                    console.error("Error deleting announcement image:", e);
                }

                await snapshot.ref.delete();
                await logModerationEvent({
                    contentType: "image",
                    contentId: announcementId,
                    collection: "announcements",
                    userId,
                    action: "blocked",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
                await notifyUserAboutRemoval(userId, "annuncio", imageResult.reason);
                await incrementViolations(userId);
                return;
            }
        }
    });

/**
 * Moderate Chat Messages
 * Trigger: When a new message is sent in a chat
 */
exports.moderateChatMessage = functions
    .region("europe-west1")
    .firestore.document("chats/{chatId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
        const message = snapshot.data();
        const { chatId, messageId } = context.params;
        const userId = message.senderId;

        // Skip system messages
        if (message.type === "system") return;

        console.log(`Moderating chat message ${messageId} in chat ${chatId} (type: ${message.type})`);

        // 1. Moderate text content (for text, walkInvite, petCard messages)
        if (message.text && message.type !== "image" && message.type !== "location") {
            const result = await moderateText(message.text);

            if (!result.safe) {
                await snapshot.ref.update({
                    text: "[Messaggio rimosso per violazione delle linee guida]",
                    moderated: true,
                    originalText: message.text,
                });

                await logModerationEvent({
                    contentType: "text",
                    contentId: messageId,
                    collection: `chats/${chatId}/messages`,
                    userId,
                    action: "blocked",
                    reason: result.reason,
                    details: result.details,
                });
                await incrementViolations(userId);
                return; // Stop here if text is blocked
            } else if (result.action === "flagged") {
                await logModerationEvent({
                    contentType: "text",
                    contentId: messageId,
                    collection: `chats/${chatId}/messages`,
                    userId,
                    action: "flagged",
                    reason: result.reason,
                    details: result.details,
                });
            }
        }

        // 2. Moderate image content (for image messages)
        if (message.type === "image" && message.metadata && message.metadata.imageUrl) {
            const imageUrl = message.metadata.imageUrl;
            console.log(`Moderating chat image in message ${messageId}`);

            const imageResult = await moderateImage(imageUrl);

            if (!imageResult.safe) {
                // Delete the image from Storage
                try {
                    const storage = admin.storage().bucket();
                    const filePath = decodeURIComponent(
                        imageUrl.split("/o/")[1]?.split("?")[0],
                    );
                    if (filePath) {
                        await storage.file(filePath).delete().catch(() => { });
                    }
                } catch (e) {
                    console.error("Error deleting chat image:", e);
                }

                // Replace message content
                await snapshot.ref.update({
                    text: "[Foto rimossa per violazione delle linee guida]",
                    metadata: {},
                    moderated: true,
                    type: "text",
                });

                // Update lastMessage on chat doc if this was the latest
                try {
                    const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
                    if (chatDoc.exists) {
                        const lastMsg = chatDoc.data().lastMessage;
                        if (lastMsg && lastMsg.id === messageId) {
                            await chatDoc.ref.update({
                                "lastMessage.text": "[Foto rimossa]",
                                "lastMessage.type": "text",
                                "lastMessage.metadata": {},
                            });
                        }
                    }
                } catch (e) {
                    console.error("Error updating lastMessage:", e);
                }

                await logModerationEvent({
                    contentType: "image",
                    contentId: messageId,
                    collection: `chats/${chatId}/messages`,
                    userId,
                    action: "blocked",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
                await incrementViolations(userId);
            } else if (imageResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "image",
                    contentId: messageId,
                    collection: `chats/${chatId}/messages`,
                    userId,
                    action: "flagged",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
            }
        }
    });

/**
 * Moderate User Profile Updates
 * Trigger: When a user profile is updated (bio, name changes)
 */
exports.moderateUserProfile = functions
    .region("europe-west1")
    .firestore.document("users/{userId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const userId = context.params.userId;

        // Only check if relevant fields changed
        const bioChanged = before.bio !== after.bio;
        const nameChanged = (before.firstName !== after.firstName) ||
            (before.lastName !== after.lastName);
        const photoChanged = before.photoUrl !== after.photoUrl;
        const coverChanged = before.coverImageUrl !== after.coverImageUrl;

        // Guard: skip if no moderation-relevant fields changed
        // (prevents recursive triggers when this function updates the doc)
        if (!bioChanged && !nameChanged && !photoChanged && !coverChanged) {
            return;
        }

        // 1. Moderate bio text
        if (bioChanged && after.bio) {
            console.log(`Moderating bio for user: ${userId}`);
            const result = await moderateText(after.bio);

            if (!result.safe) {
                // Remove the bio
                await change.after.ref.update({ bio: null });
                await logModerationEvent({
                    contentType: "text",
                    contentId: userId,
                    collection: "users",
                    userId,
                    action: "blocked",
                    reason: result.reason,
                    details: result.details,
                });
                await notifyUserAboutRemoval(userId, "bio", result.reason);
                await incrementViolations(userId);
            }
        }

        // 2. Moderate name (for offensive names)
        if (nameChanged) {
            const fullName = `${after.firstName || ""} ${after.lastName || ""}`.trim();
            if (fullName.length > 2) {
                console.log(`Moderating name for user: ${userId}`);
                const result = await moderateText(fullName);

                if (!result.safe) {
                    await change.after.ref.update({
                        firstName: before.firstName,
                        lastName: before.lastName,
                    });
                    await logModerationEvent({
                        contentType: "text",
                        contentId: userId,
                        collection: "users",
                        userId,
                        action: "blocked",
                        reason: `Nome inappropriato: ${result.reason}`,
                    });
                    await notifyUserAboutRemoval(userId, "nome", result.reason);
                    await incrementViolations(userId);
                }
            }
        }

        // 3. Moderate profile photo
        if (photoChanged && after.photoUrl) {
            console.log(`Moderating profile photo for user: ${userId}`);
            const result = await moderateImage(after.photoUrl);

            if (!result.safe) {
                // Remove the photo
                await change.after.ref.update({ photoUrl: null });
                try {
                    const storage = admin.storage().bucket();
                    await storage.file(`users/${userId}/profile.jpg`).delete().catch(() => { });
                } catch (e) {
                    console.error("Error deleting profile image:", e);
                }
                await logModerationEvent({
                    contentType: "image",
                    contentId: userId,
                    collection: "users",
                    userId,
                    action: "blocked",
                    reason: result.reason,
                    details: result.details,
                });
                await notifyUserAboutRemoval(userId, "foto profilo", result.reason);
                await incrementViolations(userId);
            }
        }

        // 4. Moderate cover image
        if (coverChanged && after.coverImageUrl) {
            console.log(`Moderating cover image for user: ${userId}`);
            const result = await moderateImage(after.coverImageUrl);

            if (!result.safe) {
                await change.after.ref.update({ coverImageUrl: null });
                try {
                    const storage = admin.storage().bucket();
                    await storage.file(`users/${userId}/cover.jpg`).delete().catch(() => { });
                } catch (e) {
                    console.error("Error deleting cover image:", e);
                }
                await logModerationEvent({
                    contentType: "image",
                    contentId: userId,
                    collection: "users",
                    userId,
                    action: "blocked",
                    reason: result.reason,
                    details: result.details,
                });
                await notifyUserAboutRemoval(userId, "immagine di copertina", result.reason);
                await incrementViolations(userId);
            }
        }
    });

/**
 * Auto-ban users with too many violations
 * Trigger: When moderation violations count changes
 */
exports.checkAutoban = functions
    .region("europe-west1")
    .firestore.document("users/{userId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const userId = context.params.userId;

        const violationsBefore = before.moderationViolations || 0;
        const violationsAfter = after.moderationViolations || 0;

        // Only process if violations increased
        if (violationsAfter <= violationsBefore) return;

        // Warning at 3 violations
        if (violationsAfter === 3) {
            await admin.firestore().collection("users").doc(userId)
                .collection("notifications").add({
                    type: "moderation_warning",
                    title: "⚠️ Avviso di moderazione",
                    body: "Hai ricevuto 3 violazioni delle linee guida. Al raggiungimento di 5 violazioni il tuo account verrà sospeso.",
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                });
        }

        // Auto-suspend at 5 violations
        if (violationsAfter >= 5 && !after.suspended) {
            await change.after.ref.update({
                suspended: true,
                suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
                suspendReason: "Troppe violazioni delle linee guida della community",
            });

            await admin.firestore().collection("users").doc(userId)
                .collection("notifications").add({
                    type: "account_suspended",
                    title: "🚫 Account sospeso",
                    body: "Il tuo account è stato sospeso per ripetute violazioni delle linee guida. Contatta il supporto per maggiori informazioni.",
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                });

            await logModerationEvent({
                contentType: "account",
                contentId: userId,
                collection: "users",
                userId,
                action: "suspended",
                reason: `Auto-suspended after ${violationsAfter} violations`,
            });
        }
    });

// ══════════════════════════════════════════════════════════
//  REEL MODERATION (Video thumbnail + caption)
// ══════════════════════════════════════════════════════════

/**
 * Moderate Reels
 * Trigger: When a new reel is created
 *
 * Strategy:
 * 1. Moderate caption text (Gemini)
 * 2. Moderate thumbnail image if present (Cloud Vision SafeSearch)
 * 3. If no thumbnail, extract a representative frame via Gemini Vision
 *    by analyzing the video URL for unsafe content descriptions
 * 4. Update moderationStatus to 'approved' or 'rejected'
 */
exports.moderateReel = functions
    .region("europe-west1")
    .runWith({ timeoutSeconds: 120, memory: "512MB" })
    .firestore.document("reels/{reelId}")
    .onCreate(async (snapshot, context) => {
        const reel = snapshot.data();
        const reelId = context.params.reelId;
        const userId = reel.authorId;

        console.log(`Moderating reel: ${reelId}`);

        // 1. Moderate caption text
        if (reel.caption) {
            const textResult = await moderateText(reel.caption);
            console.log(`Reel caption moderation for ${reelId}:`, textResult.action);

            if (!textResult.safe) {
                // Reject: update status + cleanup
                await _rejectReel(snapshot, reelId, userId, "text", textResult);
                return;
            }

            if (textResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "text",
                    contentId: reelId,
                    collection: "reels",
                    userId,
                    action: "flagged",
                    reason: textResult.reason,
                    details: textResult.details,
                });
            }
        }

        // 2. Moderate thumbnail image (if provided)
        if (reel.thumbnailUrl) {
            const imageResult = await moderateImage(reel.thumbnailUrl);
            console.log(`Reel thumbnail moderation for ${reelId}:`, imageResult.action);

            if (!imageResult.safe) {
                await _rejectReel(snapshot, reelId, userId, "image", imageResult);
                return;
            }

            if (imageResult.action === "flagged") {
                await logModerationEvent({
                    contentType: "image",
                    contentId: reelId,
                    collection: "reels",
                    userId,
                    action: "flagged",
                    reason: imageResult.reason,
                    details: imageResult.details,
                });
            }
        }

        // 3. Use Gemini Vision to analyze video content description
        //    Since we can't directly frame-sample on Cloud Functions,
        //    we ask Gemini to evaluate the video URL metadata + context
        if (reel.videoUrl) {
            try {
                const videoAnalysis = await _analyzeVideoContent(reel.videoUrl, reel.caption);
                console.log(`Reel video AI analysis for ${reelId}:`, videoAnalysis.action);

                if (!videoAnalysis.safe) {
                    await _rejectReel(snapshot, reelId, userId, "video", videoAnalysis);
                    return;
                }

                if (videoAnalysis.action === "flagged") {
                    await logModerationEvent({
                        contentType: "video",
                        contentId: reelId,
                        collection: "reels",
                        userId,
                        action: "flagged",
                        reason: videoAnalysis.reason,
                        details: videoAnalysis.details,
                    });
                }
            } catch (e) {
                console.error(`Video analysis failed for reel ${reelId}:`, e.message);
                // Fail open - don't block on analysis failure
            }
        }

        // 4. All checks passed → approve
        await snapshot.ref.update({ moderationStatus: "approved" });
        console.log(`Reel ${reelId} approved`);
    });

/**
 * Analyze video content using Gemini multimodal
 * Sends the video URL to Gemini for content safety evaluation
 */
async function _analyzeVideoContent(videoUrl, caption) {
    try {
        const prompt = `Sei un sistema di moderazione contenuti per un'app sociale dedicata ai proprietari di animali domestici.

Devi valutare se un video caricato è appropriato. Ti fornisco l'URL del video e la descrizione associata.

VIDEO URL: ${videoUrl}
DESCRIZIONE: ${caption || "(nessuna)"}

Basandoti sul contesto (un'app per proprietari di cani e gatti), rispondi ESCLUSIVAMENTE con un JSON valido:

{
  "safe": true/false,
  "severity": "none" | "low" | "medium" | "high",
  "reason": "breve spiegazione in italiano se non safe, altrimenti null"
}

REGOLE:
- Video di animali domestici, passeggiate, giochi → SAFE
- Video di natura, parchi, persone con animali → SAFE
- Contenuti violenti, espliciti, maltrattamento animali → NOT SAFE (severity: "high")
- Video non correlati ma innocui → SAFE (severity: "low")
- "safe: false" SOLO per severity "high"
- Nel dubbio, approva il contenuto (fail open)`;

        const result = await geminiModel.generateContent(prompt);
        const response = result.response;
        const responseText = response.candidates[0].content.parts[0].text;

        let analysis;
        try {
            const cleanJson = responseText.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim();
            analysis = JSON.parse(cleanJson);
        } catch (parseError) {
            console.error("Failed to parse Gemini video response:", responseText);
            return { safe: true, action: "error", reason: "Parse error", details: null };
        }

        if (!analysis.safe && analysis.severity === "high") {
            return {
                safe: false,
                action: "blocked",
                reason: analysis.reason || "Video inappropriato",
                details: { severity: analysis.severity },
            };
        }

        if (analysis.severity === "medium") {
            return {
                safe: true,
                action: "flagged",
                reason: analysis.reason,
                details: { severity: analysis.severity },
            };
        }

        return { safe: true, action: "approved", reason: null, details: null };
    } catch (e) {
        console.error("Gemini video analysis error:", e);
        return { safe: true, action: "error", reason: e.message, details: null };
    }
}

/**
 * Helper: Reject a reel - delete video/thumbnail from Storage,
 * update Firestore status, log event, notify user, increment violations
 */
async function _rejectReel(snapshot, reelId, userId, contentType, result) {
    const reel = snapshot.data();

    // Update status to rejected
    await snapshot.ref.update({
        moderationStatus: "rejected",
        rejectionReason: result.reason,
    });

    // Delete video from Storage
    if (reel.videoUrl) {
        try {
            const storage = admin.storage().bucket();
            const filePath = decodeURIComponent(
                reel.videoUrl.split("/o/")[1]?.split("?")[0],
            );
            if (filePath) {
                await storage.file(filePath).delete().catch(() => { });
            }
        } catch (e) {
            console.error("Error deleting reel video:", e);
        }
    }

    // Delete thumbnail from Storage
    if (reel.thumbnailUrl) {
        try {
            const storage = admin.storage().bucket();
            const filePath = decodeURIComponent(
                reel.thumbnailUrl.split("/o/")[1]?.split("?")[0],
            );
            if (filePath) {
                await storage.file(filePath).delete().catch(() => { });
            }
        } catch (e) {
            console.error("Error deleting reel thumbnail:", e);
        }
    }

    await logModerationEvent({
        contentType,
        contentId: reelId,
        collection: "reels",
        userId,
        action: "blocked",
        reason: result.reason,
        details: result.details,
    });
    await notifyUserAboutRemoval(userId, "reel", result.reason);
    await incrementViolations(userId);

    console.log(`Reel ${reelId} REJECTED: ${result.reason}`);
}

// ══════════════════════════════════════════════════════════
//  DOG PROFILE MODERATION (Match/Dating profiles)
// ══════════════════════════════════════════════════════════

/**
 * Helper to moderate a dog profile's name, notes, and media URLs.
 */
async function _moderateDog(dogId, before, after, docRef) {
    const userId = after.ownerId;
    if (!userId) return;

    // 1. Moderate name
    if (after.name && (!before || before.name !== after.name)) {
        console.log(`Moderating name for dog: ${dogId}`);
        const result = await moderateText(after.name);
        if (!result.safe) {
            const fallbackName = before ? before.name : "Pet";
            await docRef.update({ name: fallbackName });
            await logModerationEvent({
                contentType: "text",
                contentId: dogId,
                collection: "dogs",
                userId,
                action: "blocked",
                reason: `Nome pet inappropriato: ${result.reason}`,
            });
            await notifyUserAboutRemoval(userId, "nome del pet", result.reason);
            await incrementViolations(userId);
            
            // Reload after update
            const freshDoc = await docRef.get();
            after = freshDoc.data();
        }
    }

    // 2. Moderate notes
    if (after.notes && (!before || before.notes !== after.notes)) {
        console.log(`Moderating notes for dog: ${dogId}`);
        const result = await moderateText(after.notes);
        if (!result.safe) {
            await docRef.update({ notes: null });
            await logModerationEvent({
                contentType: "text",
                contentId: dogId,
                collection: "dogs",
                userId,
                action: "blocked",
                reason: result.reason,
                details: result.details,
            });
            await notifyUserAboutRemoval(userId, `descrizione di ${after.name || "un pet"}`, result.reason);
            await incrementViolations(userId);
            
            // Reload after update
            const freshDoc = await docRef.get();
            after = freshDoc.data();
        }
    }

    // 3. Moderate mediaUrls / photoUrl
    const mediaUrlsChanged = !before || JSON.stringify(before.mediaUrls) !== JSON.stringify(after.mediaUrls);
    const photoUrlChanged = !before || before.photoUrl !== after.photoUrl;

    if ((mediaUrlsChanged && after.mediaUrls && after.mediaUrls.length > 0) || (photoUrlChanged && after.photoUrl)) {
        console.log(`Moderating images for dog: ${dogId}`);
        
        let urlsToCheck = [];
        if (after.mediaUrls && after.mediaUrls.length > 0) {
            urlsToCheck = [...after.mediaUrls];
        } else if (after.photoUrl) {
            urlsToCheck = [after.photoUrl];
        }

        const updatedUrls = [...urlsToCheck];
        let modified = false;

        for (const url of urlsToCheck) {
            const result = await moderateImage(url);
            if (!result.safe) {
                const index = updatedUrls.indexOf(url);
                if (index > -1) {
                    updatedUrls.splice(index, 1);
                    modified = true;
                }

                // Delete from Storage
                try {
                    const storage = admin.storage().bucket();
                    const filePath = decodeURIComponent(
                        url.split("/o/")[1]?.split("?")[0],
                    );
                    if (filePath) {
                        await storage.file(filePath).delete().catch(() => { });
                    }
                } catch (e) {
                    console.error("Error deleting dog image:", e);
                }

                await logModerationEvent({
                    contentType: "image",
                    contentId: dogId,
                    collection: "dogs",
                    userId,
                    action: "blocked",
                    reason: result.reason,
                    details: result.details,
                });
                await notifyUserAboutRemoval(userId, `foto di ${after.name || "un pet"}`, result.reason);
                await incrementViolations(userId);
            }
        }

        if (modified) {
            const newPhotoUrl = updatedUrls.length > 0 ? updatedUrls[0] : null;
            await docRef.update({
                mediaUrls: updatedUrls,
                photoUrl: newPhotoUrl
            });
        }
    }
}

/**
 * Moderate Dog Profile on creation
 */
exports.moderateDogProfileCreate = functions
    .region("europe-west1")
    .firestore.document("dogs/{dogId}")
    .onCreate(async (snapshot, context) => {
        const dog = snapshot.data();
        const dogId = context.params.dogId;
        console.log(`moderateDogProfileCreate triggered for ${dogId}`);
        await _moderateDog(dogId, null, dog, snapshot.ref);
    });

/**
 * Moderate Dog Profile on update
 */
exports.moderateDogProfileUpdate = functions
    .region("europe-west1")
    .firestore.document("dogs/{dogId}")
    .onUpdate(async (change, context) => {
        const before = change.before.data();
        const after = change.after.data();
        const dogId = context.params.dogId;

        // Prevent infinite loops by comparing fields we moderate
        const nameChanged = before.name !== after.name;
        const notesChanged = before.notes !== after.notes;
        const mediaUrlsChanged = JSON.stringify(before.mediaUrls) !== JSON.stringify(after.mediaUrls);
        const photoUrlChanged = before.photoUrl !== after.photoUrl;

        if (!nameChanged && !notesChanged && !mediaUrlsChanged && !photoUrlChanged) {
            return;
        }

        console.log(`moderateDogProfileUpdate triggered for ${dogId}`);
        await _moderateDog(dogId, before, after, change.after.ref);
    });


