# OneTaskFocus

OneTaskFocus is a minimal focus timer built with SwiftUI and SwiftData.

## App Summary

OneTaskFocus helps users do one thing at a time:

- choose a single task
- start a focus timer
- finish the session
- review simple local history

The app is designed to feel quiet, fast, and uncluttered. There are no accounts, no ads, and no subscription flow.

## Features

- Single-task focus timer
- Preset durations
- Pause and end session controls
- Session completion flow
- Local session history
- Streak and focus totals
- Appearance and accent settings
- Local notifications when a session ends

## Tech Stack

- SwiftUI
- SwiftData
- UserNotifications

## Project Structure

- `OneTaskFocus/ContentView.swift`: main app UI and timer flow
- `OneTaskFocus/Item.swift`: SwiftData model for saved focus sessions
- `OneTaskFocus/OneTaskFocusApp.swift`: app entry point and model container
- `OneTaskFocus/Assets.xcassets`: colors and app icon assets

## Privacy

OneTaskFocus stores focus session data locally on device. It does not require an account and does not depend on a remote backend.

See `PRIVACY.md` for the full privacy policy.

## Support

See `SUPPORT.md` for support information.
