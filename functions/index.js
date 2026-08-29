const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Helper: Save a notification to the user's in-app notifications subcollection
 * This makes push notifications also appear in the Notifiche screen.
 * @param {string} userId - The recipient user ID
 * @param {object} options - { type, title, body, data (optional) }
 */
async function saveInAppNotification(userId, { type, title, body, data = {} }) {
  try {
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('notifications')
      .add({
        type: type || 'generic',
        title: title || 'Notifica',
        body: body || '',
        data: data,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (e) {
    console.error(`[saveInAppNotification] Error for user ${userId}:`, e);
  }
}

// ── Content Moderation (Vision + Gemini) ──
const moderation = require("./moderation");
exports.moderateSocialPost = moderation.moderateSocialPost;
exports.moderatePostComment = moderation.moderatePostComment;
exports.moderateAnnouncement = moderation.moderateAnnouncement;
exports.moderateChatMessage = moderation.moderateChatMessage;
exports.moderateUserProfile = moderation.moderateUserProfile;
exports.checkAutoban = moderation.checkAutoban;
exports.moderateReel = moderation.moderateReel;
exports.moderateDogProfileCreate = moderation.moderateDogProfileCreate;
exports.moderateDogProfileUpdate = moderation.moderateDogProfileUpdate;


// ── Video Watermark ──
const watermark = require("./watermark");
exports.watermarkVideo = watermark.watermarkVideo;
exports.cleanupWatermarkedVideos = watermark.cleanupWatermarkedVideos;

// ── Social autopublish (griglia IG/FB schedulata, cloud) ──
const socialAutopublish = require("./socialAutopublish");
exports.socialAutopublish = socialAutopublish.socialAutopublish;


// ── Business Claim Approval ──
exports.onBusinessClaimUpdate = functions
  .region("europe-west1")
  .firestore.document("business_claims/{claimId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process status changes
    if (before.status === after.status) return;

    const claimId = context.params.claimId;
    const db = admin.firestore();

    if (after.status === "approved") {
      console.log(`Business claim ${claimId} APPROVED for user ${after.userId}`);

      // 1. Mark business as claimed in Firestore
      const businessRef = db.collection("pet_businesses").doc(after.businessId);
      await businessRef.set({
        isClaimed: true,
        claimedByUserId: after.userId,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 2. Update user account type to business
      const userRef = db.collection("users").doc(after.userId);
      await userRef.update({
        accountType: "business",
        claimedBusinessId: after.businessId,
      });

      // 3. Notify user
      await db.collection("users").doc(after.userId).collection("notifications").add({
        type: "business_claim_approved",
        title: "🎉 Attività riscattata!",
        body: `La tua richiesta per "${after.businessName}" è stata approvata. Ora puoi gestire la tua pagina!`,
        businessId: after.businessId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 4. Update claim with reviewedAt
      await change.after.ref.update({
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (after.status === "rejected") {
      console.log(`Business claim ${claimId} REJECTED for user ${after.userId}`);

      // Notify user about rejection
      await db.collection("users").doc(after.userId).collection("notifications").add({
        type: "business_claim_rejected",
        title: "Richiesta non approvata",
        body: after.rejectionReason
          ? `La tua richiesta per "${after.businessName}" non è stata approvata: ${after.rejectionReason}`
          : `La tua richiesta per "${after.businessName}" non è stata approvata. Riprova con documenti più chiari.`,
        businessId: after.businessId,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update reviewedAt
      await change.after.ref.update({
        reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });


/**
 * Trigger: On Create Message in Chat
 * Sends notification to all other participants in the chat.
 */
exports.sendChatNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const chatId = context.params.chatId;

    try {
      // 1. Get Chat Metadata (to find participants)
      const chatDoc = await admin.firestore().collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return null;

      const chatData = chatDoc.data();
      const participants = chatData.participants || [];
      const senderId = message.senderId;

      // 2. Identify Recipients (everyone except sender)
      const recipientIds = participants.filter((uid) => uid !== senderId);

      if (recipientIds.length === 0) return null;

      // 3. Get Sender Info (Name)
      const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
      const senderName = senderDoc.exists ? senderDoc.data().firstName : "Qualcuno";

      // 4. Send to each recipient
      // Note: We loop through recipients to handle their tokens individually per user
      // so we can clean up specific user tokens.
      const promises = recipientIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        // Construct Payload for HTTP v1
        const messagePayload = {
          tokens: tokens, // sendEachForMulticast expects 'tokens'
          notification: {
            title: `Nuovo messaggio da ${senderName}`,
            body: message.type === "image" ? "📷 Foto inviata"
                 : message.type === "location" ? "📍 Posizione condivisa"
                 : message.type === "petCard" ? "🐕 Ha condiviso un profilo pet"
                 : message.type === "walkInvite" ? "🚶 Ha proposto una passeggiata"
                 : message.text,
          },
          data: {
            type: "chat_message",
            chatId: String(chatId),
            senderId: String(senderId),
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            notification: {
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default"
            }
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: "default",
                category: "FLUTTER_NOTIFICATION_CLICK"
              }
            }
          }
        };

        // Send multicast
        const response = await admin.messaging().sendEachForMulticast(messagePayload);

        // Cleanup invalid tokens
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);
    } catch (error) {
      console.error("Error sending chat notification:", error);
    }
  });

/**
 * Trigger: On Create Match
 * Sends notification to both participants when a new match is registered.
 */
exports.sendMatchNotification = functions.firestore
  .document("pet_matches/{matchId}")
  .onCreate(async (snapshot, context) => {
    const matchData = snapshot.data();
    const uids = matchData.uids || [];
    const petIds = matchData.petIds || [];

    if (uids.length < 2 || petIds.length < 2) return null;

    try {
      const user1Id = uids[0];
      const user2Id = uids[1];

      const pet1Id = petIds[0];
      const pet2Id = petIds[1];

      // Fetch pet details to get names
      const pet1Doc = await admin.firestore().collection("dogs").doc(pet1Id).get();
      const pet2Doc = await admin.firestore().collection("dogs").doc(pet2Id).get();

      const pet1Name = pet1Doc.exists ? pet1Doc.data().name : "Un pet";
      const pet2Name = pet2Doc.exists ? pet2Doc.data().name : "un pet";

      const sendToUser = async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: {
            title: "È un Match! 🐾",
            body: `${pet1Name} e ${pet2Name} hanno fiutato un'intesa! 🐾`,
          },
          data: {
            type: "pet_match",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            notification: {
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default"
            }
          },
          apns: {
            payload: {
              aps: { badge: 1, sound: "default" }
            }
          }
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);

        // Save in-app notification
        await saveInAppNotification(recipientId, {
          type: 'pet_match',
          title: 'È un Match! 🐾',
          body: `${pet1Name} e ${pet2Name} hanno fiutato un'intesa! 🐾`,
        });
      };

      // Notify both participants
      await Promise.all([
        sendToUser(user1Id),
        sendToUser(user2Id)
      ]);
    } catch (error) {
      console.error("Error sending match notification:", error);
    }
  });

/**
 * Trigger: On Update User (Friend Request)
 * Sends notification when user receives a new friend request.
 */
exports.sendFriendRequestNotification = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const userId = context.params.userId;

    // Check if friendRequests array grew
    const newRequests = newData.friendRequests || [];
    const oldRequests = oldData.friendRequests || [];

    if (newRequests.length > oldRequests.length) {
      // Find the new requester ID
      const addedRequestIds = newRequests.filter((uid) => !oldRequests.includes(uid));

      for (const requesterId of addedRequestIds) {
        try {
          // Get Requester Name
          const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
          const requesterName = requesterDoc.exists ? requesterDoc.data().firstName : "Qualcuno";

          // Get Recipient Tokens (from newData)
          const tokens = newData.fcmTokens || [];
          if (tokens.length === 0) continue;

          const messagePayload = {
            tokens: tokens,
            notification: {
              title: "Nuova richiesta di amicizia",
              body: `${requesterName} vuole stringere amicizia!`,
            },
            data: {
              type: "friend_request",
              requesterId: String(requesterId),
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            },
            android: {
              notification: {
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                sound: "default"
              }
            },
            apns: {
              payload: {
                aps: { badge: 1, sound: "default" }
              }
            }
          };

          const response = await admin.messaging().sendEachForMulticast(messagePayload);
          await cleanupTokens(response, tokens, userId);

          // Save in-app notification
          await saveInAppNotification(userId, {
            type: 'friend_request',
            title: 'Nuova richiesta di amicizia',
            body: `${requesterName} vuole stringere amicizia!`,
            data: { requesterId },
          });

        } catch (error) {
          console.error("Error sending friend request notification:", error);
        }
      }
    }
  });

/**
 * Trigger: On Create Radar Ping (Abbaio)
 * Sends dynamic notification (Bau/Miao/Ciao) based on sender's pets.
 */
exports.sendRadarPingNotification = functions.firestore
  .document("radar_pings/{pingId}")
  .onCreate(async (snapshot, context) => {
    const pingData = snapshot.data();
    const pingId = context.params.pingId;
    const targetIds = pingData.targetIds || [];
    const senderId = pingData.senderId;
    const senderName = pingData.senderName || "Un utente";

    if (targetIds.length === 0) return null;

    try {
      // 1. Determine Sender "Voice" (Dog/Cat/Human)
      const petsSnapshot = await admin.firestore().collection("dogs")
        .where("ownerId", "==", senderId).limit(3).get();

      let title = `Ciao! 👋 ${senderName} ti saluta!`;
      let body = `${senderName} ti ha inviato un saluto dal Radar.`;

      if (!petsSnapshot.empty) {
        // Check for dogs or cats
        const pets = petsSnapshot.docs.map(doc => doc.data());
        const dog = pets.find(p => p.species === "dog" || !p.species); // Default to dog if missing
        const cat = pets.find(p => p.species === "cat");

        if (dog) {
          title = `Bau! 🐶 ${dog.name} ti saluta!`;
          body = `${dog.name} (e ${senderName}) ti stanno facendo le feste!`;
        } else if (cat) {
          title = `Miao! 🐱 ${cat.name} ti saluta!`;
          body = `${cat.name} (e ${senderName}) ti stanno facendo le fusa!`;
        }
      }

      // 2. Fan-out to targets
      const promises = targetIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: {
            title: title,
            body: body,
          },
          data: {
            type: "radar_ping",
            pingId: String(pingId),
            senderId: String(senderId),
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            notification: {
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default"
            }
          },
          apns: {
            payload: {
              aps: { badge: 1, sound: "default" }
            }
          }
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);
      return snapshot.ref.update({ status: 'sent' });

    } catch (e) {
      console.error("Error in Radar Ping:", e);
      return null;
    }
  });

/**
 * Trigger: On Create SOS Alert (Lost Pet)
 * Broadcasts to all users within 5km radius of the SOS location.
 * Falls back to zone-based matching if no nearby GPS users found.
 * 
 * CRITICAL: Uses HIGH PRIORITY for both Android and iOS to ensure
 * the notification is delivered even when the app is closed/killed.
 */
exports.sendSOSNotification = functions.firestore
  .document("lost_pet_alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    const alertData = snapshot.data();
    const alertId = context.params.alertId;
    const ownerId = alertData.ownerId;
    const alertLat = alertData.latitude;
    const alertLng = alertData.longitude;

    const SOS_RADIUS_KM = 5.0; // 5km radius for lost pet alerts (critical alert)

    try {
      // 0. Get pet name for a personalized notification
      let petName = "Un animale";
      if (alertData.petId) {
        try {
          const petDoc = await admin.firestore().collection("dogs").doc(alertData.petId).get();
          if (petDoc.exists) {
            petName = petDoc.data().name || petName;
          }
        } catch (_) {}
      }

      // 1. Find users by GPS proximity (user_locations collection)
      let nearbyUserIds = [];

      if (alertLat && alertLng) {
        nearbyUserIds = await findUsersNearLocation(alertLat, alertLng, SOS_RADIUS_KM, ownerId);
        console.log(`SOS: Found ${nearbyUserIds.length} users within ${SOS_RADIUS_KM}km via GPS`);
      }

      // 2. Fallback to zone-based if no GPS matches
      if (nearbyUserIds.length === 0) {
        console.log("SOS: No GPS matches, falling back to zone-based matching");
        const ownerDoc = await admin.firestore().collection("users").doc(ownerId).get();
        if (!ownerDoc.exists) return;
        const regionZone = ownerDoc.data().zone;

        if (regionZone) {
          const usersInZone = await admin.firestore().collection("users")
            .where("zone", "==", regionZone)
            .limit(500)
            .get();
          usersInZone.forEach(doc => {
            if (doc.id !== ownerId) nearbyUserIds.push(doc.id);
          });
          console.log(`SOS: Found ${nearbyUserIds.length} users in zone "${regionZone}"`);
        }
      }

      if (nearbyUserIds.length === 0) {
        console.log("SOS: No users to notify");
        return;
      }

      // 3. Send HIGH PRIORITY notifications
      const promises = nearbyUserIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: {
            title: "🆘 SOS SMARRIMENTO!",
            body: `${petName} si è smarrito vicino a te! Aiutaci a cercarlo.`,
          },
          data: {
            type: "sos_alert",
            alertId: String(alertId),
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          // Android: HIGH PRIORITY to wake the device
          android: {
            priority: "high",
            notification: {
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default",
              channelId: "high_importance_channel",
              priority: "max",
              defaultVibrateTimings: true,
              defaultSound: true,
            },
            // Time-to-live: 4 hours (SOS is time-sensitive)
            ttl: 14400000,
          },
          // iOS: HIGH PRIORITY APNs headers
          apns: {
            headers: {
              "apns-priority": "10",           // Immediate delivery
              "apns-push-type": "alert",       // Alert type (not background)
            },
            payload: {
              aps: {
                badge: 1,
                sound: "default",
                "content-available": 1,         // Wake the app
                "mutable-content": 1,           // Allow notification extension
                category: "SOS_ALERT",
              }
            }
          },
          // Web: HIGH PRIORITY (FCM v1)
          webpush: {
            headers: {
              Urgency: "high"
            }
          }
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);
      return snapshot.ref.update({ notificationSent: true, notifiedCount: nearbyUserIds.length });

    } catch (e) {
      console.error("Error in SOS:", e);
    }
  });

/**
 * Trigger: On Create Safety Alert (Danger)
 * Broadcasts to all users within 2km radius of the danger location.
 * Falls back to zone-based matching if no nearby GPS users found.
 */
exports.sendSafetyAlertNotification = functions.firestore
  .document("safety_alerts/{alertId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const alertId = context.params.alertId;
    const authorId = data.authorId;
    const alertLat = data.latitude;
    const alertLng = data.longitude;

    const SAFETY_RADIUS_KM = 2.0; // 2km radius for danger alerts

    let title = "⚠️ Pericolo Segnalato";
    const type = data.type || "other";

    switch (type) {
      case "poison": title = "☠️ Allerta Bocconi Avvelenati!"; break;
      case "glass": title = "⚠️ Attenzione: Vetri/Pericoli"; break;
      case "aggression": title = "🐕 Segnalazione Cane Aggressivo"; break;
      case "police": title = "👮 Controlli in corso"; break;
      default: title = "⚠️ Nuova segnalazione pericolo"; break;
    }

    try {
      // 1. Find users by GPS proximity
      let nearbyUserIds = [];

      if (alertLat && alertLng) {
        nearbyUserIds = await findUsersNearLocation(alertLat, alertLng, SAFETY_RADIUS_KM, authorId);
        console.log(`Safety: Found ${nearbyUserIds.length} users within ${SAFETY_RADIUS_KM}km via GPS`);
      }

      // 2. Fallback to zone
      if (nearbyUserIds.length === 0) {
        console.log("Safety: No GPS matches, falling back to zone-based matching");
        const authorDoc = await admin.firestore().collection("users").doc(authorId).get();
        if (!authorDoc.exists) return;
        const regionZone = authorDoc.data().zone;

        if (regionZone) {
          const usersInZone = await admin.firestore().collection("users")
            .where("zone", "==", regionZone)
            .limit(500)
            .get();
          usersInZone.forEach(doc => {
            if (doc.id !== authorId) nearbyUserIds.push(doc.id);
          });
          console.log(`Safety: Found ${nearbyUserIds.length} users in zone "${regionZone}"`);
        }
      }

      if (nearbyUserIds.length === 0) return;

      // 3. Send notifications
      const promises = nearbyUserIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: {
            title: title,
            body: `Pericolo segnalato vicino a te! Presta attenzione.`,
          },
          data: {
            type: "safety_alert",
            alertId: String(alertId),
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          android: {
            notification: {
              clickAction: "FLUTTER_NOTIFICATION_CLICK",
              sound: "default"
            }
          },
          apns: {
            payload: {
              aps: { badge: 1, sound: "default" }
            }
          }
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);

    } catch (e) {
      console.error("Safety Alert Error:", e);
    }
  });

// ============================
// COMMENT / INTERACTION NOTIFICATIONS
// ============================

/**
 * Trigger: On Update Announcement (New Comment/Response)
 * Sends a notification to the announcement author when someone comments or reacts.
 */
exports.sendAnnouncementCommentNotification = functions.firestore
  .document("announcements/{announcementId}")
  .onUpdate(async (change, context) => {
    try {
      const newData = change.after.data();
      const oldData = change.before.data();

      const newResponses = newData.responses || [];
      const oldResponses = oldData.responses || [];

      // Only trigger if responses array grew
      if (newResponses.length <= oldResponses.length) return;

      const authorId = newData.userId;
      if (!authorId) return;

      // Get the latest response (last element of array)
      const latestResponse = newResponses[newResponses.length - 1];
      if (!latestResponse) return;

      // Don't notify if the author commented on their own announcement
      if (latestResponse.userId === authorId) return;

      const responderName = latestResponse.userName || 'Qualcuno';
      const responseType = latestResponse.type || 'message';

      let title, body;
      if (responseType === 'message') {
        title = '💬 Nuovo commento';
        body = `${responderName} ha commentato il tuo annuncio`;
      } else if (responseType === 'watching') {
        title = '🐾 Nuova zampata';
        body = `${responderName} tiene d'occhio il tuo annuncio`;
      } else {
        title = '📣 Nuova interazione';
        body = `${responderName} ha interagito con il tuo annuncio`;
      }

      // Get author's FCM tokens
      const authorDoc = await admin.firestore().collection('users').doc(authorId).get();
      if (!authorDoc.exists) return;

      const tokens = authorDoc.data().fcmTokens || [];
      if (tokens.length === 0) return;

      const messagePayload = {
        tokens: tokens,
        notification: { title, body },
        data: {
          type: 'announcement_comment',
          announcementId: context.params.announcementId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        apns: {
          payload: {
            aps: { badge: 1, sound: 'default' }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      await cleanupTokens(response, tokens, authorId);

      // Save in-app notification
      await saveInAppNotification(authorId, {
        type: responseType === 'message' ? 'announcement_comment' : 'announcement_watching',
        title,
        body,
        data: { announcementId: context.params.announcementId, responderId: latestResponse.userId },
      });

      console.log(`Announcement comment notification sent to ${authorId} from ${latestResponse.userId}`);

    } catch (e) {
      console.error("Announcement Comment Notification Error:", e);
    }
  });

/**
 * Trigger: On Create Social Post Comment
 * Sends a notification to the post author when someone comments.
 */
exports.sendSocialPostCommentNotification = functions.firestore
  .document("social_posts/{postId}/comments/{commentId}")
  .onCreate(async (snapshot, context) => {
    try {
      const commentData = snapshot.data();
      const postId = context.params.postId;

      // Get the parent post to find the author
      const postDoc = await admin.firestore().collection('social_posts').doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const authorId = postData.authorId;
      if (!authorId) return;

      // Don't notify if commenting on own post
      const commenterId = commentData.authorId;
      if (commenterId === authorId) return;

      const commenterName = commentData.authorName || 'Qualcuno';

      // Get author's FCM tokens
      const authorDoc = await admin.firestore().collection('users').doc(authorId).get();
      if (!authorDoc.exists) return;

      const tokens = authorDoc.data().fcmTokens || [];
      if (tokens.length === 0) return;

      const messagePayload = {
        tokens: tokens,
        notification: {
          title: '💬 Nuovo commento',
          body: `${commenterName} ha commentato il tuo post`,
        },
        data: {
          type: 'social_comment',
          postId: postId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        apns: {
          payload: {
            aps: { badge: 1, sound: 'default' }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      await cleanupTokens(response, tokens, authorId);

      // Save in-app notification
      await saveInAppNotification(authorId, {
        type: 'social_comment',
        title: '💬 Nuovo commento',
        body: `${commenterName} ha commentato il tuo post`,
        data: { postId },
      });

      console.log(`Social comment notification sent to ${authorId} from ${commenterId}`);

    } catch (e) {
      console.error("Social Comment Notification Error:", e);
    }
  });

/**
 * Trigger: On Update Social Post (New Like)
 * Sends a notification to the post author when someone likes their post.
 */
exports.sendSocialPostLikeNotification = functions.firestore
  .document("social_posts/{postId}")
  .onUpdate(async (change, context) => {
    try {
      const newData = change.after.data();
      const oldData = change.before.data();

      const newLikes = newData.likes || [];
      const oldLikes = oldData.likes || [];

      // Only trigger when likes array grows (not on unlike)
      if (newLikes.length <= oldLikes.length) return;

      const authorId = newData.authorId;
      if (!authorId) return;

      // Find the new liker
      const newLikerId = newLikes.find(uid => !oldLikes.includes(uid));
      if (!newLikerId) return;

      // Don't notify if liking own post
      if (newLikerId === authorId) return;

      // Get liker's name
      const likerDoc = await admin.firestore().collection('users').doc(newLikerId).get();
      const likerName = likerDoc.exists
        ? `${likerDoc.data().firstName || ''} ${likerDoc.data().lastName || ''}`.trim() || 'Qualcuno'
        : 'Qualcuno';

      // Get author's FCM tokens
      const authorDoc = await admin.firestore().collection('users').doc(authorId).get();
      if (!authorDoc.exists) return;

      const tokens = authorDoc.data().fcmTokens || [];
      if (tokens.length === 0) return;

      const messagePayload = {
        tokens: tokens,
        notification: {
          title: '❤️ Nuovo mi piace',
          body: `A ${likerName} piace il tuo post`,
        },
        data: {
          type: 'social_like',
          postId: context.params.postId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        apns: {
          payload: {
            aps: { badge: 1, sound: 'default' }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      await cleanupTokens(response, tokens, authorId);

      // Save in-app notification
      await saveInAppNotification(authorId, {
        type: 'social_like',
        title: '❤️ Nuovo mi piace',
        body: `A ${likerName} piace il tuo post`,
        data: { postId: context.params.postId },
      });

      console.log(`Social like notification sent to ${authorId} from ${newLikerId}`);

    } catch (e) {
      console.error("Social Like Notification Error:", e);
    }
  });

/**
 * Helper: Find users near a GPS location using the user_locations collection.
 * Uses Haversine formula to calculate real distance.
 * 
 * @param {number} lat - Alert latitude
 * @param {number} lng - Alert longitude
 * @param {number} radiusKm - Search radius in kilometers
 * @param {string} excludeUid - User ID to exclude (the alert author)
 * @returns {Promise<string[]>} Array of user IDs within radius
 */
async function findUsersNearLocation(lat, lng, radiusKm, excludeUid) {
  // GeoFlutterFire stores data as: { geo: { geopoint: GeoPoint, geohash: "..." }, uid: "..." }
  // We need to query a bounding box first, then filter by precise distance.

  // Calculate bounding box (rough filter)
  const latDelta = radiusKm / 111.0; // 1 degree latitude ≈ 111km
  const lngDelta = radiusKm / (111.0 * Math.cos(lat * Math.PI / 180));

  const minLat = lat - latDelta;
  const maxLat = lat + latDelta;
  // Note: Firestore can only do inequality on one field, so we filter lat in query
  // and lng in code (post-filter)

  try {
    // Query user_locations within latitude bounding box
    // Firestore stores geopoint inside nested map: geo.geopoint
    const snapshot = await admin.firestore().collection("user_locations")
      .limit(1000) // Safety limit
      .get();

    const nearbyIds = [];

    snapshot.forEach(doc => {
      if (doc.id === excludeUid) return;

      const data = doc.data();
      if (!data.geo || !data.geo.geopoint) return;

      const userLat = data.geo.geopoint.latitude || data.geo.geopoint._latitude;
      const userLng = data.geo.geopoint.longitude || data.geo.geopoint._longitude;

      if (!userLat || !userLng) return;

      // Quick bounding box check
      if (userLat < minLat || userLat > maxLat) return;
      const minLng = lng - lngDelta;
      const maxLng = lng + lngDelta;
      if (userLng < minLng || userLng > maxLng) return;

      // Precise Haversine distance
      const distance = haversineDistance(lat, lng, userLat, userLng);
      if (distance <= radiusKm) {
        nearbyIds.push(doc.id);
      }
    });

    return nearbyIds;
  } catch (e) {
    console.error("Error finding nearby users:", e);
    return [];
  }
}

/**
 * Haversine formula to calculate distance between two GPS coordinates.
 * @returns {number} Distance in kilometers
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Trigger: On Create Announcement
 * Sends push notification to nearby users (10km radius) when a new announcement is posted.
 * Skips 'lost' category since SOS has its own notification function.
 */
exports.sendAnnouncementNotification = functions.firestore
  .document("announcements/{id}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const announcementId = context.params.id;
    const authorId = data.userId;
    const category = data.category || "news";

    // Skip 'lost' category — SOS has its own notification
    if (category === "lost") {
      console.log("Announcement: Skipping 'lost' category (handled by SOS)");
      return null;
    }

    const ANNOUNCEMENT_RADIUS_KM = 10.0;

    // Extract location from the announcement
    const location = data.location || {};
    const geopoint = location.geopoint;
    let announcementLat = null;
    let announcementLng = null;

    if (geopoint && geopoint._latitude !== undefined) {
      announcementLat = geopoint._latitude;
      announcementLng = geopoint._longitude;
    } else if (geopoint && geopoint.latitude !== undefined) {
      announcementLat = geopoint.latitude;
      announcementLng = geopoint.longitude;
    }

    // Category display names for notification
    const categoryLabels = {
      news: "📢 Novità",
      walk: "🚶 Passeggiata",
      training: "🎓 Addestramento",
      social: "🎉 Raduno",
      litter: "🐾 Cucciolata",
      advice: "💡 Consiglio",
      other: "📋 Annuncio",
    };

    const title = categoryLabels[category] || "📋 Nuovo Annuncio";
    const authorName = data.authorName || "Un utente";
    const body = data.message
      ? `${authorName}: ${data.message.substring(0, 100)}${data.message.length > 100 ? "..." : ""}`
      : `${authorName} ha pubblicato un nuovo annuncio`;

    try {
      let nearbyUserIds = [];

      // 1. Find users by GPS proximity
      if (announcementLat && announcementLng) {
        nearbyUserIds = await findUsersNearLocation(
          announcementLat, announcementLng, ANNOUNCEMENT_RADIUS_KM, authorId
        );
        console.log(`Announcement: Found ${nearbyUserIds.length} users within ${ANNOUNCEMENT_RADIUS_KM}km`);
      }

      // 2. Fallback to zone-based
      if (nearbyUserIds.length === 0 && data.zone) {
        console.log("Announcement: Falling back to zone-based matching");
        const usersInZone = await admin.firestore().collection("users")
          .where("zone", "==", data.zone)
          .limit(500)
          .get();
        usersInZone.forEach(doc => {
          if (doc.id !== authorId) nearbyUserIds.push(doc.id);
        });
        console.log(`Announcement: Found ${nearbyUserIds.length} users in zone "${data.zone}"`);
      }

      if (nearbyUserIds.length === 0) {
        console.log("Announcement: No users to notify");
        return null;
      }

      // 3. Send notifications
      const promises = nearbyUserIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: { title, body },
          data: {
            type: "announcement",
            announcementId: String(announcementId),
            category: category,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: { notification: { clickAction: "FLUTTER_NOTIFICATION_CLICK", sound: "default" } },
          apns: { payload: { aps: { badge: 1, sound: "default" } } },
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);
      console.log(`Announcement: Notified ${nearbyUserIds.length} users for "${category}" announcement`);
      return null;

    } catch (e) {
      console.error("Announcement notification error:", e);
      return null;
    }
  });

/**
 * Trigger: On Create Offer (Business Promotion)
 * Sends push notification to nearby users (10km radius) when a business publishes a new offer.
 * Looks up the business owner's location from user_locations collection.
 */
exports.sendOfferNotification = functions.firestore
  .document("offers/{offerId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const offerId = context.params.offerId;
    const businessUserId = data.userId;
    const offerTitle = data.title || "Nuova Offerta";
    const partnerName = data.partnerName || "Un'attività";
    const discount = data.discountPercentage;

    const OFFER_RADIUS_KM = 10.0;

    try {
      // 1. Get business owner's location from user_locations
      let businessLat = null;
      let businessLng = null;

      const locationDoc = await admin.firestore()
        .collection("user_locations")
        .doc(businessUserId)
        .get();

      if (locationDoc.exists) {
        const locData = locationDoc.data();
        const position = locData.position || {};
        const geopoint = position.geopoint;
        if (geopoint) {
          businessLat = geopoint._latitude || geopoint.latitude;
          businessLng = geopoint._longitude || geopoint.longitude;
        }
      }

      // 2. Find nearby users
      let nearbyUserIds = [];

      if (businessLat && businessLng) {
        nearbyUserIds = await findUsersNearLocation(
          businessLat, businessLng, OFFER_RADIUS_KM, businessUserId
        );
        console.log(`Offer: Found ${nearbyUserIds.length} users within ${OFFER_RADIUS_KM}km`);
      }

      // 3. Fallback to zone-based
      if (nearbyUserIds.length === 0) {
        console.log("Offer: No GPS location or no nearby users, falling back to zone");
        const businessUserDoc = await admin.firestore().collection("users").doc(businessUserId).get();
        if (businessUserDoc.exists) {
          const zone = businessUserDoc.data().zone;
          if (zone) {
            const usersInZone = await admin.firestore().collection("users")
              .where("zone", "==", zone)
              .limit(500)
              .get();
            usersInZone.forEach(doc => {
              if (doc.id !== businessUserId) nearbyUserIds.push(doc.id);
            });
            console.log(`Offer: Found ${nearbyUserIds.length} users in zone "${zone}"`);
          }
        }
      }

      if (nearbyUserIds.length === 0) {
        console.log("Offer: No users to notify");
        return null;
      }

      // 4. Build notification
      const title = discount
        ? `🏷️ -${Math.round(discount)}% da ${partnerName}!`
        : `🏷️ Nuova offerta da ${partnerName}!`;
      const body = offerTitle;

      // 5. Send notifications
      const promises = nearbyUserIds.map(async (recipientId) => {
        const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
        if (!userDoc.exists) return;

        const tokens = userDoc.data().fcmTokens || [];
        if (tokens.length === 0) return;

        const messagePayload = {
          tokens: tokens,
          notification: { title, body },
          data: {
            type: "offer",
            offerId: String(offerId),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: { notification: { clickAction: "FLUTTER_NOTIFICATION_CLICK", sound: "default" } },
          apns: { payload: { aps: { badge: 1, sound: "default" } } },
        };

        const response = await admin.messaging().sendEachForMulticast(messagePayload);
        await cleanupTokens(response, tokens, recipientId);
      });

      await Promise.all(promises);
      console.log(`Offer: Notified ${nearbyUserIds.length} users for offer "${offerTitle}"`);

      // 6. Update offer with notification status
      return snapshot.ref.update({
        notificationSent: true,
        notifiedCount: nearbyUserIds.length,
      });

    } catch (e) {
      console.error("Offer notification error:", e);
      return null;
    }
  });

/**
 * Helper: Remove invalid tokens
 * Updated for FCM HTTP v1 (sendEachForMulticast) response format
 */
async function cleanupTokens(response, tokens, userId) {
  // sendEachForMulticast returns { responses: [ { success, error? } ], successCount, failureCount }
  if (response.failureCount === 0) return;

  const tokensToRemove = [];
  response.responses.forEach((result, index) => {
    if (!result.success) {
      const error = result.error;
      console.error('Failure sending notification to', tokens[index], error);

      // Check for invalid token error codes in V1
      if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
        tokensToRemove.push(tokens[index]);
      }
    }
  });

  if (tokensToRemove.length > 0) {
    await admin.firestore().collection("users").doc(userId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
    });
    console.log('Removed invalid tokens for user', userId, tokensToRemove);
  }
}

// ============================
// GOOGLE PLACES PROXY
// ============================

/**
 * Callable Function: nearbyPetBusinesses
 * Proxies Google Places Nearby Search API requests server-side
 * so the API key doesn't need IP/bundle restrictions removed.
 * 
 * Data: { latitude: number, longitude: number, radiusInMeters?: number }
 * Returns: { results: [ { placeId, name, address, lat, lng, types, rating, userRatingsTotal, openNow, category } ] }
 */
exports.nearbyPetBusinesses = functions.https.onCall(async (data, context) => {
  const latitude = data.latitude;
  const longitude = data.longitude;
  const radiusInMeters = data.radiusInMeters || 5000;

  if (!latitude || !longitude) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'latitude and longitude are required.'
    );
  }

  const db = admin.firestore();
  const cacheKey = `${Number(latitude).toFixed(2)}_${Number(longitude).toFixed(2)}`;
  const cacheDocRef = db.collection('places_cache').doc(cacheKey);

  try {
    const cacheDoc = await cacheDocRef.get();
    if (cacheDoc.exists) {
      const cacheData = cacheDoc.data();
      const createdAt = cacheData.createdAt ? cacheData.createdAt.toDate().getTime() : 0;
      const ageInHours = (Date.now() - createdAt) / (1000 * 60 * 60);
      if (ageInHours < 24) {
        console.log(`Cache HIT for key ${cacheKey} (age: ${ageInHours.toFixed(1)}h)`);
        return { results: cacheData.results || [] };
      }
      console.log(`Cache EXPIRED for key ${cacheKey} (age: ${ageInHours.toFixed(1)}h)`);
    } else {
      console.log(`Cache MISS for key ${cacheKey}`);
    }
  } catch (err) {
    console.error(`Error reading cache for key ${cacheKey}:`, err);
  }

  // API Key stored server-side (same key, but no IP restrictions on server)
  const API_KEY = 'AIzaSyArI5lyZaLUWv84JeMkXRIQB2JIdtjD-Ew';

  const allResults = [];
  const seenPlaceIds = new Set();

  // Helper: perform a single Google Places Nearby Search
  async function nearbySearch(params) {
    const query = new URLSearchParams({
      location: `${latitude},${longitude}`,
      radius: String(radiusInMeters),
      key: API_KEY,
      language: 'it',
      ...params,
    });

    const url = `https://maps.googleapis.com/maps/api/place/nearbysearch/json?${query}`;

    try {
      const response = await fetch(url);
      const body = await response.json();

      if (body.status === 'OK') {
        return body.results || [];
      } else if (body.status === 'ZERO_RESULTS') {
        return [];
      }
      console.warn('Places API status:', body.status, body.error_message || '');
      return [];
    } catch (e) {
      console.error('Places API fetch error:', e);
      return [];
    }
  }

  // Helper: map keyword to category
  function categoryFromKeyword(keyword) {
    if (keyword.includes('toelettatura')) return 'groomer';
    if (keyword.includes('pensione')) return 'petHotel';
    if (keyword.includes('educatore')) return 'dogTrainer';
    if (keyword.includes('area cani') || keyword.includes('sgambamento')) return 'dogPark';
    if (keyword.includes('spiaggia') || keyword.includes('dog beach')) return 'petFriendlyBeach';
    if (keyword.includes('stabilimento balneare') || keyword.includes('bagno cani')) return 'petFriendlyBathhouse';
    return 'other';
  }

  // Helper: map Google types to category
  function categoryFromTypes(types) {
    if (types.includes('veterinary_care')) return 'vetClinic';
    if (types.includes('pet_store')) return 'petShop';
    if (types.includes('pharmacy')) return 'petPharmacy';
    if (types.includes('cafe') || types.includes('restaurant')) return 'petFriendlyCafe';
    return 'other';
  }

  // Helper: normalize a Google Places result
  function normalize(place, categoryOverride) {
    const loc = (place.geometry && place.geometry.location) || {};
    const types = place.types || [];
    return {
      placeId: place.place_id,
      name: place.name || 'Sconosciuto',
      address: place.vicinity || '',
      lat: loc.lat || 0,
      lng: loc.lng || 0,
      types: types,
      rating: place.rating || null,
      userRatingsTotal: place.user_ratings_total || null,
      openNow: place.opening_hours ? (place.opening_hours.open_now ? 'Aperto' : 'Chiuso') : null,
      category: categoryOverride || categoryFromTypes(types),
    };
  }

  // 1. Search by types
  const typeSearches = ['veterinary_care', 'pet_store'];
  for (const type of typeSearches) {
    const results = await nearbySearch({ type });
    for (const place of results) {
      if (!seenPlaceIds.has(place.place_id)) {
        seenPlaceIds.add(place.place_id);
        allResults.push(normalize(place));
      }
    }
  }

  // 2. Search by keywords
  const keywordSearches = [
    { keyword: 'toelettatura cani' },
    { keyword: 'pensione animali' },
    { keyword: 'educatore cinofilo' },
    { keyword: 'area cani' },
    { keyword: 'sgambamento cani' },
    { keyword: 'spiaggia cani' },
    { keyword: 'dog beach' },
    { keyword: 'stabilimento balneare cani' },
  ];
  for (const { keyword } of keywordSearches) {
    const results = await nearbySearch({ keyword });
    for (const place of results) {
      if (!seenPlaceIds.has(place.place_id)) {
        seenPlaceIds.add(place.place_id);
        allResults.push(normalize(place, categoryFromKeyword(keyword)));
      }
    }
  }

  console.log(`Found ${allResults.length} pet businesses near ${latitude},${longitude}`);

  try {
    await cacheDocRef.set({
      results: allResults,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`Cache saved for key ${cacheKey}`);
  } catch (err) {
    console.error(`Error writing cache for key ${cacheKey}:`, err);
  }

  return { results: allResults };
});

/**
 * Callable Function: placeDetails
 * Proxies Google Places Details API requests server-side.
 * 
 * Data: { placeId: string }
 * Returns: { phone, website, address, url, openingHours }
 */
exports.placeDetails = functions.https.onCall(async (data, context) => {
  const placeId = data.placeId;

  if (!placeId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'placeId is required.'
    );
  }

  const API_KEY = 'AIzaSyArI5lyZaLUWv84JeMkXRIQB2JIdtjD-Ew';

  const query = new URLSearchParams({
    place_id: placeId,
    key: API_KEY,
    language: 'it',
    fields: 'formatted_phone_number,website,opening_hours,formatted_address,url',
  });

  const url = `https://maps.googleapis.com/maps/api/place/details/json?${query}`;

  try {
    const response = await fetch(url);
    const body = await response.json();

    if (body.status === 'OK' && body.result) {
      const r = body.result;
      // Transform opening_hours into a simple map
      let openingHours = null;
      if (r.opening_hours && r.opening_hours.weekday_text) {
        openingHours = {};
        for (const line of r.opening_hours.weekday_text) {
          const parts = line.split(': ');
          if (parts.length === 2) {
            openingHours[parts[0]] = parts[1];
          }
        }
      }

      return {
        phone: r.formatted_phone_number || null,
        website: r.website || null,
        address: r.formatted_address || null,
        url: r.url || null,
        openingHours: openingHours,
      };
    }

    console.warn('Places Details API status:', body.status);
    return null;
  } catch (e) {
    console.error('Places Details API error:', e);
    throw new functions.https.HttpsError('internal', 'Failed to fetch place details');
  }
});

// ── Admin Notifications ──────────────────────────────────────────────
// Admin emails that receive push notifications for business events
const ADMIN_EMAILS = ['f.gabelli@gmail.com'];

/**
 * Helper: send push notification to all admin users
 */
async function notifyAdmins(title, body, data = {}) {
  const db = admin.firestore();
  
  for (const email of ADMIN_EMAILS) {
    try {
      const usersSnapshot = await db.collection('users')
          .where('email', '==', email)
          .limit(1)
          .get();

      if (usersSnapshot.empty) {
        console.warn(`Admin user not found: ${email}`);
        continue;
      }

      const adminUser = usersSnapshot.docs[0].data();
      const tokens = adminUser.fcmTokens || [];

      if (tokens.length === 0) {
        console.warn(`No FCM tokens for admin: ${email}`);
        continue;
      }

      const message = {
        tokens: tokens,
        notification: { title, body },
        data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
        apns: {
          payload: {
            aps: {
              alert: { title, body },
              sound: 'default',
              badge: 1,
            },
          },
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'admin_alerts',
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Admin notification sent to ${email}: ${response.successCount} success, ${response.failureCount} failed`);

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && (
            resp.error?.code === 'messaging/invalid-registration-token' ||
            resp.error?.code === 'messaging/registration-token-not-registered'
          )) {
            invalidTokens.push(tokens[idx]);
          }
        });
        if (invalidTokens.length > 0) {
          await usersSnapshot.docs[0].ref.update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          });
        }
      }
    } catch (err) {
      console.error(`Error notifying admin ${email}:`, err);
    }
  }
}

/**
 * Trigger: New ad inquiry submitted from landing page
 */
exports.notifyAdminNewAdInquiry = functions.firestore
    .document('ad_inquiries/{inquiryId}')
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const businessName = data.businessName || 'Sconosciuta';
      const contactName = data.contactName || '';
      const city = data.city || '';
      const businessType = data.businessType || '';

      await notifyAdmins(
        '📢 Nuova richiesta pubblicitaria',
        `${businessName} (${businessType}) — ${contactName}, ${city}`,
        {
          type: 'ad_inquiry',
          inquiryId: context.params.inquiryId,
        }
      );
    });

/**
 * Trigger: New business claim request submitted
 */
exports.notifyAdminNewBusinessClaim = functions.firestore
    .document('business_claims/{claimId}')
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const businessName = data.businessName || 'Sconosciuta';
      const ownerName = data.ownerName || '';
      const role = data.role || '';

      await notifyAdmins(
        '🏪 Nuova richiesta riscatto attività',
        `${businessName} — ${ownerName} (${role})`,
        {
          type: 'business_claim',
          claimId: context.params.claimId,
          businessId: data.businessId || '',
        }
      );
    });

// ============================
// SCHEDULED: SOS EXPIRATION (72 hours)
// ============================

/**
 * Scheduled Function: Expire SOS Alerts after 72 hours
 * Runs every hour. Finds all active SOS alerts older than 72 hours,
 * deactivates them, deletes the linked announcement, and notifies the owner.
 */
exports.expireSOSAlerts = functions.pubsub
  .schedule("every 1 hours")
  .timeZone("Europe/Rome")
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const cutoffMs = now.toMillis() - (72 * 60 * 60 * 1000); // 72 hours ago
    const cutoffTimestamp = admin.firestore.Timestamp.fromMillis(cutoffMs);

    try {
      // Find all active SOS alerts older than 72 hours
      const expiredAlerts = await db.collection("lost_pet_alerts")
        .where("isActive", "==", true)
        .where("createdAt", "<=", cutoffTimestamp)
        .get();

      if (expiredAlerts.empty) {
        console.log("SOS Expiration: No expired alerts found.");
        return null;
      }

      console.log(`SOS Expiration: Found ${expiredAlerts.size} alerts to expire.`);

      const batch = db.batch();
      const ownerNotifications = [];

      for (const doc of expiredAlerts.docs) {
        const alertData = doc.data();

        // 1. Deactivate the SOS alert
        batch.update(doc.ref, {
          isActive: false,
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          expiredReason: "auto_72h",
        });

        // 2. Delete the linked announcement if exists
        if (alertData.announcementId) {
          const announcementRef = db.collection("announcements").doc(alertData.announcementId);
          batch.delete(announcementRef);
          console.log(`SOS Expiration: Deleting linked announcement ${alertData.announcementId}`);
        }

        // 3. Queue owner notification
        if (alertData.ownerId) {
          // Get pet name for personalized notification
          let petName = "Il tuo animale";
          if (alertData.petId) {
            try {
              const petDoc = await db.collection("dogs").doc(alertData.petId).get();
              if (petDoc.exists) {
                petName = petDoc.data().name || petName;
              }
            } catch (_) {}
          }

          ownerNotifications.push({
            ownerId: alertData.ownerId,
            petName: petName,
            alertId: doc.id,
          });
        }
      }

      // Execute batch
      await batch.commit();
      console.log(`SOS Expiration: ${expiredAlerts.size} alerts expired successfully.`);

      // Send notifications to owners
      for (const notif of ownerNotifications) {
        await saveInAppNotification(notif.ownerId, {
          type: "sos_expired",
          title: "⏰ SOS Scaduto",
          body: `L'allarme SOS per ${notif.petName} è scaduto dopo 72 ore. Puoi lanciarne uno nuovo dalla pagina dei tuoi pet.`,
          data: { alertId: notif.alertId },
        });
      }

      return null;
    } catch (e) {
      console.error("SOS Expiration Error:", e);
      return null;
    }
  });

/**
 * Cloud Function: exportUserData (GDPR DSAR Art. 20)
 * HTTPS callable function to export all data associated with a user.
 */
exports.exportUserData = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    // 1. Authenticate caller
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utente deve essere autenticato."
      );
    }

    const callerUid = context.auth.uid;
    let targetUid = callerUid;

    // 2. Check if admin requests other user's data
    if (data && data.userId && data.userId !== callerUid) {
      const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
      const callerData = callerDoc.exists ? callerDoc.data() : {};
      const isAdmin = callerData.isAdmin === true || ADMIN_EMAILS.includes(callerDoc.data().email || "");
      
      if (!isAdmin) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Solo gli amministratori possono esportare i dati di altri utenti."
        );
      }
      targetUid = data.userId;
    }

    console.log(`Starting data export (GDPR) for target user: ${targetUid}`);
    const db = admin.firestore();

    try {
      // 3. Log the DSAR request in dsar_requests collection (Audit Trail)
      await db.collection("dsar_requests").add({
        requestedBy: callerUid,
        targetUser: targetUid,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: "completed",
      });

      // 4. Gather data in parallel
      const profilePromise = db.collection("users").doc(targetUid).get();
      const petsPromise = db.collection("dogs").where("ownerId", "==", targetUid).get();
      const postsPromise = db.collection("social_posts").where("authorId", "==", targetUid).get();
      const reelsPromise = db.collection("reels").where("authorId", "==", targetUid).get();
      
      // Collection group query for comments written by the target user
      const commentsPromise = db.collectionGroup("comments").where("authorId", "==", targetUid).get();
      
      // Swipes: sent by target user
      const swipesPromise = db.collection("pet_swipes").where("senderUid", "==", targetUid).get();
      
      // Matches: target user is involved
      const matchesPromise = db.collection("pet_matches").where("uids", "array-contains", targetUid).get();
      
      // Walks: completed walks by target user
      const walksPromise = db.collection("completed_walks").where("userId", "==", targetUid).get();

      // Resolve base promises
      const [
        profileSnap,
        petsSnap,
        postsSnap,
        reelsSnap,
        commentsSnap,
        swipesSnap,
        matchesSnap,
        walksSnap,
      ] = await Promise.all([
        profilePromise,
        petsPromise,
        postsPromise,
        reelsPromise,
        commentsPromise,
        swipesPromise,
        matchesPromise,
        walksPromise,
      ]);

      if (!profileSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Profilo utente target non trovato."
        );
      }

      const profileData = profileSnap.data();

      // 5. Gather medical records (health_records) for each pet
      const petIds = petsSnap.docs.map(doc => doc.id);
      let medicalRecords = [];

      if (petIds.length > 0) {
        // Query health_records in batches or loop (usually few pets, so simple loop is fine)
        const healthRecordsPromises = petIds.map(petId => 
          db.collection("health_records").where("petId", "==", petId).get()
        );
        const healthRecordsSnaps = await Promise.all(healthRecordsPromises);
        
        healthRecordsSnaps.forEach(snap => {
          snap.forEach(doc => {
            medicalRecords.push({ id: doc.id, ...doc.data() });
          });
        });
      }

      // 6. Gather business profile if applicable
      let businessProfile = null;
      if (profileData.claimedBusinessId) {
        const busDoc = await db.collection("pet_businesses").doc(profileData.claimedBusinessId).get();
        if (busDoc.exists) {
          businessProfile = { id: busDoc.id, ...busDoc.data() };
        }
      }

      // 7. Gather chat messages
      // First find all chats where the user is a participant
      const chatsSnap = await db.collection("chats")
        .where("participants", "array-contains", targetUid)
        .get();

      const chatMessages = [];
      
      if (!chatsSnap.empty) {
        const messagePromises = chatsSnap.docs.map(async (chatDoc) => {
          const chatId = chatDoc.id;
          const messagesSnap = await db.collection("chats")
            .doc(chatId)
            .collection("messages")
            .get();
            
          messagesSnap.forEach(msgDoc => {
            const msgData = msgDoc.data();
            // GDPR Requirement: if targetUid is the sender, export full message.
            // If someone else, include only metadata/timestamp/senderId (privacy of others)
            if (msgData.senderId === targetUid) {
              chatMessages.push({
                chatId: chatId,
                messageId: msgDoc.id,
                ...msgData,
              });
            } else {
              chatMessages.push({
                chatId: chatId,
                messageId: msgDoc.id,
                senderId: msgData.senderId,
                createdAt: msgData.createdAt,
                type: msgData.type || "text",
                info: "[Testo e media esclusi per tutela privacy dell'altro utente]",
              });
            }
          });
        });
        
        await Promise.all(messagePromises);
      }

      // 8. Construct final structured export object
      const exportData = {
        profile: {
          id: targetUid,
          ...profileData,
        },
        pets: petsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        social_posts: postsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        reels: reelsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        comments: commentsSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        follow_relationships: {
          following: profileData.following || [],
          followers: profileData.followers || [],
        },
        swipes: swipesSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        matches: matchesSnap.docs.map(doc => {
          const matchVal = doc.data();
          return {
            id: doc.id,
            createdAt: matchVal.createdAt,
            petIds: matchVal.petIds,
            // Only expose uids, other users details are kept private
            uids: matchVal.uids,
          };
        }),
        chat_messages: chatMessages,
        walks: walksSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })),
        medical_records: medicalRecords,
        business_profile: businessProfile,
      };

      console.log(`GDPR export successfully completed for target user: ${targetUid}`);
      return exportData;

    } catch (error) {
      console.error(`Error exporting user data for ${targetUid}:`, error);
      throw new functions.https.HttpsError(
        "internal",
        `Errore durante l'esportazione dei dati: ${error.message}`
      );
    }
  });

