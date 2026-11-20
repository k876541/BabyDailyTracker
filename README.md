# BabyDailyTracker

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

## Test

```sh
swift test
```

## MVP exclusions

- WHO growth percentiles
- Medical advice
- Cloud sync or user accounts
- Medication reminders and notification actions are planned for a later phase

