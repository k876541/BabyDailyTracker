# Fixed-Time Medication Reminder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a finite-course, fixed-time medication reminder with local notification actions, completion history, snoozing, and minimum-interval validation.

**Architecture:** Keep SwiftUI + MVVM + Repository + SwiftData. Put reminder UI, domain rules, scheduling abstraction, coordinator, and focused documentation in `Features/MedicationReminder`; keep persistent models in the existing model layer and isolate `UNUserNotificationCenter` behind a protocol so domain and action handling are deterministic in tests.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, UserNotifications, Swift Testing, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-11-23-medication-reminder-design.md`

## Global Constraints

- Support one active reminder course; do not add medicine name, dosage, units, photos, multiple concurrent courses, medical advice, backend, APNs, accounts, or sync.
- Use one-time local notifications and cap fixed occurrences at 48.
- Minimum interval is selectable as exactly 240 or 300 minutes; default is 240 minutes.
- Snooze is positive, defaults to 5 minutes, and the UI changes it in five-minute steps.
- Late completion never changes the next fixed occurrence; it may only produce a time-based warning.
- Notification actions are `MEDICATION_COMPLETED` and `MEDICATION_SNOOZE` in category `MEDICATION_REMINDER`.
- Keep notification and SwiftData failures user-visible; do not force unwrap or crash.
- New concurrency-sensitive UI and persistence types are `@MainActor`; no detached or unmanaged fire-and-forget task.
- Do not add third-party packages.

## Review Focus

- A course spanning midnight must validate the last time of one day against the first time of the next day; Task 1 pins this with `crossDayGapBelowMinimumIsRejected`.
- A time-zone or clock change must not silently leave stale future requests; Task 4 pins reconciliation with `reconcileReplacesFutureRequests`.
- Partial notification scheduling must roll back already-added requests and avoid a saved half-course; Task 4 pins this with `createRollsBackAfterSchedulingFailure`.
- Repeated snooze must replace the previous snooze request rather than accumulate requests; Task 3 pins this with `snoozeUsesStableReplacementIdentifier`.
- A completion action arriving twice must remain idempotent and preserve the first actual completion time; Task 4 pins this with `completeActionIsIdempotent`.

---

### Task 1: Schedule Domain and Validation

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationSchedule.swift`
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/DESIGN.md`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationScheduleTests.swift`

**Interfaces:**
- Consumes: `Foundation.Calendar`, a caller-provided calendar, and the current feature spec.
- Produces: `MedicationReminderTime`, `MedicationReminderDraft`, `MedicationScheduleValidationError`, and `MedicationScheduleBuilder.occurrenceDates(for:calendar:) throws -> [Date]`.

- [ ] **Step 1: Write failing schedule tests**

Add tests named `emptyTimesAreRejected`, `duplicateTimesAreRejected`, `invalidDurationIsRejected`, `invalidMinimumIntervalIsRejected`, `invalidSnoozeIsRejected`, `crossDayGapBelowMinimumIsRejected`, `exactFourHourGapIsAccepted`, `exactFiveHourGapIsAccepted`, `moreThanFortyEightOccurrencesIsRejected`, and `occurrencesAreChronological`. Assert exact error cases and exact generated dates using a fixed Gregorian UTC calendar.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationScheduleTests`

Expected: FAIL because the schedule types do not exist.

- [ ] **Step 3: Implement the schedule types**

Define:

```swift
struct MedicationReminderTime: Hashable, Codable, Sendable {
    let hour: Int
    let minute: Int
}

struct MedicationReminderDraft: Equatable, Sendable {
    var startDate: Date
    var durationDays: Int
    var times: [MedicationReminderTime]
    var minimumIntervalMinutes: Int
    var snoozeMinutes: Int
}

enum MedicationScheduleValidationError: Error, Equatable {
    case invalidDuration
    case noReminderTimes
    case invalidTime
    case duplicateTime
    case unsupportedMinimumInterval
    case invalidSnooze
    case intervalTooShort(requiredMinutes: Int)
    case tooManyOccurrences(maximum: Int)
    case invalidCalendarDate
}

enum MedicationScheduleBuilder {
    static let maximumOccurrences = 48
    static func occurrenceDates(for draft: MedicationReminderDraft, calendar: Calendar) throws -> [Date]
}
```

Expand all dates first, sort them, then validate every adjacent pair so cross-day gaps use the same rule. Add a focused `DESIGN.md` covering responsibility, data flow, invariants, notification IDs, and concurrency ownership without duplicating the full product spec.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --disable-sandbox --filter MedicationScheduleTests`

