#!/usr/bin/env node
/**
 * fix_usernames.js
 *
 * Usage:
 *   node fix_usernames.js --serviceAccount ./serviceAccount.json --projectId your-project-id [--action dry-run|rename|delete] [--deleteAuth true]
 *
 * - dry-run (default): prints a report of duplicate usernames and suggestions
 * - rename: renames duplicates by appending a numeric suffix (username, username_1, username_2...)
 * - delete: deletes duplicate Firestore `users/{uid}` docs (and optionally Auth users with --deleteAuth true)
 *
 * WARNING: `delete` will remove documents and optionally Auth users. Use `dry-run` first.
 */

const admin = require('firebase-admin');
const fs = require('fs');

function parseArgs() {
  const args = {};
  process.argv.slice(2).forEach((a) => {
    const [k, v] = a.split('=');
    const key = k.replace(/^--/, '');
    args[key] = v === undefined ? true : v;
  });
  return args;
}

async function main() {
  const args = parseArgs();
  const serviceAccountPath = args.serviceAccount || process.env.FIREBASE_SERVICE_ACCOUNT;
  const projectId = args.projectId || process.env.FIREBASE_PROJECT_ID;
  const action = args.action || 'dry-run';
  const deleteAuth = args.deleteAuth === 'true' || args.deleteAuth === true;

  if (!serviceAccountPath || !fs.existsSync(serviceAccountPath)) {
    console.error('Missing or invalid --serviceAccount path. Provide a path to a Firebase service account JSON.');
    process.exit(1);
  }
  if (!projectId) {
    console.error('Missing --projectId.');
    process.exit(1);
  }

  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId,
  });

  const db = admin.firestore();

  console.log('Scanning users collection...');
  const usersSnap = await db.collection('users').get();
  const byUsername = new Map();

  usersSnap.forEach((doc) => {
    const data = doc.data() || {};
    const username = (data.username || '').toString().toLowerCase();
    if (!username) return; // skip users without username
    if (!byUsername.has(username)) byUsername.set(username, []);
    byUsername.get(username).push({ id: doc.id, data });
  });

  const duplicates = [];
  for (const [username, list] of byUsername) {
    if (list.length > 1) duplicates.push({ username, list });
  }

  console.log(`Found ${duplicates.length} duplicate username(s).`);

  for (const dup of duplicates) {
    console.log('\n=== Conflict: ' + dup.username + ' ===');
    // sort by createdAt if available (oldest first)
    dup.list.sort((a, b) => {
      const ta = a.data.createdAt ? a.data.createdAt._seconds || 0 : 0;
      const tb = b.data.createdAt ? b.data.createdAt._seconds || 0 : 0;
      return ta - tb;
    });

    console.log('Candidates:');
    dup.list.forEach((it, idx) => {
      console.log(`${idx}: uid=${it.id} email=${it.data.email || '<no-email>'} createdAt=${JSON.stringify(it.data.createdAt)}`);
    });

    // Keep the first (oldest) and process others
    const toKeep = dup.list[0];
    const toProcess = dup.list.slice(1);

    if (action === 'dry-run') {
      console.log(`Would keep uid=${toKeep.id} and ${toProcess.length} other(s) would be ${action}.`);
      continue;
    }

    if (action === 'delete') {
      for (const docInfo of toProcess) {
        console.log(`Deleting Firestore user doc ${docInfo.id}`);
        await db.collection('users').doc(docInfo.id).delete();
        // remove any username reservation for this uid if exists
        const unameDocs = await db.collection('usernames').where('uid', '==', docInfo.id).get();
        for (const ud of unameDocs.docs) await ud.ref.delete();
        if (deleteAuth) {
          try {
            await admin.auth().deleteUser(docInfo.id);
            console.log(`Also deleted Auth user ${docInfo.id}`);
          } catch (e) {
            console.warn(`Failed to delete Auth user ${docInfo.id}: ${e}`);
          }
        }
      }
      // ensure a username doc exists for the kept one
      const usernameRef = db.collection('usernames').doc(dup.username);
      await usernameRef.set({ uid: toKeep.id, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      continue;
    }

    if (action === 'rename') {
      // ensure username reservation for the kept one
      const usernameRef = db.collection('usernames').doc(dup.username);
      await usernameRef.set({ uid: toKeep.id, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });

      // rename duplicates with suffixes
      let suffix = 1;
      for (const docInfo of toProcess) {
        let newName = `${dup.username}_${suffix}`;
        // ensure unique among existing
        while (true) {
          const exists = (await db.collection('users').where('username', '==', newName).get()).size > 0 || (await db.collection('usernames').doc(newName).get()).exists;
          if (!exists) break;
          suffix += 1;
          newName = `${dup.username}_${suffix}`;
        }
        console.log(`Renaming ${docInfo.id} -> ${newName}`);
        await db.collection('users').doc(docInfo.id).update({ username: newName });
        await db.collection('usernames').doc(newName).set({ uid: docInfo.id, createdAt: admin.firestore.FieldValue.serverTimestamp() });
        suffix += 1;
      }
      continue;
    }
  }

  // For non-duplicate usernames, ensure username reservation exists
  console.log('\nEnsuring username reservations for unique users...');
  for (const [username, list] of byUsername) {
    if (list.length === 1) {
      const docInfo = list[0];
      const usernameRef = db.collection('usernames').doc(username);
      const snap = await usernameRef.get();
      if (!snap.exists) {
        console.log(`Creating reservation for ${username} -> ${docInfo.id}`);
        await usernameRef.set({ uid: docInfo.id, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      }
    }
  }

  console.log('\nDone.');
  process.exit(0);
}

main().catch((err) => {
  console.error('Script error:', err);
  process.exit(1);
});
