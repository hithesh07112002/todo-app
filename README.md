# Collaborative Todo

A Flutter task manager with a Node.js/SQLite backend and WebSocket-powered live
updates. Connected clients share task creation, edits, status changes, and
deletions.

## Implemented requirements

- **Todo CRUD:** create, edit, delete, and change a task's status between
  Pending, In Progress, and Completed.
- **Task fields:** the server stores an ID, title, description, status,
  `createdBy`, `updatedBy`, `createdAt`, and `updatedAt` for every task.
- **Real-time collaboration:** REST requests persist each change in SQLite;
  WebSocket clients receive an initial snapshot and broadcasts for task
  creation, updates, and deletion. The Flutter client reconnects and reloads
  tasks after a dropped connection.
- **Editor information:** task cards show who created and last updated each
  task, along with creation and last-update timestamps.
- **Live status chart:** a `fl_chart` pie chart and count labels are derived
  from the synchronized task list.
- **Print/export:** the report action creates a printable PDF with a status
  chart and task list, including task descriptions and editor/timestamp data.
- **State management and architecture:** Provider manages presentation state;
  feature folders separate the task domain model, data/realtime repository,
  presentation, and report generation.

Display names are user-entered and self-reported; authentication is not part
of this implementation.

## Requirements

- Flutter SDK and Dart
- Node.js 22.5 or newer
- npm

On Windows, install Node.js LTS (which includes npm) with:

```powershell
winget install --id OpenJS.NodeJS.LTS --exact
```

Restart VS Code or open a new terminal after installation so the updated PATH
is loaded. The commands below use `npm.cmd` to avoid PowerShell execution
policies blocking the `npm.ps1` shim.

## Run the backend

```powershell
cd backend
npm.cmd install
npm.cmd start
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

## Publish the complete website on Render

The GitHub repository URL shows project files and the README. To serve the
actual Flutter website, Node API, and WebSocket from one Render URL:

1. Push this repository to GitHub.
2. In Render, choose **New → Blueprint**, connect this repository, and apply
   the configuration in `render.yaml`.
3. Wait for the Docker build and deployment to finish. Open the Render service
   URL, typically `https://collaborative-todo-api.onrender.com`.

The root `Dockerfile` builds the Flutter web app and packages it with the Node
server. Express serves the Flutter files at `/`, REST endpoints at `/api`, and
the WebSocket connection at `/ws` from the same origin. The frontend therefore
does not need a separate API URL or cross-origin setup in production.

**Free-host limitations:** Render Free services can sleep when idle and take
time to wake on the next request. The SQLite database is stored on the
container's temporary filesystem and may be erased when the service restarts
or redeploys. This is a demo deployment, not durable shared task storage. For
persistent SQLite data, use a paid Render disk. Display names are self-reported
and the API currently has no authentication, so do not put sensitive tasks on
the public demo.

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
- Node's built-in `node:sqlite` module for SQLite persistence
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
npm.cmd test
```