Expected: all MedicationSchedule tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/MedicationReminder Tests/ToddlerDailyTrackerTests/MedicationScheduleTests.swift
git commit -m "feat: validate medication reminder schedules"
```

### Task 2: SwiftData Models and Repository

**Files:**
- Modify: `Sources/ToddlerDailyTracker/Models/Models.swift`
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderRepository.swift`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationReminderRepositoryTests.swift`

**Interfaces:**
- Consumes: `MedicationReminderDraft` and chronological dates from Task 1.
- Produces: `MedicationReminderPlan`, `MedicationReminderTimeModel`, `MedicationDoseOccurrence`, `MedicationDoseStatus`, and the `MedicationReminderRepository` protocol used by Tasks 4–6.

- [ ] **Step 1: Write failing in-memory SwiftData tests**

Add tests named `createStoresOneActivePlanAndOccurrences`, `secondActivePlanIsRejected`, `replaceUpdatesPlanAndOccurrenceGraph`, `todayOccurrencesAreChronological`, `completeStoresActualTime`, `completingTwicePreservesFirstTime`, `snoozeStoresOnlyLatestReminderTime`, `endMarksPendingOccurrencesSkipped`, and `deleteRemovesThePlanGraph`. Use a `ModelConfiguration(isStoredInMemoryOnly: true)` containing all three new models.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationReminderRepositoryTests`

Expected: FAIL because the models and repository do not exist.

- [ ] **Step 3: Add persistence models**

Add `@Model` types matching the spec. Persist UUID identifiers explicitly. Define `MedicationDoseStatus: String, Codable, Sendable` with `pending`, `snoozed`, `completed`, and `skipped`; expose a safe computed status that maps unknown stored values to `pending` without crashing.

- [ ] **Step 4: Implement the repository**

Define the `@MainActor` interface:

```swift
protocol MedicationReminderRepository: AnyObject {
    func activePlan() throws -> MedicationReminderPlan?
    func create(draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan
    func replace(planID: UUID, draft: MedicationReminderDraft, dates: [Date]) throws -> MedicationReminderPlan
    func occurrences(on date: Date, calendar: Calendar) throws -> [MedicationDoseOccurrence]
    func futureOccurrences(from date: Date) throws -> [MedicationDoseOccurrence]
    func complete(occurrenceID: UUID, at date: Date) throws
    func snooze(occurrenceID: UUID, until date: Date) throws
    func end(planID: UUID, at date: Date) throws
    func delete(planID: UUID) throws
}
```

Implement `SwiftDataMedicationReminderRepository` with one save per public mutation and explicit `MedicationReminderRepositoryError` cases for missing occurrence, missing plan, and active plan already present.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `swift test --disable-sandbox --filter MedicationReminderRepositoryTests`

Expected: all repository tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/ToddlerDailyTracker/Models/Models.swift Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderRepository.swift Tests/ToddlerDailyTrackerTests/MedicationReminderRepositoryTests.swift
git commit -m "feat: persist medication reminder courses"
```

### Task 3: Local Notification Scheduler

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationNotificationScheduler.swift`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationNotificationSchedulerTests.swift`

**Interfaces:**
- Consumes: occurrence UUID, scheduled date, and snooze date.
- Produces: `MedicationNotificationScheduling`, `MedicationNotificationAuthorization`, request identifier helpers, and `UserNotificationMedicationScheduler`.

- [ ] **Step 1: Write failing scheduler contract tests**

Use a recording notification-center adapter and add `fixedRequestContainsOccurrenceIDAndCategory`, `snoozeUsesStableReplacementIdentifier`, `cancelRemovesFixedAndSnoozeRequests`, `registersCompletedAndSnoozeActions`, and `authorizationStatesMapWithoutForceUnwrap`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationNotificationSchedulerTests`

Expected: FAIL because the scheduler contract does not exist.

- [ ] **Step 3: Implement notification abstractions**

Define:

```swift
enum MedicationNotificationAuthorization: Equatable, Sendable {
    case notDetermined, authorized, denied
}

@MainActor
protocol MedicationNotificationScheduling: AnyObject {
    func authorizationStatus() async -> MedicationNotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func registerActions()
    func scheduleFixed(occurrenceID: UUID, at date: Date) async throws
    func scheduleSnooze(occurrenceID: UUID, at date: Date) async throws
    func cancel(occurrenceIDs: [UUID])
}
```

Use `medication.fixed.<UUID>` and `medication.snooze.<UUID>` as stable request identifiers. Build `UNNotificationCategory` with the exact identifiers in Global Constraints. Do not use text-input actions in this version.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --disable-sandbox --filter MedicationNotificationSchedulerTests`

Expected: all scheduler tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationNotificationScheduler.swift Tests/ToddlerDailyTrackerTests/MedicationNotificationSchedulerTests.swift
git commit -m "feat: schedule medication notifications"
```

