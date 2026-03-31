# AMS Frontend

Flutter client for Attendance Master Scholar with Google Sign-In.

## Run

From `ams_project/frontend` for Android:

```powershell
flutter run `
  --dart-define=AMS_API_BASE_URL=http://10.0.2.2:8000 `
  --dart-define=AMS_GOOGLE_SERVER_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID
```

From `ams_project/frontend` for Flutter web:

```powershell
flutter run -d chrome `
  --web-hostname localhost `
  --web-port 7357 `
  --dart-define=AMS_API_BASE_URL=http://127.0.0.1:8000
```

Optional:

```powershell
--dart-define=AMS_GOOGLE_WEB_CLIENT_ID=YOUR_GOOGLE_WEB_CLIENT_ID
--dart-define=AMS_GOOGLE_HOSTED_DOMAIN=college.edu
```

Use `http://10.0.2.2:8000` for the Android emulator and your machine IP for a
physical device.

## Login Experience

The app now uses a role-first Google sign-in flow:

- user selects `Principal`, `HOD`, `Lecturer`, or `Student`
- then taps `Continue with Google`
- sends the Google ID token plus selected role to `POST /auth/google`
- stores the returned AMS JWT locally
- restores sessions through `GET /auth/me`

## Role Routing

- `principal` → Principal dashboard
- `hod` → HOD dashboard
- `lecturer` → Lecturer attendance dashboard
- `student` → Student attendance dashboard

If the backend rejects the email, the app shows:

`This account is not registered in the college attendance system.`

## Android Google Setup Notes

Register the Android app in Google Cloud or Firebase with the correct:

- package name
- signing SHA
- web OAuth client

For Flutter web, configure the OAuth web client with:

- Authorized JavaScript origin: `http://localhost`
- Authorized JavaScript origin: `http://localhost:7357`

This flow uses Google Identity Services on the frontend and sends the Google
ID token to `POST /auth/google`. It does not use a backend OAuth callback or a
Google client secret.

The backend `.env` remains the source of truth for the web client ID:

- backend `.env` as `AMS_GOOGLE_CLIENT_ID`
- Flutter web reads it from `GET /auth/google/config` at startup

You can still override it explicitly on web with `AMS_GOOGLE_WEB_CLIENT_ID`.
Pass the same Google web client ID to:

- backend `.env` as `AMS_GOOGLE_CLIENT_ID`
- Flutter web as `AMS_GOOGLE_WEB_CLIENT_ID`
- Android as `AMS_GOOGLE_SERVER_CLIENT_ID`
