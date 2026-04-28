# Export users to CSV

One-off script that pulls every Firebase Auth account (plus the matching
`userProfiles` Firestore doc) and writes them to `users.csv`.

**Passwords are NOT exported.** Firebase only stores salted hashes — no API
can return them. The CSV contains uid, email, displayName, providers,
created/last-signed-in timestamps, etc.

## One-time setup

1. Install Node.js (v18+).
2. Firebase Console → ⚙ Project Settings → **Service accounts** →
   **Generate new private key**. Save the downloaded JSON in this folder
   as `service-account.json`. **Do not commit it** — `.gitignore` already
   excludes it.
3. Open a terminal in this folder and run `npm install`.

## Run

```
node export_users.js
```

You'll get `users.csv` next to the script. Open it in Excel / Google Sheets
(UTF-8 BOM is included so Khmer names render correctly).

## Safety

`service-account.json` grants admin access to your Firebase project. Keep
it on your machine only. If it ever leaks, revoke it in
Project Settings → Service accounts → ⋮ → Delete.
