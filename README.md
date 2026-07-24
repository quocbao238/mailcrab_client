# MailCrab Client

A Flutter desktop/mobile client for [MailCrab](https://github.com/tweedegolf/mailcrab) — the SMTP test server for development. Instead of keeping the MailCrab web UI open in a browser tab, this app shows incoming test mail in a native window and fires a **local system notification** the moment a new email arrives.

Maintained by [@quocbao238](https://github.com/quocbao238).

## Features

- **Live inbox** — connects to MailCrab's WebSocket (`/ws`), new mail appears instantly (no polling)
- **Native notifications** — system notification on new mail; click it to jump to the message (toggle in Settings). Settings shows the OS permission status, can re-request it, and walks you through enabling it manually if it was denied
- **Icon badge** — unread-mail count on the app icon: macOS Dock badge and Windows taskbar overlay (red 1–9/9+ counter)
- **Full message view** — HTML, plain-text, raw source, and headers tabs; inline `cid:` images resolved automatically
- **Attachments** — one click to download/open via the MailCrab API
- **Search & unread badges** — filter by sender/subject, unread counter in the title bar
- **Manage mail** — delete one message or wipe the whole mailbox
- **Connection awareness** — internet connectivity check (offline banner) plus server status chip (Live / Connecting / Polling / Offline) with automatic reconnect and catch-up refresh
- **Polling fallback** — if a proxy blocks the WebSocket upgrade, the app polls `/api/messages` every 10 s so live updates and notifications keep working
- **Custom theme** — light/dark/system mode and a pick-your-color Material 3 palette, applied instantly and persisted locally (works on Windows/macOS/Linux via shared_preferences)
- **Configurable server** — any host/port, HTTPS and `MAILCRAB_PREFIX` path prefixes supported; test connection from the Settings dialog

## Architecture

State management is **BLoC** (`flutter_bloc`).

```
lib/
├── main.dart                          # bootstrap: settings, notifications, BlocProvider
└── src/
    ├── bloc/
    │   ├── mailbox_bloc.dart          # events → states; wires WS + connectivity + notifications
    │   ├── mailbox_event.dart         # UI events + internal (_MailReceived, _WsStatusChanged, …)
    │   └── mailbox_state.dart         # single immutable state (Equatable)
    ├── models/models.dart             # MailMessage / MailMessageMetadata / Address / Attachment
    ├── services/
    │   ├── api_client.dart            # REST: /api/messages, /api/message/{id}, delete, raw, …
    │   ├── ws_listener.dart           # /ws listener with exponential-backoff reconnect
    │   ├── notification_service.dart  # flutter_local_notifications (macOS/iOS/Android/Linux/Windows)
    │   └── settings_service.dart      # persisted app settings (shared_preferences)
    └── ui/                            # responsive master–detail UI (Material 3)
```

## Getting started

1. Run a MailCrab server, e.g.:

   ```bash
   docker run --rm -p 1080:1080 -p 1025:1025 marlonb/mailcrab:latest
   ```

2. Run the app (macOS is the primary target):

   ```bash
   flutter run -d macos
   ```

3. The app connects to `http://localhost:1080` by default — change it in **Settings** (gear icon).

4. Point your application's SMTP config at `localhost:1025` and watch mail arrive.

> **Android emulator note:** use `http://10.0.2.2:1080` to reach a MailCrab running on the host machine.

## Tests

```bash
flutter test
```

Covers JSON parsing of the MailCrab API types, server-URL normalization, and mailbox state logic.

## Author

Bao Bui — [github.com/quocbao238](https://github.com/quocbao238)