### Task 4: Transaction Coordinator and Notification Actions

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderCoordinator.swift`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationReminderCoordinatorTests.swift`

**Interfaces:**
- Consumes: schedule builder from Task 1, repository from Task 2, and scheduler from Task 3.
- Produces: `MedicationReminderCoordinator.create`, `update`, `complete`, `snooze`, `end`, `delete`, and `reconcile` for ViewModels and notification responses.

- [ ] **Step 1: Write failing coordinator tests with fakes**

Add tests named `createRequestsPermissionWhenUndetermined`, `deniedPermissionDoesNotCreateCourse`, `createSchedulesAllOccurrences`, `createRollsBackAfterSchedulingFailure`, `updateReplacesOccurrencesAndRequests`, `updateFailureRestoresPreviousSchedule`, `completeActionIsIdempotent`, `snoozeReplacesPreviousRequest`, `lateCompletionDoesNotMoveNextOccurrence`, `endCancelsFutureRequests`, `deleteCancelsFutureRequests`, and `reconcileReplacesFutureRequests`. Assert repository mutations and exact scheduler calls; do not use `sleep`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationReminderCoordinatorTests`

Expected: FAIL because the coordinator does not exist.

- [ ] **Step 3: Implement the `@MainActor` coordinator**

Define:

```swift
@MainActor
final class MedicationReminderCoordinator {
    func create(_ draft: MedicationReminderDraft) async throws
    func update(planID: UUID, draft: MedicationReminderDraft) async throws
    func complete(occurrenceID: UUID, at date: Date) async throws
    func snooze(occurrenceID: UUID, now: Date) async throws
    func end(planID: UUID, at date: Date) async throws
    func delete(planID: UUID) async throws
    func reconcile(now: Date) async throws
}
```

Inject repository, scheduler, calendar, and `now`. If notification scheduling fails, cancel request IDs already scheduled and remove the newly created plan. An update snapshots the old draft and future occurrence IDs, replaces the graph, and restores the old graph and requests if rescheduling fails. Completion is a no-op when already completed. Reconciliation cancels and recreates only future pending or snoozed requests.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run: `swift test --disable-sandbox --filter MedicationReminderCoordinatorTests`

Expected: all coordinator tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderCoordinator.swift Tests/ToddlerDailyTrackerTests/MedicationReminderCoordinatorTests.swift
git commit -m "feat: coordinate medication reminder state"
```

### Task 5: Reminder ViewModel and SwiftUI Flow

**Files:**
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderViewModel.swift`
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderView.swift`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationReminderViewModelTests.swift`

**Interfaces:**
- Consumes: repository and coordinator from Tasks 2 and 4.
- Produces: `MedicationReminderViewModel` state and `MedicationReminderView(context:)` used by `MainTabView`.

- [ ] **Step 1: Write failing ViewModel tests**

Add `emptyStateWhenNoPlan`, `loadShowsTodayOccurrences`, `maximumDaysReflectsFortyEightOccurrenceLimit`, `saveShowsIntervalValidationMessage`, `savePreventsReentry`, `lateCompletionProducesGapWarningWithoutChangingSchedule`, `endReloadsState`, and `repositoryFailureBecomesUserMessage`.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationReminderViewModelTests`

Expected: FAIL because the ViewModel does not exist.

- [ ] **Step 3: Implement ViewModel state and actions**

Create an `@MainActor @Observable` ViewModel with `activePlan`, `todayOccurrences`, editable `draft`, `isSaving`, `errorMessage`, `intervalWarning`, and computed `maximumDurationDays`. Expose `load()`, `save() async`, `end() async`, and `delete() async`; `save()` calls create when no plan exists and update when editing an active plan, and ignores a second save while one is active.

- [ ] **Step 4: Implement the reminder screens**

Build the empty, setup, and active-course states described in the spec. Use a five-minute wheel/stepper for daily times and snooze, show inline validation before save, sort times, and expose edit/end/delete actions with destructive confirmation. Do not add medicine-specific fields or medical language.

- [ ] **Step 5: Run focused and full tests**

Run: `swift test --disable-sandbox --filter MedicationReminderViewModelTests`

Expected: all ViewModel tests pass.

Run: `swift test --disable-sandbox`

