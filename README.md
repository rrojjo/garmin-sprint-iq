# Series — Speedwork Chrono IQ

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Platform: Garmin Connect IQ](https://img.shields.io/badge/platform-Connect%20IQ-007CC3)
![Min API 3.4.0](https://img.shields.io/badge/API-3.4.0%2B-blue)
![Language: Monkey C](https://img.shields.io/badge/language-Monkey%20C-orange)

A lap stopwatch for track intervals ("series"), built as a Garmin Connect IQ
watch app. It records the session as a native Garmin activity
(running / track) named **Series**, with heart rate and one FIT lap per split,
so your workouts sync to Garmin Connect like any other run.

## Features

- **Lap stopwatch with a big current-lap display**: tenths of a second on the
  main clock, hundredths in the lap history.
- **Instant lap feedback**: after pressing LAP, the closed lap stays on screen
  for 4 seconds while the next one keeps timing.
- **Lap history** of the three most recent laps, scrollable with UP/DOWN; the
  fastest lap is highlighted in green.
- **Status line** with time of day, total elapsed time and live heart rate;
  battery level is shown when idle.
- **Native FIT recording** (`SPORT_RUNNING` / `SUB_SPORT_TRACK`); pausing the
  stopwatch also pauses the recording.
- **Pause menu**: Resume, *Lap and continue* (to fix an accidental pause),
  View laps, Settings, Save and Discard (with confirmation).
- **Crash recovery**: lap times and elapsed time are checkpointed to local
  storage; if the app closes unexpectedly, the session is restored in the
  paused state. An active recording is saved if the app is stopped.
- **Settings**: vibration, lap sound and dark/light theme.
- **Localized** in English and Spanish.
- **Smooth rendering**: frames are composed in an off-screen buffer and the
  main clock is redrawn only when the visible tenth changes.

## Controls

| Button | Stopped | Running | Paused (pause menu open) |
| --- | --- | --- | --- |
| START | Start | Pause and open pause menu | Select menu item |
| BACK / LAP | Exit app | Mark lap | *Lap and continue* |
| UP / DOWN | Scroll lap history | Scroll lap history | Navigate menu |
| Hold UP (menu) | Settings | — | — |

## Requirements

- [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) (API level 3.4.0 or later)
- Supported device: **Garmin Forerunner 55** (`fr55`)
- Optional: Visual Studio Code with the Monkey C extension

## Build and sideload

### 1. Generate your own developer key

The signing key is private and is not part of this repository. Create one
(or use *Monkey C: Generate a Developer Key* in VS Code):

```sh
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key -nocrypt
```

Keep `developer_key` at the repository root; it is git-ignored.

### 2. Compile

From the `stopwatch/` folder:

```sh
monkeyc -f monkey.jungle -d fr55 -o bin/Series.prg -y ../developer_key -w -l 3 -r -O 2
```

On Windows, `monkeyc.bat` lives in the SDK's `bin` folder. The path to the
active SDK can be read from `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg`.

### 3. Run in the simulator

```sh
connectiq                      # start the simulator
monkeydo bin/Series.prg fr55
```

### 4. Sideload to the watch

Connect the watch via USB and copy `bin/Series.prg` to `GARMIN/APPS/`.
Replace any previous copy of the app instead of keeping two versions.

## Tests

Unit tests (run with the simulator open):

```sh
monkeyc -f monkey.jungle -d fr55 -o bin/Series-tests.prg -y ../developer_key -w -l 3 -t
monkeydo bin/Series-tests.prg fr55 /t
```

They cover pause handling, time accumulation, restore while paused,
formatting, save on exit and the 4-second lap preview.

Integration app (uses the real simulator clock, production view and native
recording; records two laps, pauses, resumes and saves):

```sh
monkeyc -f integration.jungle -d fr55 -o bin/Series-integration.prg -y ../developer_key -w -l 3
monkeydo bin/Series-integration.prg fr55
```

Simulator FIT files are written to
`%TEMP%\com.garmin.connectiq\GARMIN\Activities` (Windows). Run the integration
app in a fresh simulator session to avoid leftovers from the accelerated unit
tests.

## Project structure

```
stopwatch/
├── manifest.xml                    # App manifest (fr55, Fit + Sensor permissions)
├── monkey.jungle                   # Production build
├── integration.jungle              # Integration build (adds tests/)
├── integration-manifest.xml
├── resources/                      # English strings, launcher icon
├── resources-spa/                  # Spanish strings
├── source/
│   ├── stopwatchApp.mc             # Entry point, restore / force-save
│   ├── StopwatchSession.mc         # Timing state machine, FIT recording, persistence
│   ├── stopwatchView.mc            # Buffered rendering, lap list, HR, battery
│   ├── stopwatchDelegate.mc        # Buttons, vibration and lap tone
│   ├── stopwatchMenuDelegate.mc    # Pause menu
│   ├── PausedLapsDelegate.mc       # Lap list while paused
│   ├── DiscardConfirmationDelegate.mc
│   ├── SettingsMenuDelegate.mc
│   ├── Settings.mc                 # Persistent settings
│   └── StopwatchTests.mc           # Unit tests
└── tests/
    └── IntegrationApp.mc           # Integration test app
```

## Limitations

- Crash recovery restores laps and elapsed time from the last local checkpoint;
  if Garmin lost the native recording, past sensor samples cannot be rebuilt.
- Only the Forerunner 55 is targeted; other devices may need layout changes.

## License

Released under the [MIT License](LICENSE). © 2026 Pablo Rojo.
