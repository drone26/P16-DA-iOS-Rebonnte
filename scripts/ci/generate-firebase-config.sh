#!/usr/bin/env bash
#
# Recreates the git-ignored Firebase configuration that developers keep locally so
# CI can build the app and run the Emulator Suite. None of these files contain real
# secrets: the app never talks to the production project in CI. Unit tests skip
# `FirebaseApp.configure()` entirely (guarded by XCTest), and UI tests run against
# the local emulators, which accept any API key.
#
# Files written (all listed in .gitignore):
#   - MediStock/GoogleService-Info.plist  (fake API key, real project & bundle id)
#   - firebase.json, .firebaserc, firestore.rules, firestore.indexes.json, storage.rules
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Guard: this script overwrites files that developers keep locally with their own
# (git-ignored) copies. Only run it on CI, or when explicitly forced.
if [[ "${CI:-}" != "true" && "${1:-}" != "--force" ]]; then
  echo "Refusing to overwrite local Firebase config outside CI." >&2
  echo "Re-run with --force if you really mean to replace these files." >&2
  exit 1
fi

PROJECT_ID="gestionstockmedicaments-3818"
BUNDLE_ID="eu.myk8s.MediStock"
# FirebaseInstallations validates API_KEY's shape (`A` + 38 more chars, 39 total)
# during FIRApp.configure() and raises an uncaught NSException — crashing the app
# on every launch — if it doesn't look like a real key. The emulators never check
# it, so any string of the right shape works.
FAKE_API_KEY="AIzaSyFAKE0CIFAKE0API0KEY00000000000000"

echo "Generating MediStock/GoogleService-Info.plist"
cat > MediStock/GoogleService-Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_KEY</key>
	<string>${FAKE_API_KEY}</string>
	<key>GCM_SENDER_ID</key>
	<string>000000000000</string>
	<key>PLIST_VERSION</key>
	<string>1</string>
	<key>BUNDLE_ID</key>
	<string>${BUNDLE_ID}</string>
	<key>PROJECT_ID</key>
	<string>${PROJECT_ID}</string>
	<key>STORAGE_BUCKET</key>
	<string>${PROJECT_ID}.appspot.com</string>
	<key>IS_ADS_ENABLED</key>
	<false></false>
	<key>IS_ANALYTICS_ENABLED</key>
	<false></false>
	<key>IS_APPINVITE_ENABLED</key>
	<true></true>
	<key>IS_GCM_ENABLED</key>
	<true></true>
	<key>IS_SIGNIN_ENABLED</key>
	<true></true>
	<key>GOOGLE_APP_ID</key>
	<string>1:000000000000:ios:0000000000000000000000</string>
</dict>
</plist>
PLIST

echo "Generating .firebaserc"
cat > .firebaserc <<RC
{
  "projects": {
    "default": "${PROJECT_ID}"
  }
}
RC

echo "Generating firebase.json"
cat > firebase.json <<'JSON'
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "storage": {
    "rules": "storage.rules"
  },
  "emulators": {
    "auth": { "host": "127.0.0.1", "port": 9099 },
    "firestore": { "host": "127.0.0.1", "port": 8080 },
    "storage": { "host": "127.0.0.1", "port": 9199 },
    "ui": { "enabled": false },
    "singleProjectMode": true
  }
}
JSON

echo "Generating firestore.rules"
cat > firestore.rules <<'RULES'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // MediStock is an internal inventory tool: every authenticated user shares the
    // same medicine stock and change history. "Signed in" is the whole access model.
    function isSignedIn() {
      return request.auth != null;
    }

    function isValidMedicine(data) {
      return data.name is string
          && data.name.size() > 0
          && data.stock is int
          && data.stock >= 0
          && data.aisle is string
          && (!('nameSubstrings' in data) || data.nameSubstrings is list);
    }

    match /medicines/{medicineId} {
      allow read: if isSignedIn();
      allow create, update: if isSignedIn() && isValidMedicine(request.resource.data);
      allow delete: if isSignedIn();
    }

    match /history/{entryId} {
      // Audit log: append-only for signed-in users, never editable or deletable.
      allow read, create: if isSignedIn();
      allow update, delete: if false;
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
RULES

echo "Generating storage.rules"
cat > storage.rules <<'RULES'
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // MediStock does not use Cloud Storage: deny every path.
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
RULES

echo "Generating firestore.indexes.json"
cat > firestore.indexes.json <<'JSON'
{
  "indexes": [
    {
      "collectionGroup": "history",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "medicineId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "medicines",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "nameSubstrings", "arrayConfig": "CONTAINS" },
        { "fieldPath": "name", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "medicines",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "nameSubstrings", "arrayConfig": "CONTAINS" },
        { "fieldPath": "stock", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
JSON

echo "Firebase configuration generated."