Expected: all existing and new tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderViewModel.swift Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationReminderView.swift Tests/ToddlerDailyTrackerTests/MedicationReminderViewModelTests.swift
git commit -m "feat: add medication reminder screens"
```

### Task 6: App Lifecycle, Notification Response, and Navigation

**Files:**
- Modify: `Sources/ToddlerDailyTracker/ToddlerDailyTrackerApp.swift`
- Modify: `Sources/ToddlerDailyTracker/Views/ContentView.swift`
- Create: `Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationNotificationDelegate.swift`
- Modify: `ToddlerDailyTracker.xcodeproj/project.pbxproj`
- Test: `Tests/ToddlerDailyTrackerTests/MedicationNotificationResponseTests.swift`

**Interfaces:**
- Consumes: coordinator action methods and reminder view from Tasks 4–5.
- Produces: cold-launch-safe notification response routing and the fourth `提醒` tab.

- [ ] **Step 1: Write failing response-routing tests**

Add `completedActionRoutesOccurrenceID`, `snoozeActionRoutesOccurrenceID`, `unknownActionIsIgnored`, `malformedOccurrenceIDIsIgnored`, and `foregroundPresentationRequestsBannerAndSound`. Test a platform-neutral response router; keep UIKit delegate code thin.

- [ ] **Step 2: Run the focused tests and verify RED**

Run: `swift test --disable-sandbox --filter MedicationNotificationResponseTests`

Expected: FAIL because response routing does not exist.

- [ ] **Step 3: Implement response routing and iOS delegate**

Create `MedicationNotificationResponseRouter` with explicit action and occurrence ID inputs. Under `#if os(iOS)`, implement `UNUserNotificationCenterDelegate`; on response, create one structured `Task { @MainActor in ... }`, await coordinator handling, and always call the system completion handler. Register categories before notifications can arrive and support cold launch with the same shared `ModelContainer` used by SwiftUI.

- [ ] **Step 4: Register models and add the Reminder tab**

Add the three new models to the app's shared schema, inject the container into the notification delegate/coordinator, add `MedicationReminderView(context:)` as the fourth tab with a bell icon, and reconcile future notifications when the app becomes active.

- [ ] **Step 5: Register all new source files in the Xcode project**

Add explicit PBX file references, source build entries, and group children for every new production Swift file. Tests remain compiled by Swift Package tests and do not need an Xcode test target in the current project.

- [ ] **Step 6: Run focused tests and build**

Run: `swift test --disable-sandbox --filter MedicationNotificationResponseTests`

Expected: all response tests pass.

Run: `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/BabyDailyTrackerDerivedData CODE_SIGNING_ALLOWED=NO build`

Expected: exit code 0.

- [ ] **Step 7: Commit**

```bash
git add Sources/ToddlerDailyTracker/ToddlerDailyTrackerApp.swift Sources/ToddlerDailyTracker/Views/ContentView.swift Sources/ToddlerDailyTracker/Features/MedicationReminder/MedicationNotificationDelegate.swift ToddlerDailyTracker.xcodeproj/project.pbxproj Tests/ToddlerDailyTrackerTests/MedicationNotificationResponseTests.swift
git commit -m "feat: handle medication notification actions"
```

### Task 7: End-to-End Verification and Documentation

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml` only if the existing commands do not discover all new tests.

**Interfaces:**
- Consumes: the complete feature from Tasks 1–6.
- Produces: documented behavior and a verified branch ready to push.

- [ ] **Step 1: Update README**

Document fixed-time reminders, the 48-occurrence limit, notification permission, completed/snooze actions, the lack of medicine details and dynamic rescheduling, and simulator/manual-test limitations.

- [ ] **Step 2: Run complete automated verification**

Run: `swift test --disable-sandbox`

Expected: all existing and new tests pass.

Run: `xcodebuild -quiet -project ToddlerDailyTracker.xcodeproj -scheme ToddlerDailyTracker -destination 'generic/platform=iOS Simulator' -derivedDataPath /private/tmp/BabyDailyTrackerDerivedData CODE_SIGNING_ALLOWED=NO build`

Expected: exit code 0.

Run: `git diff --check`

Expected: no output.

- [ ] **Step 3: Perform focused manual verification**

On an iOS Simulator or device, grant notifications; create a short course; confirm a foreground banner; use「已完成」and verify actual time; use「知道了」and verify the configured delay; deny permission and verify recovery guidance; edit and delete a course and confirm pending notifications are removed.

- [ ] **Step 4: Run Swift concurrency and structure review**

Use the installed `swift-vc-code-review` skill in diff mode. The feature is SwiftUI-only, so enforce feature-folder ownership, focused `DESIGN.md`, `@MainActor` persistence/UI boundaries, structured notification tasks, and tests for cancellation, reentry, stale responses, and error paths.

- [ ] **Step 5: Commit documentation or review fixes**

```bash
git add README.md .github/workflows/ci.yml Sources Tests ToddlerDailyTracker.xcodeproj/project.pbxproj
git commit -m "docs: document medication reminders"
```

- [ ] **Step 6: Push and verify GitHub Actions**

Run: `git push -u origin feature/medication-reminders`

Expected: branch is pushed and the CI workflow passes its formatting, unit test, and iOS Simulator build checks.
