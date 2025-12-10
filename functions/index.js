const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

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
        const promises = recipientIds.map(async (recipientId) => {
          const userDoc = await admin.firestore().collection("users").doc(recipientId).get();
          if (!userDoc.exists) return;

          const tokens = userDoc.data().fcmTokens || [];
          if (tokens.length === 0) return;

          // Construct Payload
          const payload = {
            notification: {
              title: `Nuovo messaggio da ${senderName}`,
              body: message.type === "image" ? "📷 Foto inviata" : message.text,
              clickAction: "FLUTTER_NOTIFICATION_CLICK", // Optional, useful for routing
            },
            data: {
              type: "chat_message",
              chatId: chatId,
              senderId: senderId,
            },
          };

          // Send to device group or list of tokens
          // Send to each token individually to handle invalid tokens
          const response = await admin.messaging().sendToDevice(tokens, payload);
          
          // Cleanup invalid tokens
          await cleanupTokens(response, tokens, recipientId);
        });

        await Promise.all(promises);
      } catch (error) {
        console.error("Error sending chat notification:", error);
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

                const payload = {
                    notification: {
                        title: "Nuova richiesta di amicizia",
                        body: `${requesterName} vuole stringere amicizia!`,
                    },
                    data: {
                        type: "friend_request",
                        requesterId: requesterId,
                    },
                };

                const response = await admin.messaging().sendToDevice(tokens, payload);
                await cleanupTokens(response, tokens, userId);

            } catch (error) {
                console.error("Error sending friend request notification:", error);
            }
        }
      }
    });

/**
 * Helper: Remove invalid tokens
 */
async function cleanupTokens(response, tokens, userId) {
    const tokensToRemove = [];
    response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
            console.error('Failure sending notification to', tokens[index], error);
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
        console.log('Removed invalid tokens:', tokensToRemove);
    }
}
