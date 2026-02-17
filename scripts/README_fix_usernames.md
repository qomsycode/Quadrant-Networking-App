Fix duplicate usernames script
=================================

This folder contains `fix_usernames.js`, a Node.js script that uses the Firebase Admin SDK to detect and optionally resolve duplicate usernames in your Firestore `users` collection.

Prerequisites
-------------
- Node.js (14+)
- A Firebase service account JSON with Project Owner or appropriate privileges

Usage
-----
1. Install dependencies (recommended inside this repo):

```bash
npm init -y
npm install firebase-admin
```

2. Run a dry-run report:

```bash
node scripts/fix_usernames.js --serviceAccount=./serviceAccount.json --projectId=your-firebase-project --action=dry-run
```

3. Rename duplicates (safe):

```bash
node scripts/fix_usernames.js --serviceAccount=./serviceAccount.json --projectId=your-firebase-project --action=rename
```

4. Delete duplicate Firestore user docs (destructive):

```bash
node scripts/fix_usernames.js --serviceAccount=./serviceAccount.json --projectId=your-firebase-project --action=delete
```

Add `--deleteAuth=true` to also remove the Firebase Auth user accounts when using `--action=delete`.

Recommendation
--------------
Run `dry-run` first to inspect conflicts. Prefer `rename` unless you really want to remove accounts. Keep a backup of Firestore before destructive operations.
