# Collaborative Todo

A Flutter task manager with a Node.js/SQLite backend and WebSocket-powered live
updates. Connected clients share task creation, edits, status changes, and
deletions.

## Requirements

- Flutter SDK and Dart
- Node.js 20 or newer
- npm

## Run the backend

```powershell
cd backend
npm install
npm start
```

By default, the API and WebSocket server listen on port `3000`, and the SQLite
database is created at `backend/data/todos.sqlite`. Configure the port and
database path with `PORT` and `DATABASE_PATH` environment variables.

Endpoints:

- `GET /health`
- `GET /api/tasks`
- `POST /api/tasks`
- `PUT /api/tasks/:id`
- `DELETE /api/tasks/:id`
- `WS /ws`

## Run the Flutter app

From the project root:

```powershell
flutter pub get
flutter run
```

The default server URL is `http://localhost:3000`. To select another address,
pass `--dart-define=API_BASE_URL=http://<host>:3000` to `flutter run`. For the
Android emulator, use `http://10.0.2.2:3000`. For a physical device, use the
development computer's LAN IP and ensure both devices can reach it. Android
allows cleartext HTTP only in debug builds for local development; use HTTPS in
production.

Each user can set a display name from the person icon. Names are self-reported
and are not authenticated.

## Packages

Flutter:

- `provider` for application state
- `material_ui` for Material widgets
- `http` and `web_socket_channel` for REST and real-time transport
- `fl_chart` for the live status chart
- `pdf` and `printing` for printable/exportable reports
- `intl` for task timestamps

Backend:

- `express` for the HTTP API
- `ws` for WebSocket connections and task event broadcasts
- `better-sqlite3` for SQLite persistence
- `cors` to allow a Flutter web client hosted on another origin

## Architecture

The Flutter app is organized by feature. `domain` contains the typed task and
status model, `data` contains the REST/WebSocket repository, and
`presentation` contains the Provider controller, UI, and report generation.
The controller loads an initial snapshot, applies server events to the shared
task state, and refreshes the list when reconnecting.

The backend is organized around a SQLite database module and an HTTP/WebSocket
server. SQLite is the source of truth: CRUD requests are validated and
persisted before the server broadcasts an event. New WebSocket clients receive
a snapshot before subsequent live events.

## Tests

```powershell
flutter test
flutter analyze
cd backend
npm test
```
