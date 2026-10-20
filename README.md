# BatteryHealthLens

See your battery's cycle count, true capacity and wear in a menu bar popover, with a daily health history.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![Release](https://img.shields.io/github/v/release/turhe123/battery-health-lens)

## Why

BatteryHealthLens is a free, open-source, 100% native, backend-free alternative to paid utilities in the *Battery & Power* category. It was inspired by apps such as Battery Health 3 ($9.99 one-time), and aims to cover the same everyday need: knowing how worn your Mac's battery really is. It reads the battery data macOS already exposes, keeps everything on your Mac, and needs no account or server.

## Features

- **Menu bar item** showing the charge percentage, with a bolt icon while charging (the percentage can be hidden in Settings).
- **Health ring** with the battery health percentage (maximum capacity ÷ design capacity), colored green, orange or red, plus charging / on adapter / on battery status.
- **Stat tiles**: cycle count, design capacity, full-charge capacity, current charge (mAh), temperature, voltage, amperage, adapter connected, and adapter wattage. Values a Mac doesn't report are shown as a dash.
- **Health History chart** (Swift Charts) built from one snapshot per day, with 1M, 6M and All ranges. It says "Collecting data, check back tomorrow" until two snapshots exist.
- **Optional alerts** via local notifications when health falls below a threshold (50–100%) or the cycle count reaches a chosen number (100–3000). Each alert fires once per crossing.
- **Copy Report** puts a plain-text summary of the current readings on the clipboard.
- **Settings**: alert thresholds, show/hide percentage in the menu bar, Celsius or Fahrenheit, and launch at login.
- **Automatic refresh** every 30 seconds, on power source changes, and on wake from sleep.
- **Empty state** on Macs without a battery ("No Battery Found").
- **Small local history**: a JSON file in `~/Library/Application Support/BatteryHealthLens/history.json`, limited to five years; implausible readings (above 120%) are discarded.

## Screenshots

_Screenshots coming soon._

## Install

1. Download `BatteryHealthLens-macOS.zip` from the [latest release](https://github.com/turhe123/battery-health-lens/releases/latest).
2. Unzip it and move `BatteryHealthLens.app` to `/Applications`.
3. Because the app is open source and not notarized, remove the quarantine attribute:

   ```bash
   xattr -cr /Applications/BatteryHealthLens.app
   ```

4. Right-click the app and choose **Open** the first time you launch it.

Requires macOS 14.0 or later.

## Build from source

You need Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project BatteryHealthLens.xcodeproj -scheme BatteryHealthLens -configuration Release -derivedDataPath ./build build
```

The app is produced at `build/Build/Products/Release/BatteryHealthLens.app`.

## Permissions

BatteryHealthLens reads the `AppleSmartBattery` entry from the IOKit registry, which any normal user can read, so it needs **no** Accessibility, Screen Recording, Microphone, Camera, Location or Full Disk Access permission. The only system prompts you may see are:

- **Notifications**: requested only when you turn on alerts in Settings, so the app can tell you when health or cycle count crosses your thresholds. If the app is denied, alerts simply don't appear.
- **Login item**: if you enable "Launch at login", macOS registers the app through `ServiceManagement` and may show it in System Settings › General › Login Items.

## Built with AI

BatteryHealthLens was written by [Claude Code](https://claude.com/claude-code) inside an automated pipeline, from a plain-English spec. No code, binaries or assets from any commercial app were used; it is a clean-room reimplementation of a feature set, not a copy.

What that means in practice:

- The full source is in this repo under the MIT license. Read it before you run it.
- No network calls, no analytics, no third-party dependencies. Only Apple frameworks.
- Ad-hoc signed and not notarized, which is why Gatekeeper warns on first launch.
- It has had less human review than a hand-written app. Bug reports and pull requests are welcome.

## Support ❤️

If BatteryHealthLens is useful to you, you can support its development:

[Support Or (Leo) Davidai ❤️](https://ko-fi.com/leodavidai)

The app also has a "Support / Donate ❤️" button in the popover and in Settings.

## License

MIT © Or Davidai Bachar
