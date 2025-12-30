# Grammatica

Grammatica is a Flutter mobile and web app for language learning. It uses Firebase Authentication and Realtime Database to provide sign-in (email/password and anonymous) and per-user lesson progress.

## Features
- Firebase Authentication (email/password and anonymous)
- Role-based access (LEARNER, ADMIN)
- Admin Dashboard with Users (responsive table) and Lessons CRUD
- Lessons stored in Cloud Firestore with per-user progress
- Profile page: update username (with password confirmation), update password (reauth + confirm), sign out, delete account
- SnackBar notifications for important actions
- Cross-platform: Android, iOS, Web, Desktop

## Quick start

1) Install dependencies

```
flutter pub get
```

2) Configure Firebase

The project includes a placeholder `lib/firebase_options.dart`. The easiest way to set this up is with FlutterFire CLI:

```
npm i -g firebase-tools
flutter pub global activate flutterfire_cli
flutterfire configure --project <your-project-id>
```

This will generate a real `firebase_options.dart` with your project configuration and update platform files (Android, iOS, Web).

Alternatively, manually replace the placeholders in `lib/firebase_options.dart` with your Firebase project values and add the required platform configuration files (e.g., `google-services.json`, `GoogleService-Info.plist`).

3) Firestore security rules (development)

Set Firestore rules for dev/testing to allow reading lessons for everyone and restricting user docs to owners. For production, harden these rules.

Example dev rules (allow admin by looking up the caller's role in users collection):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isAdmin() {
      return isSignedIn() &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'ADMIN';
    }
    function isSelf(userId) { return isSignedIn() && request.auth.uid == userId; }

    match /lessons/{lessonId} {
      allow read: if true; // lessons are public to read
      allow write: if isAdmin(); // only admins can modify lessons
    }

    match /users/{userId} {
      allow read, write: if isSelf(userId) || isAdmin(); // admin can list all users
      match /progress/{lessonId} {
        allow read, write: if isSelf(userId) || isAdmin();
      }
    }
  }
}
```

4) Seeding

The app automatically seeds a placeholder lesson in Firestore on first run if the lessons collection is empty.

5) Roles

- Users are created in Firestore with: createdAt, email, role (LEARNER), status (ACTIVE), subscription_status (NONE), username ('Firstname Lastname').
- Admins can promote/demote users in the dashboard.
- Admins see Admin Dashboard (Users + Lessons). Learners see lessons.

6) Run the app

```
flutter run -d chrome   # Web
flutter run              # Mobile (pick a device)
```

## Project structure
- `lib/main.dart`: UI and app routing
- `lib/services/auth_service.dart`: FirebaseAuth wrapper
- `lib/services/database_service.dart`: Realtime Database access and models
- `lib/firebase_options.dart`: Firebase config (replace with your values)

## Notes
- For iOS/Android, ensure Google services files are added and plugins are enabled.
- For Web, using `DefaultFirebaseOptions.currentPlatform` handles initialization without adding script tags manually.
