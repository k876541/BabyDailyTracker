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

## UI states and errors

The reminder tab has an empty state, an editable course form, and an active-course state with today's occurrences. Validation failures stay in the editor, notification denial explains that permission is required, and persistence or scheduling failures become retryable alerts. Saving ignores repeated taps until the active operation completes.

## Tests

Swift Testing covers schedule boundaries, cross-midnight intervals, the 48-occurrence limit, in-memory SwiftData create/update/delete and ordering, completed-record preservation, notification request construction, authorization states, rollback, repeated snooze, action routing, ViewModel validation, dependency failure, and save reentry without fixed sleeps.

## Known limitations

The system controls banner delivery under Focus and Notification Summary. The first version supports one active course, fixed future times, and local notifications only; it does not store medicine details, provide medical advice, use remote push, or dynamically move later times after a late completion.
