# HAJEMI

HAJEMI is a Flutter app for managing smart devices and related household activity.

## Prerequisites

Before you start, make sure you have:

- Flutter SDK (the project expects Flutter 3.3 or newer)
- Android Studio or Xcode (for emulators/simulators)
- A running backend API that matches the app configuration
- An emulator, simulator, or physical device connected

## Setup

1. Install Flutter and verify your environment:
   ```bash
   flutter doctor
   ```
2. Install project dependencies:
   ```bash
   flutter pub get
   ```
3. If the app cannot connect to the backend, update the API base URL in [lib/core/constants.dart](lib/core/constants.dart).

## Run the app

Start the app with:

```bash
flutter run
```

If you want to run it on a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

## Useful commands

- Refresh dependencies after pulling changes:
  ```bash
  flutter pub get
  ```
- Clear build artifacts if you run into startup issues:
  ```bash
  flutter clean
  flutter pub get
  ```

## Notes

The app currently points to a local backend URL:

```text
http://192.168.1.38:8000
```

If your backend runs somewhere else, update the base URL before running the app.
