const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

async function assertIsAdmin(context) {
  if (!context.auth?.uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  }
  const snap = await admin.firestore().doc(`user_roles/${context.auth.uid}`).get();
  const role = (snap.data()?.role || '').toString().toLowerCase();
  if (role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin only.');
  }
}

exports.setUserActive = functions.https.onCall(async (data, context) => {
  await assertIsAdmin(context);
  const { uid, isActive } = data || {};
  if (!uid || typeof isActive !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'uid and isActive required');
  }
  await admin.auth().updateUser(uid, { disabled: !isActive });
  if (!isActive) await admin.auth().revokeRefreshTokens(uid);
  await admin.firestore().doc(`user_roles/${uid}`).set({ isActive }, { merge: true });
  return { success: true };
});

exports.setUserEmail = functions.https.onCall(async (data, context) => {
  await assertIsAdmin(context);
  const { uid, newEmail } = data || {};
  if (!uid || !newEmail) {
    throw new functions.https.HttpsError('invalid-argument', 'uid and newEmail required');
  }
  await admin.auth().updateUser(uid, { email: newEmail });
  await admin.firestore().doc(`user_roles/${uid}`).set({
    email: newEmail,
    firebaseAuthEmail: newEmail.toLowerCase(),
  }, { merge: true });
  return { success: true };
});