// ── Trigger: On User Auth Delete ──
// Rimuove in modo automatico e sicuro tutti i dati associati all'utente
exports.cleanupUserDataOnAuthDelete = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const db = admin.firestore();
  console.log(`[cleanupUserDataOnAuthDelete] Starting cleanup for user: ${uid}`);

  const batch = db.batch();

  // 1. Delete dogs
  const dogsSnap = await db.collection("dogs").where("ownerId", "==", uid).get();
  dogsSnap.forEach((doc) => {
    batch.delete(doc.ref);
  });

  // 2. Delete social_posts
  const postsSnap = await db.collection("social_posts").where("authorId", "==", uid).get();
  postsSnap.forEach((doc) => {
    batch.delete(doc.ref);
  });

  // 3. Delete reels
  const reelsSnap = await db.collection("reels").where("authorId", "==", uid).get();
  reelsSnap.forEach((doc) => {
    batch.delete(doc.ref);
  });

  // 4. Delete user_locations
  const locationRef = db.collection("user_locations").doc(uid);
  batch.delete(locationRef);

  // 5. Delete safety_alerts
  const alertsSnap = await db.collection("safety_alerts").where("authorId", "==", uid).get();
  alertsSnap.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log(`[cleanupUserDataOnAuthDelete] Cleanup successfully completed for user: ${uid}`);
});

