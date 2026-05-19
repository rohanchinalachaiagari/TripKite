# TripKite

**An offline-first iOS travel companion built in SwiftUI.**

TripKite keeps trips, itinerary items, travel documents, and reminders in one place. It all works without a network connection.

![Trip List](Screenshots/trip-list.png)

---

## Overview

TripKite is a focused iOS app for organizing personal travel. Users can create trips, add itinerary items (flights, hotels, activities, restaurants, transportation, notes), attach local documents, and schedule local reminders for upcoming events. All data is stored on-device using Core Data and the app sandbox.

The project is a small surface area built with production-style engineering: clean architecture, protocol-based dependency injection, local persistence, testable view models, and offline-first behavior.

![Trip Detail](Screenshots/trip-detail.png)

---

## Motivation

Travel apps are a natural fit for offline-first design: connectivity is unpredictable exactly when an itinerary matters most. TripKite was built as a portfolio project that holds itself to the same constraints a real product would:

- Apple-native frameworks only — no third-party packages, no networking, no backend.
- Architecture shaped so cloud sync could be added later without a rewrite.
- A codebase small enough to read in a single sitting and complete enough to ship.

---

## Core Features

- Create, edit, and delete trips
- Add itinerary items with type, time, location, confirmation number, and notes
- Chronological timeline grouped by day
- "Happening Now" and "Up Next" focus card on the trip detail screen
- Local reminders at preset offsets (5 min / 15 min / 30 min / 1 hour / 1 day / at start time)
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
- **MainActor bridging for notifications.** A `NotificationResponseHandler` bridges the `UNUserNotificationCenter` delegate callback (called on an arbitrary queue) to a `@MainActor`-isolated `AppRouter`.

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

The dependency graph is constructed once in `TripKiteApp.init` and threaded down through initializers.

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
- Deleting an item nullifies the relationship on associated documents. The document is preserved at trip level rather than vanishing.
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

Reminders are pure local notifications. The user picks a preset offset on the item editor (e.g. "15 minutes before"); the editor saves the item, then asks `NotificationSchedulingService` to cancel any prior reminder for that item id and schedule a fresh one.

The scheduling service builds an identifier of the form `trip-<tripId>-item-<itemId>`, which lets it cancel a single reminder by item id or every reminder for a trip on deletion.

Permission handling:

- Authorization is requested lazily. The first time the user changes the reminder picker away from "None."
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

The test suite covers business logic, repository round-trips, and view-model behavior. The suite exercises:

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

- **No cloud sync.** Trips and documents are device-local. Reinstalling or switching devices loses data unless restored from an iCloud device backup.
- **No timezone awareness for reminders.** Reminder fire times are absolute offsets from the item's stored `Date`. Changing timezones between scheduling and delivery does not shift the fire moment to the destination's local time.
- **No Core Data model migration scaffolding.** The schema is at version 1. The first schema change post-ship will require adding a model version and lightweight migration setup.
- **No orphan file sweeper.** If the app is force-killed between a file copy and the metadata write, an orphan file may be left in the sandbox. In-process error paths roll back correctly.
- **No search or filtering.** The trip list shows Upcoming and Past sections; itinerary items are timeline-sorted only.
- **No widget, no settings screen.**
- **Reminders persist a `reminderOffset` even if the user has denied notifications.** An inline hint surfaces in the editor, but the denied state is not flagged on the trip detail or item row.

---

## Future Roadmap

Out of scope for V1 and explicitly not yet implemented:

- Cloud sync via CloudKit (the repository layer is shaped to make this additive rather than a rewrite).
- A TestFlight beta build.
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
git clone https://github.com/<your-username>/TripKite.git
cd TripKite
open TripKite.xcodeproj
```

In Xcode:

1. Select the `TripKite` scheme.
2. Choose an iPhone simulator (or a real device for notification testing — banners do not render in the simulator until triggered manually).
3. Press **⌘R** to run.
4. Press **⌘U** to run the test suite.

No package resolution or signing setup is required for simulator builds.

---

## Quality Checks

Run the XCTest suite with **⌘U** before tagging a build. The suite covers the persistence layer, view models, validators, and the notification route parser.

For manual verification, walk through the trip creation, reminder firing (both lock-screen and foreground), and document attachment flows on a real device. A more detailed checklist lives in [`docs/QA.md`](docs/QA.md).

---

## Engineering Decisions

A few design choices worth calling out:

- **Pure-Swift domain models with a mapping boundary.** `NSManagedObject` subclasses never leak out of the persistence layer. View models and tests work exclusively with `Sendable` value types, which keeps the test suite fast and the rest of the codebase decoupled from Core Data.
- **A fresh background context per repository call.** Reads and writes never block the main thread, and each call is its own transactional boundary. Repository tests use real in-memory Core Data stacks rather than mocking Core Data itself — Core Data's behavior is too load-bearing to mock cheaply.
- **Files outside Core Data, metadata inside.** Document bytes live in the app sandbox under a UUID filename; only metadata is persisted. The two-write sequence has an explicit rollback so a failed metadata write doesn't leave orphan files on disk.
- **Protocol-based dependency injection without a framework.** The graph is built once in `TripKiteApp.init` and threaded down through view initializers. Each system capability (notifications, document storage) sits behind a `Sendable` protocol that mocks satisfy directly.
- **Single notification identifier scheme.** `trip-<tripId>-item-<itemId>` lets the scheduling service cancel a single reminder by item id or every reminder for a trip on deletion using a single substring match — no separate index needed.
- **Deep-link routing as a navigation value.** Notification taps produce a `PendingTripRoute`, which becomes a `TripDestination { trip, focusItemId }` pushed onto the navigation stack. The detail view consumes `focusItemId` once after items load. Routing intent lives in the navigation layer rather than as state shared between the router and the detail screen.
- **Deferred Core Data migration scaffolding.** The schema is intentionally at version 1. Migration setup is straightforward to add when the first schema change is needed; adding it preemptively would be premature complexity.
