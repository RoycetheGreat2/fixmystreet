# FixMyStreet

Flutter app for reporting local infrastructure issues (photos, GPS, map, status tracking). Citizens submit reports; admins manage them via Firebase.

## Live portfolio & download

| | Link |
|---|---|
| **Project page** | https://fixmystreet-portfolio.vercel.app |
| **Download APK** | https://fixmystreet-portfolio.vercel.app/fixmystreet.apk |

## Features

- Photo reports with GPS and duplicate detection (50 m)
- Community map & heatmap
- My reports, notifications, profile
- Admin dashboard (users, reports, analytics)

## Run locally

**Prerequisites:** [Flutter](https://docs.flutter.dev/get-started/install) SDK ^3.9, Firebase project with Email/Password auth enabled.

```bash
git clone https://github.com/RoycetheGreat2/fixmystreet.git
cd fixmystreet
flutter pub get
flutter run
```

**Admin access:** In Firestore `users/{uid}`, set `isAdmin: true`.

## Stack

Flutter · Firebase Auth · Cloud Firestore · Cloudinary · flutter_map · geolocator

## Screenshots

See the [portfolio site](https://fixmystreet-portfolio.vercel.app) for UI previews.
