# Focus24

A Flutter + Firebase to-do / productivity application built with an MVVM architecture.

## Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Firestore, Authentication)
- **Architecture:** MVVM (`models` / `views` / `viewmodels` / `services`)
- **Platforms:** Android, iOS, Web, macOS, Linux, Windows

## Team

| Member          | Role                                  |
| --------------- | ------------------------------------- |
| Mai Soklyna     | Team Lead & Backend (Firebase)        |
| Young Soklong   | Authentication & User Profile         |
| Roeun Monorom   | Core Task Management                  |
| Po Ratana       | Collaboration / Shared Lists          |
| Rin Monyroth    | Productivity & Analytics              |
| Nuv Singju      | UI/UX, Localization & QA              |

## Getting Started

### Prerequisites
- Flutter SDK installed ([guide](https://docs.flutter.dev/get-started/install))
- A Firebase project

### Setup

1. Clone the repo:
   ```bash
   git clone <your-repo-url>
   cd Focus24
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase (generates `lib/firebase_options.dart`, which is gitignored):
   ```bash
   flutterfire configure
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
  models/       # Data models
  views/        # UI screens
  viewmodels/   # State & business logic
  services/     # Firebase & external services
  routes/       # Navigation
  theme/        # App theming
  utils/        # Helpers
```

## Notes

- `lib/firebase_options.dart` is **not** committed — each developer generates it locally via `flutterfire configure`.
- The Firebase user-export utility lives in `scripts/export-users/`. Its `service-account.json` private key is gitignored and must be obtained from the Firebase Console.
