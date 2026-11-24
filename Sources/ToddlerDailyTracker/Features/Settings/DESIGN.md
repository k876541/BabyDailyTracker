# Settings Feature

## Responsibility

Settings owns destructive local-data reset. It does not edit individual records or manage multiple babies.

## Data flow

`SettingsView` advances `SettingsViewModel` through two confirmation stages. The repository deletes every local root model in one ModelContext save and returns medication occurrence IDs. Only after persistence succeeds does the ViewModel cancel those notification requests and report success to the App root, which returns to onboarding.

## Failure behavior

Persistence failure keeps the user on Settings, preserves the onboarding state, does not cancel notifications, and exposes a user-visible error. Repeated confirmation calls cannot execute another reset after the confirmation state is consumed.

## Tests

Swift Testing uses an in-memory ModelContainer to verify every model is removed and focused ViewModel doubles to verify confirmation, single execution, notification cancellation, and failure behavior.
