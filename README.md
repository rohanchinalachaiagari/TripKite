# TripKit

**An offline-first iOS travel companion built in SwiftUI.**

TripKit keeps trips, itinerary items, travel documents, and reminders in one place — and works without a network connection.

![Trip List](Screenshots/trip-list.png)

---

## Overview

TripKit is a small, focused iOS app for organizing personal travel. Users can create trips, add itinerary items (flights, hotels, activities, restaurants, transportation, notes), attach local documents, and schedule local reminders for upcoming events. All data is stored on-device using Core Data and the app sandbox.

The project's goal is to demonstrate production-style iOS engineering in a small surface area: clean architecture, protocol-based dependency injection, local persistence, testable view models, and thoughtful offline-first behavior.

![Trip Detail](Screenshots/trip-detail.png)

---

## Why I Built It

I wanted a portfolio project that looked like real product code rather than a tutorial walkthrough. The constraints I set for myself:

- Pick a domain where offline reliability genuinely matters — travel is a great fit because connectivity is unpredictable when you actually need your itinerary.
- Use only Apple-native frameworks. No third-party packages, no Firebase, no networking.
- Build the architecture as if the app might one day need cloud sync, without actually building cloud sync.
- Make the codebase readable in a single afternoon by someone who has never seen it before.

The result is a deliberately small app with the kind of seams and tests I'd want in production.

---

## Core Features

- Create, edit, and delete trips
- Add itinerary items with type, time, location, confirmation number, and notes
- Chronological timeline grouped by day
- "Happening Now" and "Up Next" focus card on the trip detail screen
- Local reminders at preset offsets before an item (5 min / 15 min / 30 min / 1 hour / 1 day / at start time)
- Foreground and background notification delivery
- Notification tap routes directly into the trip and item
- Attach PDFs, images, and screenshots to a trip
- Optionally associate a document with a specific itinerary item
- QuickLook preview, rename, delete, and reassign documents
- Confirmation prompt when an itinerary item falls outside the trip's date range
- Empty and error states throughout

![Itinerary Timeline](Screenshots/itinerary-timeline.png)

---

## Technical Highlights

- **MVVM with protocol-based repositories.** View models depend on `TripRepository`, `ItineraryRepository`, `DocumentRepository`, and `NotificationSchedulingService` — never on Core Data, FileManager, or UNUserNotificationCenter directly.
- **Pure-Swift domain models.** `Trip`, `ItineraryItem`, and `TravelDocument` are `Sendable` value types with no framework dependencies. Core Data entities live behind a `+Mapping` extension boundary.
- **Background Core Data contexts.** Every repository call runs on a fresh background context, so the main thread never blocks on disk I/O.
- **File / Core Data split for attachments.** File bytes live in the app sandbox; only metadata lives in Core Data, with a rollback path if the metadata write fails after the file copy.
- **Deterministic view models.** `@Sendable () -> Date` injection lets tests pin "now" and verify focus-card, status, and reminder behavior without flakiness.
- **Two-step notification delegate.** A small `NotificationResponseHandler` bridges the `UNUserNotificationCenter` delegate callback (called on an arbitrary queue) to a `@MainActor`-isolated `AppRouter`.

---

## Architecture Overview

```text
SwiftUI View
    │
    ▼
ViewModel (@MainActor, ObservableObject)
    │
    ▼
Repository / Service protocol
    │
    ▼
Concrete implementation (Core Data / FileManager / UserNotifications)
```

- Views are declarative and route user intent to view models.
- View models own presentation state, validation orchestration, and async coordination.
- Repositories abstract persistence; services abstract system capabilities (notifications, document storage).
- Domain logic that isn't presentation lives in standalone enums (`TripValidator`, `ItineraryValidator`, `ItineraryFocusResolver`, `ImageFormatDetection`).
- `AppRouter` carries deep-link intent from notification taps into the navigation stack.

The dependency graph is constructed once in `TripKitApp.init` and threaded down through initializers.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI, NavigationStack |
| State | `@StateObject` / `@ObservedObject`, `@MainActor` view models |
| Persistence | Core Data (background contexts) |
| Files | FileManager, sandboxed `Documents/Attachments/` |
| Notifications | UserNotifications (UNUserNotificationCenter, time-interval triggers) |
| Document preview | QuickLook (`QLPreviewController` wrapped in `UIViewControllerRepresentable`) |
| Pickers | PhotosUI, `fileImporter` |
| Concurrency | Swift Concurrency (`async`/`await`, actor-isolated contexts) |
| Tests | XCTest |
| Min iOS | 17.6 |

No third-party packages.

---

## Core Data Persistence

The schema has three entities (`TripEntity`, `ItineraryItemEntity`, `TravelDocumentEntity`) connected by `Cascade` / `Nullify` rules so deletes behave correctly:

- Deleting a trip cascades to its items and document records.
- Deleting an item nullifies the relationship on associated documents — the document is preserved at trip level rather than vanishing.
- Deleting a document removes only its record (and, separately, the file on disk).