/**
 * Cloud Function: adminContactUser
 * HTTPS callable function for an admin to start a chat and send a message to a user.
 */
exports.adminContactUser = functions
  .region("europe-west1")
  .https.onCall(async (data, context) => {
    // 1. Authenticate caller
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utente deve essere autenticato."
      );
    }

    const adminUid = context.auth.uid;
    const { targetUid, messageText } = data;

    if (!targetUid || !messageText) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Parametri mancanti: targetUid o messageText."
      );
    }

    const db = admin.firestore();

    // 2. Check if caller is admin
    const callerDoc = await db.collection("users").doc(adminUid).get();
    const callerData = callerDoc.exists ? callerDoc.data() : {};
    const isAdmin = callerData.isAdmin === true || ADMIN_EMAILS.includes(callerData.email || "");

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Solo gli amministratori possono contattare direttamente gli utenti."
      );
    }

    try {
      // 3. Ensure system user "DOGZN" exists in users collection
      const systemUid = "DOGZN";
      const systemUserRef = db.collection("users").doc(systemUid);
      const systemUserDoc = await systemUserRef.get();
      if (!systemUserDoc.exists) {
        await systemUserRef.set({
          firstName: "DOGZN",
          lastName: "",
          email: "support@dogzn.com",
          accountType: "system",
          isPremium: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // 4. Create or get chat document between "DOGZN" and target user
      const participants = [systemUid, targetUid].sort();
      const chatId = participants.join("_");

      const chatRef = db.collection("chats").doc(chatId);
      const chatDoc = await chatRef.get();

      const batch = db.batch();

      if (!chatDoc.exists) {
        batch.set(chatRef, {
          participants: participants,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "accepted",
          initiatorId: systemUid,
        });
      }

      // 5. Create message document
      const messageRef = chatRef.collection("messages").doc();
      const messageData = {
        id: messageRef.id,
        senderId: systemUid,
        text: messageText,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "text",
        isRead: false,
        reactions: {},
        isEdited: false,
        isDeleted: false,
        metadata: {},
      };

      batch.set(messageRef, messageData);

      // 6. Update lastMessage on chat document
      batch.update(chatRef, {
        lastMessage: messageData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return { success: true, chatId };
    } catch (error) {
      console.error("Error in adminContactUser:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Errore durante l'invio del messaggio: " + error.message
      );
    }
  });


// ── Admin Broadcast Message ──────────────────────────────────────────────
/**
 * Cloud Function: adminBroadcastMessage
 * Funzione HTTPS callable per inviare un messaggio broadcast personalizzato
 * a tutti gli utenti (o a un sottoinsieme filtrato).
 * Supporta tag dinamici come {{nome}}, {{cognome}}, {{nome_cane}}, ecc.
 * Crea chat individuali con l'utente di sistema DOGZN e invia notifiche push.
 */
exports.adminBroadcastMessage = functions
  .region("europe-west1")
  .runWith({ timeoutSeconds: 540 })
  .https.onCall(async (data, context) => {
    // 1. Verifica autenticazione
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utente deve essere autenticato."
      );
    }

    const adminUid = context.auth.uid;
    const { messageTemplate, targetFilter, targetUserIds } = data;

    // Validazione input
    if (!messageTemplate || typeof messageTemplate !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Parametro mancante o non valido: messageTemplate."
      );
    }

    const db = admin.firestore();

    // 2. Verifica che il chiamante sia un amministratore
    const callerDoc = await db.collection("users").doc(adminUid).get();
    const callerData = callerDoc.exists ? callerDoc.data() : {};
    const isAdmin =
      callerData.isAdmin === true ||
      ADMIN_EMAILS.includes(callerData.email || "");

    if (!isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Solo gli amministratori possono inviare messaggi broadcast."
      );
    }

    try {
      // 3. Assicurarsi che l'utente di sistema "DOGZN" esista
      const systemUid = "DOGZN";
      const systemUserRef = db.collection("users").doc(systemUid);
      const systemUserDoc = await systemUserRef.get();
      if (!systemUserDoc.exists) {
        await systemUserRef.set({
          firstName: "DOGZN",
          lastName: "",
          email: "support@dogzn.com",
          accountType: "system",
          isPremium: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log("Utente di sistema DOGZN creato.");
      }

      // 4. Query degli utenti target con filtri opzionali o lista esplicita
      let targetUsers = [];

      if (targetUserIds && Array.isArray(targetUserIds) && targetUserIds.length > 0) {
        // Modalità selezione manuale: carica utenti specifici per ID
        console.log(`Modalità selezione manuale: ${targetUserIds.length} utenti specificati`);
        const batchSize = 10; // Firestore getAll supporta max ~100 documenti alla volta
        for (let i = 0; i < targetUserIds.length; i += batchSize) {
          const chunk = targetUserIds.slice(i, i + batchSize);
          const refs = chunk.map((uid) => db.collection("users").doc(uid));
          const docs = await db.getAll(...refs);
          for (const doc of docs) {
            if (!doc.exists) continue;
            const userData = doc.data();
            if (
              doc.id !== systemUid &&
              userData.isBanned !== true &&
              userData.accountType !== "system"
            ) {
              targetUsers.push({ id: doc.id, ...userData });
            }
          }
        }
      } else {
        // Modalità filtri: query con filtri opzionali
        let usersQuery = db.collection("users");

        if (targetFilter) {
          if (targetFilter.city) {
            usersQuery = usersQuery.where("city", "==", targetFilter.city);
          }
          if (targetFilter.isPremium !== undefined && targetFilter.isPremium !== null) {
            usersQuery = usersQuery.where("isPremium", "==", targetFilter.isPremium);
          }
          if (targetFilter.accountType) {
            usersQuery = usersQuery.where("accountType", "==", targetFilter.accountType);
          }
          if (targetFilter.gender) {
            usersQuery = usersQuery.where("gender", "==", targetFilter.gender);
          }
        }

        const usersSnapshot = await usersQuery.get();
        console.log(`Utenti trovati dalla query: ${usersSnapshot.size}`);

        // Filtra utenti esclusi: DOGZN, bannati, account di sistema
        usersSnapshot.forEach((doc) => {
          const userData = doc.data();
          if (
            doc.id !== systemUid &&
            userData.isBanned !== true &&
            userData.accountType !== "system"
          ) {
            targetUsers.push({ id: doc.id, ...userData });
          }
        });
      }

      console.log(`Utenti target dopo filtri di esclusione: ${targetUsers.length}`);

      if (targetUsers.length === 0) {
        return {
          success: true,
          sentCount: 0,
          failedCount: 0,
          totalTargeted: 0,
        };
      }

      // 5. Per ogni utente, carica il primo pet e personalizza il messaggio
      let sentCount = 0;
      let failedCount = 0;
      const totalTargeted = targetUsers.length;

      // Gestione batch: max 500 operazioni per batch (3 op per utente ≈ 166 utenti)
      const MAX_OPS_PER_BATCH = 500;
      const USERS_PER_BATCH = Math.floor(MAX_OPS_PER_BATCH / 3); // ~166

      // Dividi gli utenti in gruppi per i batch
      const userChunks = [];
      for (let i = 0; i < targetUsers.length; i += USERS_PER_BATCH) {
        userChunks.push(targetUsers.slice(i, i + USERS_PER_BATCH));
      }

      console.log(`Numero di batch da processare: ${userChunks.length}`);

      for (let chunkIndex = 0; chunkIndex < userChunks.length; chunkIndex++) {
        const chunk = userChunks[chunkIndex];
        const batch = db.batch();
        const notificationsToSend = []; // Raccoglie le notifiche per questo chunk

        console.log(
          `Elaborazione batch ${chunkIndex + 1}/${userChunks.length} (${chunk.length} utenti)`
        );

        for (const user of chunk) {
          try {
            // 5a. Carica il primo pet dell'utente
            const petsSnapshot = await db
              .collection("dogs")
              .where("ownerId", "==", user.id)
              .orderBy("createdAt", "asc")
              .limit(1)
              .get();

            const pet =
              petsSnapshot.size > 0 ? petsSnapshot.docs[0].data() : {};

            // 6. Sostituzione dei tag nel template
            const personalizedMessage = replaceMessageTags(
              messageTemplate,
              user,
              pet
            );

            // 7. Crea chat + messaggio
            const participants = [systemUid, user.id].sort();
            const chatId = participants.join("_");

            const chatRef = db.collection("chats").doc(chatId);
            const messageRef = chatRef.collection("messages").doc();

            const messageData = {
              id: messageRef.id,
              senderId: systemUid,
              text: personalizedMessage,
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
              type: "text",
              isRead: false,
              reactions: {},
              isEdited: false,
              isDeleted: false,
              metadata: {},
            };

            // Set con merge per creare la chat se non esiste
            batch.set(
              chatRef,
              {
                participants: participants,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "accepted",
                initiatorId: systemUid,
              },
              { merge: true }
            );

            // Crea il messaggio nella sottocollezione
            batch.set(messageRef, messageData);

            // Aggiorna lastMessage sulla chat
            batch.update(chatRef, {
              lastMessage: messageData,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // 8. Prepara notifica push se l'utente ha token FCM
            if (user.fcmTokens && Array.isArray(user.fcmTokens) && user.fcmTokens.length > 0) {
              const truncatedBody =
                personalizedMessage.length > 200
                  ? personalizedMessage.substring(0, 200) + "..."
                  : personalizedMessage;

              notificationsToSend.push({
                userId: user.id,
                tokens: user.fcmTokens,
                notification: {
                  title: "DOGZN",
                  body: truncatedBody,
                },
                data: {
                  type: "chat_message",
                  chatId: chatId,
                },
              });
            }

            sentCount++;
          } catch (userError) {
            console.error(
              `Errore nell'elaborazione dell'utente ${user.id}:`,
              userError
            );
            failedCount++;
          }
        }

        // Commit del batch
        try {
          await batch.commit();
          console.log(`Batch ${chunkIndex + 1} committato con successo.`);
        } catch (batchError) {
          console.error(
            `Errore nel commit del batch ${chunkIndex + 1}:`,
            batchError
          );
          // I messaggi di questo batch sono falliti
          failedCount += chunk.length;
          sentCount -= chunk.length;
          continue; // Passa al prossimo batch
        }

        // Invio notifiche push per questo batch
        for (const notif of notificationsToSend) {
          try {
            const message = {
              tokens: notif.tokens,
              notification: notif.notification,
              data: {
                ...notif.data,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                    category: "FLUTTER_NOTIFICATION_CLICK",
                  },
                },
              },
              android: {
                priority: "high",
                notification: {
                  clickAction: "FLUTTER_NOTIFICATION_CLICK",
                  sound: "default",
                },
              },
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            if (response.failureCount > 0) {
              console.warn(
                `Notifica parzialmente fallita per utente ${notif.userId}: ` +
                  `${response.successCount} successi, ${response.failureCount} fallimenti`
              );

              // Pulizia token invalidi
              const invalidTokens = [];
              response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                  const errorCode = resp.error?.code;
                  // Token invalidi o non registrati
                  if (
                    errorCode === "messaging/invalid-registration-token" ||
                    errorCode === "messaging/registration-token-not-registered" ||
                    errorCode === "messaging/invalid-argument"
                  ) {
                    invalidTokens.push(notif.tokens[idx]);
                  }
                }
              });

              if (invalidTokens.length > 0) {
                try {
                  await db.collection("users").doc(notif.userId).update({
                    fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
                  });
                  console.log(
                    `Rimossi ${invalidTokens.length} token invalidi per utente ${notif.userId}`
                  );
                } catch (cleanupError) {
                  console.error(`Errore pulizia token per ${notif.userId}:`, cleanupError);
                }
              }
            }
          } catch (pushError) {
            console.error(
              `Errore invio push a utente ${notif.userId}:`,
              pushError
            );
            // Non incrementiamo failedCount perché il messaggio chat è stato inviato
          }
        }
      }

      console.log(
        `Broadcast completato: ${sentCount} inviati, ${failedCount} falliti, ${totalTargeted} target totali`
      );

      return {
        success: true,
        sentCount,
        failedCount,
        totalTargeted,
      };
    } catch (error) {
      console.error("Errore in adminBroadcastMessage:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Errore durante l'invio del messaggio broadcast: " + error.message
      );
    }
  });

