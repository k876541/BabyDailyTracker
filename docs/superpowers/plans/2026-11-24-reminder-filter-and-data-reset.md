# Reminder Filtering and Data Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Skip elapsed occurrences when a medication course starts today and add a double-confirmed settings flow that clears all local baby data.

**Architecture:** The medication coordinator filters expanded occurrence dates against an injected clock before persistence. A Settings feature owns a reset repository, coordinator, view model, view, and focused design document; the App root receives reset completion and returns to onboarding.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, UserNotifications, Swift Testing

**Spec:** `docs/superpowers/specs/2026-11-24-reminder-filter-and-data-reset-design.md`

## Global Constraints

- Keep SwiftUI + MVVM + Repository + SwiftData.
- Support one local baby only; reset removes all local records and pending medication notifications.
- Require two explicit confirmations before reset.
- Do not add cloud sync, accounts, or recovery.
- Do not dispatch subagents.

## Review Focus

- A course beginning today with mixed elapsed/future times keeps only future occurrences, including all later days.
- A course with no future occurrence is rejected without persisting data or requesting notifications.
- Reset removes every root model and the medication child graph without leaving orphaned data.
- Reset failure does not navigate to onboarding or cancel notifications for data that remains.
- Confirmation re-entry cannot execute reset more than once.

---

### Task 1: Filter elapsed medication occurrences

**Files:**
- Modify: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderCoordinator.swift`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationReminderCoordinatorTests.swift`

**Interfaces:**
- Consumes: `MedicationScheduleBuilder.occurrenceDates(for:calendar:)` and the coordinator's injected `now` closure.
- Produces: `create(_:)` persists and schedules only dates strictly later than the captured current time.

- [ ] Add a failing coordinator test for 09:00, 13:00, 17:00 at 12:17 over two days; expect today 13:00/17:00 plus all three next-day occurrences.
- [ ] Run the focused test and confirm the persisted schedule still contains 09:00 today.
- [ ] Capture `now()` once, filter dates with `> currentDate`, and reject only when the filtered array is empty.
- [ ] Run the coordinator tests and full Swift test suite.
- [ ] Commit with `fix: skip elapsed medication occurrences`.

### Task 2: Reset all local baby data

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/Settings/AppDataResetRepository.swift`
- Create: `Sources/ToddlerDailyTracker/Features/Settings/SettingsViewModel.swift`
- Create: `Sources/ToddlerDailyTracker/Features/Settings/DESIGN.md`
- Create: `Tests/ToddlerDailyTrackerTests/AppDataResetRepositoryTests.swift`
- Create: `Tests/ToddlerDailyTrackerTests/SettingsViewModelTests.swift`
- Modify: `Package.swift`

**Interfaces:**
- Produces: `AppDataResetRepository.reset() throws -> [UUID]`, returning medication occurrence IDs after a successful SwiftData save.
- Produces: `SettingsViewModel` confirmation state and `confirmPermanentReset() async -> Bool`; the result is true only after data reset and notification cancellation succeed.

- [ ] Add failing in-memory SwiftData tests proving every model type is cleared and occurrence IDs are returned.
- [ ] Implement the reset repository with typed fetch/delete operations and one final save.
- [ ] Add failing ViewModel tests proving first confirmation has no side effect, second confirmation resets once, failure remains on settings, and notification IDs are cancelled only after success.
- [ ] Implement the reset coordinator/ViewModel with `@MainActor` isolation, re-entry protection, and user-visible errors.
- [ ] Run focused tests and the full suite.
- [ ] Commit with `feat: reset local baby data`.

### Task 3: Add Settings UI and return to onboarding

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/Settings/SettingsView.swift`
- Modify: `Sources/ToddlerDailyTracker/ViewModels/GrowthViewModel.swift`
- Modify: `Sources/ToddlerDailyTracker/Views/ContentView.swift`
- Modify: `ToddlerDailyTracker.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Test: `Tests/ToddlerDailyTrackerTests/BabyOnboardingTests.swift`

**Interfaces:**
- Consumes: `SettingsViewModel.confirmPermanentReset()` and its confirmation stage.
- Produces: a fifth Settings tab; successful reset calls `AppLaunchViewModel.showOnboarding()`.

- [ ] Add a failing AppLaunchViewModel test that reset completion moves `.ready` to `.needsBabyProfile` and selects the Today tab for the next onboarding completion.
- [ ] Implement the root transition method and Settings tab with two sequential alerts, destructive copy, progress state, and error alert.
- [ ] Add all new source files to the Xcode project and exclude `Features/Settings/DESIGN.md` from SwiftPM resources.
- [ ] Update README limitations and reset behavior.
- [ ] Run all Swift tests, generic iOS Simulator build, `git diff --check`, and a Swift Concurrency scan.
- [ ] Commit with `feat: add baby data reset settings`.
