# MedicationReminder

## Responsibility

Own one finite fixed-time medication reminder course, its local notification schedule, and the user's completed or snoozed responses. It does not model medicine identity, dosage, medical advice, accounts, or sync.

## Data flow

SwiftUI sends an editable draft to an `@MainActor` ViewModel. The schedule builder validates and expands it into at most 48 chronological dates. A coordinator keeps SwiftData and the notification scheduler consistent. Notification responses return an occurrence UUID to the same coordinator before the ViewModel reloads persisted state.

## Invariants

- One active course.
- Minimum interval is 240 or 300 minutes, including across midnight.
- Fixed occurrence count is at most 48.
- Late completion never moves the next fixed occurrence.
- One occurrence has one fixed notification ID and at most one snooze notification ID.

## Notification identifiers

- Fixed: `medication.fixed.<occurrence UUID>`
- Snooze: `medication.snooze.<occurrence UUID>`
- Category: `MEDICATION_REMINDER`
- Actions: `MEDICATION_COMPLETED`, `MEDICATION_SNOOZE`

## Concurrency

SwiftData, ViewModel, coordinator, and notification scheduling boundaries are main-actor isolated. Notification delegate callbacks enter one structured main-actor task and always complete the system callback.