/**
 * Helper: sostituisce i tag dinamici nel template del messaggio
 * con i dati dell'utente e del suo pet.
 *
 * @param {string} template - Il template del messaggio con tag come {{nome}}
 * @param {object} user - I dati dell'utente da Firestore
 * @param {object} pet - I dati del primo pet dell'utente
 * @returns {string} Il messaggio personalizzato
 */
function replaceMessageTags(template, user, pet) {
  const firstName = user.firstName || "";
  const lastName = user.lastName || "";
  const fullName = `${firstName} ${lastName}`.trim();

  // Determina il piano dell'utente
  let piano = "Free";
  if (user.accountType === "business" && user.isPremium) {
    piano = "Business Pro";
  } else if (user.isPremium) {
    piano = "Premium";
  }

  // Determina il tipo di account
  const tipoAccount =
    user.accountType === "business" ? "Business" : "Personale";

  // Determina il genere
  let genere = "Altro";
  if (user.gender === "male") {
    genere = "Uomo";
  } else if (user.gender === "female") {
    genere = "Donna";
  }

  // Determina la specie del pet
  const specie = pet.species === "cat" ? "Gatto" : "Cane";

  // Sostituzione di tutti i tag
  let result = template;
  result = result.replace(/\{\{nome\}\}/g, firstName);
  result = result.replace(/\{\{cognome\}\}/g, lastName);
  result = result.replace(/\{\{nome_completo\}\}/g, fullName);
  result = result.replace(/\{\{nome_cane\}\}/g, pet.name || "");
  result = result.replace(/\{\{razza_cane\}\}/g, pet.breed || "");
  result = result.replace(/\{\{specie\}\}/g, specie);
  result = result.replace(/\{\{città\}\}/g, user.city || "");
  result = result.replace(/\{\{zona\}\}/g, user.zone || "");
  result = result.replace(/\{\{piano\}\}/g, piano);
  result = result.replace(/\{\{tipo_account\}\}/g, tipoAccount);
  result = result.replace(/\{\{genere\}\}/g, genere);

  return result;
}


