# Even Realities G1 BLE Protocol (working notes)

This repository implements a subset of the Even Realities G1 BLE protocol for the G1 glasses.

**Primary reference** (community reverse engineering):
- https://github.com/JohnRThomas/EvenDemoApp/wiki/Even-Realities-G1-BLE-Protocol

**Secondary reference** (Python implementation by this org):
- https://github.com/emingenc/even_glasses/tree/main/even_glasses

## Overview

### Dual-radio model
G1 uses **two BLE radios**: **Left** and **Right**.

- Some commands must be sent to **both sides**.
- Some commands are sent to **only one side** (commonly noted as Left or Right in the reference wiki).

### Transport
G1 uses the **Nordic UART Service (NUS)** with a stream of packets.

Known UUIDs (from `even_glasses` reference):
- UART Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- TX (Write):   `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- RX (Notify):  `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`

In this Flutter library, the BLE layer is under `lib/src/bluetooth/`.

### Sequences
The wiki describes:
- A **global sequence** used by many packets.
- A separate **audio sequence** used for audio streaming (`0xF1`) that resets when microphone is enabled/disabled.

This library maintains per-feature sequencing internally.

## Response codes
Many commands respond with a generic success/failure:
- Success: `0xC9`
- Failure: `0xCA`
- Continue: `0xCB` (used for multi-part transfers)

See `G1ResponseStatus` in `lib/src/protocol/commands.dart`.

## Messages (device → host)

### Audio stream (`0xF1`)
- Command: `0xF1`
- Payload: `[seq, audio_bytes...]`

The wiki calls out that `seq` is **not** the global sequence.

### Debug (`0xF4`)
- Command: `0xF4`
- Payload: NUL-terminated ASCII string

Enabled via System Control `0x23 0x6C`.

### Event (`0xF5`)
The device sends an `0xF5` event stream with subcodes (tap, head up/down, worn/in-case, battery level, etc.).

The wiki lists many event IDs; not all are handled in this library yet.

### Status (`0x22`)
The wiki documents status packets sent during head-up/tap scenarios.

## Commands (host → device)

This section lists the command IDs and how they map to the Flutter library.

### Brightness Set (`0x01`)
- Sets brightness level and/or auto brightness.
- Wiki: send to **Right**.
- Flutter: `G1Commands.brightness` and feature `g1_settings.dart`.

### Silent Mode Set (`0x03`)
- Toggles silent mode.
- Wiki: both sides.
- Flutter: `G1Commands.silentMode` and feature `g1_settings.dart`.

### Notification App List Set (`0x04`)
- Sends JSON configuration with allowlist of apps.
- Wiki: send to **Left**.
- Flutter: `G1Commands.setup` and feature `g1_notifications.dart`.

### Dashboard Set (`0x06`)
- Multi-subcommand container.
- Used for time/weather/calendar/news/map panes.
- Flutter: feature `g1_dashboard.dart` and `g1_time_weather.dart` (pane mode, calendar, news, stock, map all implemented).

Wiki highlights:
- Pane mode set (subcommand `0x06`)
- Calendar pane set (subcommand `0x03`)
- News pane set (subcommand `0x05`)
- Map pane set (subcommand `0x07`)

### Timer Control (`0x07`) (TODO)
Not implemented in this Flutter library.

### Head Up Action Set (`0x08`)
Controls what happens on head-up.
- Wiki: both sides.
- Flutter: implemented via `g1_settings.setHeadUpAction()`.

### Teleprompter Control (`0x09`) (TODO)
Not implemented in this Flutter library.

### Navigation Control (`0x0A`)
- Full-screen navigation feature.
- Flutter: `g1_navigation.dart`.

Wiki lists subcommands:
- `0x00` Init
- `0x01` Update Trip Status
- `0x02` Update Map Overview
- `0x03` Set Panoramic Map
- `0x04` App Sync Packet
- `0x05` Exit
- `0x06` Arrived

Note: turn icon codes are modelled by `G1NavigationTurn` in `lib/src/models/navigation_model.dart`.

### Head Up Angle Set (`0x0B`)
- Sets angle threshold.
- Wiki: Right side.
- Flutter: `g1_settings.dart`.

### Transcribe Control (`0x0D`) (TODO)
Not implemented as a first-class feature.

### Microphone Set (`0x0E`)
- Enables/disables microphone streaming.
- Wiki: Left side.
- Flutter: `lib/src/voice/` (enable/disable, wake-word and AI session events).

### Translate Control (`0x0F`) (TODO)
Not implemented as a first-class feature (Flutter has `g1_translate.dart`, but full protocol coverage is TBD).

### Head Up Calibration Control (`0x10`) (TODO)
Not implemented.

### File Upload (`0x15`)
- Upload BMP (1-bit, 576x136) in chunks.
- First packet includes storage address bytes: `00 1C 00 00`.
- Flutter: `g1_bitmap.dart`, `crc32.dart`.

### Bitmap Show (`0x16`)
- Shows a previously uploaded bitmap.
- Requires CRC32-XZ over (address + bmp data) as per wiki.
- Flutter: `g1_bitmap.dart`.

### Bitmap Hide / Clear (`0x18`)
- Clears screen.
- Flutter: `G1Commands.clearScreen`.

### Packet End (`0x20`)
- Ends transfers (used by BMP upload). Payload fixed: `[0x20, 0x0D, 0x0E]`.
- Flutter: `G1Commands.packetEnd`.

### Status Get (`0x22`) (TODO)
Not implemented.

### System Control (`0x23`)
Subcommands:
- Debug logging set: `0x23 0x6C 0x00/0xC1`
- Reboot: `0x23 0x72`
- Firmware build info get: `0x23 0x74`

Flutter: implemented in `g1_settings.dart` (`setDebugLogging`, `reboot`, `requestFirmwareInfo`).

### Teleprompter Suspend (`0x24`) (TODO)
Not implemented.

### Teleprompter Position Set (`0x25`) (TODO)
Not implemented.

### Hardware Set (`0x26`)
Used for display height/depth, double-tap action, long-press, head-lift mic.
Flutter: implemented in `g1_settings.dart` (`setDisplayPosition`, `setDoubleTapAction`, `setLongPressEnabled`, `setHeadLiftMicEnabled`).

### Wear Detection Set (`0x27`)
- Enable/disable wear detection.
- Flutter: `g1_settings.setWearDetection()`.

### Brightness Get (`0x29`) (TODO)
Not implemented.

### Silent Mode Get (`0x2B`) (TODO)
Not implemented.

### Info Battery and Firmware Get (`0x2C`)
Flutter: implemented in `g1_settings.dart` (`requestBatteryInfo`, `requestFirmwareInfo`).

### Notification App List Get (`0x2E`) (TODO)
Not implemented.

### Head Up Angle Get (`0x32`) (TODO)
Not implemented.

### Serial Number Lens Get (`0x33`) (TODO)
Not implemented.

### Serial Number Glasses Get (`0x34`) (TODO)
Not implemented.

### ESB Channel Get (`0x35`) (TODO)
Not implemented.

### ESB Notification Count Get (`0x36`) (TODO)
Not implemented.

### Time Since Boot Get (`0x37`) (TODO)
Not implemented.

### Notification Auto Display Get (`0x3C`) (TODO)
Not implemented.

### Language Set (`0x3D`)
Flutter: implemented in `g1_settings.setLanguage()`.

### Buried Point Get (`0x3E`) (TODO)
Not implemented.

### Hardware Get (`0x3F`) (TODO)
Command constant exists; getter not yet implemented in Flutter.

### Notification Auto Display Set (`0x4F`)
Not implemented.

### Text Set (`0x4E`)
- Displays full screen text (AI response, etc.).
- Flutter: `g1_display.dart`, `G1ScreenStatus`.

### Notification Send (`0x4B`)
- Sends JSON in chunks.
- Flutter: `g1_notifications.dart`.

### Notification Clear (`0x4C`) (TODO)
Not implemented.

### MTU Set (`0x4D`)
- Sets device MTU (often to 251).
- Flutter: `G1Commands.init` is currently `0x4D` (naming mismatch vs wiki).

### Unknown (`0x50`)
Wiki lists an unknown `0x50` command. Flutter currently labels `0x50` as `translate`, which is likely incorrect.

## Known gaps / TODOs

This library currently focuses on:
- BLE connectivity (left/right)
- Sending text (`0x4E`)
- Bitmap upload/display (`0x15`, `0x20`, `0x16`)
- Notifications (`0x04`, `0x4B`)
- Navigation (`0x0A`)
- Some settings (`0x01`, `0x03`, `0x0B`, `0x27`)

Many “Get” commands and System Control commands are not implemented yet.

If you want, we can add the missing implementations incrementally by:
1) aligning command IDs and names with the wiki,
2) adding parsers for incoming `0xF4`/`0xF5` messages,
3) implementing the highest-value TODOs (system info, debug, notification auto-display, etc.).