Each entity has a `UUID` `id` with a uniqueness constraint and `NSMergeByPropertyObjectTrumpMergePolicy` configured on every background context.

Repositories accept a `CoreDataStack` instance and never expose `NSManagedObject` to callers; mapping happens in `+Mapping` extensions that produce pure-Swift value types. This makes view models trivially testable with in-memory mocks.

```swift
protocol TripRepository: Sendable {
    func fetchTrips() async throws -> [Trip]
    func trip(with id: UUID) async throws -> Trip?
    func createTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
}
```

---

## Local Notifications & Reminders

Reminders are pure local notifications — no APNs, no server. The user picks a preset offset on the item editor (e.g. "15 minutes before"); the editor saves the item, then asks `NotificationSchedulingService` to cancel any prior reminder for that item id and schedule a fresh one.

The scheduling service builds an identifier of the form `trip-<tripId>-item-<itemId>`, which lets it cancel a single reminder by item id or every reminder for a trip on deletion.

Permission handling:

- Authorization is requested lazily — the first time the user changes the reminder picker away from "None."
- If the user denies, the editor surfaces an inline hint pointing them to Settings.
- Scheduling errors (e.g. the reminder time is already in the past) are non-fatal; the item still saves.

Foreground delivery is wired through the `UNUserNotificationCenterDelegate.willPresent` callback so reminders fire even when the app is open.

---

## Document Storage

Documents are split between Core Data and the file system:

- The file bytes (PDF, image, screenshot) are copied into `Documents/Attachments/` under a UUID-based filename.
- The `TravelDocumentEntity` records the display name, file type, file size, relative path, and optional `itineraryItemId` association.

Key behaviors:

- A 25 MB per-file cap, checked before copy when the size is reported and again on raw-data writes.
- Security-scoped URL bracketing for the document picker (`startAccessingSecurityScopedResource` / `stop`).
- Photo imports use magic-byte detection to choose `.png` vs `.jpg` vs `.heic` and pick a `Screenshot-` or `Photo-` prefix.
- If the metadata write fails after the file is copied, the file is rolled back so orphans aren't left on disk.
- Trip deletion fetches document paths before the cascade, then sweeps the files; per-file failures are non-fatal.

```swift
protocol DocumentStorageService: Sendable {
    func saveDocument(
        from sourceURL: URL,
        suggestedFileName: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument

    func saveDocument(
        from data: Data,
        fileName: String,
        fileType: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument

    func deleteFile(at relativePath: String) async throws
    func absoluteURL(for document: TravelDocument) throws -> URL
}
```

---

## Notification Routing

When the user taps a reminder banner, the system delivers the response to `NotificationResponseHandler`, which:

1. Parses the `userInfo` payload via `NotificationRouteParser` into a `PendingTripRoute { tripId, itemId? }`.
2. Hops to the `@MainActor` and assigns the route to `AppRouter.pendingTripDetail`.

`TripListView` observes that publisher and, on a non-nil route:

1. Resolves the trip from the repository (in case the entity was deleted between scheduling and delivery).
2. Resets the navigation path and pushes a `TripDestination { trip, focusItemId }` value.
3. Clears the pending route.

`TripDetailView` consumes `focusItemId` once after items load, opening the editor for the targeted item. A one-shot `hasConsumedFocus` flag prevents re-presentation if the user dismisses the editor and the `.task` re-fires on back-navigation.

This keeps deep linking in the navigation layer — no router coupling pushed into the detail view, no race between the route clear and the consumer.

---

## Testing Strategy

The test suite covers business logic, repository round-trips, and view-model behavior. Roughly 20 test files exercise:

- **View models** — `TripListViewModel`, `TripDetailViewModel`, `TripEditorViewModel`, `ItineraryItemEditorViewModel`, `DocumentListViewModel` (load, save, delete, validation, focus, error paths, reminder scheduling, outside-range confirmation, rename, item association).
- **Repositories** — `CoreDataTripRepository`, `CoreDataItineraryRepository`, `CoreDataDocumentRepository` using in-memory stacks (CRUD, sort order, foreign-key errors, cascade and nullify rules).
- **Services** — `FileManagerDocumentStorageService` round-trips real files in a sandboxed temp dir, including 25 MB cap enforcement and idempotent deletes.
- **Domain utilities** — `ItineraryFocusResolver`, `TravelDocument` filtering, `ImageFormatDetection`, `ReminderOption`, `NotificationRouteParser`, `AppRouter`.

Patterns used:

- Actor-isolated mocks (`MockTripRepository`, `MockDocumentRepository`, etc.) for view-model tests.
- `@Sendable () -> Date` injection for deterministic "now."
- Real in-memory Core Data stacks (`CoreDataStack(inMemory: true)`) for repository tests rather than mocking Core Data itself.

---

## Known Limitations

Honest list of what V1 doesn't do:

- **No cloud sync.** Trips and documents are device-local. Reinstalling or switching devices loses data unless restored from an iCloud device backup.
- **No timezone awareness for reminders.** Reminder fire times are absolute offsets from the item's stored `Date`. If the user changes timezones between scheduling and delivery, the fire moment doesn't shift to the destination's local time.
- **No Core Data model migration scaffolding.** The schema is at version 1. The first schema change post-ship will require adding a model version and lightweight migration setup.
- **No orphan file sweeper.** If the app is force-killed between a file copy and the metadata write, an orphan file may be left in the sandbox. In-process error paths roll back correctly.
- **No search or filtering.** The trip list shows Upcoming and Past sections; itinerary items are timeline-sorted only.
- **No widget, no settings screen.**
- **Reminders persist a `reminderOffset` even if the user has denied notifications.** An inline hint surfaces in the editor, but a denied state is not flagged on the trip detail or item row.

---

## Future Roadmap

These are out of scope for V1 and explicitly not yet implemented:

- Cloud sync via CloudKit (the repository layer is shaped to make this additive rather than a rewrite).
- A TestFlight beta build for friends and family.
- Per-itinerary destination timezone support for reminders.
- Reservation / screenshot OCR import.
- Real-time collaboration on a shared trip.
- Search across trips and itinerary items, plus type-based filters.
- A WidgetKit widget showing the next upcoming event.
- A settings screen for default reminder offsets and notification preferences.
- Optional Firebase or other backend integration (currently unused).

---

## Setup

**Requirements**

- Xcode 16 or newer
- iOS 17.6 or newer (simulator or device)
- macOS Sonoma or newer

**Steps**

```bash
git clone https://github.com/<your-username>/TripKit.git
cd TripKit
open TripKit.xcodeproj
```

In Xcode:

1. Select the `TripKit` scheme.
2. Choose an iPhone simulator (or a real device for notification testing — banners do not render in the simulator until you trigger them manually).
3. Press **⌘R** to run.
4. Press **⌘U** to run the test suite.

No package resolution or signing setup is required for simulator builds.

---

## Manual QA Checklist

A short script for verifying the happy paths before tagging a build:

- [ ] Create a trip, add an itinerary item, confirm it appears in the timeline grouped under the correct day.
- [ ] Edit the trip's title and confirm the change propagates to the trip detail header and list row.
- [ ] Delete an itinerary item via swipe; confirm the row disappears and any reminder for it is cancelled.
- [ ] Add an item with start date outside the trip's range; confirm the "Outside trip dates" confirmation appears and respects Cancel / Save Anyway.
- [ ] Add an item with a 1-minute reminder; lock the device; confirm the banner fires and tapping it opens the item's editor.
- [ ] Schedule a reminder a minute out and leave the app foregrounded; confirm a banner and sound appear.
- [ ] Attach a PDF via Files; verify the row shows file name, size, and type, and that tap opens QuickLook.
- [ ] Attach a screenshot via Photos; verify the row title starts with `Screenshot-` or `Photo-`.
- [ ] Rename a document with and without a matching extension suffix; verify the trailing `.png` / `.pdf` is stripped from the display name.
- [ ] Assign a document to an itinerary item via the context menu; confirm a paperclip icon appears on the item's timeline row.
- [ ] Open that item's editor and confirm the associated document is listed in the Documents section.
- [ ] Delete a trip with attached documents; confirm both records and files are removed.
- [ ] Attempt to import a file larger than 25 MB; confirm a "too large" alert appears and nothing is copied.

---

## Interview Talking Points

Things I'd highlight in a deep-dive conversation:

- **Offline-first by construction.** Everything is local on the device. There's no syncing layer to hide behind; correctness has to come from the local model.
- **Protocol-based dependency injection** without a DI framework. The graph is constructed in `TripKitApp.init` and threaded down. Repositories and services all conform to `Sendable` protocols that mocks satisfy directly.
- **Concurrency model.** View models are `@MainActor`. Repositories are `nonisolated` and create a fresh background `NSManagedObjectContext` per call. `NotificationResponseHandler` is `@unchecked Sendable` and hops to the MainActor before mutating `AppRouter`.
- **File / metadata coordination.** The two-write (file copy then Core Data save) sequence and its rollback path. The 25 MB cap. The decision to keep file bytes out of Core Data.
- **Notification identifier design.** `trip-<tripId>-item-<itemId>` lets a single string identifier serve both "cancel one reminder" and "cancel all reminders for a deleted trip."
- **Deep-link routing.** A small `AppRouter` + `TripDestination` value type carry intent from a notification tap into the navigation stack without coupling the detail view to the router.
- **Testability tradeoffs.** Repository tests use real in-memory Core Data because mocking Core Data itself buys you nothing; view-model tests use actor-isolated mocks because they need to assert call counts and inject failures.
- **Honest about limits.** No cloud sync, no timezones, no migrations yet. V1 was scoped down deliberately so the architecture would have room to add those without a rewrite.