// =============================================================================
// Pulizia schedulata token FCM invalidi
// Esegue ogni notte alle 3:00 (Europe/Rome)
// =============================================================================

exports.cleanupInvalidFcmTokens = functions
  .region("europe-west1")
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .pubsub.schedule("0 3 * * *")
  .timeZone("Europe/Rome")
  .onRun(async (context) => {
    const db = admin.firestore();
    console.log("Inizio pulizia token FCM invalidi...");

    let totalUsersChecked = 0;
    let totalTokensRemoved = 0;
    let totalUsersCleanedUp = 0;

    try {
      // Prendi tutti gli utenti che hanno almeno un token FCM
      const usersSnapshot = await db.collection("users")
        .where("fcmTokens", "!=", [])
        .get();

      console.log(`Trovati ${usersSnapshot.size} utenti con token FCM`);

      // Processa in blocchi da 20 per non sovraccaricare FCM
      const users = usersSnapshot.docs;
      const chunkSize = 20;

      for (let i = 0; i < users.length; i += chunkSize) {
        const chunk = users.slice(i, i + chunkSize);

        const promises = chunk.map(async (userDoc) => {
          const userData = userDoc.data();
          const tokens = userData.fcmTokens || [];

          if (!Array.isArray(tokens) || tokens.length === 0) return;

          totalUsersChecked++;

          // Verifica ogni token inviando un messaggio dry-run
          const invalidTokens = [];
          for (const token of tokens) {
            try {
              await admin.messaging().send(
                {
                  token: token,
                  data: { ping: "true" },
                },
                true // dryRun = true, non invia realmente
              );
            } catch (error) {
              const errorCode = error.code;
              if (
                errorCode === "messaging/invalid-registration-token" ||
                errorCode === "messaging/registration-token-not-registered" ||
                errorCode === "messaging/invalid-argument"
              ) {
                invalidTokens.push(token);
              }
            }
          }

          // Rimuovi token invalidi
          if (invalidTokens.length > 0) {
            try {
              await db.collection("users").doc(userDoc.id).update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
              });
              totalTokensRemoved += invalidTokens.length;
              totalUsersCleanedUp++;
              console.log(
                `Utente ${userDoc.id}: rimossi ${invalidTokens.length}/${tokens.length} token invalidi`
              );
            } catch (updateError) {
              console.error(`Errore aggiornamento utente ${userDoc.id}:`, updateError);
            }
          }
        });

        await Promise.all(promises);
      }

      console.log(
        `Pulizia completata: ${totalUsersChecked} utenti controllati, ` +
        `${totalUsersCleanedUp} utenti aggiornati, ` +
        `${totalTokensRemoved} token rimossi`
      );
    } catch (error) {
      console.error("Errore nella pulizia token FCM:", error);
    }

    return null;
  });
