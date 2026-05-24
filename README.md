# grod_remote

<p align="center">
  <img src="assets/grod-remote-logo-01.webp" alt="grod_remote logo" width="280" />
</p>

A Flutter phone remote for the [`grod`](https://github.com/captainzonks/grod) /
[`grod_tv`](https://github.com/captainzonks/grod_tv) cast daemons. Drives the
same `http://<daemon>:7878` API from Android (and, by virtue of Flutter, can be
rebuilt for iOS / desktop on demand).

Built against:

- Flutter 3.44.0 stable
- Dart 3.12
- `multicast_dns` 0.3.3 (with Android-safe `reusePort` shim)
- `http` 1.x, `shared_preferences` 2.x, `provider` 6.x

## What it does

- **Discovers** running grod daemons on the LAN via the `_grod._tcp.local.`
  mDNS service. Auto-fills host/port; presents a chooser if more than one
  daemon answers.
- **Casts** any YouTube/Piped URL from clipboard or via search.
- **Drives playback** — play/pause, seek ±10s, volume, mute, skip.
- **Manages the queue** — add, remove, view.
- **Configures the daemon** — default quality preset, Piped instance URL,
  PIN. Settings written here are pushed to the daemon and persisted locally
  so the client can re-assert them after a daemon restart.

## Screens

| Screen   | Purpose                                                                   |
| -------- | ------------------------------------------------------------------------- |
| Home     | Now-playing card, transport controls, queue list, Cast-URL FAB            |
| Search   | Free-text Piped search → tap result to cast or queue                      |
| Settings | Server discovery, host/port/PIN, Piped instance preset picker, quality    |

## Settings model

Local state lives in `SharedPreferences` under these keys (see
`lib/services/app_state.dart`):

| Key                  | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `server_host`        | Daemon LAN IP                                                            |
| `server_port`        | Daemon port (`7878` default)                                             |
| `server_pin`         | Optional `X-Grod-Pin` value                                              |
| `default_quality`    | User's preferred cast quality, independent of `status.quality`           |
| `last_piped_url`     | Most recent Piped instance the user picked                               |

The reason `default_quality` and `last_piped_url` are tracked locally rather
than reading the daemon's `/status` response on every open is that
`status.quality` reports the **currently loaded track's** resolved height,
which would silently downgrade the displayed default to 360p whenever a
low-bitrate stream was the last thing cast.

## Daemon API client

`lib/services/grod_api.dart` is a thin `package:http`-backed wrapper around
the daemon's REST surface. See
[`grod_tv/docs/api.md`](https://github.com/captainzonks/grod_tv/blob/main/docs/api.md)
for the wire format — the Flutter client and the daemon track the same
schema 1:1.

Endpoints used here:

- `GET /status` (polled every 3s while a server is configured)
- `GET /search?q=...`
- `POST /cast {url, force?}`
- `POST /queue {url}` / `DELETE /queue` / `DELETE /queue/{pos}`
- `POST /skip`, `/play-pause`, `/volume-up`, `/volume-down`, `/mute`, `/unmute`
- `POST /forward {seconds}`, `/back {seconds}`
- `POST /quality {quality}`
- `POST /piped-url {url}`

## mDNS discovery (Android quirk)

The `multicast_dns` package's default socket factory passes `reusePort: true`,
which Android's Dart runtime rejects with

```
Dart Socket ERROR: socket_linux.cc:157: `reusePort` not supported on this platform.
```

`lib/services/discovery.dart` overrides the factory to force `reusePort=false`
on Android while preserving the default behavior elsewhere. Without this
patch the Settings → "Find server on LAN" path silently returns no results
even when the daemon is broadcasting.

## VPN gotcha

Proton VPN (and most "kill-switch" VPN clients) route LAN traffic through the
tunnel by default. If the discovery dialog and HTTP requests both fail with
"Cannot reach server" while the daemon is visible from your laptop, check
your VPN's split-tunnel / "allow LAN" setting. The fix is on the VPN side;
the app has no opinion about your routing table.

## Building

```bash
flutter pub get
flutter run            # debug build, hot-reload
flutter build apk      # release APK at build/app/outputs/flutter-apk/
```

The repo ships pre-commit hooks (ggshield) — `pre-commit install` after
clone if you intend to commit. Hooks block accidental secret commits.

## License

MIT.
