# Firebase Push Notifications Setup Guide

This document provides step-by-step instructions for configuring Firebase Cloud Messaging (FCM) for the HAJEMI Smart application.

## 1. Firebase Project Setup

### Create a Firebase Project
1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and follow the prompts to create a new project named `HAJEMI-Smart`.
3. Disable or enable Google Analytics as per your preference.

### Register Applications
#### Android
1. In the Firebase Console, click the **Android icon** to add an app.
2. Enter the package name: `com.hajemi.smart` (verify this in `android/app/build.gradle`).
3. Download the `google-services.json` file.
4. Place `google-services.json` in the `android/app/` directory of this project.

#### iOS (If applicable)
1. Click **Add app** and select **iOS**.
2. Enter the bundle ID (e.g., `com.hajemi.smart`).
3. Download `GoogleService-Info.plist`.
4. Open the project in Xcode and drag this file into the `Runner` folder.

## 2. Required Credentials & Security

### Sensitive Files (DO NOT COMMIT)
The following files contain sensitive credentials and should **never** be committed to public repositories:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart` (if generated)
- `service-account.json` (Backend Firebase Admin SDK key)

### .gitignore Recommendations
Ensure your `.gitignore` includes:
```
google-services.json
GoogleService-Info.plist
firebase_options.dart
*-account.json
```

## 3. Frontend Setup (Flutter)

### Dependencies
The project uses the following packages:
- `firebase_core`: Core Firebase initialization.
- `firebase_messaging`: Handling FCM tokens and messages.
- `flutter_local_notifications`: Displaying notifications in the foreground.

### Configuration
1. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`.
2. Run `flutterfire configure` from the project root to generate `lib/firebase_options.dart` and automatically update Gradle files.

#### Manual Gradle Setup (If not using FlutterFire CLI)
If you prefer manual setup, update the following files:

**`android/build.gradle.kts`** (Root):
Add the classpath dependency:
```kotlin
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}
```

**`android/app/build.gradle.kts`**:
Add the plugin at the top:
```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
```

### FCM Token Management
- The application automatically obtains the FCM token upon initialization or login.
- It is registered to the backend via `POST /users/me/fcm-token`.

## 4. Backend Setup (Firebase Admin SDK)

The backend must be configured to send notifications to users based on specific events.

### Service Account Key
1. In the Firebase Console, go to **Project Settings** > **Service accounts**.
2. Click **Generate new private key**.
3. Save the JSON file as `service-account.json` in your backend project's secure config directory.

### Environment Variables
Configure your backend to point to the service account file:
```bash
GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

### Triggering Notifications
The backend should listen for the following events and send FCM messages:

#### A. Household Events
- **Trigger**: When a user joins a household (`POST /household/join`).
- **Target**: The household creator/admin.
- **Payload**:
  - Title: `New Household Member`
  - Body: `<User Name> has joined your household.`

#### B. Auto Night Light Events
- **Trigger**: When the device logic (LDR threshold) toggles the light state.
- **Target**: All members of the household associated with the device.
- **Payload**:
  - Title: `Auto Night Light`
  - Body: `The Auto Night Light has been turned ON/OFF automatically.`

#### C. Home Gate Security Alert
- **Trigger**: Movement detected at the gate (`GET /gate/{id}/detections` status changes to `DETECTED`).
- **Target**: All members of the household.
- **Payload**:
  - Title: `Home Gate Security Alert`
  - Body: `Motion has been detected at the gate.`

#### D. Anti-Theft Alert
- **Trigger**: Movement detected by the room sensor.
- **Target**: All members of the household.
- **Payload**:
  - Title: `Anti-Theft Alert`
  - Body: `Suspicious movement has been detected.`

## 5. Testing Instructions

### Foreground Testing
1. Run the app on a physical device or emulator.
2. Trigger an event (e.g., join a household).
3. A local notification should appear at the top of the screen.

### Background Testing
1. Minimize the app.
2. Trigger an event.
3. The system-level notification should appear in the device notification tray.

### Troubleshooting
- Check if `google-services.json` is in the correct folder.
- Ensure the device has internet access and Google Play Services (Android).
- Verify the FCM token is being sent to the backend logs.
