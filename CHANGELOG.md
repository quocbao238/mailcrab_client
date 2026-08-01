# Changelog

## 1.1.0

Support for MailCrab servers that sit behind an SSO login.

### Added

- **Sign in with SSO.** An embedded sign-in window (Settings → *Sign in with
  SSO*, or the *Sign in* button on the banner) handles gateways that redirect
  the API to an identity provider. The resulting session cookie is sent with
  every REST call and on the WebSocket handshake, so the live inbox keeps
  working — not just polling.
- **Silent session renewal.** The gateway cookie is short-lived, but the
  identity provider's own session outlives it. When a request comes back
  rejected the app replays the redirect chain in the background and picks up a
  fresh cookie with no interaction; the status chip briefly reads
  "Signing in…". You are only asked to sign in again once that longer session
  is gone too.
- **Manual auth cookie** field in Settings, for platforms without an embedded
  WebView (Linux) and for CI.

### Changed

- Redirects are no longer followed on API calls. A gateway answers an
  unauthenticated request with a redirect to its login page; following it
  returned HTML and surfaced as a confusing JSON parse error. Redirects, 401
  and 403 are now reported as "sign-in required".
- When a session is rejected the app stops retrying instead of polling every
  10 seconds against a server that will keep refusing.
- Inline `cid:` images in HTML mail are fetched through the authenticated
  client and embedded, so they render on SSO-protected servers.

### Fixed

- The Settings dialog overflowed on short windows; its content now scrolls.
- Events raised from timers, sockets and platform callbacks after the app
  shut down could crash with "Cannot add new events after calling close".

## 1.0.0

First release: live inbox over MailCrab's WebSocket, REST client, desktop
notifications on new mail, and a Material 3 master–detail UI.
