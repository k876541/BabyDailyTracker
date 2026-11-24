# BabyDailyTracker

[![CI](https://github.com/k876541/BabyDailyTracker/actions/workflows/ci.yml/badge.svg)](https://github.com/k876541/BabyDailyTracker/actions/workflows/ci.yml)

BabyDailyTracker is a local-first SwiftUI app for recording a toddler's meals, sleep, diaper activity, and growth history.

## MVP features

- Baby profile with name, birthday, age, latest height, and latest weight
- Meal, sleep, and diaper record creation, editing, deletion, and history
- Date-based history with daily and rolling seven-day summaries
- Cross-midnight sleep duration allocated to the calendar days it overlaps
- Five-minute quick time selection with optional exact `HH:mm` input
- Height-only, weight-only, or combined growth measurements
- Backdated measurements sorted by their actual measurement time
- Height and weight trends built with Swift Charts
- Latest measurement and change from the previous valid measurement of the same type
- Input validation for missing, non-numeric, zero, negative, and non-finite values
- Fixed-time medication reminder courses with configurable start date and duration
- Four- or five-hour minimum interval validation, including across midnight
- Local notification actions for marking a reminder complete or snoozing it
- Configurable snooze interval in five-minute steps and actual completion-time history
- Up to 48 fixed reminder occurrences per course
- Same-day medication courses skip elapsed times and begin at the next future occurrence
- Settings reset with two confirmations removes all local baby records and pending medication reminders

## Architecture

- SwiftUI
- MVVM
- Repository pattern
- SwiftData
- Swift Charts
- Swift Testing

## Requirements

- Xcode 27 or later
- iOS 18 or later

## Run

Open `ToddlerDailyTracker.xcodeproj`, select an iPhone simulator, and run the `ToddlerDailyTracker` scheme.

Medication reminders require notification permission. The system controls whether notifications appear immediately as banners or are delayed by Focus or Notification Summary settings. Notification timing and actions should be verified on a simulator or device; the command-line build does not exercise delivery.

Removing baby data from Settings permanently clears the local profile, daily records, growth history, medication history, and pending medication notifications. This action cannot be undone.

## Test

```sh
swift test
```

## Continuous integration

GitHub Actions runs the complete unit test suite and builds the iOS Simulator app for every push and pull request. The CI build disables code signing, so it does not require an Apple Developer membership or signing credentials.

## MVP exclusions

- WHO growth percentiles
- Medical advice
- Cloud sync or user accounts
- Medicine names, dosage, units, photos, and multiple concurrent medication courses
- Automatic rescheduling of later reminders after a late completion
- Remote push notifications or cross-device reminder sync

