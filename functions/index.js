// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Scheduled function that runs daily and removes chat rooms (and their messages)
 * that have been completed for more than 7 days.
 *
 * It queries the `chat_rooms` collection for documents where `completedAt`
 * exists and is older than the cutoff timestamp. For each matching room it:
 *   1. Deletes the chat room document.
 *   2. Deletes all messages in `chat_messages` that belong to that room
 *      (where `chatRoomId` equals the room ID).
 */
exports.scheduledChatCleanup = functions.pubsub.schedule('0 2 * * *') // runs daily at 02:00 UTC
    .timeZone('Etc/UTC')
    .onRun(async (context) => {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();
      const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - 7 * 24 * 60 * 60 * 1000);

      // Find chat rooms that were completed more than 7 days ago
      const roomsSnap = await db.collection('chat_rooms')
        .where('completedAt', '<=', sevenDaysAgo)
        .get();

      if (roomsSnap.empty) {
        console.log('No chat rooms to clean up.');
        return null;
      }

      console.log(`Found ${roomsSnap.size} chat rooms to delete.`);

      // Process each room
      for (const roomDoc of roomsSnap.docs) {
        const roomId = roomDoc.id;
        const batch = db.batch();
        // Delete the chat room document
        batch.delete(roomDoc.ref);

        // Delete all messages belonging to this room
        const msgsSnap = await db.collection('chat_messages')
          .where('chatRoomId', '==', roomId)
          .get();
        msgsSnap.forEach(msgDoc => batch.delete(msgDoc.ref));

        // Commit the batch (max 500 ops per batch, which is safe for typical usage)
        await batch.commit();
        console.log(`Deleted chat room ${roomId} and ${msgsSnap.size} messages.`);
      }

      console.log('Chat cleanup completed.');
      return null;
    });
