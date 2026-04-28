// One-off Firebase user export. Lists every account in Firebase Auth,
// enriches each row with the matching Firestore `userProfiles` doc,
// and writes a CSV next to this script.
//
// Passwords cannot be exported — Firebase Auth stores only salted hashes
// and they are never returned by any API.
//
// Usage:
//   1. Firebase Console → Project Settings → Service accounts →
//      "Generate new private key". Save the JSON next to this file as
//      `service-account.json`.
//   2. cd scripts/export-users
//   3. npm install
//   4. node export_users.js
//   5. Open users.csv (UTF-8).

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const keyPath = path.join(__dirname, 'service-account.json');
if (!fs.existsSync(keyPath)) {
  console.error(
    '\nMissing service-account.json next to this script.\n\n' +
      'To create it:\n' +
      '  1. Open https://console.firebase.google.com\n' +
      '  2. Pick your project (Focus24).\n' +
      '  3. Click the gear icon → Project settings.\n' +
      '  4. Open the "Service accounts" tab.\n' +
      '  5. Click "Generate new private key" → "Generate key".\n' +
      '  6. Save the downloaded .json file in this folder and\n' +
      '     rename it to exactly: service-account.json\n' +
      `     (i.e. ${keyPath})\n` +
      '  7. Re-run: node export_users.js\n'
  );
  process.exit(1);
}
const serviceAccount = require(keyPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const db = admin.firestore();

function csvEscape(value) {
  if (value === null || value === undefined) return '';
  const s = String(value);
  if (s.includes('"') || s.includes(',') || s.includes('\n') || s.includes('\r')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

async function fetchAllAuthUsers() {
  const users = [];
  let pageToken;
  do {
    const result = await auth.listUsers(1000, pageToken);
    users.push(...result.users);
    pageToken = result.pageToken;
  } while (pageToken);
  return users;
}

async function fetchProfileMap() {
  const map = new Map();
  const snap = await db.collection('userProfiles').get();
  snap.forEach((doc) => map.set(doc.id, doc.data()));
  return map;
}

(async () => {
  console.log('Listing users from Firebase Auth…');
  const [users, profiles] = await Promise.all([
    fetchAllAuthUsers(),
    fetchProfileMap(),
  ]);
  console.log(`Found ${users.length} accounts.`);

  const header = [
    'uid',
    'email',
    'emailVerified',
    'displayName',
    'profileDisplayName',
    'phoneNumber',
    'providers',
    'disabled',
    'createdAt',
    'lastSignInAt',
    'photoUrl',
  ];

  const rows = users.map((u) => {
    const profile = profiles.get(u.uid) || {};
    const providers = (u.providerData || []).map((p) => p.providerId).join('|');
    return [
      u.uid,
      u.email,
      u.emailVerified,
      u.displayName,
      profile.displayName,
      u.phoneNumber,
      providers,
      u.disabled,
      u.metadata && u.metadata.creationTime,
      u.metadata && u.metadata.lastSignInTime,
      u.photoURL,
    ];
  });

  const csv = [header, ...rows]
    .map((cols) => cols.map(csvEscape).join(','))
    .join('\n');

  const out = path.join(__dirname, 'users.csv');
  fs.writeFileSync(out, '﻿' + csv, 'utf8'); // BOM so Excel reads UTF-8.
  console.log(`Wrote ${rows.length} rows to ${out}`);
  process.exit(0);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
