# 🦀 MailCrab Client

[![Release](https://img.shields.io/github/v/release/quocbao238/mailcrab_client)](https://github.com/quocbao238/mailcrab_client/releases/latest)
[![CI](https://github.com/quocbao238/mailcrab_client/actions/workflows/release.yml/badge.svg)](https://github.com/quocbao238/mailcrab_client/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A native desktop & mobile client for [MailCrab](https://github.com/tweedegolf/mailcrab) — the email testing server for development. Stop keeping a browser tab open: get your test emails in a native app with **system notifications the moment mail arrives**, an unread badge on the app icon, and a fast searchable inbox.

- ⚡ **Real-time inbox** — new mail appears instantly (WebSocket, with automatic fallback to polling)
- 🔔 **Native notifications** — with a preview of the email body; click to open the message
- 🔴 **Unread badge** on the app icon (macOS Dock, Windows taskbar)
- 📎 View HTML / plain text / raw source / headers, download attachments
- 🎨 Light/dark mode and theme colors, applied instantly
- 🔌 Works with any MailCrab server — local Docker or remote, HTTPS and path prefixes supported

## 📥 Download

Click your platform to download the latest version directly:

<p align="center">
  <a href="https://github.com/quocbao238/mailcrab_client/releases/latest/download/MailCrab-macos.dmg"><img src="https://img.shields.io/badge/macOS-Download%20.dmg-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS"></a>&nbsp;
  <a href="https://github.com/quocbao238/mailcrab_client/releases/latest/download/MailCrab-linux-x64.tar.gz"><img src="https://img.shields.io/badge/Linux-Download%20.tar.gz-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Download for Linux"></a>&nbsp;
  <a href="https://github.com/quocbao238/mailcrab_client/releases/latest/download/MailCrab-android.apk"><img src="https://img.shields.io/badge/Android-Download%20.apk-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Download for Android"></a>&nbsp;
  <a href="https://github.com/quocbao238/mailcrab_client/releases/latest/download/MailCrab-windows-x64.zip"><img src="https://img.shields.io/badge/Windows-Download%20.zip-0078D4?style=for-the-badge" alt="Download for Windows"></a>
</p>

macOS builds are universal (Intel & Apple Silicon); Linux/Windows are x64. Older versions live on the [Releases page](https://github.com/quocbao238/mailcrab_client/releases).

## 🚀 Install

### macOS

1. Open the `.dmg` and drag **MailCrab** into **Applications**.
2. First launch: macOS may warn that the app is from an unidentified developer (it isn't notarized yet). Fix it with either:
   - **System Settings → Privacy & Security →** scroll down **→ Open Anyway**, or
   - Terminal: `xattr -cr /Applications/MailCrab.app`
3. Allow notifications when prompted. If banners don't appear, make sure **Focus / Do Not Disturb is off**.

### Linux

```bash
mkdir -p ~/mailcrab && tar xzf MailCrab-linux-x64.tar.gz -C ~/mailcrab
~/mailcrab/mailcrab_client
```

Requires GTK 3 (preinstalled on most desktops) and a notification daemon (GNOME, KDE, XFCE… all work).

### Windows

Unzip anywhere and run `mailcrab_client.exe`. Notifications appear as standard Windows toasts; the unread count shows as a red overlay on the taskbar icon.

### Android

Install the APK (enable "Install from unknown sources" if asked). To reach a MailCrab running on your computer, use your machine's LAN IP in Settings (e.g. `http://192.168.1.20:1080`) — or `http://10.0.2.2:1080` from the Android emulator.

## 🏁 Getting started

1. Run a MailCrab server if you don't have one:

   ```bash
   docker run --rm -p 1080:1080 -p 1025:1025 marlonb/mailcrab:latest
   ```

2. Open MailCrab Client — it connects to `http://localhost:1080` by default. Use **Settings** (⚙) to point it at any other server and hit **Test connection**.
3. Point your application's SMTP settings at `localhost:1025` and watch the mail roll in — with a notification for every message.

## 🛠 Development

Built with Flutter (BLoC state management). PRs welcome!

```bash
flutter pub get
flutter test          # unit tests
flutter run -d macos  # or: -d linux, -d windows, an Android device…
```

Project layout: `lib/src/bloc` (state), `lib/src/services` (MailCrab REST/WebSocket API, notifications, badges, settings), `lib/src/ui` (Material 3 responsive UI). The MailCrab API surface used: `GET /api/messages`, `GET /api/message/{id}`, `POST /api/delete/{id}`, `POST /api/delete-all`, and the `/ws` WebSocket for real-time events.

### Releasing

Releases are fully automated ([release.yml](.github/workflows/release.yml)). Maintainers just push a semver tag:

```bash
git tag v1.2.3
git push --tags
```

CI runs the tests, builds **Android APK, Linux tar.gz, macOS DMG, and Windows zip** (all stamped with the tag version), and publishes them to a GitHub Release with auto-generated notes.

## 📄 License

[MIT](LICENSE) — © 2026 [Bao Bui (@quocbao238)](https://github.com/quocbao238)
