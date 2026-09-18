# AimLab Mobile

A standalone Flutter Android aim-training/practice app. It provides fair-play drills for one-tap reaction, target tapping, accuracy, crosshair/head-level discipline, sensitivity practice, and local statistics.

It does **not** control, inject input into, read from, or modify Free Fire or any other external game.

## Run

```bash
flutter pub get
flutter analyze
flutter run
```

The app stores training statistics and preferences locally with `shared_preferences`. The current implementation deliberately uses a self-contained training canvas, so it does not require a camera, model, network connection, or external game integration.

## Screens

- Home dashboard with quick metrics and training focus
- One-Tap Training with timed targets, reaction scoring, hits/misses, pause, and restart
- Statistics with persistent totals and best results
- Settings for round duration, target size, vibration/sound preferences
