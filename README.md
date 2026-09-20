# MediStock

MediStock is an iOS app for managing a shared medicine stock: tracking quantities
per aisle, adding/removing medicines, and keeping an audit history of every stock
change. Built with SwiftUI and Firebase (Auth + Firestore).

## Features

- Email/password sign-in (Firebase Auth)
- Browse medicines by name or by aisle, with pagination and search
- Add, edit, and delete medicines; adjust stock levels
- Per-medicine change history (append-only audit log)
- User profile screen

## Tech stack

- **SwiftUI**, MVVM architecture
- **Firebase**: Auth, Firestore (via Swift Package Manager)
- ViewModels depend on protocols (`MedicineRepository`, `AuthServicing`) so
  production code talks to Firebase while tests inject mocks — unit tests never
  touch the production project
- Deployment target: iOS 17.5+

## Project structure

```
MediStock/
  App/          # App & scene delegates, entry point
  Model/        # Medicine, HistoryEntry, User, SortOption
  Persistence/  # Repository/service protocols + Firebase implementations
  View/         # SwiftUI views
  ViewModel/    # MedicineStockViewModel, SessionStore
MediStockTests/     # Unit tests (mocked repositories, no Firebase)
MediStockUITests/   # XCUITest suite driven against the Firebase Emulator Suite
scripts/ci/          # CI helper scripts
.github/workflows/   # GitHub Actions CI
```

## Getting started

1. Clone the repo and open `MediStock.xcodeproj` in Xcode.
2. Set up your local Firebase configuration (see below) — several config files
   are git-ignored and must exist locally before the app will build and run.
3. Build and run the `MediStock` scheme on a simulator or device.

### Local Firebase configuration

`GoogleService-Info.plist`, `firebase.json`, `.firebaserc`, `firestore.rules`,
`firestore.indexes.json`, and `storage.rules` are all git-ignored (each developer
keeps their own copy; see `.gitignore`). To get a working local setup:

- **Real project**: download `GoogleService-Info.plist` from the Firebase console
  for project `gestionstockmedicaments-3818` and place it at
  `MediStock/GoogleService-Info.plist`, then keep `firebase.json`/`.firebaserc`/
  the rules files pointed at that project.
- **Emulator-only / CI-style setup**: run `./scripts/ci/generate-firebase-config.sh --force`
  to generate all of the files above with a fake API key. This is enough to run
  the app against the emulators and to run the full test suite — it never talks
  to production.

## Configuring the Firebase Emulator Suite

UI tests (and local emulator-based development) run against the Firebase
Emulator Suite instead of production Firebase.

1. Install the Firebase CLI: `curl -sL https://firebase.tools | bash`.
2. Make sure `firebase.json` exists locally (see above) — it pins the emulator
   ports:
   - Auth: `127.0.0.1:9099`
   - Firestore: `127.0.0.1:8080`
   - Storage: `127.0.0.1:9199` (unused by the app)
   - Emulator UI: `http://127.0.0.1:4000`
3. Start the emulators from the repo root:
   ```
   firebase emulators:start
   ```
4. Launch the app with the `-useFirebaseEmulator` launch argument to route Auth
   and Firestore calls to the running emulators instead of production (add
   `-signOutOnLaunch` to also force a clean, signed-out session).
5. Data lives only in the emulator process — restarting it resets everything.

## Running tests

Unit tests use mocked repositories and never touch Firebase:

```
xcodebuild test -project MediStock.xcodeproj -scheme MediStock \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MediStockTests
```

UI tests drive the real app and require the Firebase Emulator Suite to be
running first (see above). They must run serially, since all tests share one
emulator instance:

```
xcodebuild test -project MediStock.xcodeproj -scheme MediStock \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MediStockUITests -parallel-testing-enabled NO
```

## Continuous Integration (GitHub Actions)

`.github/workflows/ci.yml` runs on every push and pull request, with three jobs:

- **lint** — runs SwiftLint (`.swiftlint.yml`) in the official SwiftLint
  container. Currently non-blocking (`continue-on-error: true`), so it surfaces
  violations without failing the pipeline.
- **unit-tests** — runs on `macos-26`, regenerates the git-ignored Firebase
  config via `scripts/ci/generate-firebase-config.sh`, then runs
  `MediStockTests`. Test results are uploaded as a build artifact.
- **ui-tests** — runs on `macos-26`, regenerates the Firebase config, builds the
  UI test target, then starts the Firebase Emulator Suite (Auth + Firestore)
  and waits for ports 8080/9099 before running `MediStockUITests` serially.
  Emulator logs and test results are uploaded as build artifacts.

Because `GoogleService-Info.plist` and the Firebase project files are
git-ignored, CI can't use a developer's local copies — `generate-firebase-config.sh`
recreates them with a fake API key (real project/bundle IDs) so the app builds
and the emulators run identically to a local setup. Production Firebase is
never touched by CI or by the test suites; deploying rules/indexes to
production is a manual step (`firebase deploy --only firestore:rules,firestore:indexes`).
