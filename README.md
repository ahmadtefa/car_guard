# Car Guard 🚗

A Flutter application that turns an ESP8266 module into a live vehicle
monitor: engine temperature, battery voltage, coolant level, and radiator fan
status streamed straight to your phone over Wi-Fi.

## Features

- **Live dashboard** — engine temperature, battery voltage, voltage
  difference, coolant level, and fan status update in real time.
- **Robust transport** — live updates over WebSocket (port 81) with an
  automatic HTTP polling fallback when the socket drops.
- **Smart alerts** — dashboard banner + local notifications when:
  - the engine overheats (warning & critical thresholds),
  - the battery voltage drops below your minimum,
  - the coolant level runs low,
  - the device connection is lost.
- **Settings page** — configure the device address and every alert threshold;
  everything is persisted on the phone and restored on the next launch.
- **Auto reconnect** — the app reconnects to the last saved device address on
  startup.
- **Live charts** — engine temperature and battery voltage sparklines for the
  last five minutes (dependency-free CustomPainter).
- **Device controls** — mute the buzzer, run the fan test, or reboot the
  module straight from the dashboard (`/mute`, `/testfan`, `/restart`).
- **Demo mode** — simulate a full device (thermostat cycles, alternator
  voltage swings, low-coolant windows) to explore the app without hardware.
- **4 gauge styles + classic cards** — Racing bars, sporty analog gauges with
  a redline, vertical segmented bars and the Audi sweeper, straight from the
  original Kayan dashboard; switch with the palette button.
- **Full-screen HUD** — tap any gauge to see one giant live reading.
- **Alternator & fan cards** — charging status with live animations.
- **High-voltage alert** — warns when charging voltage exceeds your maximum.
- **Module settings screen** — read/edit the limits stored on the ESP8266
  itself (`/getallsettings` + `/saveallsettings`), test fan, restart, and
  provision the module Wi-Fi (`/savewifi`).
- **Theme choice** — Auto / Light / Dark, persisted with the rest of the
  settings.
- **Arabic + English UI** — full translation with automatic RTL layout; quick
  toggle from the dashboard.
- **Module-borne limits** — alarm thresholds reported by the firmware in the
  live stream override the app-side ones, exactly like the original dashboard.
- **Automatic WebSocket reconnect** — up to 10 attempts with growing delay,
  HTTP polling keeps running meanwhile.
- **In-app alarm siren** — loops while a warning/critical alert is active,
  with a mute toggle that also silences the module buzzer.
- **Correct CSV protocol** — `temp,volt,fanState,?,maxTemp,fanOnTemp,
  minVolt,maxVolt,offset`, matching the reference firmware.
- **Background monitoring (Android)** — a foreground service keeps polling
  the module every 5 seconds with the screen off, shows live readings in a
  persistent notification, fires alert notifications, and auto-starts after
  phone reboot (enable it from Settings).

## Architecture

The project follows a feature-first layout on top of Riverpod:

```
lib/
├── app/                    # Entry point, router, root widget
├── core/
│   ├── constants/          # Colors, spacing, endpoints, strings
│   ├── models/             # AppSettings, DeviceAlert, shared data models
│   ├── providers/          # Riverpod wiring for device & status streams
│   ├── services/           # ESP8266 repository, alerts, notifications,
│   │                       # storage, connectivity, permissions, OTA
│   ├── theme/              # Material 3 theme
│   └── widgets/            # Shared design-system widgets
└── features/
    ├── dashboard/          # Live dashboard cards + alerts banner
    ├── device/             # Device connection screen
    └── settings/           # Device address & alert thresholds
```

Key components:

| Component | Responsibility |
| --- | --- |
| `Esp8266Repository` | WebSocket + HTTP communication with the module |
| `AlertEvaluator` | Pure logic mapping readings + settings → alerts |
| `AlertsNotifier` | De-duplicates alerts and fires notifications |
| `SettingsNotifier` | Loads/saves `AppSettings` via SharedPreferences |
| `NotificationServiceImpl` | Local notifications (Android & iOS) |

## Device protocol

The repository accepts two payload formats:

**JSON** (preferred):

```json
{
  "volt": 12.58,
  "voltDiff": 0.12,
  "temp": 92.5,
  "coolant": 1,
  "fanState": 1,
  "buzzerState": 0
}
```

**CSV** (fallback): `temp,volt,coolant,fan,buzzer,voltDiff`

HTTP endpoints exposed by the module (`DeviceEndpoints`): `/data`,
`/getallsettings`, `/saveallsettings`, `/saveadvancedsettings`,
`/calibratevoltage`, `/getwifisettings`, `/savewifi`, `/restart`, `/mute`,
`/testfan`, `/update`.

## Getting started

```bash
flutter pub get
flutter run              # debug on a connected device/emulator
flutter analyze          # static analysis
flutter test             # run the test suite
```

Pair your phone with the ESP8266 access point (or the same network), then set
the module address in **Connection** or **Settings**. The default is
`192.168.4.1:81`.

## Android Auto

The app ships an Android Auto front-end (`CarGuardCarAppService`): on a
supported head unit (or the Desktop Head Unit for testing) it shows live
engine temperature, battery voltage, fan state and the module alarm,
color-coded by the thresholds the module reports. It reads the saved
device address from the app settings and polls `/data` every 5 seconds.

> Note: vehicle-monitoring is not a Play-Store-distributable Android Auto
> category — this integration is for personal (sideloaded) use.
> CarPlay is not possible: Apple restricts CarPlay to specific app
> categories (audio, navigation, messaging…).

## Play Store

See `docs/play-store-checklist.md` for the full Arabic release roadmap.
Key points: `applicationId` is `com.kayan.carguard` (change before first
upload — it can never change after), the Android Auto service block must
be removed from the manifest for Play builds (disallowed category), and a
release keystore is required.

## Testing

Tests live in `test/` and mirror the `lib/` layout:

```bash
flutter test
```

## Roadmap

- [ ] OTA firmware updates from the app (`/update`)
- [ ] Persist readings history across sessions (currently in-memory)
- [x] Localization (Arabic + English) — done
- [x] Advanced calibration screen (offset, R1/R2, pull-up, voltage wizard) — done
- [x] In-app alarm siren while an alert is active — done
